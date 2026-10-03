package com.smartexpiry;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import tools.jackson.databind.json.JsonMapper;
import java.net.URI;
import java.net.http.*;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AuthIsolationIntegrationTest {
    @LocalServerPort int port;
    @Autowired JdbcTemplate jdbc;
    final HttpClient client = HttpClient.newHttpClient();
    final JsonMapper mapper = JsonMapper.builder().build();
    HttpResponse<String> send(String token, String method, String path, String body) throws Exception {
        return client.send(HttpRequest.newBuilder(URI.create("http://localhost:"+port+"/api/v1"+path))
            .header("Content-Type","application/json").header("Authorization","Bearer "+token)
            .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body)).build(),HttpResponse.BodyHandlers.ofString());
    }
    String register(String name) throws Exception {
        var res = send("","POST","/auth/register","{\"username\":\""+name+"\",\"password\":\"test-password-123\"}");
        assertThat(res.statusCode()).isEqualTo(200);
        return mapper.readTree(res.body()).path("data").path("accessToken").asText();
    }
    @Test void isolationRevocationAndPasswordChange() throws Exception {
        assertThat(send("","GET","/items",null).statusCode()).isEqualTo(401);
        String name = "a"+UUID.randomUUID().toString().substring(0,8);
        String a = register(name), b = register("b"+UUID.randomUUID().toString().substring(0,8));
        String id = UUID.randomUUID().toString();
        String body = "{\"clientId\":\""+id+"\",\"name\":\"Private\",\"categoryId\":\"food\",\"expiryDate\":\"2027-01-01\"}";
        assertThat(send(a,"POST","/items",body).statusCode()).isEqualTo(200);
        for (String method : new String[]{"GET","PUT","PATCH","DELETE"})
            assertThat(send(b,method,"/items/"+id, method.equals("PUT") || method.equals("PATCH") ? "{\"name\":\"attack\"}" : null).statusCode()).isEqualTo(404);
        assertThat(send(b,"POST","/items",body).statusCode()).isEqualTo(404);
        assertThat(send(b,"GET","/items",null).body()).doesNotContain(id);
        assertThat(send(a,"GET","/items/"+id,null).body()).contains("Private");
        assertThat(jdbc.queryForObject("SELECT password_hash FROM app_user WHERE username=?",String.class,name)).doesNotContain("test-password");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM auth_session WHERE token_hash=?",Integer.class,a)).isZero();
        assertThat(send(a,"POST","/auth/password","{\"currentPassword\":\"test-password-123\",\"newPassword\":\"replacement-password\"}").statusCode()).isEqualTo(200);
        assertThat(send(a,"GET","/auth/me",null).statusCode()).isEqualTo(401);
        assertThat(send("","POST","/auth/login","{\"username\":\""+name+"\",\"password\":\"test-password-123\"}").statusCode()).isEqualTo(401);
        var logged = send("","POST","/auth/login","{\"username\":\""+name+"\",\"password\":\"replacement-password\"}");
        assertThat(logged.statusCode()).isEqualTo(200);
        String fresh = mapper.readTree(logged.body()).path("data").path("accessToken").asText();
        assertThat(send(fresh,"POST","/auth/logout",null).statusCode()).isEqualTo(200);
        assertThat(send(fresh,"GET","/auth/me",null).statusCode()).isEqualTo(401);
        assertThat(send(b,"GET","/auth/me",null).statusCode()).isEqualTo(200);
    }
    @Test void expiredTokensAndDuplicateAccounts() throws Exception {
        assertThat(send("","POST","/auth/phone/code","{\"phone\":\"13900000003\"}").statusCode()).isEqualTo(503);
        assertThat(mapper.readTree(send("","GET","/auth/methods",null).body()).path("data").path("huaweiEnabled").asBoolean()).isFalse();
        String name = "c"+UUID.randomUUID().toString().substring(0,8);
        String token = register(name);
        assertThat(send("","POST","/auth/register","{\"username\":\""+name.toUpperCase()+"\",\"password\":\"test-password-123\"}").statusCode()).isEqualTo(409);
        jdbc.update("UPDATE auth_session SET expires_at=TIMESTAMP '2000-01-01 00:00:00' WHERE user_id=(SELECT id FROM app_user WHERE username=?)",name);
        assertThat(send(token,"GET","/items",null).statusCode()).isEqualTo(401);
        assertThat(send("","POST","/auth/register","{\"username\":\"bad\",\"password\":\"short\"}").statusCode()).isEqualTo(400);
    }
    @Test void backupIsolationConflictAndRecognition() throws Exception {
        String a = register("d"+UUID.randomUUID().toString().substring(0,8));
        String b = register("e"+UUID.randomUUID().toString().substring(0,8));
        String doc = "{\"schemaVersion\":1,\"items\":[],\"records\":[],\"shopping\":[]}";
        String body = mapper.writeValueAsString(java.util.Map.of("expectedRevision",0,"payload",doc));
        assertThat(send(a,"PUT","/backup",body).statusCode()).isEqualTo(200);
        assertThat(send(a,"PUT","/backup",body).statusCode()).isEqualTo(409);
        assertThat(mapper.readTree(send(b,"GET","/backup",null).body()).path("data").path("revision").asInt()).isZero();
        String next = mapper.writeValueAsString(java.util.Map.of("expectedRevision",1,"payload",doc));
        assertThat(send(a,"PUT","/backup",next).statusCode()).isEqualTo(200);
        assertThat(send(a,"PUT","/backup",next).statusCode()).isEqualTo(409);
        assertThat(send(a,"PUT","/backup","{\"expectedRevision\":2,\"payload\":\"{}\"}").statusCode()).isEqualTo(400);
        assertThat(mapper.readTree(send(a,"GET","/backup",null).body()).path("data").path("revision").asInt()).isEqualTo(2);
        var recognized = send(a,"POST","/recognition/text","{\"text\":\"品名：牛奶\\n生产日期2026年10月3日\\n保质期30天\"}");
        assertThat(recognized.statusCode()).isEqualTo(200);
        assertThat(mapper.readTree(recognized.body()).path("data").path("production").asText()).isEqualTo("2026-10-03");
        assertThat(send("","POST","/recognition/text","{\"text\":\"到期2027-01-01\"}").statusCode()).isEqualTo(401);
    }
}
