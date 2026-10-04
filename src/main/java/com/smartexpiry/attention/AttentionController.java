package com.smartexpiry.attention;

import com.smartexpiry.algorithm.attention.AttentionEngine;

import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.api.ApiResponse;
import com.smartexpiry.common.exception.BusinessException;
import com.smartexpiry.item.infrastructure.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ResourceLoader;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.json.JsonMapper;
import java.io.IOException;
import java.time.*;
import java.util.*;

@RestController
@RequestMapping("/api/v1/attention")
public class AttentionController {
    private final ItemJpaRepository items;
    private final InventoryBatchJpaRepository batches;
    private final AttentionEngine engine;
    public AttentionController(ItemJpaRepository items, InventoryBatchJpaRepository batches,
        ResourceLoader resources,
        @Value("${smart-expiry.attention.rules-location:classpath:algorithm/contracts/attention-rules.json}") String location) throws IOException {
        this.items=items; this.batches=batches;
        try (var input=resources.getResource(location).getInputStream()) {
            engine=new AttentionEngine(JsonMapper.builder().build().readValue(input,AttentionEngine.Rules.class));
        }
    }
    @GetMapping
    @Transactional(readOnly=true)
    public ApiResponse<List<AttentionEngine.Decision>> today(@RequestParam(defaultValue="10") int limit) {
        if (limit < 1 || limit > 50) throw new BusinessException(100001,"limit must be 1..50");
        var owned=items.findByOwnerIdAndDeletedAtIsNullOrderByUpdatedAtDesc(AuthService.userId());
        if (owned.isEmpty()) return ApiResponse.success(List.of());
        Map<String,List<InventoryBatchEntity>> grouped=new HashMap<>();
        batches.findByItemIdInOrderByCreatedAtAsc(owned.stream().map(ItemEntity::getId).toList())
            .forEach(batch -> grouped.computeIfAbsent(batch.getItemId(),key -> new ArrayList<>()).add(batch));
        List<AttentionEngine.Input> inputs=new ArrayList<>();
        for (var item:owned) {
            var live=grouped.getOrDefault(item.getId(),List.of()).stream().filter(b -> "ACTIVE".equals(b.getLifecycleStatus()) && b.getQuantity().signum()>0).toList();
            var expiry=new com.smartexpiry.algorithm.expiry.ExpiryService();
            var batch=live.stream().min(Comparator.comparing(b -> expiry.effectiveExpiryDate(b.getExpiryDate(),b.getOpenedDate(),b.getAfterOpenValue(),b.getAfterOpenUnit()),Comparator.nullsLast(Comparator.naturalOrder()))).orElse(null);
            var quantity=live.stream().map(InventoryBatchEntity::getQuantity).reduce(java.math.BigDecimal.ZERO,java.math.BigDecimal::add);
            int window=com.smartexpiry.algorithm.expiry.ExpiryService.defaultReminderDays(item.getCategoryId());
            LocalDate snooze=null;
            if(item.getSyncPayload()!=null) {
                var metadata=JsonMapper.builder().build().readTree(item.getSyncPayload()).path("item");
                if(metadata.hasNonNull("reminderDays")) window=metadata.path("reminderDays").asInt();
                if(metadata.hasNonNull("snoozeUntil")) snooze=LocalDate.parse(metadata.path("snoozeUntil").asText());
            }
            inputs.add(new AttentionEngine.Input(item.getId(),batch==null?null:batch.getExpiryDate(),
                batch==null?null:batch.getOpenedDate(),batch==null?null:batch.getAfterOpenValue(),
                batch==null?null:batch.getAfterOpenUnit(),window,quantity,
                item.getLifecycleStatus().name(),false,snooze));
        }
        // Full snapshots include snooze and reminder overrides; unsynchronized edits remain local.
        return ApiResponse.success(engine.rank(inputs,LocalDate.now(ZoneId.of("Asia/Shanghai")),limit));
    }
}
