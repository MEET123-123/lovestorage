package com.smartexpiry.events;

import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.api.ApiResponse;
import com.smartexpiry.common.exception.BusinessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.JsonNode;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/v1/events")
public class EventExportController {
    public record Row(String eventId,String eventType,String eventVersion,Instant occurredAt,Instant recordedAt,JsonNode properties) {}
    public record Page(List<Row> events,String nextCursor) {}
    private final JdbcTemplate jdbc;
    private final JsonMapper json=JsonMapper.builder().build();
    public EventExportController(JdbcTemplate jdbc) {this.jdbc=jdbc;}
    @GetMapping("/status") public ApiResponse<Map<String,Object>> status() {
        String user=AuthService.userId();
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("pending",jdbc.queryForObject("SELECT count(*) FROM event_outbox WHERE user_id=? AND published_at IS NULL",Long.class,user));
        result.put("published",jdbc.queryForObject("SELECT count(*) FROM behavior_event WHERE user_id=?",Long.class,user));
        return ApiResponse.success(result);
    }
    @GetMapping("/export") public ApiResponse<Page> export(@RequestParam(defaultValue="500") int limit,@RequestParam(required=false) UUID after) {
        if(limit<1 || limit>1000) throw new BusinessException(100001,"limit must be 1..1000");
        String user=AuthService.userId();String predicate="";List<Object> args=new ArrayList<>();args.add(user);
        if(after!=null) {
            var row=jdbc.queryForList("SELECT recorded_at FROM behavior_event WHERE user_id=? AND event_id=?",user,after.toString());
            if(row.isEmpty()) throw new BusinessException(300001,"cursor not found");
            predicate=" AND (recorded_at>? OR (recorded_at=? AND event_id>?))";
            args.add(row.getFirst().get("recorded_at"));args.add(row.getFirst().get("recorded_at"));args.add(after.toString());
        }
        args.add(limit+1);
        var rows=jdbc.query("SELECT event_id,event_type,event_version,occurred_at,recorded_at,properties FROM behavior_event WHERE user_id=?"+predicate+" ORDER BY recorded_at,event_id LIMIT ?",
            (rs,index)->new Row(rs.getString(1),rs.getString(2),rs.getString(3),rs.getTimestamp(4).toInstant(),rs.getTimestamp(5).toInstant(),json.readTree(rs.getString(6))),args.toArray());
        boolean more=rows.size()>limit;var page=more?rows.subList(0,limit):rows;
        return ApiResponse.success(new Page(page,more?page.getLast().eventId():null));
    }
}
