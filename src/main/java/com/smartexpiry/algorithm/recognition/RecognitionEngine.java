package com.smartexpiry.algorithm.recognition;

import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Pattern;

@Service
public class RecognitionEngine {
    public record Candidate(String field, String value, String evidence, double confidence) {}
    public record Draft(String name, String expiry, String production, String shelfLife, int unit,
                        List<Candidate> candidates, List<String> warnings, boolean requiresConfirmation, String engineVersion) {}
    private static final Pattern DATES = Pattern.compile("(生产日期|生产|制造日期|MFG|到期日期|到期|有效期至|保质期至|EXP)\\s*[:：]?\\s*(\\d{4})[-/.年](\\d{1,2})[-/.月](\\d{1,2})日?(?!\\d)",Pattern.CASE_INSENSITIVE);
    private static final Pattern LIFE = Pattern.compile("保质期\\s*[:：]?\\s*(\\d+)\\s*(天|个月|月|年)");
    public Draft parse(String input) {
        StringBuilder normalized = new StringBuilder();
        input.substring(0,Math.min(input.length(),2000)).chars().forEach(c -> normalized.append((char)(c >= 0xFF01 && c <= 0xFF5E ? c-0xFEE0 : c == 0x3000 ? ' ' : c)));
        String text = normalized.toString(), name = "", production = "", expiry = "", life = "";
        int unit = 0;
        var candidates = new ArrayList<Candidate>(); var warnings = new ArrayList<String>();
        var names = Pattern.compile("(?:名称|品名|产品名称)\\s*[:：]\\s*([^\\n;；]+)").matcher(text);
        if (names.find()) { name = names.group(1).trim(); name = name.substring(0,Math.min(80,name.length())); }
        var matcher = DATES.matcher(text);
        while (matcher.find()) {
            try {
                int year = Integer.parseInt(matcher.group(2));
                if (year < 1900) throw new IllegalArgumentException();
                String value = LocalDate.of(year,Integer.parseInt(matcher.group(3)),Integer.parseInt(matcher.group(4))).toString();
                String label = matcher.group(1).toUpperCase(Locale.ROOT);
                candidates.add(new Candidate(label.startsWith("生产") || label.startsWith("制造") || label.equals("MFG") ? "production" : "expiry",value,matcher.group(),0.95));
            } catch (Exception ex) { warnings.add("无效日期："+matcher.group()); }
        }
        for (String field : List.of("production","expiry")) {
            var values = candidates.stream().filter(c -> c.field().equals(field)).map(Candidate::value).distinct().toList();
            if (values.size() == 1) { if (field.equals("production")) production = values.getFirst(); else expiry = values.getFirst(); }
            if (values.size() > 1) warnings.add((field.equals("production") ? "生产" : "到期")+"日期存在多个候选，请手动选择");
        }
        var values = new LinkedHashSet<String>(); var lives = LIFE.matcher(text);
        while (lives.find()) {
            try {
                int value = Integer.parseInt(lives.group(1));
                if (value < 1 || value > 1200) throw new IllegalArgumentException();
                values.add(value+":"+(lives.group(2).equals("天") ? 0 : lives.group(2).equals("年") ? 2 : 1));
            } catch (Exception ex) { warnings.add("保质期超出 1–1200 的范围"); }
        }
        if (values.size() == 1) { var parts = values.getFirst().split(":"); life=parts[0]; unit=Integer.parseInt(parts[1]); }
        if (values.size() > 1) warnings.add("保质期存在多个候选，请手动选择");
        if (!production.isEmpty() && !expiry.isEmpty() && expiry.compareTo(production) < 0) { expiry=""; warnings.add("到期早于生产日期，请对照包装核对"); }
        if (expiry.isEmpty() && (production.isEmpty() || life.isEmpty())) warnings.add("未获得完整日期，不推测缺失年份或无标签日期");
        if (name.isEmpty()) warnings.add("未识别明确品名，请填写物品名称");
        if (input.length() > 2000) warnings.add("仅处理前 2000 个字符");
        return new Draft(name,expiry,production,life,unit,candidates,warnings,true,"rules-1.0");
    }
}
