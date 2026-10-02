package com.smartexpiry.item.api;

import com.smartexpiry.expiry.domain.ShelfLifeUnit;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record UpdateItemRequest(
    @Size(min = 1, max = 120) String name,
    String categoryId,
    @Size(min = 1, max = 120) String brand,
    @PositiveOrZero BigDecimal quantity,
    @Size(max = 32) String unit,
    LocalDate productionDate,
    LocalDate expiryDate,
    @Positive Integer shelfLifeValue,
    ShelfLifeUnit shelfLifeUnit,
    LocalDate openedDate,
    @Positive Integer afterOpenValue,
    ShelfLifeUnit afterOpenUnit
) {}
