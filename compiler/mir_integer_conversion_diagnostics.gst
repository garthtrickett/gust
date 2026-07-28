// Diagnostics consume the compiler-owned conversion rule and never recompute
// widths, signedness, target selection, or policy.

import "mir_integer_conversion.gst" as conversion;

func mir_integer_conversion_diagnostic(rule: conversion.MirIntegerConversionRule[ctx], reason_code: str, ctx: &Arena) str {
    mut output := "gust_integer_conversion_diagnostic: contract=gust.integer_conversion.diagnostic.v1";
    output = std.Concat(output, " source_type=");
    output = std.Concat(output, rule.source_type_id);
    output = std.Concat(output, " destination_type=");
    output = std.Concat(output, rule.destination_type_id);
    output = std.Concat(output, " target=");
    output = std.Concat(output, rule.target_triple);
    output = std.Concat(output, " source_width=");
    output = std.Concat(output, std.FormatInt(rule.source_width));
    output = std.Concat(output, " destination_width=");
    output = std.Concat(output, std.FormatInt(rule.destination_width));
    output = std.Concat(output, " conversion_kind=");
    output = std.Concat(output, rule.kind);
    output = std.Concat(output, " policy=");
    output = std.Concat(output, rule.policy);
    output = std.Concat(output, " reason_code=");
    output = std.Concat(output, reason_code);
    return std.Clone(ctx, output);
}

func mir_integer_conversion_missing_rule_diagnostic(source_type_id: str, destination_type_id: str, target_triple: str, kind: str, policy: str, reason_code: str, ctx: &Arena) str {
    mut output := "gust_integer_conversion_diagnostic: contract=gust.integer_conversion.diagnostic.v1";
    output = std.Concat(output, " source_type=");
    output = std.Concat(output, source_type_id);
    output = std.Concat(output, " destination_type=");
    output = std.Concat(output, destination_type_id);
    output = std.Concat(output, " target=");
    output = std.Concat(output, target_triple);
    output = std.Concat(output, " source_width=unknown destination_width=unknown conversion_kind=");
    output = std.Concat(output, kind);
    output = std.Concat(output, " policy=");
    output = std.Concat(output, policy);
    output = std.Concat(output, " reason_code=");
    output = std.Concat(output, reason_code);
    return std.Clone(ctx, output);
}