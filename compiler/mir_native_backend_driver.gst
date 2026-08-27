import "mir_native_backend_capability.gst" as capability;

// Phase 10 compiler-owned native-backend driver discovery and handshake.
//
// The model is backend-neutral. Filesystem existence and executable facts are
// supplied by the future orchestration layer so this module can freeze
// precedence, validation, and diagnostics without spawning a process, reading
// an environment variable, searching PATH, touching an output path, or
// creating an artifact.
type MirNativeBackendDriverDiscoveryClassification enum {
    FoundExplicit,
    FoundSibling,
    ExplicitPathNotAbsolute,
    ExplicitUnavailable,
    SiblingUnavailable
}

type MirNativeBackendDriverDiscoveryResult[ctx] struct {
    classification: MirNativeBackendDriverDiscoveryClassification,
    path: str,
    detail: str
}

type MirNativeBackendDriverHandshakeClassification enum {
    Compatible,
    Malformed,
    ProtocolMismatch,
    BundleFormatMismatch,
    CanonicalMirFormatMismatch,
    TargetMismatch,
    ObjectFormatMismatch,
    LinkCapabilityMismatch,
    PipelineTaxonomyMismatch,
    CapabilityInventoryInvalid
}

type MirNativeBackendDriverHandshake[ctx] struct {
    parsed: int,
    protocol: str,
    driver_name: str,
    driver_version: str,
    program_mir_bundle_format: str,
    target_triple: str,
    object_format: str,
    link_capability: str,
    pipeline_taxonomy: str,
    canonical_mir_formats: Index[std.Vector[str, ctx], ctx],
    operations: Index[std.Vector[str, ctx], ctx],
    types_and_abis: Index[std.Vector[str, ctx], ctx],
    runtime_imports: Index[std.Vector[str, ctx], ctx],
    target_requirements: Index[std.Vector[str, ctx], ctx],
    parse_detail: str
}

type MirNativeBackendDriverHandshakeResult[ctx] struct {
    classification: MirNativeBackendDriverHandshakeClassification,
    detail: str
}

