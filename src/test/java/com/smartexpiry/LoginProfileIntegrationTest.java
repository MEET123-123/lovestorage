package com.smartexpiry;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.ActiveProfiles;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import java.net.URI;
import java.net.http.*;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

@ActiveProfiles("local-sms")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class LoginProfileIntegrationTest {
    @LocalServerPort int port;
    final HttpClient client=HttpClient.newHttpClient();
    final JsonMapper json=JsonMapper.builder().build();
    HttpResponse<String> send(String token,String method,String path,String body) throws Exception {
        return client.send(HttpRequest.newBuilder(URI.create("http://localhost:"+port+"/api/v1"+path))
            .header("Content-Type","application/json").header("Authorization","Bearer "+token)
            .method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(body)).build(),HttpResponse.BodyHandlers.ofString());
    }
    JsonNode data(HttpResponse<String> response) {
        assertThat(response.statusCode()).as(response.body()).isEqualTo(200);return json.readTree(response.body()).get("data");
    }
    @Test void phoneChallengeOneUseAndPersistentProfileIsolation() throws Exception {
        assertThat(data(send("","GET","/auth/methods",null)).get("phoneMode").asText()).isEqualTo("LOCAL_DEBUG");
        String phone="13900000001",body="{\"phone\":\""+phone+"\"}";
        String code=data(send("","POST","/auth/phone/code",body)).get("debugCode").asText();
        assertThat(code).matches("[0-9]{6}");
        assertThat(send("","POST","/auth/phone/code",body).statusCode()).isEqualTo(429);
        String login="{\"phone\":\""+phone+"\",\"code\":\""+code+"\"}";
        String token=data(send("","POST","/auth/phone/login",login)).get("accessToken").asText();
        assertThat(send("","POST","/auth/phone/login",login).statusCode()).isEqualTo(401);
        String profile="{\"displayName\":\"小满\",\"avatarKey\":\"cat\",\"bio\":\"好好生活\",\"allergies\":[\"花生\",\"花生\"],\"dislikes\":[\"香菜\"],\"preferences\":[\"清淡\",\"低糖\"]}";
        assertThat(data(send(token,"PUT","/profile",profile)).get("allergies").size()).isEqualTo(1);
        var saved=data(send(token,"GET","/profile",null));
        assertThat(saved.get("displayName").asText()).isEqualTo("小满");
        assertThat(saved.get("avatarKey").asText()).isEqualTo("cat");
        assertThat(saved.get("preferences").size()).isEqualTo(2);
        String other=data(send("","POST","/auth/register","{\"username\":\"u"+UUID.randomUUID().toString().replace("-", "").substring(0,15)+"\",\"password\":\"integration-test-password\"}")).get("accessToken").asText();
        assertThat(data(send(other,"GET","/profile",null)).get("allergies").size()).isZero();
        assertThat(send("","GET","/profile",null).statusCode()).isEqualTo(401);
        assertThat(send(token,"PUT","/profile",profile.replace("cat","invalid-avatar")).statusCode()).isEqualTo(400);
        assertThat(send(token,"PUT","/profile",profile.replace("小满"," ")).statusCode()).isEqualTo(400);
        assertThat(data(send(token,"GET","/profile",null)).get("displayName").asText()).isEqualTo("小满");
    }
    @Test void phoneAttemptLimitAndMalformedPhone() throws Exception {
        assertThat(send("","POST","/auth/phone/code","{\"phone\":\"123\"}").statusCode()).isEqualTo(400);
        String phone="13900000002";
        String code=data(send("","POST","/auth/phone/code","{\"phone\":\""+phone+"\"}")).get("debugCode").asText();
        String wrong=code.equals("000000")?"111111":"000000";
        for(int n=0;n<5;n++) assertThat(send("","POST","/auth/phone/login","{\"phone\":\""+phone+"\",\"code\":\""+wrong+"\"}").statusCode()).isEqualTo(401);
        assertThat(send("","POST","/auth/phone/login","{\"phone\":\""+phone+"\",\"code\":\""+code+"\"}").statusCode()).isEqualTo(401);
    }
}
