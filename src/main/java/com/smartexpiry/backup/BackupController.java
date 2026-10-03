package com.smartexpiry.backup;

import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.api.ApiResponse;
import com.smartexpiry.common.exception.BusinessException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.json.JsonMapper;
import java.sql.Timestamp;
import java.time.Instant;

@RestController
@RequestMapping("/api/v1/backup")
public class BackupController {
    public record Save(@Min(0) long expectedRevision, @NotNull @Size(min=2,max=500000) String payload) {}
    public record Backup(long revision, String payload, Instant updatedAt) {}
    private final JdbcTemplate jdbc;
    private final JsonMapper json = JsonMapper.builder().build();
    public BackupController(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    @GetMapping public ApiResponse<Backup> get() {
        var rows = jdbc.query("SELECT revision,payload,updated_at FROM account_backup WHERE user_id=?",
            (rs,n) -> new Backup(rs.getLong(1),rs.getString(2),rs.getTimestamp(3).toInstant()),AuthService.userId());
        return ApiResponse.success(rows.isEmpty() ? new Backup(0,"",null) : rows.getFirst());
    }
    @PutMapping public ApiResponse<Backup> save(@Valid @RequestBody Save body) {
        try {
            var doc = json.readTree(body.payload());
            if (doc.path("schemaVersion").asInt() != 1 || !doc.path("items").isArray()
                || !doc.path("records").isArray() || !doc.path("shopping").isArray()
                || doc.path("items").size() > 10000 || doc.path("records").size() > 10000 || doc.path("shopping").size() > 10000)
                throw new IllegalArgumentException();
        } catch (Exception ex) { throw new BusinessException(100001,"备份格式无效"); }
        Instant now = Instant.now();
        String user = AuthService.userId();
        if (body.expectedRevision() == 0) {
            jdbc.update("INSERT INTO account_backup(user_id,revision,payload,updated_at) VALUES (?,1,?,?)",user,body.payload(),Timestamp.from(now));
        } else {
            int changed = jdbc.update("UPDATE account_backup SET revision=revision+1,payload=?,updated_at=? WHERE user_id=? AND revision=?",
                body.payload(),Timestamp.from(now),user,body.expectedRevision());
            if (changed != 1) throw new BusinessException(100409,"云端备份已变化，请先核对，不能覆盖其他设备的新备份");
        }
        return ApiResponse.success(new Backup(body.expectedRevision()+1,body.payload(),now));
    }
}