func mir_native_backend_driver_empty_string_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_native_backend_driver_path_is_safe(path: str) int {
    if len(path) == 0 {
        return 0;
    }
    if std.str_find(path, "\n") != 0 - 1 {
        return 0;
    }
    if std.str_find(path, "\r") != 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_native_backend_driver_path_is_absolute(path: str) int {
    if mir_native_backend_driver_path_is_safe(path) == 0 {
        return 0;
    }
    if std.str_byte_at(path, 0) == 47 {
        return 1;
    }
    return 0;
}

func mir_native_backend_make_driver_discovery_result(classification_tag: int, path: str, detail: str, ctx: &Arena) MirNativeBackendDriverDiscoveryResult[ctx] {
    mut result: MirNativeBackendDriverDiscoveryResult[ctx];
    unsafe {
        result.classification.tag = classification_tag;
    }
    result.path = std.Clone(ctx, path);
    result.detail = std.Clone(ctx, detail);
    return result;
}

func mir_native_backend_discover_driver(explicit_path: str, explicit_exists: int, explicit_executable: int, sibling_path: str, sibling_exists: int, sibling_executable: int, ctx: &Arena) MirNativeBackendDriverDiscoveryResult[ctx] {
    if len(explicit_path) > 0 {
        if mir_native_backend_driver_path_is_absolute(explicit_path) == 0 {
            return mir_native_backend_make_driver_discovery_result(
                2,
                explicit_path,
                "explicit native backend driver path must be absolute",
                ctx
            );
        }
        if explicit_exists == 0 || explicit_executable == 0 {
            return mir_native_backend_make_driver_discovery_result(
                3,
                explicit_path,
                "explicit native backend driver path is unavailable or not executable",
                ctx
            );
        }
        return mir_native_backend_make_driver_discovery_result(
            0,
            explicit_path,
            "explicit native backend driver selected",
            ctx
        );
    }

    if mir_native_backend_driver_path_is_absolute(sibling_path) == 0 {
        return mir_native_backend_make_driver_discovery_result(
            4,
            sibling_path,
            "sibling native backend driver path is unavailable",
            ctx
        );
    }
    if sibling_exists == 0 || sibling_executable == 0 {
        return mir_native_backend_make_driver_discovery_result(
            4,
            sibling_path,
            "sibling native backend driver path is unavailable or not executable",
            ctx
        );
    }

    return mir_native_backend_make_driver_discovery_result(
        1,
        sibling_path,
        "sibling native backend driver selected",
        ctx
    );
}

func mir_native_backend_make_empty_driver_handshake(ctx: &Arena) MirNativeBackendDriverHandshake[ctx] {
    mut handshake: MirNativeBackendDriverHandshake[ctx];
    handshake.parsed = 1;
    handshake.protocol = "";
    handshake.driver_name = "";
    handshake.driver_version = "";
    handshake.program_mir_bundle_format = "";
    handshake.target_triple = "";
    handshake.object_format = "";
    handshake.link_capability = "";
    handshake.pipeline_taxonomy = "";
    handshake.canonical_mir_formats = mir_native_backend_driver_empty_string_vector(ctx);
    handshake.operations = mir_native_backend_driver_empty_string_vector(ctx);
    handshake.types_and_abis = mir_native_backend_driver_empty_string_vector(ctx);
    handshake.runtime_imports = mir_native_backend_driver_empty_string_vector(ctx);
    handshake.target_requirements = mir_native_backend_driver_empty_string_vector(ctx);
    handshake.parse_detail = "";
    return handshake;
}

func mir_native_backend_driver_handshake_parse_failure(handshake: MirNativeBackendDriverHandshake[ctx], detail: str, ctx: &Arena) MirNativeBackendDriverHandshake[ctx] {
    mut failed := handshake;
    failed.parsed = 0;
    failed.parse_detail = std.Clone(ctx, detail);
    return failed;
}

func mir_native_backend_driver_push_string(values_idx: Index[std.Vector[str, ctx], ctx], value: str, ctx: &Arena) {
    mut values: std.Vector[str, ctx] := ctx[values_idx];
    values.Push(std.Clone(ctx, value));
    ctx.Set(values_idx, values);
}

func mir_native_backend_parse_driver_handshake(content: str, ctx: &Arena) MirNativeBackendDriverHandshake[ctx] {
    mut handshake := mir_native_backend_make_empty_driver_handshake(ctx);
    mut lines := std.str_split(content, "\n", ctx);
    mut line_index := 0;

    while line_index < len(lines) {
        mut line := lines[line_index];
        if len(line) == 0 {
            line_index = line_index + 1;
            continue;
        }

        mut separator := std.str_find(line, ": ");
        if separator == 0 - 1 {
            return mir_native_backend_driver_handshake_parse_failure(
                handshake,
                "driver handshake line is missing the ': ' separator",
                ctx
            );
        }

        mut key := std.str_slice(line, 0, separator);
        mut value := std.str_slice(line, separator + 2, len(line));
        if len(key) == 0 || len(value) == 0 {
            return mir_native_backend_driver_handshake_parse_failure(
                handshake,
                "driver handshake key and value must be nonempty",
                ctx
            );
        }

        if std.str_eq(key, "protocol") == 1 {
            if len(handshake.protocol) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate protocol",
                    ctx
                );
            }
            handshake.protocol = std.Clone(ctx, value);
        } else if std.str_eq(key, "driver_name") == 1 {
            if len(handshake.driver_name) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate driver_name",
                    ctx
                );
            }
            handshake.driver_name = std.Clone(ctx, value);
        } else if std.str_eq(key, "driver_version") == 1 {
            if len(handshake.driver_version) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate driver_version",
                    ctx
                );
            }
            handshake.driver_version = std.Clone(ctx, value);
        } else if std.str_eq(key, "program_mir_bundle_format") == 1 {
            if len(handshake.program_mir_bundle_format) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate program_mir_bundle_format",
                    ctx
                );
            }
            handshake.program_mir_bundle_format = std.Clone(ctx, value);
        } else if std.str_eq(key, "target_triple") == 1 {
            if len(handshake.target_triple) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate target_triple",
                    ctx
                );
            }
            handshake.target_triple = std.Clone(ctx, value);
        } else if std.str_eq(key, "object_format") == 1 {
            if len(handshake.object_format) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate object_format",
                    ctx
                );
            }
            handshake.object_format = std.Clone(ctx, value);
        } else if std.str_eq(key, "link_capability") == 1 {
            if len(handshake.link_capability) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate link_capability",
                    ctx
                );
            }
            handshake.link_capability = std.Clone(ctx, value);
        } else if std.str_eq(key, "pipeline_taxonomy") == 1 {
            if len(handshake.pipeline_taxonomy) > 0 {
                return mir_native_backend_driver_handshake_parse_failure(
                    handshake,
                    "driver handshake contains duplicate pipeline_taxonomy",
                    ctx
                );
            }
            handshake.pipeline_taxonomy = std.Clone(ctx, value);
        } else if std.str_eq(key, "canonical_mir_format") == 1 {
            mir_native_backend_driver_push_string(
                handshake.canonical_mir_formats,
                value,
                ctx
            );
        } else if std.str_eq(key, "operation") == 1 {
            mir_native_backend_driver_push_string(handshake.operations, value, ctx);
        } else if std.str_eq(key, "type_or_abi") == 1 {
            mir_native_backend_driver_push_string(handshake.types_and_abis, value, ctx);
        } else if std.str_eq(key, "runtime_import") == 1 {
            mir_native_backend_driver_push_string(handshake.runtime_imports, value, ctx);
        } else if std.str_eq(key, "target_requirement") == 1 {
            mir_native_backend_driver_push_string(
                handshake.target_requirements,
                value,
                ctx
            );
        } else {
            return mir_native_backend_driver_handshake_parse_failure(
                handshake,
                "driver handshake contains an unknown key",
                ctx
            );
        }

        line_index = line_index + 1;
    }

    return handshake;
}

