package com.smartexpiry.item.api;

import com.smartexpiry.expiry.domain.ShelfLifeUnit;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record UpdateItemRequest(
    com.smartexpiry.item.domain.ItemLifecycleStatus lifecycleStatus,
    @Size(min = 1, max = 120) String name,
    String categoryId,
    @Size(min = 1, max = 120) String brand,
    @Positive @jakarta.validation.constraints.Digits(integer=9, fraction=3) @jakarta.validation.constraints.DecimalMax("999999999") BigDecimal quantity,
    @Size(max = 32) String unit,
    LocalDate productionDate,
    LocalDate expiryDate,
    @Positive @jakarta.validation.constraints.Max(1200) Integer shelfLifeValue,
    ShelfLifeUnit shelfLifeUnit,
    LocalDate openedDate,
    @Positive @jakarta.validation.constraints.Max(1200) Integer afterOpenValue,
    ShelfLifeUnit afterOpenUnit
) {}
