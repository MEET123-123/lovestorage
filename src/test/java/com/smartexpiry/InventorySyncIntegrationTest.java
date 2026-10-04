package com.smartexpiry;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.smartexpiry.events.EventStore;
import java.util.*;
import static org.assertj.core.api.Assertions.assertThat;

@org.springframework.boot.test.context.SpringBootTest(webEnvironment=org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT)
class InventorySyncIntegrationTest {
    @org.springframework.boot.test.web.server.LocalServerPort int port;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
    final java.net.http.HttpClient client=java.net.http.HttpClient.newHttpClient();
    final tools.jackson.databind.json.JsonMapper mapper=tools.jackson.databind.json.JsonMapper.builder().build();
    java.net.http.HttpResponse<String> send(String token,String method,String path,String body) throws Exception {
        return client.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create("http://localhost:"+port+"/api/v1"+path))
            .header("Content-Type","application/json").header("Authorization","Bearer "+token)
            .method(method,body==null?java.net.http.HttpRequest.BodyPublishers.noBody():java.net.http.HttpRequest.BodyPublishers.ofString(body)).build(),java.net.http.HttpResponse.BodyHandlers.ofString());
    }
    String register(String name) throws Exception {
        var result=send("","POST","/auth/register",mapper.writeValueAsString(Map.of("username",name,"password","test-password-123")));
        assertThat(result.statusCode()).isEqualTo(200);return mapper.readTree(result.body()).path("data").path("accessToken").asText();
    }
    @Autowired EventStore events;
    String document(String name,String one,String two) throws Exception {
        return mapper.writeValueAsString(Map.of("item",Map.of("name",name,"categoryId","food","lifecycleStatus","ACTIVE","notes","包装完整"),
            "batches",List.of(Map.of("id",one,"quantity",2,"unit","件","expiryDate","2027-01-01","lifecycleStatus","ACTIVE"),
                Map.of("id",two,"quantity",3,"unit","件","expiryDate","2026-12-01","lifecycleStatus","ACTIVE"))));
    }
    String write(String payload,Long version) throws Exception {
        var body=new HashMap<String,Object>(); body.put("payload",payload);if(version!=null) body.put("expectedVersion",version);
        return mapper.writeValueAsString(body);
    }
    @Test void fullBatchesVersionConflictReplayAndRollback() throws Exception {
        String token=register("s"+UUID.randomUUID().toString().substring(0,8)),other=register("t"+UUID.randomUUID().toString().substring(0,8));
        String id=UUID.randomUUID().toString(),one=UUID.randomUUID().toString(),two=UUID.randomUUID().toString();
        String doc=document("批次测试",one,two),path="/sync/inventory/"+id;
        var first=send(token,"PUT",path,write(doc,null));assertThat(first.statusCode()).isEqualTo(200);
        long version=mapper.readTree(first.body()).path("data").path("version").asLong();
        assertThat(send(token,"PUT",path,write(doc,null)).statusCode()).isEqualTo(200);
        assertThat(send(other,"GET",path,null).statusCode()).isEqualTo(404);
        assertThat(send(other,"GET","/sync/inventory",null).body()).doesNotContain(id);
        var item=mapper.readTree(send(token,"GET","/items/"+id,null).body()).path("data");
        assertThat(item.path("quantity").asInt()).isEqualTo(5);assertThat(item.path("effectiveExpiryDate").asText()).isEqualTo("2026-12-01");
        assertThat(send(token,"PUT",path,write(document("新名字",one,two),null)).statusCode()).isEqualTo(409);
        var changed=send(token,"PUT",path,write(document("新名字",one,two),version));assertThat(changed.statusCode()).isEqualTo(200);
        assertThat(send(token,"PUT",path,write(doc,version)).statusCode()).isEqualTo(409);
        long next=mapper.readTree(changed.body()).path("data").path("version").asLong();
        String invalid=document("不该保存",one,two).replace("2026-12-01","2026-02-30");
        assertThat(send(token,"PUT",path,write(invalid,next)).statusCode()).isEqualTo(400);
        assertThat(send(token,"GET",path,null).body()).contains("新名字").doesNotContain("不该保存");
        String victim=UUID.randomUUID().toString();
        assertThat(send(token,"PUT","/sync/inventory/"+victim,write(doc,null)).statusCode()).isEqualTo(404);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM item WHERE id=?",Integer.class,victim)).isZero();
    }
    @Test void eventsDeduplicatePreserveLateTimeAndRejectPrivateFields() throws Exception {
        String token=register("e"+UUID.randomUUID().toString().substring(0,8));String id=UUID.randomUUID().toString();
        assertThat(send(token,"PUT","/sync/inventory/"+id,write(document("事件物品",UUID.randomUUID().toString(),UUID.randomUUID().toString()),null)).statusCode()).isEqualTo(200);
        String eventId=UUID.randomUUID().toString();
        var event=Map.of("eventId",eventId,"eventType","ITEM_PARTIAL_CONSUMED","eventVersion","1.0","occurredAt","2026-01-01T00:00:00Z","properties",Map.of("itemId",id,"quantity",1));
        String body=mapper.writeValueAsString(Map.of("events",List.of(event)));
        assertThat(send(token,"POST","/events",body).statusCode()).isEqualTo(200);
        assertThat(send(token,"POST","/events",body).statusCode()).isEqualTo(200);
        events.publish();events.publish();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM behavior_event WHERE event_id=?",Integer.class,eventId)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM behavior_event WHERE event_id=? AND recorded_at>occurred_at",Integer.class,eventId)).isEqualTo(1);
        String leaked=body.replace("\"quantity\":1","\"rawOcr\":\"private\"");
        assertThat(send(token,"POST","/events",leaked).statusCode()).isEqualTo(400);
        String decisionId=UUID.randomUUID().toString();
        var decision=Map.of("eventId",UUID.randomUUID().toString(),"eventType","DECISION_SHOWN","eventVersion","1.0","occurredAt","2026-01-02T00:00:00Z",
            "properties",Map.of("itemId",id,"decisionId",decisionId,"algorithmVersion","attention-rule-v1","score",90,"reasonCodes",List.of("EXPIRES_TODAY")));
        assertThat(send(token,"POST","/events",mapper.writeValueAsString(Map.of("events",List.of(decision)))).statusCode()).isEqualTo(200);
        events.publish();
        assertThat(send("","GET","/events/export",null).statusCode()).isEqualTo(401);
        var page=mapper.readTree(send(token,"GET","/events/export?limit=1",null).body()).path("data");
        assertThat(page.path("events").size()).isEqualTo(1);
        String cursor=page.path("nextCursor").asText();assertThat(cursor).isNotBlank();
        var second=mapper.readTree(send(token,"GET","/events/export?limit=1000&after="+cursor,null).body()).path("data");
        assertThat(second.path("events").toString()).doesNotContain(page.path("events").get(0).path("eventId").asText());
        assertThat(send(token,"GET","/events/export?limit=1001",null).statusCode()).isEqualTo(400);
        String outsider=register("x"+UUID.randomUUID().toString().substring(0,8));
        assertThat(send(outsider,"GET","/events/export?after="+cursor,null).statusCode()).isEqualTo(404);
        assertThat(send(outsider,"GET","/events/export",null).body()).doesNotContain(decisionId);
        assertThat(mapper.readTree(send(token,"GET","/events/status",null).body()).path("data").path("pending").asLong()).isZero();
    }
}
