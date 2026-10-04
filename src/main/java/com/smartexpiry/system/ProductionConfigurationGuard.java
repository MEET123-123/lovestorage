package com.smartexpiry.system;

import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

@Component
@Profile("prod")
public class ProductionConfigurationGuard {
    public ProductionConfigurationGuard(Environment environment) {
        if(environment.acceptsProfiles(Profiles.of("local | local-sms")))
            throw new IllegalStateException("prod cannot enable local or local-sms profiles");
        String url=environment.getProperty("spring.datasource.url","");
        String user=environment.getProperty("spring.datasource.username","");
        String password=environment.getProperty("spring.datasource.password","");
        if(!url.startsWith("jdbc:postgresql://") || user.isBlank() || password.isBlank() || password.equals("smart_expiry"))
            throw new IllegalStateException("prod requires an explicit PostgreSQL URL, username and non-default password");
    }
}
