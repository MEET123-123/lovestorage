package com.smartexpiry;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@org.springframework.scheduling.annotation.EnableScheduling
public class SmartExpiryApplication {
    public static void main(String[] args) {
        SpringApplication.run(SmartExpiryApplication.class, args);
    }
}
