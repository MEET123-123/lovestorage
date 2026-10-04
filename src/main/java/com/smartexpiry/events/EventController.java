package com.smartexpiry.events;

import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.api.ApiResponse;
import com.smartexpiry.common.exception.BusinessException;
import com.smartexpiry.item.infrastructure.ItemJpaRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/v1/events")
public class EventController {
    public record Event(@NotNull UUID eventId,@NotBlank String eventType,@NotNull @Pattern(regexp="1\\.0") String eventVersion,
        @NotNull Instant occurredAt,@NotNull Map<String,Object> properties) {}
    public record Batch(@NotNull @Size(min=1,max=100) List<@Valid Event> events) {}
    private static final Set<String> TYPES=Set.of("ITEM_CREATED","ITEM_UPDATED","ITEM_CONSUMED","ITEM_PARTIAL_CONSUMED","ITEM_DISCARDED","ITEM_DELETED","ITEM_SNOOZED","DRAFT_SAVED","REMINDER_DELIVERED","REMINDER_ACTION","SUGGESTION_ACCEPTED","DECISION_SHOWN","DECISION_FEEDBACK");
    private final EventStore store; private final ItemJpaRepository items;
    private final JsonMapper json=JsonMapper.builder().build();
    public EventController(EventStore store,ItemJpaRepository items) { this.store=store; this.items=items; }
    @PostMapping @Transactional
    public ApiResponse<Integer> ingest(@Valid @RequestBody Batch batch) {
        String user=AuthService.userId();
        for(var event:batch.events()) {
            if(!TYPES.contains(event.eventType()) || event.occurredAt().isAfter(Instant.now().plusSeconds(300))
                || !Set.of("itemId","batchId","quantity","decisionId","algorithmVersion","action","score","remainingDays","opened","reasonCodes","mock").containsAll(event.properties().keySet())) throw new BusinessException(100001,"事件类型、时间或字段不合法");
            validateDecision(event);
            Object itemId=event.properties().get("itemId");
            if(!(itemId instanceof String id) || items.findById(id).filter(i -> user.equals(i.getOwnerId())).isEmpty()) throw new BusinessException(300001,"item not found");
            if(event.properties().get("quantity")!=null && (!(event.properties().get("quantity") instanceof Number n) || !Double.isFinite(n.doubleValue()) || n.doubleValue()<=0)) throw new BusinessException(100001,"事件数量无效");
            if(event.properties().get("batchId")!=null && !(event.properties().get("batchId") instanceof String)) throw new BusinessException(100001,"批次标识无效");
            store.append(event.eventId().toString(),user,event.eventType(),event.occurredAt(),json.writeValueAsString(new TreeMap<>(event.properties())));
        }
        return ApiResponse.success(batch.events().size());
    }
    private void validateDecision(Event event) {
        var p=event.properties();
        try {
            if(p.containsKey("decisionId")) UUID.fromString((String)p.get("decisionId"));
            if(p.containsKey("algorithmVersion") && (!(p.get("algorithmVersion") instanceof String version) || !version.matches("[a-zA-Z0-9_.-]{1,64}"))) throw new IllegalArgumentException();
            if(p.containsKey("action") && !Set.of("CONSUMED","DISCARDED","SNOOZE","UNDO","NOT_HELPFUL").contains(p.get("action"))) throw new IllegalArgumentException();
            if(p.containsKey("opened") && !(p.get("opened") instanceof Boolean)) throw new IllegalArgumentException();
            if(p.containsKey("mock") && !(p.get("mock") instanceof Boolean)) throw new IllegalArgumentException();
            for(String key:List.of("score","remainingDays")) if(p.containsKey(key)) {
                if(!(p.get(key) instanceof Number n) || !Double.isFinite(n.doubleValue()) || n.doubleValue()!=n.intValue() || Math.abs(n.doubleValue())>4000000 || key.equals("score") && n.intValue()<0) throw new IllegalArgumentException();
            }
            if(p.containsKey("reasonCodes")) {
                if(!(p.get("reasonCodes") instanceof List<?> codes) || codes.size()>30 || codes.stream().anyMatch(v -> !(v instanceof String code) || !code.matches("[A-Z_]{1,64}"))) throw new IllegalArgumentException();
            }
            if(event.eventType().startsWith("DECISION_") && (!p.containsKey("decisionId") || !p.containsKey("algorithmVersion"))) throw new IllegalArgumentException();
            if(event.eventType().equals("DECISION_FEEDBACK") && !p.containsKey("action")) throw new IllegalArgumentException();
            if(event.eventType().equals("DECISION_SHOWN") && (!p.containsKey("score") || !p.containsKey("reasonCodes"))) throw new IllegalArgumentException();
        } catch(RuntimeException ex) { throw new BusinessException(100001,"算法决策事件字段不合法"); }
    }
}
