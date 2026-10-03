package com.smartexpiry.recognition;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;
import static org.assertj.core.api.Assertions.assertThat;

class RecognitionEngineTest {
    @Test void sharedFixtures() throws Exception {
        var json = JsonMapper.builder().build(); var engine = new RecognitionEngine();
        try (var stream = getClass().getResourceAsStream("/shared/recognition-test-cases.json")) {
            for (var fixture : json.readTree(stream)) {
                var draft = engine.parse(fixture.get("text").asText()); var actual = json.valueToTree(draft);
                for (String field : new String[]{"name","production","expiry","shelfLife","unit"})
                    assertThat(actual.get(field)).as(fixture.get("id").asText()+":"+field).isEqualTo(fixture.get(field));
                assertThat(draft.candidates()).hasSize(fixture.get("candidateCount").asInt());
                assertThat(draft.requiresConfirmation()).isTrue();
            }
        }
    }
}
