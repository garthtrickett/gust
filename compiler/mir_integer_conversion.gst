// Phase 14.3 compiler-owned signed, unsigned, and width-conversion authority.
//
// Conversion meaning is selected here before either backend runs. The C and
// Cranelift consumers receive the same target identity, scalar layout IDs,
// explicit conversion kind, width/signedness pair, policy, and stable reason
// codes. This module intentionally does not model pointer/integer or floating-
// point conversions.

import "mir_layout.gst" as layout;

// Sample values are canonical decimal text. Gust `int` currently lowers to C
// `int`, so a text carrier preserves u32/i64/u64 boundary values without host
// overflow before the compiler-owned request reaches either backend.

type MirIntegerConversionRule[ctx] struct {
    rule_id: str,
    rule_name: str,
    target_id: str,
    target_triple: str,
    kind: str,
    source_type_id: str,
    source_layout_id: str,
    destination_type_id: str,
    destination_layout_id: str,
    source_width: int,
    destination_width: int,
    source_signedness: str,
    destination_signedness: str,
    policy: str,
    success_reason_code: str,
    failure_reason_code: str,
    target_required: int
}

type MirIntegerConversionSample[ctx] struct {
    sample_id: str,
    rule_id: str,
    rule_name: str,
    context_kind: str,
    input_value: str,
    expect_success: int,
    expected_value: str,
    expected_reason_code: str
}

type MirIntegerConversionTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    rules: Index[std.Vector[MirIntegerConversionRule[ctx], ctx], ctx],
    samples: Index[std.Vector[MirIntegerConversionSample[ctx], ctx], ctx]
}

type MirIntegerConversionRuleQuery[ctx] struct {
    found: int,
    rule: MirIntegerConversionRule[ctx]
}

type MirIntegerConversionValidation[ctx] struct {
    valid: int,
    reason_code: str,
    rule: MirIntegerConversionRule[ctx]
}

type MirIntegerConversionResult[ctx] struct {
    success: int,
    value: int,
    reason_code: str
}

