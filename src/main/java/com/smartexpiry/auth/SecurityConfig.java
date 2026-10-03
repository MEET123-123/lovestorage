package com.smartexpiry.auth;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.*;
import org.springframework.context.annotation.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.*;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;

@Configuration
public class SecurityConfig {
    @Bean PasswordEncoder passwordEncoder() { return Pbkdf2PasswordEncoder.defaultsForSpringSecurity_v5_8(); }
    @Bean org.springframework.security.core.userdetails.UserDetailsService noDefaultUser() {
        return name -> { throw new org.springframework.security.core.userdetails.UsernameNotFoundException("Bearer authentication required"); };
    }
    @Bean SecurityFilterChain security(HttpSecurity http, AuthService auth) throws Exception {
        return http.csrf(c -> c.disable()) // Only explicit Bearer headers, no cookie authentication.
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .requestCache(c -> c.disable())
            .authorizeHttpRequests(a -> a
                .requestMatchers("/api/v1/health", "/api/v1/auth/methods", "/error").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.POST, "/api/v1/auth/register", "/api/v1/auth/login", "/api/v1/auth/phone/code", "/api/v1/auth/phone/login").permitAll()
                .anyRequest().authenticated())
            .exceptionHandling(e -> e.authenticationEntryPoint((req,res,ex) -> error(res,401,200001,"请先登录或重新登录"))
                .accessDeniedHandler((req,res,ex) -> error(res,403,200003,"无访问权限")))
            .addFilterBefore(new ApiFilter(auth), UsernamePasswordAuthenticationFilter.class).build();
    }
    static void error(HttpServletResponse response, int status, int code, String message) throws IOException {
        response.setStatus(status); response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"code\":" + code + ",\"message\":\"" + message + "\",\"data\":null}");
    }
    static final class ApiFilter extends OncePerRequestFilter {
        private final AuthService auth;
        private final Map<String, long[]> attempts = new HashMap<>();
        ApiFilter(AuthService auth) { this.auth = auth; }
        private synchronized boolean allowed(String ip) {
            long now = System.currentTimeMillis();
            attempts.entrySet().removeIf(e -> now - e.getValue()[0] >= 60_000);
            if (!attempts.containsKey(ip) && attempts.size() >= 10000) return false;
            long[] bucket = attempts.computeIfAbsent(ip, k -> new long[]{now,0});
            return ++bucket[1] <= 30;
        }
        @Override protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain) throws ServletException, IOException {
            res.setHeader("Cache-Control", "no-store");
            if (req.getContentLengthLong() > 2_000_000) { error(res,413,100001,"请求过大"); return; }
            if (req.getServletPath().startsWith("/api/v1/auth/") && !req.getMethod().equals("GET") && !allowed(req.getRemoteAddr())) {
                res.setHeader("Retry-After", "60"); error(res,429,200004,"操作过于频繁，请稍后再试"); return;
            }
            String header = req.getHeader("Authorization");
            if (header != null && header.startsWith("Bearer ")) {
                var user = auth.authenticate(header.substring(7));
                if (user != null) SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(user,null,List.of()));
            }
            chain.doFilter(req,res);
        }
    }
}
