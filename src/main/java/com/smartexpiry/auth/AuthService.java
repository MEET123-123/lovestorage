package com.smartexpiry.auth;

import com.smartexpiry.common.exception.BusinessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
public class AuthService {
    public record User(String id, String username) {}
    public record Session(String accessToken, Instant expiresAt, User user) {}
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    private final String dummyHash;
    private final SecureRandom random = new SecureRandom();
    public AuthService(JdbcTemplate jdbc, PasswordEncoder encoder) {
        this.jdbc = jdbc; this.encoder = encoder;
        this.dummyHash = encoder.encode(UUID.randomUUID().toString());
    }
    public static String userId() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof User user))
            throw new BusinessException(200001, "请先登录");
        return user.id();
    }
    @Transactional
    public Session register(String username, String password) {
        String normalized = username.toLowerCase(Locale.ROOT);
        String id = UUID.randomUUID().toString();
        jdbc.update("INSERT INTO app_user(id,username,password_hash,created_at) VALUES (?,?,?,?)",
            id, normalized, encoder.encode(password), Timestamp.from(Instant.now()));
        return issue(new User(id, normalized));
    }
    @Transactional
    public Session login(String username, String password) {
        var rows = jdbc.queryForList("SELECT id,username,password_hash FROM app_user WHERE username = ?", username.toLowerCase(Locale.ROOT));
        String hash = rows.isEmpty() ? dummyHash : (String) rows.getFirst().get("password_hash");
        if (!encoder.matches(password, hash) || rows.isEmpty())
            throw new BusinessException(200001, "用户名或密码错误");
        var row = rows.getFirst();
        return issue(new User((String) row.get("id"), (String) row.get("username")));
    }
    private Session issue(User user) {
        byte[] bytes = new byte[32]; random.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant expires = Instant.now().plus(12, ChronoUnit.HOURS);
        jdbc.update("DELETE FROM auth_session WHERE expires_at <= ?", Timestamp.from(Instant.now()));
        jdbc.update("INSERT INTO auth_session(token_hash,user_id,expires_at) VALUES (?,?,?)", digest(token), user.id(), Timestamp.from(expires));
        return new Session(token, expires, user);
    }
    @Transactional
    public Session localPhoneLogin(String phone) {
        var users = jdbc.query("SELECT u.id,u.username FROM login_identity i JOIN app_user u ON i.user_id=u.id WHERE i.provider='LOCAL_PHONE' AND i.subject=?",
            (rs,n) -> new User(rs.getString(1),rs.getString(2)),phone);
        if (!users.isEmpty()) return issue(users.getFirst());
        String id = UUID.randomUUID().toString();
        String username = "phone_"+UUID.randomUUID().toString().replace("-", "").substring(0,20);
        jdbc.update("INSERT INTO app_user(id,username,password_hash,created_at) VALUES (?,?,?,?)",id,username,encoder.encode(UUID.randomUUID().toString()),Timestamp.from(Instant.now()));
        jdbc.update("INSERT INTO login_identity(provider,subject,user_id) VALUES ('LOCAL_PHONE',?,?)",phone,id);
        return issue(new User(id,username));
    }
    public User authenticate(String token) {
        if (token == null || !token.matches("[A-Za-z0-9_-]{43}")) return null;
        var users = jdbc.query("SELECT u.id,u.username FROM auth_session s JOIN app_user u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at > ?",
            (rs, row) -> new User(rs.getString(1), rs.getString(2)), digest(token), Timestamp.from(Instant.now()));
        return users.isEmpty() ? null : users.getFirst();
    }
    public void logout(String token) { jdbc.update("DELETE FROM auth_session WHERE token_hash=?", digest(token)); }
    @Transactional
    public void changePassword(String current, String replacement) {
        String id = userId();
        String hash = jdbc.queryForObject("SELECT password_hash FROM app_user WHERE id=?", String.class, id);
        if (!encoder.matches(current, hash)) throw new BusinessException(200001, "当前密码错误");
        jdbc.update("UPDATE app_user SET password_hash=? WHERE id=?", encoder.encode(replacement), id);
        jdbc.update("DELETE FROM auth_session WHERE user_id=?", id);
    }
    private static String digest(String value) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException ex) { throw new IllegalStateException(ex); }
    }
}