func mir_integer_conversion_empty_rule_vector(ctx: &Arena) Index[std.Vector[MirIntegerConversionRule[ctx], ctx], ctx] {
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := std.VectorNew(ctx);
    mut rules_idx: Index[std.Vector[MirIntegerConversionRule[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(rules_idx, rules);
    return rules_idx;
}

func mir_integer_conversion_empty_sample_vector(ctx: &Arena) Index[std.Vector[MirIntegerConversionSample[ctx], ctx], ctx] {
    mut samples: std.Vector[MirIntegerConversionSample[ctx], ctx] := std.VectorNew(ctx);
    mut samples_idx: Index[std.Vector[MirIntegerConversionSample[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(samples_idx, samples);
    return samples_idx;
}

func mir_integer_conversion_make_empty_table(target_triple: str, ctx: &Arena) MirIntegerConversionTable[ctx] {
    mut table: MirIntegerConversionTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_integer_conversion_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.rules = mir_integer_conversion_empty_rule_vector(ctx);
    table.samples = mir_integer_conversion_empty_sample_vector(ctx);
    return table;
}

func mir_integer_conversion_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "sign_extend") == 1 { return 1; }
    if std.str_eq(kind, "zero_extend") == 1 { return 1; }
    if std.str_eq(kind, "truncate") == 1 { return 1; }
    if std.str_eq(kind, "checked_numeric") == 1 { return 1; }
    if std.str_eq(kind, "wrapping_numeric") == 1 { return 1; }
    if std.str_eq(kind, "bit_reinterpret") == 1 { return 1; }
    if std.str_eq(kind, "bool_to_integer") == 1 { return 1; }
    if std.str_eq(kind, "integer_to_bool") == 1 { return 1; }
    return 0;
}

func mir_integer_conversion_identity(target_id: str, kind: str, source_type_id: str, destination_type_id: str, source_width: int, destination_width: int, policy: str, ctx: &Arena) str {
    mut identity := "conversion:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    identity = std.Concat(identity, ":source=");
    identity = std.Concat(identity, source_type_id);
    identity = std.Concat(identity, ":destination=");
    identity = std.Concat(identity, destination_type_id);
    identity = std.Concat(identity, ":source_width=");
    identity = std.Concat(identity, std.FormatInt(source_width));
    identity = std.Concat(identity, ":destination_width=");
    identity = std.Concat(identity, std.FormatInt(destination_width));
    identity = std.Concat(identity, ":policy=");
    identity = std.Concat(identity, policy);
    return std.Clone(ctx, identity);
}

func mir_integer_conversion_make_rule(rule_name: str, target_id: str, target_triple: str, kind: str, source_type_id: str, source_layout_id: str, destination_type_id: str, destination_layout_id: str, source_width: int, destination_width: int, source_signedness: str, destination_signedness: str, policy: str, failure_reason_code: str, target_required: int, ctx: &Arena) MirIntegerConversionRule[ctx] {
    mut rule: MirIntegerConversionRule[ctx];
    rule.rule_id = mir_integer_conversion_identity(
        target_id,
        kind,
        source_type_id,
        destination_type_id,
        source_width,
        destination_width,
        policy,
        ctx
    );
    rule.rule_name = std.Clone(ctx, rule_name);
    rule.target_id = std.Clone(ctx, target_id);
    rule.target_triple = std.Clone(ctx, target_triple);
    rule.kind = std.Clone(ctx, kind);
    rule.source_type_id = std.Clone(ctx, source_type_id);
    rule.source_layout_id = std.Clone(ctx, source_layout_id);
    rule.destination_type_id = std.Clone(ctx, destination_type_id);
    rule.destination_layout_id = std.Clone(ctx, destination_layout_id);
    rule.source_width = source_width;
    rule.destination_width = destination_width;
    rule.source_signedness = std.Clone(ctx, source_signedness);
    rule.destination_signedness = std.Clone(ctx, destination_signedness);
    rule.policy = std.Clone(ctx, policy);
    rule.success_reason_code = std.Clone(ctx, "conversion_value_valid");
    rule.failure_reason_code = std.Clone(ctx, failure_reason_code);
    rule.target_required = target_required;
    return rule;
}

func mir_integer_conversion_table_with_rule(table: MirIntegerConversionTable[ctx], rule: MirIntegerConversionRule[ctx], ctx: &Arena) MirIntegerConversionTable[ctx] {
    mut updated := table;
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := ctx[updated.rules];
    rules.Push(rule);
    ctx.Set(updated.rules, rules);
    return updated;
}

func mir_integer_conversion_table_with_sample(table: MirIntegerConversionTable[ctx], sample: MirIntegerConversionSample[ctx], ctx: &Arena) MirIntegerConversionTable[ctx] {
    mut updated := table;
    mut samples: std.Vector[MirIntegerConversionSample[ctx], ctx] := ctx[updated.samples];
    samples.Push(sample);
    ctx.Set(updated.samples, samples);
    return updated;
}

func mir_integer_conversion_rule(table: MirIntegerConversionTable[ctx], rule_name: str, ctx: &Arena) MirIntegerConversionRuleQuery[ctx] {
    mut result: MirIntegerConversionRuleQuery[ctx];
    result.found = 0;
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := ctx[table.rules];
    mut index := 0;
    while index < len(rules) {
        mut rule := rules[index];
        if std.str_eq(rule.rule_name, rule_name) == 1 {
            result.found = 1;
            result.rule = rule;
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_integer_conversion_select(table: MirIntegerConversionTable[ctx], source_type_id: str, destination_type_id: str, kind: str, policy: str, target_id: str, ctx: &Arena) MirIntegerConversionValidation[ctx] {
    mut result: MirIntegerConversionValidation[ctx];
    result.valid = 0;
    result.reason_code = std.Clone(ctx, "conversion_rule_not_declared");
    if mir_integer_conversion_kind_is_valid(kind) == 0 {
        if std.str_eq(kind, "implicit") == 1 {
            result.reason_code = std.Clone(ctx, "conversion_unsupported_implicit");
        }
        return result;
    }
    if std.str_find(source_type_id, "pointer") != 0 - 1 ||
       std.str_find(destination_type_id, "pointer") != 0 - 1
    {
        result.reason_code = std.Clone(ctx, "conversion_pointer_integer_deferred");
        return result;
    }
    if std.str_find(source_type_id, "f32") != 0 - 1 ||
       std.str_find(source_type_id, "f64") != 0 - 1 ||
       std.str_find(destination_type_id, "f32") != 0 - 1 ||
       std.str_find(destination_type_id, "f64") != 0 - 1
    {
        result.reason_code = std.Clone(ctx, "conversion_floating_point_deferred");
        return result;
    }
    if len(target_id) == 0 {
        result.reason_code = std.Clone(ctx, "conversion_target_required");
        return result;
    }
    if std.str_eq(table.target_id, target_id) == 0 {
        result.reason_code = std.Clone(ctx, "conversion_target_mismatch");
        return result;
    }
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := ctx[table.rules];
    mut index := 0;
    while index < len(rules) {
        mut rule := rules[index];
        if std.str_eq(rule.source_type_id, source_type_id) == 1 &&
           std.str_eq(rule.destination_type_id, destination_type_id) == 1 &&
           std.str_eq(rule.kind, kind) == 1 &&
           std.str_eq(rule.policy, policy) == 1
        {
            result.valid = 1;
            result.reason_code = std.Clone(ctx, rule.success_reason_code);
            result.rule = rule;
            return result;
        }
        index = index + 1;
    }
    if std.str_eq(kind, "truncate") == 1 && len(policy) == 0 {
        result.reason_code = std.Clone(ctx, "conversion_narrowing_policy_required");
    }
    return result;
}

func mir_integer_conversion_value_fits(type_id: str, width: int, signedness: str, value: int) int {
    if std.str_eq(type_id, "type:gust:bool") == 1 {
        if value == 0 || value == 1 { return 1; }
        return 0;
    }
    if std.str_eq(signedness, "unsigned") == 1 {
        if value < 0 { return 0; }
        if width == 32 && value > 4294967295 { return 0; }
        return 1;
    }
    if width == 32 {
        if value < 0 - 2147483647 - 1 || value > 2147483647 { return 0; }
    }
    return 1;
}

func mir_integer_conversion_wrap_u32(value: int) int {
    mut quotient := value / 4294967296;
    mut wrapped := value - quotient * 4294967296;
    if wrapped < 0 {
        wrapped = wrapped + 4294967296;
    }
    return wrapped;
}

func mir_integer_conversion_wrap_i32(value: int) int {
    mut wrapped := mir_integer_conversion_wrap_u32(value);
    if wrapped >= 2147483648 {
        wrapped = wrapped - 4294967296;
    }
    return wrapped;
}

func mir_integer_conversion_evaluate(rule: MirIntegerConversionRule[ctx], input_value: int, ctx: &Arena) MirIntegerConversionResult[ctx] {
    mut result: MirIntegerConversionResult[ctx];
    result.success = 0;
    result.value = 0;
    result.reason_code = std.Clone(ctx, rule.failure_reason_code);

    if mir_integer_conversion_value_fits(
        rule.source_type_id,
        rule.source_width,
        rule.source_signedness,
        input_value
    ) == 0 {
        if std.str_eq(rule.source_type_id, "type:gust:bool") == 1 {
            result.reason_code = std.Clone(ctx, "conversion_invalid_boolean_value");
        } else if std.str_eq(rule.source_signedness, "unsigned") == 1 && input_value < 0 {
            result.reason_code = std.Clone(ctx, "conversion_negative_to_unsigned");
        } else {
            result.reason_code = std.Clone(ctx, "conversion_source_out_of_range");
        }
        return result;
    }

    if std.str_eq(rule.kind, "sign_extend") == 1 ||
       std.str_eq(rule.kind, "zero_extend") == 1
    {
        result.success = 1;
        result.value = input_value;
        result.reason_code = std.Clone(ctx, rule.success_reason_code);
        return result;
    }

    if std.str_eq(rule.kind, "truncate") == 1 ||
       std.str_eq(rule.kind, "wrapping_numeric") == 1
    {
        if rule.destination_width != 32 {
            result.reason_code = std.Clone(ctx, "conversion_unsupported_width");
            return result;
        }
        result.success = 1;
        if std.str_eq(rule.destination_signedness, "signed") == 1 {
            result.value = mir_integer_conversion_wrap_i32(input_value);
        } else {
            result.value = mir_integer_conversion_wrap_u32(input_value);
        }
        result.reason_code = std.Clone(ctx, rule.success_reason_code);
        return result;
    }

    if std.str_eq(rule.kind, "checked_numeric") == 1 {
        if mir_integer_conversion_value_fits(
            rule.destination_type_id,
            rule.destination_width,
            rule.destination_signedness,
            input_value
        ) == 0 {
            if std.str_eq(rule.destination_signedness, "unsigned") == 1 && input_value < 0 {
                result.reason_code = std.Clone(ctx, "conversion_negative_to_unsigned");
            } else if std.str_eq(rule.source_signedness, "unsigned") == 1 &&
                      std.str_eq(rule.destination_signedness, "signed") == 1
            {
                result.reason_code = std.Clone(ctx, "conversion_unsigned_to_signed_out_of_range");
            } else {
                result.reason_code = std.Clone(ctx, "conversion_out_of_range");
            }
            return result;
        }
        result.success = 1;
        result.value = input_value;
        result.reason_code = std.Clone(ctx, rule.success_reason_code);
        return result;
    }

    if std.str_eq(rule.kind, "bit_reinterpret") == 1 {
        if rule.source_width != rule.destination_width || rule.source_width != 32 {
            result.reason_code = std.Clone(ctx, "conversion_width_mismatch");
            return result;
        }
        result.success = 1;
        if std.str_eq(rule.destination_signedness, "signed") == 1 {
            result.value = mir_integer_conversion_wrap_i32(input_value);
        } else {
            result.value = mir_integer_conversion_wrap_u32(input_value);
        }
        result.reason_code = std.Clone(ctx, rule.success_reason_code);
        return result;
    }

    if std.str_eq(rule.kind, "bool_to_integer") == 1 {
        if input_value != 0 && input_value != 1 {
            result.reason_code = std.Clone(ctx, "conversion_invalid_boolean_value");
            return result;
        }
        result.success = 1;
        result.value = input_value;
        result.reason_code = std.Clone(ctx, rule.success_reason_code);
        return result;
    }

    if std.str_eq(rule.kind, "integer_to_bool") == 1 {
        if input_value != 0 && input_value != 1 {
            result.reason_code = std.Clone(ctx, "conversion_invalid_boolean_value");
            return result;
        }
        result.success = 1;
        result.value = input_value;
        result.reason_code = std.Clone(ctx, rule.success_reason_code);
        return result;
    }

    result.reason_code = std.Clone(ctx, "conversion_kind_not_supported");
    return result;
}

func mir_integer_conversion_add_rule(table: MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], rule_name: str, kind: str, source_type_id: str, destination_type_id: str, policy: str, failure_reason_code: str, target_required: int, ctx: &Arena) MirIntegerConversionTable[ctx] {
    mut source := layout.mir_layout_of(
        layout_table,
        source_type_id,
        layout_table.target.target_id,
        ctx
    );
    mut destination := layout.mir_layout_of(
        layout_table,
        destination_type_id,
        layout_table.target.target_id,
        ctx
    );
    if source.found == 0 || destination.found == 0 {
        return table;
    }
    return mir_integer_conversion_table_with_rule(
        table,
        mir_integer_conversion_make_rule(
            rule_name,
            layout_table.target.target_id,
            layout_table.target.target_triple,
            kind,
            source_type_id,
            source.layout.layout_id,
            destination_type_id,
            destination.layout.layout_id,
            source.layout.bit_width,
            destination.layout.bit_width,
            source.layout.signedness,
            destination.layout.signedness,
            policy,
            failure_reason_code,
            target_required,
            ctx
        ),
        ctx
    );
}

func mir_integer_conversion_decimal_is_canonical(value: str) int {
    if len(value) == 0 {
        return 0;
    }
    mut index := 0;
    mut negative := 0;
    if std.str_byte_at(value, 0) == 45 {
        negative = 1;
        index = 1;
        if len(value) == 1 {
            return 0;
        }
    }
    if std.str_byte_at(value, index) == 48 && len(value) - index > 1 {
        return 0;
    }
    if negative == 1 && len(value) - index == 1 &&
       std.str_byte_at(value, index) == 48
    {
        return 0;
    }
    while index < len(value) {
        mut byte := std.str_byte_at(value, index);
        if byte < 48 || byte > 57 {
            return 0;
        }
        index = index + 1;
    }
    return 1;
}

func mir_integer_conversion_context_is_valid(context_kind: str) int {
    if std.str_eq(context_kind, "comparison") == 1 { return 1; }
    if std.str_eq(context_kind, "local") == 1 { return 1; }
    if std.str_eq(context_kind, "branch") == 1 { return 1; }
    if std.str_eq(context_kind, "aggregate_field") == 1 { return 1; }
    return 0;
}

func mir_integer_conversion_make_sample(table: MirIntegerConversionTable[ctx], sample_id: str, rule_name: str, input_value: str, expect_success: int, expected_value: str, expected_reason_code: str, context_kind: str, ctx: &Arena) MirIntegerConversionSample[ctx] {
    mut sample: MirIntegerConversionSample[ctx];
    sample.sample_id = std.Clone(ctx, sample_id);
    sample.rule_name = std.Clone(ctx, rule_name);
    sample.context_kind = std.Clone(ctx, context_kind);
    sample.input_value = std.Clone(ctx, input_value);
    sample.expect_success = expect_success;
    sample.expected_value = std.Clone(ctx, expected_value);
    sample.expected_reason_code = std.Clone(ctx, expected_reason_code);
    mut query := mir_integer_conversion_rule(table, rule_name, ctx);
    if query.found == 0 {
        sample.rule_id = std.Clone(ctx, "");
        return sample;
    }
    sample.rule_id = std.Clone(ctx, query.rule.rule_id);
    return sample;
}

func mir_integer_conversion_add_default_samples(table: MirIntegerConversionTable[ctx], pointer_width: int, ctx: &Arena) MirIntegerConversionTable[ctx] {
    mut updated := table;
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "sign_extend_i32_min", "sign_extend_i32_i64", "-2147483648", 1, "-2147483648", "conversion_value_valid", "local", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "sign_extend_i32_max", "sign_extend_i32_i64", "2147483647", 1, "2147483647", "conversion_value_valid", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "zero_extend_u32_max", "zero_extend_u32_u64", "4294967295", 1, "4294967295", "conversion_value_valid", "aggregate_field", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "truncate_i64_low_bits", "truncate_i64_i32", "4294967297", 1, "1", "conversion_value_valid", "local", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "truncate_i64_signed", "truncate_i64_i32", "4294967295", 1, "-1", "conversion_value_valid", "branch", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "truncate_u64_low_bits", "truncate_u64_u32", "4294967297", 1, "1", "conversion_value_valid", "aggregate_field", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "checked_i64_i32_max", "checked_i64_i32", "2147483647", 1, "2147483647", "conversion_value_valid", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "checked_i64_i32_overflow", "checked_i64_i32", "2147483648", 0, "0", "conversion_out_of_range", "branch", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "checked_u64_u32_max", "checked_u64_u32", "4294967295", 1, "4294967295", "conversion_value_valid", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "checked_u64_u32_overflow", "checked_u64_u32", "4294967296", 0, "0", "conversion_out_of_range", "branch", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "checked_negative_to_u32", "checked_i32_u32", "-1", 0, "0", "conversion_negative_to_unsigned", "local", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "checked_u32_to_i32_overflow", "checked_u32_i32", "4294967295", 0, "0", "conversion_unsigned_to_signed_out_of_range", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "wrapping_i32_to_u32", "wrapping_i32_u32", "-1", 1, "4294967295", "conversion_value_valid", "aggregate_field", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "wrapping_u32_to_i32", "wrapping_u32_i32", "4294967295", 1, "-1", "conversion_value_valid", "aggregate_field", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "reinterpret_i32_to_u32", "reinterpret_i32_u32", "-1", 1, "4294967295", "conversion_value_valid", "local", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "reinterpret_u32_to_i32", "reinterpret_u32_i32", "4294967295", 1, "-1", "conversion_value_valid", "local", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "bool_to_i32_false", "bool_to_i32", "0", 1, "0", "conversion_value_valid", "branch", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "bool_to_i32_true", "bool_to_i32", "1", 1, "1", "conversion_value_valid", "branch", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "i32_to_bool_zero", "i32_to_bool", "0", 1, "0", "conversion_value_valid", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "i32_to_bool_one", "i32_to_bool", "1", 1, "1", "conversion_value_valid", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "i32_to_bool_invalid", "i32_to_bool", "2", 0, "0", "conversion_invalid_boolean_value", "branch", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "i32_to_isize_boundary", "i32_to_isize", "2147483647", 1, "2147483647", "conversion_value_valid", "local", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "u32_to_usize_boundary", "u32_to_usize", "4294967295", 1, "4294967295", "conversion_value_valid", "aggregate_field", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "isize_to_i32_boundary", "isize_to_i32", "2147483647", 1, "2147483647", "conversion_value_valid", "comparison", ctx), ctx);
    updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "usize_to_u32_boundary", "usize_to_u32", "4294967295", 1, "4294967295", "conversion_value_valid", "comparison", ctx), ctx);
    if pointer_width == 64 {
        updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "isize_to_i32_target_overflow", "isize_to_i32", "2147483648", 0, "0", "conversion_out_of_range", "branch", ctx), ctx);
        updated = mir_integer_conversion_table_with_sample(updated, mir_integer_conversion_make_sample(updated, "usize_to_u32_target_overflow", "usize_to_u32", "4294967296", 0, "0", "conversion_out_of_range", "branch", ctx), ctx);
    }
    return updated;
}

