package com.smartexpiry.system;

import com.smartexpiry.common.api.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/health")
public class HealthController {
    private final org.springframework.jdbc.core.JdbcTemplate jdbc;
    public HealthController(org.springframework.jdbc.core.JdbcTemplate jdbc) { this.jdbc = jdbc; }
    @GetMapping
    public org.springframework.http.ResponseEntity<ApiResponse<Map<String, String>>> health() {
        try { jdbc.queryForObject("SELECT 1", Integer.class); }
        catch (org.springframework.dao.DataAccessException ex) {
            return org.springframework.http.ResponseEntity.status(503).body(ApiResponse.error(100503,"database unavailable"));
        }
        return org.springframework.http.ResponseEntity.ok(ApiResponse.success(Map.of(
            "status", "UP",
            "service", "smart-expiry-server"
        )));
    }
}
