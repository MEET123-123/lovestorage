package com.smartexpiry;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ItemApiIntegrationTest {
    @LocalServerPort int port;
    private final HttpClient client = HttpClient.newHttpClient();
    private final JsonMapper json = JsonMapper.builder().build();
    private String token = "";
    @org.junit.jupiter.api.BeforeEach void login() throws Exception {
        token = data(send("POST", "/auth/register", "{\"username\":\"u" + UUID.randomUUID().toString().replace("-", "").substring(0,20) + "\",\"password\":\"test-password-123\"}"))
            .get("accessToken").asText();
    }

    private HttpResponse<String> send(String method, String path, String body) throws Exception {
        return client.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1" + path))
            .header("Content-Type", "application/json")
            .header("Authorization", "Bearer " + token)
            .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body))
            .build(), HttpResponse.BodyHandlers.ofString());
    }
    private JsonNode data(HttpResponse<String> response) {
        assertThat(response.statusCode()).isEqualTo(200);
        return json.readTree(response.body()).get("data");
    }
    private String create() throws Exception {
        return data(send("POST", "/items", """
            {"name":"Milk","categoryId":"food","productionDate":"2026-10-02","shelfLifeValue":28,"shelfLifeUnit":"DAY"}
            """)).get("id").asText();
    }
    @Test void crudAndLifecycle() throws Exception {
        assertThat(data(send("GET", "/health", null)).get("status").asText()).isEqualTo("UP");
        assertThat(data(send("GET", "/categories", null)).size()).isEqualTo(4);
        String id = create();
        var item = data(send("GET", "/items/" + id, null));
        assertThat(item.get("expiryDate").asText()).isEqualTo("2026-10-30");
        assertThat(item.has("expiryStatus")).isTrue();
        var updated = data(send("PATCH", "/items/" + id, "{\"shelfLifeValue\":30,\"name\":\"Updated\"}"));
        assertThat(updated.get("expiryDate").asText()).isEqualTo("2026-11-01");
        assertThat(updated.get("name").asText()).isEqualTo("Updated");
        assertThat(data(send("PUT", "/items/" + id, "{\"lifecycleStatus\":\"CONSUMED\"}"))
            .get("lifecycleStatus").asText()).isEqualTo("CONSUMED");
        data(send("DELETE", "/items/" + id, null));
        assertThat(send("GET", "/items/" + id, null).statusCode()).isEqualTo(404);
        assertThat(data(send("GET", "/items", null)).toString()).doesNotContain(id);
    }
    @Test void retryDoesNotDuplicateOrResurrectDeletedItems() throws Exception {
        String id = UUID.randomUUID().toString();
        String body = "{\"clientId\":\"" + id + "\",\"name\":\"Retry\",\"categoryId\":\"food\",\"expiryDate\":\"2026-10-10\"}";
        assertThat(data(send("POST", "/items", body)).get("id").asText()).isEqualTo(id);
        assertThat(data(send("POST", "/items", body)).get("id").asText()).isEqualTo(id);
        data(send("DELETE", "/items/" + id, null));
        assertThat(send("POST", "/items", body).statusCode()).isEqualTo(404);
    }
    @Test void validationAndRollback() throws Exception {
        for (String body : new String[] {
            "{\"name\":\" \",\"categoryId\":\"food\",\"expiryDate\":\"2026-10-10\"}",
            "{\"name\":\"X\",\"categoryId\":\"food\"}",
            "{\"name\":\"X\",\"categoryId\":\"missing\",\"expiryDate\":\"2026-10-10\"}",
            "{\"name\":\"X\",\"categoryId\":\"food\",\"expiryDate\":\"2026-02-30\"}", "{broken"
        }) assertThat(send("POST", "/items", body).statusCode()).isEqualTo(400);
        String id = create();
        assertThat(send("PATCH", "/items/" + id, "{\"name\":\" \",\"lifecycleStatus\":\"DISCARDED\"}").statusCode()).isEqualTo(400);
        for (String invalid : new String[]{"{\"quantity\":0}", "{\"quantity\":1.0001}", "{\"quantity\":1000000000}", "{\"shelfLifeValue\":1201}", "{\"afterOpenValue\":2,\"afterOpenUnit\":\"DAY\"}"})
            assertThat(send("PATCH", "/items/" + id, invalid).statusCode()).isEqualTo(400);
        assertThat(data(send("GET", "/items/" + id, null)).get("lifecycleStatus").asText()).isEqualTo("ACTIVE");
        assertThat(send("PATCH", "/items/" + id, "{\"expiryDate\":\"2020-01-01\"}").statusCode()).isEqualTo(400);
    }
}