func mir_integer_conversion_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirIntegerConversionTable[ctx] {
    if layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       layout_table.target.decisions_frozen == 0
    {
        return mir_integer_conversion_make_empty_table(
            layout_table.target.target_triple,
            ctx
        );
    }
    mut table: MirIntegerConversionTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_integer_conversion_table.v1");
    table.target_id = std.Clone(ctx, layout_table.target.target_id);
    table.target_triple = std.Clone(ctx, layout_table.target.target_triple);
    table.rules = mir_integer_conversion_empty_rule_vector(ctx);
    table.samples = mir_integer_conversion_empty_sample_vector(ctx);

    table = mir_integer_conversion_add_rule(table, layout_table, "sign_extend_i32_i64", "sign_extend", "type:gust:i32", "type:gust:i64", "explicit_sign_extension", "conversion_width_mismatch", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "zero_extend_u32_u64", "zero_extend", "type:gust:u32", "type:gust:u64", "explicit_zero_extension", "conversion_width_mismatch", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "truncate_i64_i32", "truncate", "type:gust:i64", "type:gust:i32", "explicit_truncate_low_bits", "conversion_narrowing_policy_required", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "truncate_u64_u32", "truncate", "type:gust:u64", "type:gust:u32", "explicit_truncate_low_bits", "conversion_narrowing_policy_required", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "checked_i64_i32", "checked_numeric", "type:gust:i64", "type:gust:i32", "checked_destination_range", "conversion_out_of_range", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "checked_u64_u32", "checked_numeric", "type:gust:u64", "type:gust:u32", "checked_destination_range", "conversion_out_of_range", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "checked_i32_u32", "checked_numeric", "type:gust:i32", "type:gust:u32", "checked_destination_range", "conversion_negative_to_unsigned", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "checked_u32_i32", "checked_numeric", "type:gust:u32", "type:gust:i32", "checked_destination_range", "conversion_unsigned_to_signed_out_of_range", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "wrapping_i32_u32", "wrapping_numeric", "type:gust:i32", "type:gust:u32", "explicit_wrapping_modulo_destination_width", "conversion_unsupported_width", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "wrapping_u32_i32", "wrapping_numeric", "type:gust:u32", "type:gust:i32", "explicit_wrapping_modulo_destination_width", "conversion_unsupported_width", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "reinterpret_i32_u32", "bit_reinterpret", "type:gust:i32", "type:gust:u32", "explicit_same_width_bit_reinterpretation", "conversion_width_mismatch", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "reinterpret_u32_i32", "bit_reinterpret", "type:gust:u32", "type:gust:i32", "explicit_same_width_bit_reinterpretation", "conversion_width_mismatch", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "bool_to_i32", "bool_to_integer", "type:gust:bool", "type:gust:i32", "canonical_bool_zero_or_one", "conversion_invalid_boolean_value", 0, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "i32_to_bool", "integer_to_bool", "type:gust:i32", "type:gust:bool", "checked_canonical_bool_zero_or_one", "conversion_invalid_boolean_value", 0, ctx);

    if layout_table.target.pointer_size == 8 {
        table = mir_integer_conversion_add_rule(table, layout_table, "i32_to_isize", "sign_extend", "type:gust:i32", "type:gust:isize", "target_width_sign_extension", "conversion_width_mismatch", 1, ctx);
        table = mir_integer_conversion_add_rule(table, layout_table, "u32_to_usize", "zero_extend", "type:gust:u32", "type:gust:usize", "target_width_zero_extension", "conversion_width_mismatch", 1, ctx);
    } else {
        table = mir_integer_conversion_add_rule(table, layout_table, "i32_to_isize", "checked_numeric", "type:gust:i32", "type:gust:isize", "target_width_checked_identity", "conversion_out_of_range", 1, ctx);
        table = mir_integer_conversion_add_rule(table, layout_table, "u32_to_usize", "checked_numeric", "type:gust:u32", "type:gust:usize", "target_width_checked_identity", "conversion_out_of_range", 1, ctx);
    }
    table = mir_integer_conversion_add_rule(table, layout_table, "isize_to_i32", "checked_numeric", "type:gust:isize", "type:gust:i32", "target_width_checked_narrowing", "conversion_out_of_range", 1, ctx);
    table = mir_integer_conversion_add_rule(table, layout_table, "usize_to_u32", "checked_numeric", "type:gust:usize", "type:gust:u32", "target_width_checked_narrowing", "conversion_out_of_range", 1, ctx);

    return mir_integer_conversion_add_default_samples(
        table,
        layout_table.target.pointer_size * 8,
        ctx
    );
}

