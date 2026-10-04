package com.smartexpiry.events;

import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.scheduling.annotation.Scheduled;
import com.smartexpiry.common.exception.BusinessException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;

@Service
public class EventStore {
    private final JdbcTemplate jdbc;
    public EventStore(JdbcTemplate jdbc) { this.jdbc=jdbc; }
    @Transactional
    public void append(String id,String user,String type,Instant occurred,String properties) {
        var existing=jdbc.queryForList("SELECT user_id,event_type,properties FROM event_outbox WHERE event_id=?",id);
        if (!existing.isEmpty()) {
            var row=existing.getFirst();
            if (!user.equals(row.get("user_id")) || !type.equals(row.get("event_type")) || !properties.equals(row.get("properties")))
                throw new BusinessException(100409,"事件 ID 已存在且内容不一致");
            return;
        }
        jdbc.update("INSERT INTO event_outbox(event_id,user_id,event_type,event_version,occurred_at,recorded_at,properties) VALUES (?,?,?,'1.0',?,?,?)",
            id,user,type,Timestamp.from(occurred),Timestamp.from(Instant.now()),properties);
    }
    // One local DB consumer, with row locks and unique event IDs. Replays do not duplicate facts.
    @Scheduled(fixedDelay=5000)
    @Transactional
    public void publish() {
        var ids=jdbc.queryForList("SELECT event_id FROM event_outbox WHERE published_at IS NULL ORDER BY recorded_at LIMIT 100",String.class);
        for(String id:ids) {
            var pending=jdbc.queryForList("SELECT event_id FROM event_outbox WHERE event_id=? AND published_at IS NULL FOR UPDATE",id);
            if(pending.isEmpty()) continue;
            jdbc.update("INSERT INTO behavior_event SELECT event_id,user_id,event_type,event_version,occurred_at,recorded_at,properties FROM event_outbox o WHERE event_id=? AND NOT EXISTS(SELECT 1 FROM behavior_event b WHERE b.event_id=o.event_id)",id);
            jdbc.update("UPDATE event_outbox SET published_at=? WHERE event_id=?",Timestamp.from(Instant.now()),id);
        }
    }
}
