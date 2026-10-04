package com.smartexpiry.algorithm.attention;

import com.smartexpiry.algorithm.expiry.ExpiryService;
import com.smartexpiry.algorithm.expiry.ShelfLifeUnit;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;

/** A deterministic attention ranking, never a food safety assessment. */
public class AttentionEngine {
    public record Rules(String version, int expired, int today, int tomorrow, int twoDays,
        int threeDays, int week, int withinWindow, int unknown, int opened, int paoNear,
        int paoWindowDays, int snoozeReturned, int quantityThreshold, int quantityBonus,
        int highThreshold, int mediumThreshold) {
        public void validate() {
            if (version == null || version.isBlank() || quantityThreshold < 1 || paoWindowDays < 0
                || highThreshold <= mediumThreshold || mediumThreshold < 0
                || java.util.stream.IntStream.of(expired,today,tomorrow,twoDays,threeDays,week,
                    withinWindow,unknown,opened,paoNear,snoozeReturned,quantityBonus).anyMatch(n -> n < 0 || n > 1000))
                throw new IllegalArgumentException("Invalid attention rule configuration");
        }
    }
    public record Input(String itemId, LocalDate expiryDate, LocalDate openedDate,
        Integer afterOpenValue, ShelfLifeUnit afterOpenUnit, int reminderDays,
        BigDecimal quantity, String lifecycleStatus, boolean deleted, LocalDate snoozeUntil) {}
    public record Decision(String itemId, int score, String priority, List<String> reasonCodes,
        LocalDate effectiveExpiryDate, Integer remainingDays, String ruleVersion) {}
    private final Rules rules;
    private final ExpiryService expiry = new ExpiryService();
    public AttentionEngine(Rules rules) { rules.validate(); this.rules = rules; }

    public Optional<Decision> evaluate(Input input, LocalDate date) {
        if (input.deleted() || !"ACTIVE".equals(input.lifecycleStatus())
            || input.quantity() != null && input.quantity().signum() <= 0
            || input.snoozeUntil() != null && input.snoozeUntil().isAfter(date)) return Optional.empty();
        var evaluation = expiry.evaluate(input.expiryDate(), input.openedDate(), input.afterOpenValue(),
            input.afterOpenUnit(), input.reminderDays(), date);
        Integer days = evaluation.remainingDays();
        if (days != null && days > input.reminderDays()) return Optional.empty();
        List<String> reasons = new ArrayList<>();
        int score;
        if (days == null) { score = rules.unknown(); reasons.add("MISSING_EXPIRY"); }
        else if (days < 0) { score = rules.expired(); reasons.add("EXPIRED"); }
        else if (days == 0) { score = rules.today(); reasons.add("EXPIRES_TODAY"); }
        else if (days == 1) { score = rules.tomorrow(); reasons.add("EXPIRES_TOMORROW"); }
        else if (days == 2) { score = rules.twoDays(); reasons.add("EXPIRES_IN_TWO_DAYS"); }
        else if (days == 3) { score = rules.threeDays(); reasons.add("EXPIRES_IN_THREE_DAYS"); }
        else if (days <= 7) { score = rules.week(); reasons.add("EXPIRES_THIS_WEEK"); }
        else { score = rules.withinWindow(); reasons.add("WITHIN_REMINDER_WINDOW"); }
        if (input.openedDate() != null && !input.openedDate().isAfter(date)) {
            score += rules.opened(); reasons.add("OPENED");
            LocalDate pao = expiry.effectiveExpiryDate(null,input.openedDate(),input.afterOpenValue(),input.afterOpenUnit());
            if (pao != null) {
                long remaining = ChronoUnit.DAYS.between(date,pao);
                if (remaining >= 0 && remaining <= rules.paoWindowDays()) { score += rules.paoNear(); reasons.add("PAO_NEAR"); }
            }
        }
        if (input.snoozeUntil() != null) { score += rules.snoozeReturned(); reasons.add("SNOOZE_RETURNED"); }
        if (input.quantity() != null && input.quantity().compareTo(BigDecimal.valueOf(rules.quantityThreshold())) >= 0) {
            score += rules.quantityBonus(); reasons.add("LARGE_QUANTITY");
        }
        String priority = score >= rules.highThreshold() ? "HIGH" : score >= rules.mediumThreshold() ? "MEDIUM" : "LOW";
        return Optional.of(new Decision(input.itemId(),score,priority,List.copyOf(reasons),
            evaluation.effectiveExpiryDate(),days,rules.version()));
    }
    public List<Decision> rank(List<Input> items, LocalDate today, int limit) {
        return items.stream().flatMap(i -> evaluate(i,today).stream())
            .sorted(Comparator.comparingInt(Decision::score).reversed()
                .thenComparing(Decision::effectiveExpiryDate, Comparator.nullsLast(Comparator.naturalOrder()))
                .thenComparing(Decision::itemId))
            .limit(limit).toList();
    }
}
