package com.smartexpiry.sync;

import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.api.ApiResponse;
import com.smartexpiry.common.exception.BusinessException;
import com.smartexpiry.algorithm.expiry.*;
import com.smartexpiry.item.infrastructure.*;
import com.smartexpiry.item.domain.ItemLifecycleStatus;
import com.smartexpiry.category.CategoryRepository;
import com.smartexpiry.events.EventStore;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.node.ObjectNode;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import java.security.MessageDigest;

@RestController
@RequestMapping("/api/v1/sync/inventory")
public class InventorySyncController {
    public record Write(@PositiveOrZero Long expectedVersion,@NotNull @Size(min=2,max=350000) String payload) {}
    public record Snapshot(String id,long version,String payload,Instant updatedAt,Instant deletedAt) {}
    private final ItemJpaRepository items; private final InventoryBatchJpaRepository batches;
    private final CategoryRepository categories; private final EventStore events;
    private final JsonMapper json=JsonMapper.builder().build();
    public InventorySyncController(ItemJpaRepository items,InventoryBatchJpaRepository batches,CategoryRepository categories,EventStore events) {
        this.items=items;this.batches=batches;this.categories=categories;this.events=events;
    }
    private ItemEntity owned(String id) {
        return items.findById(id).filter(i -> AuthService.userId().equals(i.getOwnerId()))
            .orElseThrow(() -> new BusinessException(300001,"item not found"));
    }
    @GetMapping @Transactional(readOnly=true)
    public ApiResponse<List<Snapshot>> list() {
        return ApiResponse.success(items.findByOwnerIdOrderByUpdatedAtAsc(AuthService.userId()).stream().map(this::snapshot).toList());
    }
    @GetMapping("/{id}") @Transactional(readOnly=true)
    public ApiResponse<Snapshot> get(@PathVariable UUID id) { return ApiResponse.success(snapshot(owned(id.toString()))); }
    @PutMapping("/{id}") @Transactional
    public ApiResponse<Snapshot> put(@PathVariable UUID id,@Valid @RequestBody Write body) {
        ObjectNode doc;
        try { doc=(ObjectNode)json.readTree(body.payload()); validate(doc); }
        catch(BusinessException ex) { throw ex; }
        catch(Exception ex) { throw new BusinessException(100001,"库存快照格式或字段无效"); }
        String fingerprint=fingerprint(doc), user=AuthService.userId(), key=id.toString();
        var existing=items.findById(key);
        if(existing.isPresent() && !user.equals(existing.get().getOwnerId())) throw new BusinessException(300001,"item not found");
        if(existing.isPresent() && fingerprint.equals(existing.get().getSyncFingerprint())) return ApiResponse.success(snapshot(existing.get()));
        if(existing.isPresent() && (body.expectedVersion()==null || body.expectedVersion()!=existing.get().getVersion())
            || existing.isEmpty() && body.expectedVersion()!=null) throw new BusinessException(100409,"版本冲突，请选择保留本机或采用云端");
        Instant now=Instant.now(); var data=doc.path("item");
        ItemEntity item=existing.orElseGet(() -> new ItemEntity(key,data.path("name").asText().trim(),data.path("categoryId").asText(),
            data.path("brand").asText(null),ItemLifecycleStatus.valueOf(data.path("lifecycleStatus").asText()),now,now));
        item.assignOwner(user);
        item.update(data.path("name").asText().trim(),data.path("categoryId").asText(),data.path("brand").asText(null),now);
        item.changeLifecycle(ItemLifecycleStatus.valueOf(data.path("lifecycleStatus").asText()),now);
        if(data.hasNonNull("deletedAt")) item.softDelete(now);
        if(item.getDeletedAt()!=null && !data.hasNonNull("deletedAt")) throw new BusinessException(100409,"云端已删除，不能用旧记录自动恢复");
        item.syncMetadata(body.payload(),fingerprint); items.saveAndFlush(item);
        Map<String,InventoryBatchEntity> old=new HashMap<>();
        batches.findByItemIdInOrderByCreatedAtAsc(List.of(key)).forEach(b -> old.put(b.getId(),b));
        Set<String> received=new HashSet<>();
        for(var b:doc.path("batches")) {
            String batchId=b.path("id").asText(); received.add(batchId);
            var other=batches.findById(batchId);
            if(other.isPresent() && !key.equals(other.get().getItemId())) throw new BusinessException(300001,"batch not found");
            var batch=old.get(batchId);
            BigDecimal quantity=new BigDecimal(b.path("quantity").asText());
            if(batch==null) batch=new InventoryBatchEntity(batchId,key,quantity,b.path("unit").asText("件"),date(b,"productionDate"),date(b,"expiryDate"),
                number(b,"shelfLifeValue"),unit(b,"shelfLifeUnit"),date(b,"openedDate"),number(b,"afterOpenValue"),unit(b,"afterOpenUnit"),now,now);
            else batch.update(quantity,b.path("unit").asText("件"),date(b,"productionDate"),date(b,"expiryDate"),number(b,"shelfLifeValue"),
                unit(b,"shelfLifeUnit"),date(b,"openedDate"),number(b,"afterOpenValue"),unit(b,"afterOpenUnit"),now);
            batch.setLifecycleStatus(b.path("lifecycleStatus").asText()); batches.save(batch);
        }
        for(var batch:old.values()) if(!received.contains(batch.getId())) batches.delete(batch);
        batches.flush();
        events.append(UUID.randomUUID().toString(),user,"INVENTORY_SYNCED",now,"{\"itemId\":\""+key+"\"}");
        return ApiResponse.success(snapshot(item));
    }
    private Snapshot snapshot(ItemEntity item) {
        ObjectNode metadata=json.createObjectNode();
        if(item.getSyncPayload()!=null) metadata=(ObjectNode)json.readTree(item.getSyncPayload()).path("item").deepCopy();
        metadata.put("id",item.getId());metadata.put("remoteId",item.getId());metadata.put("name",item.getName());metadata.put("categoryId",item.getCategoryId());
        metadata.put("lifecycleStatus",item.getLifecycleStatus().name());metadata.put("createdAt",item.getCreatedAt().toEpochMilli());metadata.put("updatedAt",item.getUpdatedAt().toEpochMilli());
        metadata.put("brand",item.getBrand());metadata.put("remoteVersion",item.getVersion());metadata.put("pending",0);
        if(item.getDeletedAt()!=null) metadata.put("deletedAt",item.getDeletedAt().toEpochMilli()); else metadata.remove("deletedAt");
        var array=json.createArrayNode();
        for(var batch:batches.findByItemIdInOrderByCreatedAtAsc(List.of(item.getId()))) {
            var b=json.createObjectNode();b.put("id",batch.getId());b.put("itemId",item.getId());b.put("quantity",batch.getQuantity());b.put("unit",batch.getUnit());
            b.put("lifecycleStatus",batch.getLifecycleStatus());b.put("createdAt",batch.getCreatedAt().toEpochMilli());b.put("updatedAt",batch.getUpdatedAt().toEpochMilli());
            putDate(b,"expiryDate",batch.getExpiryDate());putDate(b,"productionDate",batch.getProductionDate());putDate(b,"openedDate",batch.getOpenedDate());
            if(batch.getAfterOpenValue()!=null) {b.put("afterOpenValue",batch.getAfterOpenValue());b.put("afterOpenUnit",batch.getAfterOpenUnit().name());}
            if(batch.getShelfLifeValue()!=null) {b.put("shelfLifeValue",batch.getShelfLifeValue());b.put("shelfLifeUnit",batch.getShelfLifeUnit().name());}
            if(item.getSyncPayload()!=null) for(var original:json.readTree(item.getSyncPayload()).path("batches"))
                if(batch.getId().equals(original.path("id").asText()) && original.has("location")) b.set("location",original.get("location"));
            array.add(b);
        }
        var doc=json.createObjectNode();doc.set("item",metadata);doc.set("batches",array);
        return new Snapshot(item.getId(),item.getVersion(),json.writeValueAsString(doc),item.getUpdatedAt(),item.getDeletedAt());
    }
    private void validate(ObjectNode doc) {
        var item=doc.path("item");var bs=doc.path("batches");
        if(!item.isObject() || !bs.isArray() || bs.isEmpty() || bs.size()>1000 || !categories.existsById(item.path("categoryId").asText())) bad();
        String name=item.path("name").asText();if(name.isBlank() || name.length()>80 || item.path("notes").asText().length()>500 || item.path("brand").asText().length()>120) bad();
        if(item.hasNonNull("reminderDays") && (number(item,"reminderDays")<0 || number(item,"reminderDays")>365)) bad();
        if(item.hasNonNull("snoozeUntil")) { var snooze=date(item,"snoozeUntil"); if(snooze.getYear()<1900 || snooze.getYear()>9999) bad(); }
        ItemLifecycleStatus status=ItemLifecycleStatus.valueOf(item.path("lifecycleStatus").asText());
        Set<String> ids=new HashSet<>();String measure=null;boolean active=false;
        for(var b:bs) {
            String id=b.path("id").asText();UUID.fromString(id);if(!ids.add(id)) bad();
            BigDecimal quantity=new BigDecimal(b.path("quantity").asText());
            String life=b.path("lifecycleStatus").asText();if(!Set.of("ACTIVE","CONSUMED","DISCARDED","ARCHIVED").contains(life)) bad();
            if(quantity.signum()<0 || quantity.scale()>3 || quantity.compareTo(new BigDecimal("999999999"))>0 || "ACTIVE".equals(life) && quantity.signum()==0) bad();
            active|="ACTIVE".equals(life);String current=b.path("unit").asText("件");if(current.length()>32 || measure!=null && !measure.equals(current)) bad();measure=current;
            LocalDate expiry=date(b,"expiryDate"),production=date(b,"productionDate"),opened=date(b,"openedDate");
            if(expiry==null || java.util.stream.Stream.of(expiry,production,opened).filter(Objects::nonNull).anyMatch(d -> d.getYear()<1900 || d.getYear()>9999)
                || production!=null && expiry.isBefore(production) || opened!=null && (opened.isAfter(LocalDate.now(ZoneId.of("Asia/Shanghai"))) || production!=null && opened.isBefore(production))) bad();
            Integer after=number(b,"afterOpenValue"),shelf=number(b,"shelfLifeValue");
            if((after==null)!=(unit(b,"afterOpenUnit")==null) || after!=null && (after<1 || after>1200 || opened==null)
                || (shelf==null)!=(unit(b,"shelfLifeUnit")==null) || shelf!=null && (shelf<1 || shelf>1200)) bad();
        }
        if(status==ItemLifecycleStatus.ACTIVE && !active || status!=ItemLifecycleStatus.ACTIVE && status!=ItemLifecycleStatus.ARCHIVED && active) bad();
    }
    private String fingerprint(ObjectNode source) {
        try {
            ObjectNode copy=source.deepCopy();ObjectNode item=(ObjectNode)copy.path("item");
            for(String key:List.of("id","remoteId","remoteVersion","pending","primaryBatchId","createdAt","updatedAt")) item.remove(key);
            for(var b:copy.path("batches")) for(String key:List.of("itemId","createdAt","updatedAt")) ((ObjectNode)b).remove(key);
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(json.writeValueAsBytes(copy)));
        } catch(Exception ex) { throw new IllegalArgumentException(ex); }
    }
    private void bad() { throw new BusinessException(100001,"库存或批次字段不合法"); }
    private LocalDate date(JsonNode node,String key) { return node.hasNonNull(key)?LocalDate.parse(node.path(key).asText()):null; }
    private Integer number(JsonNode node,String key) { return node.hasNonNull(key)?Integer.valueOf(node.path(key).asText()):null; }
    private ShelfLifeUnit unit(JsonNode node,String key) { return node.hasNonNull(key)?ShelfLifeUnit.valueOf(node.path(key).asText()):null; }
    private void putDate(ObjectNode node,String key,LocalDate date) { if(date!=null) node.put(key,date.toString()); }
}