func mir_integer_conversion_table_is_valid(table: MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_integer_conversion_table.v1") == 0 ||
       layout.mir_layout_table_is_valid(layout_table, ctx) == 0 ||
       len(table.target_id) == 0 ||
       std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0
    {
        return 0;
    }
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := ctx[table.rules];
    if len(rules) != 18 {
        return 0;
    }
    mut index := 0;
    while index < len(rules) {
        mut rule := rules[index];
        if mir_integer_conversion_kind_is_valid(rule.kind) == 0 ||
           std.str_eq(rule.target_id, table.target_id) == 0 ||
           std.str_eq(rule.target_triple, table.target_triple) == 0 ||
           rule.source_width <= 0 || rule.destination_width <= 0 ||
           len(rule.rule_name) == 0 || len(rule.policy) == 0
        {
            return 0;
        }
        mut expected_id := mir_integer_conversion_identity(
            rule.target_id,
            rule.kind,
            rule.source_type_id,
            rule.destination_type_id,
            rule.source_width,
            rule.destination_width,
            rule.policy,
            ctx
        );
        if std.str_eq(expected_id, rule.rule_id) == 0 {
            return 0;
        }
        mut source := layout.mir_layout_of(
            layout_table,
            rule.source_type_id,
            table.target_id,
            ctx
        );
        mut destination := layout.mir_layout_of(
            layout_table,
            rule.destination_type_id,
            table.target_id,
            ctx
        );
        if source.found == 0 || destination.found == 0 ||
           std.str_eq(source.layout.layout_id, rule.source_layout_id) == 0 ||
           std.str_eq(destination.layout.layout_id, rule.destination_layout_id) == 0 ||
           source.layout.bit_width != rule.source_width ||
           destination.layout.bit_width != rule.destination_width ||
           std.str_eq(source.layout.signedness, rule.source_signedness) == 0 ||
           std.str_eq(destination.layout.signedness, rule.destination_signedness) == 0
        {
            return 0;
        }
        mut other := index + 1;
        while other < len(rules) {
            if std.str_eq(rule.rule_name, rules[other].rule_name) == 1 ||
               std.str_eq(rule.rule_id, rules[other].rule_id) == 1
            {
                return 0;
            }
            other = other + 1;
        }
        index = index + 1;
    }

    mut samples: std.Vector[MirIntegerConversionSample[ctx], ctx] := ctx[table.samples];
    if len(samples) < 25 {
        return 0;
    }
    mut sample_index := 0;
    while sample_index < len(samples) {
        mut sample := samples[sample_index];
        mut query := mir_integer_conversion_rule(table, sample.rule_name, ctx);
        if query.found == 0 || std.str_eq(query.rule.rule_id, sample.rule_id) == 0 {
            return 0;
        }
        if mir_integer_conversion_context_is_valid(sample.context_kind) == 0 ||
           mir_integer_conversion_decimal_is_canonical(sample.input_value) == 0 ||
           mir_integer_conversion_decimal_is_canonical(sample.expected_value) == 0 ||
           (sample.expect_success != 0 && sample.expect_success != 1)
        {
            return 0;
        }
        if sample.expect_success == 1 {
            if std.str_eq(sample.expected_reason_code, query.rule.success_reason_code) == 0 {
                return 0;
            }
        } else {
            if std.str_eq(sample.expected_value, "0") == 0 ||
               len(sample.expected_reason_code) == 0 ||
               std.str_eq(sample.expected_reason_code, query.rule.success_reason_code) == 1
            {
                return 0;
            }
        }
        mut other_sample := sample_index + 1;
        while other_sample < len(samples) {
            if std.str_eq(sample.sample_id, samples[other_sample].sample_id) == 1 {
                return 0;
            }
            other_sample = other_sample + 1;
        }
        sample_index = sample_index + 1;
    }
    return 1;
}

