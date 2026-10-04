package com.smartexpiry.algorithm.expiry;

import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

@Component
public class ExpiryService {
    public static int defaultReminderDays(String categoryId) {
        return switch (categoryId) { case "cosmetics" -> 30; case "pet_food" -> 14; default -> 7; };
    }

    public ExpiryEvaluation evaluate(
        LocalDate expiryDate,
        LocalDate openedDate,
        Integer afterOpenValue,
        ShelfLifeUnit afterOpenUnit,
        int reminderDays,
        LocalDate today
    ) {
        LocalDate effective = effectiveExpiryDate(expiryDate, openedDate, afterOpenValue, afterOpenUnit);
        if (effective == null) {
            return new ExpiryEvaluation(null, null, ExpiryStatus.UNKNOWN);
        }
        int remaining = Math.toIntExact(ChronoUnit.DAYS.between(today, effective));
        ExpiryStatus status = remaining < 0
            ? ExpiryStatus.EXPIRED
            : remaining <= reminderDays ? ExpiryStatus.NEAR_EXPIRY : ExpiryStatus.NORMAL;
        return new ExpiryEvaluation(effective, remaining, status);
    }

    public LocalDate effectiveExpiryDate(
        LocalDate expiryDate,
        LocalDate openedDate,
        Integer afterOpenValue,
        ShelfLifeUnit afterOpenUnit
    ) {
        LocalDate afterOpenExpiry = null;
        if (openedDate != null && afterOpenValue != null && afterOpenUnit != null) {
            afterOpenExpiry = switch (afterOpenUnit) {
                case DAY -> openedDate.plusDays(afterOpenValue);
                case MONTH -> openedDate.plusMonths(afterOpenValue);
                case YEAR -> openedDate.plusYears(afterOpenValue);
            };
        }
        if (expiryDate == null) return afterOpenExpiry;
        if (afterOpenExpiry == null) return expiryDate;
        return expiryDate.isBefore(afterOpenExpiry) ? expiryDate : afterOpenExpiry;
    }

    public LocalDate deriveExpiryDate(LocalDate productionDate, Integer value, ShelfLifeUnit unit) {
        if (productionDate == null || value == null || unit == null) return null;
        return switch (unit) {
            case DAY -> productionDate.plusDays(value);
            case MONTH -> productionDate.plusMonths(value);
            case YEAR -> productionDate.plusYears(value);
        };
    }
}
