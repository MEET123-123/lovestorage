package com.smartexpiry.expiry.domain;

import java.time.LocalDate;

public record ExpiryEvaluation(
    LocalDate effectiveExpiryDate,
    Integer remainingDays,
    ExpiryStatus status
) {}
