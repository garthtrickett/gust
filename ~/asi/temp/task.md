# Feature Summary: Brand Erasure in Self-Hosted Code Generator

Brand Erasure is a code generation pass that normalizes brand-annotated types by stripping localized brand suffixes during C translation. This collapses different monomorphizations of the same underlying types (e.g., `std_Vector_str_ctx` and `std_Vector_str_resolver__ctx`) into a single, unified C-compatible type (`std_Vector_str`), eliminating C compiler type mismatches at cross-module function call sites.

## Gap Analysis

- **Brand Suffix Stripping**: Current codebase lacks structural brand suffix erasure. Struct names are printed with fully branded names directly from the typechecker. We will implement `codegen_erase_struct_name` to handle direct and namespace-replaced brand stripping.
- **Recursive Type Erasure**: Type representation does not pass through an erasure helper. We will implement `codegen_erase_type` to recursively strip brand information from structs, indices, raw pointers, slices, and generic parameters.
- **Type Representation**: The `codegen_get_c_type` and other helper functions will be integrated in subsequent steps once core helpers are verified.

## Implementation Steps

### Step 1: Core Brand Erasure Utilities (Current Step)
- **Objective**: Implement the core brand erasure utilities in `compiler/codegen.gst` (`codegen_ends_with`, `codegen_rfind_char`, `codegen_strip_brand_prefix`, `codegen_erase_struct_name`, `codegen_is_brand_type`, `codegen_erase_type`).
- **Verification**: Add step-specific unit tests in `compiler/codegen_initializer_test_entry.gst` verifying that `codegen_erase_type` correctly maps `std_Vector_str_ctx` and `LookupResult_os_Dir_ctx` to `std_Vector_str` and `LookupResult_os_Dir` respectively.

### Step 2: Integrating Brand Erasure into Type Generation
- **Objective**: Integrate brand erasure into `codegen_get_c_type` and associated string formatting helpers.
- **Verification**: Assert that monomorphized types transpile to unbranded equivalents under `compiler/codegen_initializer_test_entry.gst`.

### Step 3: Deduplicating C Forward Declarations and Struct Blocks
- **Objective**: Deduplicate and group C struct forward declarations and bodies under `codegen_generate` once they are unbranded.
- **Verification**: Verify only a single body definition is generated for multiple branded type instances.

### Step 4: Broader End-to-End Bootstrap Verification
- **Objective**: Run and compile the entire compiler pipeline under CC.
- **Verification**: Assert `gust_v3.c` successfully compiles without any brand type mismatches.

- [x] Create ~/asi/temp/task.md planning checklist.
- [x] Define codegen_ends_with, codegen_rfind_char, codegen_strip_brand_prefix in compiler/codegen.gst.
- [x] Define codegen_erase_struct_name in compiler/codegen.gst.
- [x] Define codegen_is_brand_type in compiler/codegen.gst.
- [x] Define codegen_erase_type (t: ast.Type[ctx], env: &typechecker.TypeEnvironment[ctx], ctx: &Arena) ast.Type[ctx] to recursively construct an unbranded type node.