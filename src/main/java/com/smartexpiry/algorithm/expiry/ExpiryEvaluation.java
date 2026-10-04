package com.smartexpiry.algorithm.expiry;

import java.time.LocalDate;

public record ExpiryEvaluation(
    LocalDate effectiveExpiryDate,
    Integer remainingDays,
    ExpiryStatus status
) {}
