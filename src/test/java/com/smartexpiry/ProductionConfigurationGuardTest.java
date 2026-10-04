package com.smartexpiry;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import com.smartexpiry.system.ProductionConfigurationGuard;
import static org.assertj.core.api.Assertions.*;
class ProductionConfigurationGuardTest {
    MockEnvironment configured() {
        return new MockEnvironment().withProperty("spring.datasource.url","jdbc:postgresql://database:5432/smart_expiry")
            .withProperty("spring.datasource.username","app").withProperty("spring.datasource.password","dedicated-test-password");
    }
    @Test void acceptsDedicatedDatabaseAndRejectsLocalDebug() {
        var env=configured();env.setActiveProfiles("prod");assertThatCode(()->new ProductionConfigurationGuard(env)).doesNotThrowAnyException();
        env.setActiveProfiles("prod","local-sms");assertThatThrownBy(()->new ProductionConfigurationGuard(env)).isInstanceOf(IllegalStateException.class);
    }
    @Test void rejectsDefaultCredentialsAndH2() {
        var env=configured().withProperty("spring.datasource.password","smart_expiry");assertThatThrownBy(()->new ProductionConfigurationGuard(env)).isInstanceOf(IllegalStateException.class);
        var invalid=configured().withProperty("spring.datasource.url","jdbc:h2:mem:test");
        assertThatThrownBy(()->new ProductionConfigurationGuard(invalid)).isInstanceOf(IllegalStateException.class);
    }
}
