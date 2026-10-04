package com.smartexpiry.algorithm.attention;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import static org.assertj.core.api.Assertions.*;

class AttentionContractTest {
    private final JsonMapper mapper=JsonMapper.builder().build();
    private AttentionEngine engine() throws Exception {
        try(var input=getClass().getResourceAsStream("/algorithm/contracts/attention-rules.json")) {
            return new AttentionEngine(mapper.readValue(input,AttentionEngine.Rules.class));
        }
    }
    @Test void goldenCasesAndStableRanking() throws Exception {
        var engine=engine();
        var root=mapper.readTree(getClass().getResourceAsStream("/algorithm/contracts/attention-test-cases.json"));
        var today=LocalDate.parse(root.path("today").asText());
        List<AttentionEngine.Input> inputs=new ArrayList<>();
        for(var test:root.path("cases")) {
            Map<String,Object> fields=new LinkedHashMap<>(Map.of("itemId",test.path("id").asText(),
                "reminderDays",7,"quantity",1,"lifecycleStatus","ACTIVE","deleted",false));
            test.path("input").properties().forEach(e -> fields.put(e.getKey(),mapper.treeToValue(e.getValue(),Object.class)));
            var input=mapper.convertValue(fields,AttentionEngine.Input.class); inputs.add(input);
            var result=engine.evaluate(input,today);
            if(test.path("excluded").asBoolean()) { assertThat(result).as(input.itemId()).isEmpty(); continue; }
            var decision=result.orElseThrow();
            assertThat(decision.score()).as(input.itemId()).isEqualTo(test.path("score").asInt());
            assertThat(decision.priority()).isEqualTo(test.path("priority").asText());
            assertThat(mapper.writeValueAsString(decision.reasonCodes())).isEqualTo(test.path("reasonCodes").toString());
            assertThat(decision.ruleVersion()).isEqualTo("attention-rule-v1");
            if(test.has("effectiveExpiryDate")) assertThat(decision.effectiveExpiryDate().toString()).isEqualTo(test.path("effectiveExpiryDate").asText());
        }
        var result=engine.rank(inputs,today,3);
        assertThat(result).extracting(AttentionEngine.Decision::itemId).containsExactly("month-clamp","pao","expired");
        var a=new AttentionEngine.Input("a",today,null,null,null,7,BigDecimal.ONE,"ACTIVE",false,null);
        var b=new AttentionEngine.Input("b",today,null,null,null,7,BigDecimal.ONE,"ACTIVE",false,null);
        assertThat(engine.rank(List.of(b,a),today,2)).extracting(AttentionEngine.Decision::itemId).containsExactly("a","b");
    }
}
