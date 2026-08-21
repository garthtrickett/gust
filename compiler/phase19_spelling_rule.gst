// Phase 19.6 convergence authority for the legacy brand-spelling rule.
//
// This table is deliberately retained until Patch 19.8 removes spelling-based
// decisions from the self-hosted compiler. Consumers may select exact, suffix,
// or generated-expression matching, but they must all source the vocabulary
// and matching order here.

func phase19_legacy_brand_spellings(ctx: &Arena) std.Vector[str, ctx] {
    mut brands: std.Vector[str, ctx] := std.VectorNew(ctx);
    brands.Push("ctx");
    brands.Push("connCtx");
    brands.Push("arena");
    brands.Push("a");
    brands.Push("Any");
    brands.Push("ctx1");
    brands.Push("ctx2");
    brands.Push("innerCtx");
    brands.Push("outerCtx");
    brands.Push("current_ctx");
    brands.Push("next_ctx");
    brands.Push("main_ctx");
    brands.Push("bg_ctx");
    brands.Push("file_ctx");
    return brands;
}

func phase19_legacy_brand_spelling_is_exact(value: str, ctx: &Arena) int {
    mut brands := phase19_legacy_brand_spellings(ctx);
    mut index := 0;
    while index < len(brands) {
        if std.str_eq(value, brands[index]) == 1 {
            return 1;
        }
        index = index + 1;
    }
    return 0;
}

func phase19_legacy_brand_from_suffix(value: str, ctx: &Arena) str {
    mut brands := phase19_legacy_brand_spellings(ctx);
    mut index := 0;
    while index < len(brands) {
        if std.str_eq(value, brands[index]) == 1 {
            return std.Clone(ctx, brands[index]);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(brands) {
        mut brand := brands[index];
        mut single_separator := std.Concat("_", brand);
        mut module_separator := std.Concat("__", brand);
        if len(value) >= len(single_separator) {
            mut suffix := std.str_slice(value, len(value) - len(single_separator), len(value));
            if std.str_eq(suffix, single_separator) == 1 {
                return std.Clone(ctx, brand);
            }
        }
        if len(value) >= len(module_separator) {
            mut suffix := std.str_slice(value, len(value) - len(module_separator), len(value));
            if std.str_eq(suffix, module_separator) == 1 {
                return std.Clone(ctx, brand);
            }
        }
        index = index + 1;
    }
    return "";
}

func phase19_legacy_brand_spelling_in_expression(value: str, ctx: &Arena) int {
    if phase19_legacy_brand_spelling_is_exact(value, ctx) == 1 {
        return 1;
    }
    mut brands := phase19_legacy_brand_spellings(ctx);
    mut index := 0;
    while index < len(brands) {
        mut dot_form := std.Concat(".", brands[index]);
        mut arrow_form := std.Concat("->", brands[index]);
        if std.str_find(value, dot_form) != 0 - 1 || std.str_find(value, arrow_form) != 0 - 1 {
            return 1;
        }
        index = index + 1;
    }
    return 0;
}
