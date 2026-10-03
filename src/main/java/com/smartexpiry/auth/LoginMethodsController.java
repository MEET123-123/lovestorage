package com.smartexpiry.auth;

import com.smartexpiry.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class LoginMethodsController {
    public record Methods(String phoneMode, boolean huaweiEnabled, String huaweiMessage) {}
    public record Phone(@NotNull @Pattern(regexp="1[3-9][0-9]{9}") String phone) {}
    public record PhoneLogin(@NotNull @Pattern(regexp="1[3-9][0-9]{9}") String phone,
                             @NotNull @Pattern(regexp="[0-9]{6}") String code) {}
    private final LocalPhoneService phone;
    private final AuthService auth;
    public LoginMethodsController(LocalPhoneService phone, AuthService auth) { this.phone=phone; this.auth=auth; }
    @GetMapping("/methods") public ApiResponse<Methods> methods() {
        return ApiResponse.success(new Methods(phone.enabled() ? "LOCAL_DEBUG" : "UNAVAILABLE",false,"尚未配置华为应用 App ID、签名与服务端授权验证，请先使用账号密码或本地手机号调试"));
    }
    @PostMapping("/phone/code") public ApiResponse<LocalPhoneService.CodeResult> code(@Valid @RequestBody Phone request) {
        return ApiResponse.success(phone.send(request.phone()));
    }
    @PostMapping("/phone/login") public ApiResponse<AuthService.Session> login(@Valid @RequestBody PhoneLogin request) {
        phone.consume(request.phone(),request.code());
        return ApiResponse.success(auth.localPhoneLogin(request.phone()));
    }
}
