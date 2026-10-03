package com.smartexpiry.auth;

import com.smartexpiry.common.exception.BusinessException;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Service;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;

/** Explicit local-sms profile only. This is not an SMS provider or verified phone ownership. */
@Service
public class LocalPhoneService {
    public record CodeResult(String mode, String debugCode, int expiresIn, int retryAfter) {}
    private static final class Challenge {
        String code;
        long issued;
        int attempts;
        Challenge(String code,long issued) { this.code=code; this.issued=issued; }
    }
    private final Map<String,Challenge> challenges = new HashMap<>();
    private final SecureRandom random = new SecureRandom();
    private final Environment environment;
    public LocalPhoneService(Environment environment) { this.environment=environment; }
    public boolean enabled() { return environment.acceptsProfiles(Profiles.of("local-sms")); }
    private void requireLocal() { if (!enabled()) throw new BusinessException(200503,"短信服务未配置；本地调试需启用 local-sms profile"); }
    public synchronized CodeResult send(String phone) {
        requireLocal(); long now=System.currentTimeMillis();
        challenges.entrySet().removeIf(e -> now-e.getValue().issued >= 300000);
        var previous=challenges.get(phone);
        if (previous != null && now-previous.issued < 60000) throw new BusinessException(200429,"请等待 60 秒后重新获取验证码");
        if (challenges.size() >= 1000 && previous == null) throw new BusinessException(200429,"调试验证码请求过多，请稍后再试");
        String code=String.format("%06d",random.nextInt(1000000));
        challenges.put(phone,new Challenge(code,now));
        return new CodeResult("LOCAL_DEBUG",code,300,60);
    }
    public synchronized void consume(String phone,String code) {
        requireLocal(); var current=challenges.get(phone);
        if (current == null || System.currentTimeMillis()-current.issued >= 300000 || current.attempts >= 5)
            throw new BusinessException(200001,"验证码已失效，请重新获取");
        current.attempts++;
        if (!current.code.equals(code)) throw new BusinessException(200001,"验证码错误");
        // Retain cooldown until expiry, but never allow replay.
        current.attempts=5;
    }
}