func mir_native_backend_driver_string_vector_is_nonempty_unique(values_idx: Index[std.Vector[str, ctx], ctx], ctx: &Arena) int {
    mut values: std.Vector[str, ctx] := ctx[values_idx];
    if len(values) == 0 {
        return 0;
    }

    mut index := 0;
    while index < len(values) {
        if mir_native_backend_driver_path_is_safe(values[index]) == 0 {
            return 0;
        }

        mut prior_index := 0;
        while prior_index < index {
            if std.str_eq(values[prior_index], values[index]) == 1 {
                return 0;
            }
            prior_index = prior_index + 1;
        }

        index = index + 1;
    }

    return 1;
}

func mir_native_backend_make_driver_handshake_result(classification_tag: int, detail: str, ctx: &Arena) MirNativeBackendDriverHandshakeResult[ctx] {
    mut result: MirNativeBackendDriverHandshakeResult[ctx];
    unsafe {
        result.classification.tag = classification_tag;
    }
    result.detail = std.Clone(ctx, detail);
    return result;
}

func mir_native_backend_validate_driver_handshake(handshake: MirNativeBackendDriverHandshake[ctx], expected_target_triple: str, expected_object_format: str, ctx: &Arena) MirNativeBackendDriverHandshakeResult[ctx] {
    if handshake.parsed == 0 {
        return mir_native_backend_make_driver_handshake_result(
            1,
            handshake.parse_detail,
            ctx
        );
    }

    if std.str_eq(handshake.protocol, "gust.native_backend.driver.v1") == 0 {
        return mir_native_backend_make_driver_handshake_result(
            2,
            "native backend driver protocol mismatch",
            ctx
        );
    }

    if len(handshake.driver_name) == 0 || len(handshake.driver_version) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            1,
            "native backend driver identity is incomplete",
            ctx
        );
    }

    if std.str_eq(
        handshake.program_mir_bundle_format,
        "gust.compiler_program_mir_bundle.v1"
    ) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            3,
            "native backend driver program MIR bundle format mismatch",
            ctx
        );
    }

    mut canonical_formats: std.Vector[str, ctx] := ctx[handshake.canonical_mir_formats];
    if len(canonical_formats) != 3 {
        return mir_native_backend_make_driver_handshake_result(
            4,
            "native backend driver must advertise exactly the frozen v1, v2, and full-program canonical MIR formats",
            ctx
        );
    }
    if std.str_eq(canonical_formats[0], "gust.compiler_mir_ingestion.v1") == 0 {
        return mir_native_backend_make_driver_handshake_result(
            4,
            "native backend driver canonical MIR v1 capability is missing or reordered",
            ctx
        );
    }
    if std.str_eq(canonical_formats[1], "gust.compiler_mir_ingestion.v2") == 0 {
        return mir_native_backend_make_driver_handshake_result(
            4,
            "native backend driver canonical MIR v2 capability is missing or reordered",
            ctx
        );
    }
    if std.str_eq(canonical_formats[2], "gust.compiler_executable_mir.v1") == 0 {
        return mir_native_backend_make_driver_handshake_result(
            4,
            "native backend driver full-program canonical MIR capability is missing or reordered",
            ctx
        );
    }

    if len(expected_target_triple) == 0 ||
        std.str_eq(handshake.target_triple, expected_target_triple) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            5,
            "native backend driver target triple mismatch",
            ctx
        );
    }

    if len(expected_object_format) == 0 ||
        std.str_eq(handshake.object_format, expected_object_format) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            6,
            "native backend driver object format mismatch",
            ctx
        );
    }

    if std.str_eq(handshake.link_capability, "native_executable") == 0 {
        return mir_native_backend_make_driver_handshake_result(
            7,
            "native backend driver does not provide the required executable link capability",
            ctx
        );
    }

    if std.str_eq(handshake.pipeline_taxonomy, "gust.phase9g.pipeline.v1") == 0 {
        return mir_native_backend_make_driver_handshake_result(
            8,
            "native backend driver Phase 9G pipeline taxonomy mismatch",
            ctx
        );
    }

    if mir_native_backend_driver_string_vector_is_nonempty_unique(
        handshake.operations,
        ctx
    ) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            9,
            "native backend driver operation inventory is empty or contains duplicates",
            ctx
        );
    }
    if mir_native_backend_driver_string_vector_is_nonempty_unique(
        handshake.types_and_abis,
        ctx
    ) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            9,
            "native backend driver type and ABI inventory is empty or contains duplicates",
            ctx
        );
    }
    if mir_native_backend_driver_string_vector_is_nonempty_unique(
        handshake.runtime_imports,
        ctx
    ) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            9,
            "native backend driver runtime import inventory is empty or contains duplicates",
            ctx
        );
    }
    if mir_native_backend_driver_string_vector_is_nonempty_unique(
        handshake.target_requirements,
        ctx
    ) == 0 {
        return mir_native_backend_make_driver_handshake_result(
            9,
            "native backend driver target requirement inventory is empty or contains duplicates",
            ctx
        );
    }

    return mir_native_backend_make_driver_handshake_result(
        0,
        "compatible",
        ctx
    );
}

