package com.smartexpiry.category;

import com.smartexpiry.common.api.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/categories")
public class CategoryController {
    private final CategoryRepository repository;

    public CategoryController(CategoryRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public ApiResponse<List<CategoryResponse>> list() {
        var rows = repository.findAll().stream()
            .map(it -> new CategoryResponse(it.getId(), it.getName(), it.getType()))
            .toList();
        return ApiResponse.success(rows);
    }
}
