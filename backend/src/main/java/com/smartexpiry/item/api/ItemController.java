package com.smartexpiry.item.api;

import com.smartexpiry.common.api.ApiResponse;
import com.smartexpiry.item.application.ItemApplicationService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/items")
public class ItemController {
    private final ItemApplicationService service;

    public ItemController(ItemApplicationService service) {
        this.service = service;
    }

    @PostMapping
    public ApiResponse<ItemResponse> create(@Valid @RequestBody CreateItemRequest request) {
        return ApiResponse.success(service.create(request));
    }

    @GetMapping
    public ApiResponse<List<ItemResponse>> list() {
        return ApiResponse.success(service.list());
    }

    @GetMapping("/{itemId}")
    public ApiResponse<ItemResponse> get(@PathVariable String itemId) {
        return ApiResponse.success(service.get(itemId));
    }

    @PatchMapping("/{itemId}")
    public ApiResponse<ItemResponse> update(@PathVariable String itemId,
                                            @Valid @RequestBody UpdateItemRequest request) {
        return ApiResponse.success(service.update(itemId, request));
    }

    @DeleteMapping("/{itemId}")
    public ApiResponse<Boolean> delete(@PathVariable String itemId) {
        service.delete(itemId);
        return ApiResponse.success(true);
    }
}
