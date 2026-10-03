package com.smartexpiry.profile;

import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.json.JsonMapper;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/v1/profile")
public class ProfileController {
    public record Profile(@NotBlank @Size(max=40) String displayName,
        @NotNull @Pattern(regexp="leaf|cat|coffee|sun|moon|flower|ocean|star") String avatarKey,
        @NotNull @Size(max=120) String bio,
        @NotNull @Size(max=20) List<@NotBlank @Size(max=24) String> allergies,
        @NotNull @Size(max=20) List<@NotBlank @Size(max=24) String> dislikes,
        @NotNull @Size(max=20) List<@NotBlank @Size(max=24) String> preferences) {}
    private final JdbcTemplate jdbc;
    private final JsonMapper json = JsonMapper.builder().build();
    public ProfileController(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    private List<String> decode(String value) { return Arrays.asList(json.readValue(value,String[].class)); }
    private List<String> clean(List<String> values) { return values.stream().map(String::trim).distinct().toList(); }
    @GetMapping public ApiResponse<Profile> get() {
        var rows = jdbc.query("SELECT * FROM user_profile WHERE user_id=?", (rs,n) -> new Profile(rs.getString("display_name"),rs.getString("avatar_key"),rs.getString("bio"),decode(rs.getString("allergies")),decode(rs.getString("dislikes")),decode(rs.getString("preferences"))),AuthService.userId());
        if (!rows.isEmpty()) return ApiResponse.success(rows.getFirst());
        String username = jdbc.queryForObject("SELECT username FROM app_user WHERE id=?",String.class,AuthService.userId());
        return ApiResponse.success(new Profile(username,"leaf","",List.of(),List.of(),List.of()));
    }
    @PutMapping @Transactional public ApiResponse<Profile> save(@Valid @RequestBody Profile body) {
        Profile p = new Profile(body.displayName().trim(),body.avatarKey(),body.bio().trim(),clean(body.allergies()),clean(body.dislikes()),clean(body.preferences()));
        String owner = AuthService.userId();
        var args = new Object[]{p.displayName(),p.avatarKey(),p.bio(),json.writeValueAsString(p.allergies()),json.writeValueAsString(p.dislikes()),json.writeValueAsString(p.preferences()),Timestamp.from(Instant.now()),owner};
        if (jdbc.update("UPDATE user_profile SET display_name=?,avatar_key=?,bio=?,allergies=?,dislikes=?,preferences=?,updated_at=? WHERE user_id=?",args) == 0)
            jdbc.update("INSERT INTO user_profile(display_name,avatar_key,bio,allergies,dislikes,preferences,updated_at,user_id) VALUES (?,?,?,?,?,?,?,?)",args);
        return ApiResponse.success(p);
    }
}