func mir_integer_conversion_append_line(output: str, line: str, ctx: &Arena) str {
    mut updated := std.Concat(output, line);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_integer_conversion_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_integer_conversion_table_for_request(table: MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_integer_conversion_table_is_valid(table, layout_table, ctx) == 0 {
        return "conversion_table_format: invalid\n";
    }
    mut output := "";
    output = mir_integer_conversion_append_field(output, "conversion_table_format", table.format, ctx);
    output = mir_integer_conversion_append_field(output, "conversion_target_id", table.target_id, ctx);
    output = mir_integer_conversion_append_field(output, "conversion_target_triple", table.target_triple, ctx);
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := ctx[table.rules];
    output = mir_integer_conversion_append_field(output, "conversion_rule_count", std.FormatInt(len(rules)), ctx);
    mut rule_index := 0;
    while rule_index < len(rules) {
        mut rule := rules[rule_index];
        mut prefix := std.Concat("conversion_rule_", std.FormatInt(rule_index));
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_id"), rule.rule_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_name"), rule.rule_name, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_kind"), rule.kind, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_source_type_id"), rule.source_type_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_source_layout_id"), rule.source_layout_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_destination_type_id"), rule.destination_type_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_destination_layout_id"), rule.destination_layout_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_source_width"), std.FormatInt(rule.source_width), ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_destination_width"), std.FormatInt(rule.destination_width), ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_source_signedness"), rule.source_signedness, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_destination_signedness"), rule.destination_signedness, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_policy"), rule.policy, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_success_reason_code"), rule.success_reason_code, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_failure_reason_code"), rule.failure_reason_code, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_target_required"), std.FormatInt(rule.target_required), ctx);
        rule_index = rule_index + 1;
    }
    mut samples: std.Vector[MirIntegerConversionSample[ctx], ctx] := ctx[table.samples];
    output = mir_integer_conversion_append_field(output, "conversion_sample_count", std.FormatInt(len(samples)), ctx);
    mut sample_index := 0;
    while sample_index < len(samples) {
        mut sample := samples[sample_index];
        mut prefix := std.Concat("conversion_sample_", std.FormatInt(sample_index));
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_id"), sample.sample_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_rule_id"), sample.rule_id, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_rule_name"), sample.rule_name, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_context_kind"), sample.context_kind, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_input_value"), sample.input_value, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(sample.expect_success), ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_expected_value"), sample.expected_value, ctx);
        output = mir_integer_conversion_append_field(output, std.Concat(prefix, "_expected_reason_code"), sample.expected_reason_code, ctx);
        sample_index = sample_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_integer_conversion_witness(table: MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_integer_conversion_table_is_valid(table, layout_table, ctx) == 0 {
        return std.Clone(ctx, "integer_conversion_status: invalid\n");
    }
    mut output := "integer_conversion_status: valid\n";
    output = mir_integer_conversion_append_field(output, "target_id", table.target_id, ctx);
    output = mir_integer_conversion_append_field(output, "target_triple", table.target_triple, ctx);
    mut rules: std.Vector[MirIntegerConversionRule[ctx], ctx] := ctx[table.rules];
    mut samples: std.Vector[MirIntegerConversionSample[ctx], ctx] := ctx[table.samples];
    output = mir_integer_conversion_append_field(output, "rule_count", std.FormatInt(len(rules)), ctx);
    output = mir_integer_conversion_append_field(output, "sample_count", std.FormatInt(len(samples)), ctx);
    mut index := 0;
    while index < len(samples) {
        mut sample := samples[index];
        mut query := mir_integer_conversion_rule(table, sample.rule_name, ctx);
        mut line := "conversion: ";
        line = std.Concat(line, sample.sample_id);
        line = std.Concat(line, " rule=");
        line = std.Concat(line, query.rule.rule_name);
        line = std.Concat(line, " kind=");
        line = std.Concat(line, query.rule.kind);
        line = std.Concat(line, " source=");
        line = std.Concat(line, query.rule.source_type_id);
        line = std.Concat(line, " destination=");
        line = std.Concat(line, query.rule.destination_type_id);
        line = std.Concat(line, " source_width=");
        line = std.Concat(line, std.FormatInt(query.rule.source_width));
        line = std.Concat(line, " destination_width=");
        line = std.Concat(line, std.FormatInt(query.rule.destination_width));
        line = std.Concat(line, " policy=");
        line = std.Concat(line, query.rule.policy);
        line = std.Concat(line, " input=");
        line = std.Concat(line, sample.input_value);
        if sample.expect_success == 1 {
            line = std.Concat(line, " status=success value=");
            line = std.Concat(line, sample.expected_value);
        } else {
            line = std.Concat(line, " status=failure value=0");
        }
        line = std.Concat(line, " reason=");
        line = std.Concat(line, sample.expected_reason_code);
        line = std.Concat(line, " context=");
        line = std.Concat(line, sample.context_kind);
        output = mir_integer_conversion_append_line(output, line, ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
