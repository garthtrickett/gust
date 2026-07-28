// MIR-to-C consumer for the Phase 14.3 compiler-owned integer conversion table.
// The generated helper branches on the canonical conversion kind and policy;
// it does not use implementation-defined C casts as semantic authority.

import "mir_layout.gst" as layout;
import "mir_integer_conversion.gst" as conversion;

func mir_integer_conversion_c_escape(value: str, ctx: &Arena) str {
    mut output := "";
    mut index := 0;
    while index < len(value) {
        mut byte := std.str_byte_at(value, index);
        if byte == 34 {
            output = std.Concat(output, "\\\"");
        } else if byte == 92 {
            output = std.Concat(output, "\\\\");
        } else {
            output = std.Concat(output, std.str_slice(value, index, index + 1));
        }
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_integer_conversion_c_source(table: conversion.MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if conversion.mir_integer_conversion_table_is_valid(table, layout_table, ctx) == 0 {
        return std.Clone(ctx, "");
    }

    mut output := "#include <stdio.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "typedef struct { int success; long long value; const char *reason; } gust_conversion_result;\n\n");
    output = std.Concat(output, "static int gust_fits(const char *type_id, int width, const char *signedness, long long value) {\n");
    output = std.Concat(output, "    if (strcmp(type_id, \"type:gust:bool\") == 0) return value == 0 || value == 1;\n");
    output = std.Concat(output, "    if (strcmp(signedness, \"unsigned\") == 0) { if (value < 0) return 0; if (width == 32 && value > 4294967295LL) return 0; return 1; }\n");
    output = std.Concat(output, "    if (width == 32 && (value < (-2147483647LL - 1LL) || value > 2147483647LL)) return 0;\n");
    output = std.Concat(output, "    return 1;\n}\n\n");
    output = std.Concat(output, "static long long gust_wrap_u32(long long value) { long long wrapped = value % 4294967296LL; if (wrapped < 0) wrapped += 4294967296LL; return wrapped; }\n");
    output = std.Concat(output, "static long long gust_wrap_i32(long long value) { value = gust_wrap_u32(value); if (value >= 2147483648LL) value -= 4294967296LL; return value; }\n\n");
    output = std.Concat(output, "static gust_conversion_result gust_convert(const char *kind, const char *source_type, const char *destination_type, int source_width, int destination_width, const char *source_signedness, const char *destination_signedness, const char *success_reason, const char *failure_reason, long long input) {\n");
    output = std.Concat(output, "    gust_conversion_result result = {0, 0, failure_reason};\n");
    output = std.Concat(output, "    if (!gust_fits(source_type, source_width, source_signedness, input)) {\n");
    output = std.Concat(output, "        if (strcmp(source_type, \"type:gust:bool\") == 0) result.reason = \"conversion_invalid_boolean_value\";\n");
    output = std.Concat(output, "        else if (strcmp(source_signedness, \"unsigned\") == 0 && input < 0) result.reason = \"conversion_negative_to_unsigned\";\n");
    output = std.Concat(output, "        else result.reason = \"conversion_source_out_of_range\";\n");
    output = std.Concat(output, "        return result;\n    }\n");
    output = std.Concat(output, "    if (strcmp(kind, \"sign_extend\") == 0 || strcmp(kind, \"zero_extend\") == 0) { result.success = 1; result.value = input; result.reason = success_reason; return result; }\n");
    output = std.Concat(output, "    if (strcmp(kind, \"truncate\") == 0 || strcmp(kind, \"wrapping_numeric\") == 0) {\n");
    output = std.Concat(output, "        if (destination_width != 32) { result.reason = \"conversion_unsupported_width\"; return result; }\n");
    output = std.Concat(output, "        result.success = 1; result.value = strcmp(destination_signedness, \"signed\") == 0 ? gust_wrap_i32(input) : gust_wrap_u32(input); result.reason = success_reason; return result;\n    }\n");
    output = std.Concat(output, "    if (strcmp(kind, \"checked_numeric\") == 0) {\n");
    output = std.Concat(output, "        if (!gust_fits(destination_type, destination_width, destination_signedness, input)) {\n");
    output = std.Concat(output, "            if (strcmp(destination_signedness, \"unsigned\") == 0 && input < 0) result.reason = \"conversion_negative_to_unsigned\";\n");
    output = std.Concat(output, "            else if (strcmp(source_signedness, \"unsigned\") == 0 && strcmp(destination_signedness, \"signed\") == 0) result.reason = \"conversion_unsigned_to_signed_out_of_range\";\n");
    output = std.Concat(output, "            else result.reason = \"conversion_out_of_range\";\n            return result;\n        }\n");
    output = std.Concat(output, "        result.success = 1; result.value = input; result.reason = success_reason; return result;\n    }\n");
    output = std.Concat(output, "    if (strcmp(kind, \"bit_reinterpret\") == 0) {\n");
    output = std.Concat(output, "        if (source_width != destination_width || source_width != 32) { result.reason = \"conversion_width_mismatch\"; return result; }\n");
    output = std.Concat(output, "        result.success = 1; result.value = strcmp(destination_signedness, \"signed\") == 0 ? gust_wrap_i32(input) : gust_wrap_u32(input); result.reason = success_reason; return result;\n    }\n");
    output = std.Concat(output, "    if (strcmp(kind, \"bool_to_integer\") == 0 || strcmp(kind, \"integer_to_bool\") == 0) {\n");
    output = std.Concat(output, "        if (input != 0 && input != 1) { result.reason = \"conversion_invalid_boolean_value\"; return result; }\n");
    output = std.Concat(output, "        result.success = 1; result.value = input; result.reason = success_reason; return result;\n    }\n");
    output = std.Concat(output, "    result.reason = \"conversion_kind_not_supported\"; return result;\n}\n\n");

    output = std.Concat(output, "int main(void) {\n");
    output = std.Concat(output, "    puts(\"integer_conversion_status: valid\");\n");
    output = std.Concat(output, "    puts(\"target_id: ");
    output = std.Concat(output, mir_integer_conversion_c_escape(table.target_id, ctx));
    output = std.Concat(output, "\");\n");
    output = std.Concat(output, "    puts(\"target_triple: ");
    output = std.Concat(output, mir_integer_conversion_c_escape(table.target_triple, ctx));
    output = std.Concat(output, "\");\n");

    mut rules: std.Vector[conversion.MirIntegerConversionRule[ctx], ctx] := ctx[table.rules];
    mut samples: std.Vector[conversion.MirIntegerConversionSample[ctx], ctx] := ctx[table.samples];
    output = std.Concat(output, "    puts(\"rule_count: ");
    output = std.Concat(output, std.FormatInt(len(rules)));
    output = std.Concat(output, "\");\n");
    output = std.Concat(output, "    puts(\"sample_count: ");
    output = std.Concat(output, std.FormatInt(len(samples)));
    output = std.Concat(output, "\");\n");

    mut sample_index := 0;
    while sample_index < len(samples) {
        mut sample := samples[sample_index];
        mut query := conversion.mir_integer_conversion_rule(table, sample.rule_name, ctx);
        mut rule := query.rule;
        mut result_name := std.Concat("result_", std.FormatInt(sample_index));
        output = std.Concat(output, "    gust_conversion_result ");
        output = std.Concat(output, result_name);
        output = std.Concat(output, " = gust_convert(\"");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.kind, ctx));
        output = std.Concat(output, "\", \"");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.source_type_id, ctx));
        output = std.Concat(output, "\", \"");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.destination_type_id, ctx));
        output = std.Concat(output, "\", ");
        output = std.Concat(output, std.FormatInt(rule.source_width));
        output = std.Concat(output, ", ");
        output = std.Concat(output, std.FormatInt(rule.destination_width));
        output = std.Concat(output, ", \"");
        output = std.Concat(output, rule.source_signedness);
        output = std.Concat(output, "\", \"");
        output = std.Concat(output, rule.destination_signedness);
        output = std.Concat(output, "\", \"");
        output = std.Concat(output, rule.success_reason_code);
        output = std.Concat(output, "\", \"");
        output = std.Concat(output, rule.failure_reason_code);
        output = std.Concat(output, "\", ");
        output = std.Concat(output, std.FormatInt(sample.input_value));
        output = std.Concat(output, "LL);\n");

        output = std.Concat(output, "    printf(\"conversion: ");
        output = std.Concat(output, mir_integer_conversion_c_escape(sample.sample_id, ctx));
        output = std.Concat(output, " rule=");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.rule_name, ctx));
        output = std.Concat(output, " kind=");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.kind, ctx));
        output = std.Concat(output, " source=");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.source_type_id, ctx));
        output = std.Concat(output, " destination=");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.destination_type_id, ctx));
        output = std.Concat(output, " source_width=");
        output = std.Concat(output, std.FormatInt(rule.source_width));
        output = std.Concat(output, " destination_width=");
        output = std.Concat(output, std.FormatInt(rule.destination_width));
        output = std.Concat(output, " policy=");
        output = std.Concat(output, mir_integer_conversion_c_escape(rule.policy, ctx));
        output = std.Concat(output, " input=");
        output = std.Concat(output, std.FormatInt(sample.input_value));
        output = std.Concat(output, " status=%s value=%lld reason=%s context=");
        output = std.Concat(output, mir_integer_conversion_c_escape(sample.context_kind, ctx));
        output = std.Concat(output, "\\n\", ");
        output = std.Concat(output, result_name);
        output = std.Concat(output, ".success ? \"success\" : \"failure\", ");
        output = std.Concat(output, result_name);
        output = std.Concat(output, ".success ? ");
        output = std.Concat(output, result_name);
        output = std.Concat(output, ".value : 0LL, ");
        output = std.Concat(output, result_name);
        output = std.Concat(output, ".reason);\n");
        sample_index = sample_index + 1;
    }
    output = std.Concat(output, "    return 0;\n}\n");
    return std.Clone(ctx, output);
}