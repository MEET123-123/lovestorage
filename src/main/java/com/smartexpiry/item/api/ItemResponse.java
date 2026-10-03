package com.smartexpiry.item.api;

import com.smartexpiry.expiry.domain.ExpiryStatus;
import com.smartexpiry.item.domain.ItemLifecycleStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public record ItemResponse(
    String id,
    String name,
    String categoryId,
    String brand,
    ItemLifecycleStatus lifecycleStatus,
    BigDecimal quantity,
    String unit,
    LocalDate productionDate,
    LocalDate expiryDate,
    LocalDate effectiveExpiryDate,
    Integer remainingDays,
    ExpiryStatus expiryStatus,
    Instant createdAt,
    Instant updatedAt
) {}
