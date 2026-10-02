package com.smartexpiry;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
class ItemApiIntegrationTest {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    @Test
    void healthAndItemCrudSmokeTest() {
        var health = rest.getForEntity(url("/api/v1/health"), Map.class);
        assertThat(health.getStatusCode()).isEqualTo(HttpStatus.OK);

        Map<String, Object> create = Map.of(
            "name", "M1 Test Milk",
            "categoryId", "food",
            "quantity", 1,
            "unit", "box",
            "productionDate", "2026-10-02",
            "shelfLifeValue", 28,
            "shelfLifeUnit", "DAY"
        );
        var created = rest.postForEntity(url("/api/v1/items"), create, Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> data = (Map<?, ?>) created.getBody().get("data");
        String id = data.get("id").toString();
        assertThat(data.get("expiryDate").toString()).isEqualTo("2026-10-30");

        var fetched = rest.getForEntity(url("/api/v1/items/" + id), Map.class);
        assertThat(fetched.getStatusCode()).isEqualTo(HttpStatus.OK);

        var deleted = rest.exchange(url("/api/v1/items/" + id), HttpMethod.DELETE, HttpEntity.EMPTY, Map.class);
        assertThat(deleted.getStatusCode()).isEqualTo(HttpStatus.OK);

        var missing = rest.getForEntity(url("/api/v1/items/" + id), Map.class);
        assertThat(missing.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    private String url(String path) {
        return "http://localhost:" + port + path;
    }
}