func mir_native_backend_driver_capability_set(handshake: MirNativeBackendDriverHandshake[ctx], ctx: &Arena) capability.MirNativeBackendCapabilitySet[ctx] {
    mut capabilities := capability.mir_native_backend_make_capability_set(ctx);

    mut operations: std.Vector[str, ctx] := ctx[handshake.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        capabilities = capability.mir_native_backend_capability_set_with_operation(
            capabilities,
            operations[operation_index],
            ctx
        );
        operation_index = operation_index + 1;
    }

    mut types_and_abis: std.Vector[str, ctx] := ctx[handshake.types_and_abis];
    mut type_index := 0;
    while type_index < len(types_and_abis) {
        capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
            capabilities,
            types_and_abis[type_index],
            ctx
        );
        type_index = type_index + 1;
    }

    mut runtime_imports: std.Vector[str, ctx] := ctx[handshake.runtime_imports];
    mut import_index := 0;
    while import_index < len(runtime_imports) {
        capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
            capabilities,
            runtime_imports[import_index],
            ctx
        );
        import_index = import_index + 1;
    }

    mut target_requirements: std.Vector[str, ctx] := ctx[handshake.target_requirements];
    mut target_index := 0;
    while target_index < len(target_requirements) {
        capabilities = capability.mir_native_backend_capability_set_with_target_requirement(
            capabilities,
            target_requirements[target_index],
            ctx
        );
        target_index = target_index + 1;
    }

    return capabilities;
}

func mir_native_backend_driver_handshake_classification_name(classification: MirNativeBackendDriverHandshakeClassification) str {
    if classification.tag == 0 { return "compatible"; }
    if classification.tag == 1 { return "malformed"; }
    if classification.tag == 2 { return "protocol_mismatch"; }
    if classification.tag == 3 { return "bundle_format_mismatch"; }
    if classification.tag == 4 { return "canonical_mir_format_mismatch"; }
    if classification.tag == 5 { return "target_mismatch"; }
    if classification.tag == 6 { return "object_format_mismatch"; }
    if classification.tag == 7 { return "link_capability_mismatch"; }
    if classification.tag == 8 { return "pipeline_taxonomy_mismatch"; }
    if classification.tag == 9 { return "capability_inventory_invalid"; }
    return "invalid_classification";
}

func mir_native_backend_driver_handshake_diagnostic(result: MirNativeBackendDriverHandshakeResult[ctx], ctx: &Arena) str {
    mut output := "Native backend driver handshake [";
    output = std.Concat(
        output,
        mir_native_backend_driver_handshake_classification_name(
            result.classification
        )
    );
    output = std.Concat(output, "]: ");
    output = std.Concat(output, result.detail);
    return std.Clone(ctx, output);
}
