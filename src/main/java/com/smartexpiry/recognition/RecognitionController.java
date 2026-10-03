package com.smartexpiry.recognition;

import com.smartexpiry.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/recognition")
public class RecognitionController {
    public record TextRequest(@NotBlank @Size(max=2000) String text) {}
    private final RecognitionEngine engine;
    public RecognitionController(RecognitionEngine engine) { this.engine = engine; }
    @PostMapping("/text") public ApiResponse<RecognitionEngine.Draft> recognize(@Valid @RequestBody TextRequest body) {
        return ApiResponse.success(engine.parse(body.text()));
    }
}
