# Cranelift Phase 19 Canonical Branded Type Naming

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_type_naming.py project`. Do not edit by hand.

- Authority: `phase19_canonical_type_naming_v1`
- Status: `ready_for_patch19_4`
- Next patch: `19.4`
- Identity authority: `phase19_brand_identity_authority_v1`
- Construction: `template_plus_non_brand_resolved_type_arguments`
- Codegen consumer: `canonical_type_name_lookup_only`

## Result

Monomorphization now constructs a canonical name from the template and its
non-brand resolved type arguments. The exact arena identity comes from the
Patch 19.2 `BrandIdentity` record. `codegen_erase_struct_name` performs a
metadata lookup only; it no longer deletes suffixes or consults a brand-word
vocabulary.

Both the full monomorphized name and the construction state with the outer
brand argument elided map to the same canonical name. This keeps arena-index
metadata, struct declarations, and synthetic wrapper names aligned without
reverse-parsing a flattened string.

## Native ABI aliases

The following types enter through manually registered runtime signatures, not
Gust template monomorphization. Their existing C ABI spellings are recorded at
that boundary.

| Branded signature name | Canonical C name |
| --- | --- |
| `os_Dir_ctx` | `os_Dir` |
| `os_DirEntry_ctx` | `os_DirEntry` |
| `LookupResult_os_Dir_ctx` | `LookupResult_os_Dir` |
| `LookupResult_os_DirEntry_ctx` | `LookupResult_os_DirEntry` |

## Enumerated generated-C naming changes

The paired inferred/explicit fixture uses the namespaced arena identity
`lib_module__ctx`. The old surgery removed only `module__ctx`, leaving a false
`_lib` type argument. Construction removes the complete brand argument.

| Before | After | Reason |
| --- | --- | --- |
| `NamingHolder_lib` | `NamingHolder` | the legacy suffix path removed only module__ctx from lib_module__ctx |
| `CastResult_NamingHolder_lib` | `CastResult_NamingHolder` | synthetic wrappers consume the canonical payload name |

The inferred and explicit sources emit byte-identical C after this correction,
and the resulting translation unit compiles and runs. No MIR instruction,
layout, ABI, runtime symbol, or backend-specific semantic changed.
