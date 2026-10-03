package com.smartexpiry.auth;

import com.smartexpiry.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    public record Credentials(@NotBlank @Pattern(regexp="[A-Za-z0-9_]{3,32}") String username,
                              @NotBlank @Size(min=12,max=64) String password) {}
    public record PasswordChange(@NotNull @Size(min=12,max=64) String currentPassword,
                                 @NotBlank @Size(min=12,max=64) String newPassword) {}
    private final AuthService service;
    public AuthController(AuthService service) { this.service = service; }
    @PostMapping("/register") public ApiResponse<AuthService.Session> register(@Valid @RequestBody Credentials body) {
        return ApiResponse.success(service.register(body.username(), body.password()));
    }
    @PostMapping("/login") public ApiResponse<AuthService.Session> login(@Valid @RequestBody Credentials body) {
        return ApiResponse.success(service.login(body.username(), body.password()));
    }
    @GetMapping("/me") public ApiResponse<AuthService.User> me() {
        return ApiResponse.success((AuthService.User) SecurityContextHolder.getContext().getAuthentication().getPrincipal());
    }
    @PostMapping("/logout") public ApiResponse<Boolean> logout(@RequestHeader("Authorization") String header) {
        service.logout(header.substring(7)); return ApiResponse.success(true);
    }
    @PostMapping("/password") public ApiResponse<Boolean> password(@Valid @RequestBody PasswordChange body) {
        service.changePassword(body.currentPassword(), body.newPassword()); return ApiResponse.success(true);
    }
}
