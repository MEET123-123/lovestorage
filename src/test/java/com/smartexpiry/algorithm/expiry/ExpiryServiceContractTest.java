package com.smartexpiry.algorithm.expiry;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import com.smartexpiry.algorithm.expiry.ExpiryService;
import com.smartexpiry.algorithm.expiry.ShelfLifeUnit;
import org.junit.jupiter.api.Test;

import java.io.InputStream;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class ExpiryServiceContractTest {
    private final ExpiryService service = new ExpiryService();

    @Test
    void sharedExpiryCasesMustMatchJavaRules() throws Exception {
        InputStream input = getClass().getClassLoader().getResourceAsStream("algorithm/contracts/expiry-test-cases.json");
        assertNotNull(input, "shared fixture must be on test classpath");

        JsonNode cases = JsonMapper.builder().build().readTree(input);
        for (JsonNode row : cases) {
            LocalDate today = LocalDate.parse(row.get("today").asText());
            LocalDate expiryDate = LocalDate.parse(row.get("expiryDate").asText());
            LocalDate openedDate = row.has("openedDate") ? LocalDate.parse(row.get("openedDate").asText()) : null;
            Integer afterOpenValue = row.has("afterOpenValue") ? row.get("afterOpenValue").asInt() : null;
            ShelfLifeUnit afterOpenUnit = row.has("afterOpenUnit")
                ? ShelfLifeUnit.valueOf(row.get("afterOpenUnit").asText()) : null;

            var result = service.evaluate(
                expiryDate, openedDate, afterOpenValue, afterOpenUnit,
                row.get("reminderDays").asInt(), today
            );

            String id = row.get("id").asText();
            assertEquals(row.get("expectedEffectiveExpiryDate").asText(), result.effectiveExpiryDate().toString(), id);
            assertEquals(row.get("expectedRemainingDays").asInt(), result.remainingDays(), id);
            assertEquals(row.get("expectedStatus").asText(), result.status().name(), id);
        }
    }
}
