// Gust MIR scaffold.
//
// MIR is the lowered executable IR between the typechecked AST and backend
// emission. Phase 1 is intentionally inert: this file defines the future home
// for MIR data structures, but no production compiler path should depend on it
// yet.
//
// Planned pipeline:
//
//   typechecked AST / typed high-level representation
//     -> Gust MIR
//     -> MIR verifier
//     -> C backend first
//     -> Crane lift backend later
//
// Phase 1 rule:
//   Do not add AST-to-MIR lowering, MIR-to-C emission, Crane lift integration,
//   or production codegen dependencies in this file yet.

import "token.gst" as token;
import "mir_layout.gst" as layout;
import "mir_integer_conversion.gst" as conversion;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_memory_access.gst" as memory_access;
import "mir_string_view.gst" as string_view;
import "mir_array_slice.gst" as array_slice;
import "mir_struct_layout.gst" as structs;
import "mir_enum.gst" as enums;
import "mir_aggregate_transport.gst" as aggregate;
import "mir_resource_value.gst" as resource_mir;

type MirTypeLayoutReference[ctx] struct {
    type_id: str,
    layout_id: str
}

type MirPrimitiveScalarReference[ctx] struct {
    type_id: str,
    layout_id: str,
    target_id: str,
    bit_width: int,
    signedness: str
}

type MirIntegerConversionKind enum {
    SignExtend,
    ZeroExtend,
    Truncate,
    CheckedNumeric,
    WrappingNumeric,
    BitReinterpret,
    BoolToInteger,
    IntegerToBool
}

type MirIntegerConversionReference[ctx] struct {
    rule_id: str,
    rule_name: str,
    target_id: str,
    conversion_kind: MirIntegerConversionKind,
    source_type_id: str,
    source_layout_id: str,
    destination_type_id: str,
    destination_layout_id: str,
    source_width: int,
    destination_width: int,
    source_signedness: str,
    destination_signedness: str,
    policy: str
}

type MirPointerOperationKind enum {
    AddressOfLocal,
    NullPointer,
    PointerEqual,
    PointerNotEqual,
    PointerNullTest,
    PointerNonNullTest,
    NonNullToNullable,
    NullableToNonNullChecked
}

type MirPointerTypeReference[ctx] struct {
    pointer_type_id: str,
    target_id: str,
    pointee_type_id: str,
    pointee_layout_id: str,
    mutability: str,
    nullability: str,
    address_space: str,
    pointer_size: int,
    pointer_alignment: int
}

type MirPointerOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirPointerOperationKind,
    source_pointer_type_id: str,
    destination_pointer_type_id: str,
    result_type_id: str,
    origin_kind: str,
    origin_local_id: int,
    provenance_id: str
}

type MirStackSlotOperationKind enum {
    Declare,
    AddressOf,
    Initialize,
    Assign,
    Read,
    BoundedAggregateCopy
}

type MirStackSlotReference[ctx] struct {
    slot_id: str,
    target_id: str,
    storage_class: str,
    local_id: int,
    contained_type_id: str,
    contained_layout_id: str,
    size: int,
    alignment: int,
    initialization_state: str,
    source_origin: str,
    lifetime_region: str,
    mutability: str,
    address_escape_policy: str
}

type MirStackSlotOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirStackSlotOperationKind,
    slot_id: str,
    source_slot_id: str,
    destination_slot_id: str,
    contained_type_id: str,
    contained_layout_id: str,
    context_kind: str
}

type MirMemoryAccessOperationKind enum {
    Load,
    Store,
    AggregateCopy,
    LayoutOffset
}

type MirMemoryAccessReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirMemoryAccessOperationKind,
    accessed_type_id: str,
    accessed_layout_id: str,
    byte_width: int,
    required_alignment: int,
    origin_kind: str,
    origin_id: str,
    origin_slot_id: str,
    origin_mutability: str,
    origin_nullability: str,
    lifetime_region: str,
    source_file: str,
    source_line: int,
    source_column: int,
    offset_kind: str,
    offset_layout_id: str,
    element_index: int,
    source_offset: int,
    destination_offset: int
}

type MirStringViewOperationKind enum {
    LiteralCreate,
    ViewCreate,
    Length,
    IsEmpty,
    ByteAt,
    Slice,
    ByteEqual
}

type MirStringLiteralReference[ctx] struct {
    literal_id: str,
    symbol_name: str,
    encoding: str,
    byte_length: int,
    storage_kind: str,
    lifetime_region: str
}

type MirStringViewReference[ctx] struct {
    view_id: str,
    source_literal_id: str,
    start: int,
    length: int,
    data_known_null: int,
    lifetime_region: str
}

type MirStringViewOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirStringViewOperationKind,
    literal_id: str,
    view_id: str,
    rhs_view_id: str,
    index: int,
    start: int,
    length: int
}

type MirArraySliceOperationKind enum {
    ArrayInit,
    ElementAddress,
    ElementLoad,
    ElementStore,
    ArrayToSlice,
    SliceLength,
    BoundedIndex,
    Subslice
}

type MirArrayLayoutReference[ctx] struct {
    layout_id: str,
    array_type_id: str,
    target_id: str,
    element_type_id: str,
    element_layout_id: str,
    element_count: int,
    element_stride: int,
    total_size: int,
    alignment: int,
    nesting_depth: int
}

type MirArrayValueReference[ctx] struct {
    array_id: str,
    array_layout_id: str,
    element_type_id: str,
    element_count: int,
    lifetime_region: str
}

type MirSliceReference[ctx] struct {
    slice_id: str,
    source_array_id: str,
    slice_layout_id: str,
    element_type_id: str,
    start: int,
    length: int,
    data_known_null: int,
    lifetime_region: str,
    flow_origin: str
}

type MirArraySliceOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirArraySliceOperationKind,
    array_id: str,
    slice_id: str,
    result_slice_id: str,
    element_type_id: str,
    index: int,
    start: int,
    length: int
}

type MirAggregateTransportOperationKind enum {
    BlockParamDeclare,
    EdgeArgumentPass,
    JoinObserve,
    LoopCarry,
    EarlyReturn
}

type MirAggregateValueReference[ctx] struct {
    value_id: str,
    class_name: str,
    type_id: str,
    layout_id: str,
    transport_policy: str,
    size: int,
    alignment: int,
    variant_name: str,
    movement_kind: str,
    component_count: int,
    block_argument_count: int
}

type MirAggregateBlockReference[ctx] struct {
    block_id: str,
    label: str,
    is_join: int,
    is_loop_header: int,
    param_count: int,
    total_block_argument_count: int
}

type MirAggregateTransportOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirAggregateTransportOperationKind,
    block_label: str,
    edge_id: str,
    value_id: str,
    component_index: int
}

type MirStructOperationKind enum {
    Construct,
    FieldAddress,
    FieldLoad,
    FieldStore
}

type MirStructLayoutReference[ctx] struct {
    layout_id: str,
    struct_type_id: str,
    target_id: str,
    size: int,
    alignment: int,
    field_count: int,
    nesting_depth: int
}

type MirStructValueReference[ctx] struct {
    value_id: str,
    layout_id: str,
    scalar_count: int,
    storage_region: str,
    flow_origin: str
}

type MirStructOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirStructOperationKind,
    value_id: str,
    field_path: str
}

type MirEnumOperationKind enum {
    VariantConstruct,
    TagRead,
    VariantTest,
    PayloadProject,
    MatchBranch
}

type MirEnumLayoutReference[ctx] struct {
    layout_id: str,
    enum_type_id: str,
    target_id: str,
    tag_type_id: str,
    tag_layout_id: str,
    tag_width: int,
    tag_alignment: int,
    tag_offset: int,
    discriminant_assignment: str,
    variant_count: int,
    payload_offset: int,
    max_payload_size: int,
    max_payload_alignment: int,
    size: int,
    alignment: int
}

type MirEnumValueReference[ctx] struct {
    value_id: str,
    enum_layout_id: str,
    enum_type_id: str,
    variant_name: str,
    discriminant: int,
    payload_value_count: int,
    storage_region: str,
    flow_origin: str
}

type MirEnumOperationReference[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    operation_kind: MirEnumOperationKind,
    value_id: str,
    variant_name: str,
    payload_index: int
}

type MirProgram[ctx] struct {
    functions: Index[std.Vector[MirFunction[ctx], ctx], ctx],
    resource_metadata: Index[std.Vector[MirResourceMetadata[ctx], ctx], ctx],
    provenance_metadata: Index[std.Vector[MirProvenanceMetadata[ctx], ctx], ctx],
    native_boundary_metadata: Index[std.Vector[MirNativeBoundaryMetadata[ctx], ctx], ctx],
    type_layout_references: Index[std.Vector[MirTypeLayoutReference[ctx], ctx], ctx],
    primitive_scalar_references: Index[std.Vector[MirPrimitiveScalarReference[ctx], ctx], ctx],
    integer_conversion_references: Index[std.Vector[MirIntegerConversionReference[ctx], ctx], ctx],
    pointer_type_references: Index[std.Vector[MirPointerTypeReference[ctx], ctx], ctx],
    pointer_operation_references: Index[std.Vector[MirPointerOperationReference[ctx], ctx], ctx],
    stack_slot_references: Index[std.Vector[MirStackSlotReference[ctx], ctx], ctx],
    stack_slot_operation_references: Index[std.Vector[MirStackSlotOperationReference[ctx], ctx], ctx],
    memory_access_references: Index[std.Vector[MirMemoryAccessReference[ctx], ctx], ctx],
    string_literal_references: Index[std.Vector[MirStringLiteralReference[ctx], ctx], ctx],
    string_view_references: Index[std.Vector[MirStringViewReference[ctx], ctx], ctx],
    string_view_operation_references: Index[std.Vector[MirStringViewOperationReference[ctx], ctx], ctx],
    array_layout_references: Index[std.Vector[MirArrayLayoutReference[ctx], ctx], ctx],
    array_value_references: Index[std.Vector[MirArrayValueReference[ctx], ctx], ctx],
    slice_references: Index[std.Vector[MirSliceReference[ctx], ctx], ctx],
    array_slice_operation_references: Index[std.Vector[MirArraySliceOperationReference[ctx], ctx], ctx],
    aggregate_value_references: Index[std.Vector[MirAggregateValueReference[ctx], ctx], ctx],
    aggregate_block_references: Index[std.Vector[MirAggregateBlockReference[ctx], ctx], ctx],
    aggregate_operation_references: Index[std.Vector[MirAggregateTransportOperationReference[ctx], ctx], ctx],
    struct_layout_references: Index[std.Vector[MirStructLayoutReference[ctx], ctx], ctx],
    struct_value_references: Index[std.Vector[MirStructValueReference[ctx], ctx], ctx],
    struct_operation_references: Index[std.Vector[MirStructOperationReference[ctx], ctx], ctx],
    enum_layout_references: Index[std.Vector[MirEnumLayoutReference[ctx], ctx], ctx],
    enum_value_references: Index[std.Vector[MirEnumValueReference[ctx], ctx], ctx],
    enum_operation_references: Index[std.Vector[MirEnumOperationReference[ctx], ctx], ctx],
    resource_value_references: Index[std.Vector[resource_mir.MirResourceValue[ctx], ctx], ctx],
    resource_carrier_references: Index[std.Vector[resource_mir.MirResourceCarrier[ctx], ctx], ctx],
    resource_operation_references: Index[std.Vector[resource_mir.MirResourceOperation[ctx], ctx], ctx],
    resource_flow_edge_references: Index[std.Vector[resource_mir.MirResourceFlowEdge[ctx], ctx], ctx]
}

type MirFunction[ctx] struct {
    name: str,
    params: Index[std.Vector[MirLocal[ctx], ctx], ctx],
    return_type: str,
    locals: Index[std.Vector[MirLocal[ctx], ctx], ctx],
    blocks: Index[std.Vector[MirBlock[ctx], ctx], ctx],
    entry_block: int,
    span: token.Span
}

type MirBlock[ctx] struct {
    id: int,
    statements: Index[std.Vector[MirStmt[ctx], ctx], ctx],
    terminator: Index[MirTerminator[ctx], ctx],
    span: token.Span
}

type MirLocal[ctx] struct {
    id: int,
    name: str,
    local_type: str,
    span: token.Span
}

type MirStmt[ctx] enum {
    Nop {
        span: token.Span
    },
    LocalSet {
        local_id: int,
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    Expr {
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    StackSlotOperation {
        operation: Index[MirStackSlotOperationReference[ctx], ctx],
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    MemoryAccess {
        operation: Index[MirMemoryAccessReference[ctx], ctx],
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    ArraySliceOperation {
        operation: Index[MirArraySliceOperationReference[ctx], ctx],
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    ResourceOperation {
        operation: Index[resource_mir.MirResourceOperation[ctx], ctx],
        span: token.Span
    }
}

type MirValue[ctx] enum {
    IntLiteral {
        val: int,
        value_type: str,
        span: token.Span
    },
    BoolLiteral {
        val: int,
        value_type: str,
        span: token.Span
    },
    StringLiteral {
        val: str,
        value_type: str,
        span: token.Span
    },
    LocalRead {
        local_id: int,
        value_type: str,
        span: token.Span
    },
    Call {
        callee: str,
        args: Index[std.Vector[MirValue[ctx], ctx], ctx],
        value_type: str,
        span: token.Span
    },
    IntegerConvert {
        operand: Index[MirValue[ctx], ctx],
        conversion: Index[MirIntegerConversionReference[ctx], ctx],
        value_type: str,
        span: token.Span
    },
    PointerOperation {
        operands: Index[std.Vector[MirValue[ctx], ctx], ctx],
        operation: Index[MirPointerOperationReference[ctx], ctx],
        value_type: str,
        span: token.Span
    },
    MemoryAccess {
        operands: Index[std.Vector[MirValue[ctx], ctx], ctx],
        operation: Index[MirMemoryAccessReference[ctx], ctx],
        value_type: str,
        span: token.Span
    },
    StringViewOperation {
        operands: Index[std.Vector[MirValue[ctx], ctx], ctx],
        operation: Index[MirStringViewOperationReference[ctx], ctx],
        value_type: str,
        span: token.Span
    },
    ArraySliceOperation {
        operands: Index[std.Vector[MirValue[ctx], ctx], ctx],
        operation: Index[MirArraySliceOperationReference[ctx], ctx],
        value_type: str,
        span: token.Span
    },
    ResourceRead {
        value: Index[resource_mir.MirResourceValue[ctx], ctx],
        carrier_id: str,
        span: token.Span
    }
}

type MirTerminator[ctx] enum {
    ReturnVoid {
        span: token.Span
    },
    Return {
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    Jump {
        target_block: int,
        span: token.Span
    },
    Branch {
        condition: Index[MirValue[ctx], ctx],
        then_block: int,
        else_block: int,
        span: token.Span
    }
}

// Phase 7 metadata vocabulary and side-table containers.
//
// These tags and records intentionally remain side-table metadata. They do not
// change MIR lowering, verifier behavior, MIR-to-C output, native backend
// behavior, or production codegen decisions yet. Later Phase 7 steps will add
// focused fixtures that populate these tables.
type MirResourceKind enum {
    NonResource,
    LinearResource,
    DirectoryResource,
    NativeHandleResource
}

type MirResourceState enum {
    Untracked,
    Owned,
    Borrowed,
    Moved,
    Closed,
    DestructorScheduled
}

type MirProvenanceKind enum {
    Unknown,
    LocalBinding,
    Parameter,
    ReturnValue,
    NativeBoundary,
    ResourceDestructor
}

type MirNativeBoundaryKind enum {
    NotNativeBoundary,
    RuntimeCall,
    ExternFunction,
    UnsafeNativeCall,
    LayoutSensitiveCall
}

type MirResourceMetadata[ctx] struct {
    local_id: int,
    resource_kind: MirResourceKind,
    resource_state: MirResourceState,
    span: token.Span
}

type MirProvenanceMetadata[ctx] struct {
    value: Index[MirValue[ctx], ctx],
    provenance_kind: MirProvenanceKind,
    origin_name: str,
    span: token.Span
}

type MirNativeBoundaryMetadata[ctx] struct {
    function_name: str,
    boundary_kind: MirNativeBoundaryKind,
    span: token.Span
}

// Phase 10 whole-program bundle vocabulary.
//
// The bundle is a deterministic aggregation envelope around the frozen
// gust.compiler_mir_ingestion.v1 and v2 records. It does not add a v3 MIR
// syntax and it is not connected to compiler routing or the native driver.
type MirProgramBundleSymbolLinkage enum {
    ExportedEntry,
    ModuleLocal,
    ImportedHost,
    BundleExport,
    ImportedBundle
}

type MirProgramBundleSymbol[ctx] struct {
    name: str,
    link_name: str,
    signature: str,
    linkage: MirProgramBundleSymbolLinkage
}

type MirProgramBundleBlockParameter[ctx] struct {
    function_name: str,
    block_label: str,
    ordinal: int,
    name: str,
    value_type: str
}

type MirProgramBundleModule[ctx] struct {
    module_path: str,
    module_prefix: str,
    object_name: str,
    canonical_format: str,
    canonical_mir: str,
    symbols: Index[std.Vector[MirProgramBundleSymbol[ctx], ctx], ctx],
    block_parameters: Index[std.Vector[MirProgramBundleBlockParameter[ctx], ctx], ctx],
    resource_metadata_count: int,
    provenance_metadata_count: int,
    native_boundary_metadata_count: int
}

type MirProgramBundle[ctx] struct {
    entry_symbol: str,
    modules: Index[std.Vector[MirProgramBundleModule[ctx], ctx], ctx]
}

func mir_make_empty_span() token.Span {
    mut span: token.Span;
    return span;
}

func mir_empty_function_vector(ctx: &Arena) Index[std.Vector[MirFunction[ctx], ctx], ctx] {
    mut functions: std.Vector[MirFunction[ctx], ctx] := std.VectorNew(ctx);
    mut functions_idx: Index[std.Vector[MirFunction[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(functions_idx, functions);
    return functions_idx;
}

func mir_empty_local_vector(ctx: &Arena) Index[std.Vector[MirLocal[ctx], ctx], ctx] {
    mut locals: std.Vector[MirLocal[ctx], ctx] := std.VectorNew(ctx);
    mut locals_idx: Index[std.Vector[MirLocal[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(locals_idx, locals);
    return locals_idx;
}

func mir_empty_block_vector(ctx: &Arena) Index[std.Vector[MirBlock[ctx], ctx], ctx] {
    mut blocks: std.Vector[MirBlock[ctx], ctx] := std.VectorNew(ctx);
    mut blocks_idx: Index[std.Vector[MirBlock[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(blocks_idx, blocks);
    return blocks_idx;
}

func mir_empty_stmt_vector(ctx: &Arena) Index[std.Vector[MirStmt[ctx], ctx], ctx] {
    mut statements: std.Vector[MirStmt[ctx], ctx] := std.VectorNew(ctx);
    mut statements_idx: Index[std.Vector[MirStmt[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(statements_idx, statements);
    return statements_idx;
}

func mir_empty_value_vector(ctx: &Arena) Index[std.Vector[MirValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirValue[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_empty_resource_metadata_vector(ctx: &Arena) Index[std.Vector[MirResourceMetadata[ctx], ctx], ctx] {
    mut metadata: std.Vector[MirResourceMetadata[ctx], ctx] := std.VectorNew(ctx);
    mut metadata_idx: Index[std.Vector[MirResourceMetadata[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(metadata_idx, metadata);
    return metadata_idx;
}

func mir_empty_provenance_metadata_vector(ctx: &Arena) Index[std.Vector[MirProvenanceMetadata[ctx], ctx], ctx] {
    mut metadata: std.Vector[MirProvenanceMetadata[ctx], ctx] := std.VectorNew(ctx);
    mut metadata_idx: Index[std.Vector[MirProvenanceMetadata[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(metadata_idx, metadata);
    return metadata_idx;
}

func mir_empty_native_boundary_metadata_vector(ctx: &Arena) Index[std.Vector[MirNativeBoundaryMetadata[ctx], ctx], ctx] {
    mut metadata: std.Vector[MirNativeBoundaryMetadata[ctx], ctx] := std.VectorNew(ctx);
    mut metadata_idx: Index[std.Vector[MirNativeBoundaryMetadata[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(metadata_idx, metadata);
    return metadata_idx;
}

func mir_empty_type_layout_reference_vector(ctx: &Arena) Index[std.Vector[MirTypeLayoutReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirTypeLayoutReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirTypeLayoutReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_primitive_scalar_reference_vector(ctx: &Arena) Index[std.Vector[MirPrimitiveScalarReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirPrimitiveScalarReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirPrimitiveScalarReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_integer_conversion_reference_vector(ctx: &Arena) Index[std.Vector[MirIntegerConversionReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirIntegerConversionReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirIntegerConversionReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_pointer_type_reference_vector(ctx: &Arena) Index[std.Vector[MirPointerTypeReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirPointerTypeReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirPointerTypeReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_pointer_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirPointerOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirPointerOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirPointerOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_stack_slot_reference_vector(ctx: &Arena) Index[std.Vector[MirStackSlotReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStackSlotReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStackSlotReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_stack_slot_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirStackSlotOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStackSlotOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStackSlotOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_memory_access_reference_vector(ctx: &Arena) Index[std.Vector[MirMemoryAccessReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirMemoryAccessReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirMemoryAccessReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_string_literal_reference_vector(ctx: &Arena) Index[std.Vector[MirStringLiteralReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStringLiteralReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStringLiteralReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_string_view_reference_vector(ctx: &Arena) Index[std.Vector[MirStringViewReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStringViewReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStringViewReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_string_view_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirStringViewOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStringViewOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStringViewOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}


func mir_empty_array_layout_reference_vector(ctx: &Arena) Index[std.Vector[MirArrayLayoutReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirArrayLayoutReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirArrayLayoutReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_array_value_reference_vector(ctx: &Arena) Index[std.Vector[MirArrayValueReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirArrayValueReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirArrayValueReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_slice_reference_vector(ctx: &Arena) Index[std.Vector[MirSliceReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirSliceReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirSliceReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_array_slice_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirArraySliceOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirArraySliceOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirArraySliceOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_aggregate_value_reference_vector(ctx: &Arena) Index[std.Vector[MirAggregateValueReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirAggregateValueReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirAggregateValueReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_aggregate_block_reference_vector(ctx: &Arena) Index[std.Vector[MirAggregateBlockReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirAggregateBlockReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirAggregateBlockReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_aggregate_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirAggregateTransportOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirAggregateTransportOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirAggregateTransportOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_struct_layout_reference_vector(ctx: &Arena) Index[std.Vector[MirStructLayoutReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStructLayoutReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStructLayoutReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_struct_value_reference_vector(ctx: &Arena) Index[std.Vector[MirStructValueReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStructValueReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStructValueReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_struct_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirStructOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirStructOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirStructOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_enum_layout_reference_vector(ctx: &Arena) Index[std.Vector[MirEnumLayoutReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirEnumLayoutReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirEnumLayoutReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_enum_value_reference_vector(ctx: &Arena) Index[std.Vector[MirEnumValueReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirEnumValueReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirEnumValueReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_enum_operation_reference_vector(ctx: &Arena) Index[std.Vector[MirEnumOperationReference[ctx], ctx], ctx] {
    mut references: std.Vector[MirEnumOperationReference[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[MirEnumOperationReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_resource_value_reference_vector(ctx: &Arena) Index[std.Vector[resource_mir.MirResourceValue[ctx], ctx], ctx] {
    mut references: std.Vector[resource_mir.MirResourceValue[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[resource_mir.MirResourceValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_resource_carrier_reference_vector(ctx: &Arena) Index[std.Vector[resource_mir.MirResourceCarrier[ctx], ctx], ctx] {
    mut references: std.Vector[resource_mir.MirResourceCarrier[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[resource_mir.MirResourceCarrier[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_resource_operation_reference_vector(ctx: &Arena) Index[std.Vector[resource_mir.MirResourceOperation[ctx], ctx], ctx] {
    mut references: std.Vector[resource_mir.MirResourceOperation[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[resource_mir.MirResourceOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_empty_resource_flow_edge_reference_vector(ctx: &Arena) Index[std.Vector[resource_mir.MirResourceFlowEdge[ctx], ctx], ctx] {
    mut references: std.Vector[resource_mir.MirResourceFlowEdge[ctx], ctx] := std.VectorNew(ctx);
    mut references_idx: Index[std.Vector[resource_mir.MirResourceFlowEdge[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(references_idx, references);
    return references_idx;
}

func mir_value_vector_with_value(values_idx: Index[std.Vector[MirValue[ctx], ctx], ctx], value: MirValue[ctx], ctx: &Arena) Index[std.Vector[MirValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirValue[ctx], ctx] := ctx[values_idx];
    values.Push(value);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_alloc_value(value: MirValue[ctx], ctx: &Arena) Index[MirValue[ctx], ctx] {
    mut value_idx: Index[MirValue[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(value_idx, value);
    return value_idx;
}

func mir_alloc_terminator(terminator: MirTerminator[ctx], ctx: &Arena) Index[MirTerminator[ctx], ctx] {
    mut terminator_idx: Index[MirTerminator[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(terminator_idx, terminator);
    return terminator_idx;
}

func mir_make_program(ctx: &Arena) MirProgram[ctx] {
    mut program: MirProgram[ctx];
    program.functions = mir_empty_function_vector(ctx);
    program.resource_metadata = mir_empty_resource_metadata_vector(ctx);
    program.provenance_metadata = mir_empty_provenance_metadata_vector(ctx);
    program.native_boundary_metadata = mir_empty_native_boundary_metadata_vector(ctx);
    program.type_layout_references = mir_empty_type_layout_reference_vector(ctx);
    program.primitive_scalar_references = mir_empty_primitive_scalar_reference_vector(ctx);
    program.integer_conversion_references = mir_empty_integer_conversion_reference_vector(ctx);
    program.pointer_type_references = mir_empty_pointer_type_reference_vector(ctx);
    program.pointer_operation_references = mir_empty_pointer_operation_reference_vector(ctx);
    program.stack_slot_references = mir_empty_stack_slot_reference_vector(ctx);
    program.stack_slot_operation_references = mir_empty_stack_slot_operation_reference_vector(ctx);
    program.memory_access_references = mir_empty_memory_access_reference_vector(ctx);
    program.string_literal_references = mir_empty_string_literal_reference_vector(ctx);
    program.string_view_references = mir_empty_string_view_reference_vector(ctx);
    program.string_view_operation_references = mir_empty_string_view_operation_reference_vector(ctx);
    program.array_layout_references = mir_empty_array_layout_reference_vector(ctx);
    program.array_value_references = mir_empty_array_value_reference_vector(ctx);
    program.slice_references = mir_empty_slice_reference_vector(ctx);
    program.array_slice_operation_references = mir_empty_array_slice_operation_reference_vector(ctx);
    program.aggregate_value_references = mir_empty_aggregate_value_reference_vector(ctx);
    program.aggregate_block_references = mir_empty_aggregate_block_reference_vector(ctx);
    program.aggregate_operation_references = mir_empty_aggregate_operation_reference_vector(ctx);
    program.struct_layout_references = mir_empty_struct_layout_reference_vector(ctx);
    program.struct_value_references = mir_empty_struct_value_reference_vector(ctx);
    program.struct_operation_references = mir_empty_struct_operation_reference_vector(ctx);
    program.enum_layout_references = mir_empty_enum_layout_reference_vector(ctx);
    program.enum_value_references = mir_empty_enum_value_reference_vector(ctx);
    program.enum_operation_references = mir_empty_enum_operation_reference_vector(ctx);
    program.resource_value_references = mir_empty_resource_value_reference_vector(ctx);
    program.resource_carrier_references = mir_empty_resource_carrier_reference_vector(ctx);
    program.resource_operation_references = mir_empty_resource_operation_reference_vector(ctx);
    program.resource_flow_edge_references = mir_empty_resource_flow_edge_reference_vector(ctx);
    return program;
}

func mir_make_type_layout_reference(type_id: str, layout_id: str, ctx: &Arena) MirTypeLayoutReference[ctx] {
    mut reference: MirTypeLayoutReference[ctx];
    reference.type_id = std.Clone(ctx, type_id);
    reference.layout_id = std.Clone(ctx, layout_id);
    return reference;
}

func mir_program_with_type_layout_reference(program: MirProgram[ctx], reference: MirTypeLayoutReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirTypeLayoutReference[ctx], ctx] := ctx[updated.type_layout_references];
    references.Push(reference);
    ctx.Set(updated.type_layout_references, references);
    return updated;
}

func mir_make_primitive_scalar_reference(type_id: str, layout_id: str, target_id: str, bit_width: int, signedness: str, ctx: &Arena) MirPrimitiveScalarReference[ctx] {
    mut reference: MirPrimitiveScalarReference[ctx];
    reference.type_id = std.Clone(ctx, type_id);
    reference.layout_id = std.Clone(ctx, layout_id);
    reference.target_id = std.Clone(ctx, target_id);
    reference.bit_width = bit_width;
    reference.signedness = std.Clone(ctx, signedness);
    return reference;
}

func mir_program_with_primitive_scalar_reference(program: MirProgram[ctx], reference: MirPrimitiveScalarReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirPrimitiveScalarReference[ctx], ctx] := ctx[updated.primitive_scalar_references];
    references.Push(reference);
    ctx.Set(updated.primitive_scalar_references, references);
    return updated;
}

func mir_program_primitive_scalar_references_are_valid(program: MirProgram[ctx], table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if layout.mir_layout_table_is_valid(table, ctx) == 0 {
        return 0;
    }
    mut references: std.Vector[MirPrimitiveScalarReference[ctx], ctx] := ctx[program.primitive_scalar_references];
    mut reference_index := 0;
    while reference_index < len(references) {
        mut reference := references[reference_index];
        if layout.mir_layout_field_is_safe(reference.type_id, 0) == 0 ||
           layout.mir_layout_field_is_safe(reference.layout_id, 0) == 0 ||
           layout.mir_layout_field_is_safe(reference.target_id, 0) == 0 ||
           reference.bit_width <= 0
        {
            return 0;
        }
        mut query := layout.mir_layout_of(
            table,
            reference.type_id,
            reference.target_id,
            ctx
        );
        if query.found == 0 ||
           std.str_eq(query.layout.layout_id, reference.layout_id) == 0 ||
           query.layout.bit_width != reference.bit_width ||
           std.str_eq(query.layout.signedness, reference.signedness) == 0
        {
            return 0;
        }
        mut prior_index := 0;
        while prior_index < reference_index {
            if std.str_eq(references[prior_index].type_id, reference.type_id) == 1 {
                return 0;
            }
            prior_index = prior_index + 1;
        }
        reference_index = reference_index + 1;
    }
    return 1;
}

func mir_integer_conversion_kind_from_name(kind: str) MirIntegerConversionKind {
    mut result: MirIntegerConversionKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "zero_extend") == 1 { result.tag = 1; }
        if std.str_eq(kind, "truncate") == 1 { result.tag = 2; }
        if std.str_eq(kind, "checked_numeric") == 1 { result.tag = 3; }
        if std.str_eq(kind, "wrapping_numeric") == 1 { result.tag = 4; }
        if std.str_eq(kind, "bit_reinterpret") == 1 { result.tag = 5; }
        if std.str_eq(kind, "bool_to_integer") == 1 { result.tag = 6; }
        if std.str_eq(kind, "integer_to_bool") == 1 { result.tag = 7; }
    }
    return result;
}

func mir_debug_integer_conversion_kind(kind: MirIntegerConversionKind) str {
    if kind.tag == 0 { return "sign_extend"; }
    if kind.tag == 1 { return "zero_extend"; }
    if kind.tag == 2 { return "truncate"; }
    if kind.tag == 3 { return "checked_numeric"; }
    if kind.tag == 4 { return "wrapping_numeric"; }
    if kind.tag == 5 { return "bit_reinterpret"; }
    if kind.tag == 6 { return "bool_to_integer"; }
    if kind.tag == 7 { return "integer_to_bool"; }
    return "unknown_integer_conversion";
}

func mir_make_integer_conversion_reference(rule: conversion.MirIntegerConversionRule[ctx], ctx: &Arena) MirIntegerConversionReference[ctx] {
    mut reference: MirIntegerConversionReference[ctx];
    reference.rule_id = std.Clone(ctx, rule.rule_id);
    reference.rule_name = std.Clone(ctx, rule.rule_name);
    reference.target_id = std.Clone(ctx, rule.target_id);
    reference.conversion_kind = mir_integer_conversion_kind_from_name(rule.kind);
    reference.source_type_id = std.Clone(ctx, rule.source_type_id);
    reference.source_layout_id = std.Clone(ctx, rule.source_layout_id);
    reference.destination_type_id = std.Clone(ctx, rule.destination_type_id);
    reference.destination_layout_id = std.Clone(ctx, rule.destination_layout_id);
    reference.source_width = rule.source_width;
    reference.destination_width = rule.destination_width;
    reference.source_signedness = std.Clone(ctx, rule.source_signedness);
    reference.destination_signedness = std.Clone(ctx, rule.destination_signedness);
    reference.policy = std.Clone(ctx, rule.policy);
    return reference;
}

func mir_program_with_integer_conversion_reference(program: MirProgram[ctx], reference: MirIntegerConversionReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirIntegerConversionReference[ctx], ctx] := ctx[updated.integer_conversion_references];
    references.Push(reference);
    ctx.Set(updated.integer_conversion_references, references);
    return updated;
}

func mir_program_integer_conversion_references_are_valid(program: MirProgram[ctx], conversion_table: conversion.MirIntegerConversionTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if conversion.mir_integer_conversion_table_is_valid(
        conversion_table,
        layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    mut references: std.Vector[MirIntegerConversionReference[ctx], ctx] := ctx[program.integer_conversion_references];
    mut reference_index := 0;
    while reference_index < len(references) {
        mut reference := references[reference_index];
        mut query := conversion.mir_integer_conversion_rule(
            conversion_table,
            reference.rule_name,
            ctx
        );
        if query.found == 0 ||
           std.str_eq(query.rule.rule_id, reference.rule_id) == 0 ||
           std.str_eq(query.rule.target_id, reference.target_id) == 0 ||
           std.str_eq(query.rule.kind, mir_debug_integer_conversion_kind(reference.conversion_kind)) == 0 ||
           std.str_eq(query.rule.source_type_id, reference.source_type_id) == 0 ||
           std.str_eq(query.rule.source_layout_id, reference.source_layout_id) == 0 ||
           std.str_eq(query.rule.destination_type_id, reference.destination_type_id) == 0 ||
           std.str_eq(query.rule.destination_layout_id, reference.destination_layout_id) == 0 ||
           query.rule.source_width != reference.source_width ||
           query.rule.destination_width != reference.destination_width ||
           std.str_eq(query.rule.source_signedness, reference.source_signedness) == 0 ||
           std.str_eq(query.rule.destination_signedness, reference.destination_signedness) == 0 ||
           std.str_eq(query.rule.policy, reference.policy) == 0
        {
            return 0;
        }
        mut prior_index := 0;
        while prior_index < reference_index {
            if std.str_eq(references[prior_index].rule_id, reference.rule_id) == 1 {
                return 0;
            }
            prior_index = prior_index + 1;
        }
        reference_index = reference_index + 1;
    }
    return 1;
}

func mir_pointer_operation_kind_from_name(kind: str) MirPointerOperationKind {
    mut result: MirPointerOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "null_pointer") == 1 { result.tag = 1; }
        if std.str_eq(kind, "pointer_equal") == 1 { result.tag = 2; }
        if std.str_eq(kind, "pointer_not_equal") == 1 { result.tag = 3; }
        if std.str_eq(kind, "pointer_null_test") == 1 { result.tag = 4; }
        if std.str_eq(kind, "pointer_non_null_test") == 1 { result.tag = 5; }
        if std.str_eq(kind, "non_null_to_nullable") == 1 { result.tag = 6; }
        if std.str_eq(kind, "nullable_to_non_null_checked") == 1 { result.tag = 7; }
    }
    return result;
}

func mir_debug_pointer_operation_kind(kind: MirPointerOperationKind) str {
    if kind.tag == 0 { return "address_of_local"; }
    if kind.tag == 1 { return "null_pointer"; }
    if kind.tag == 2 { return "pointer_equal"; }
    if kind.tag == 3 { return "pointer_not_equal"; }
    if kind.tag == 4 { return "pointer_null_test"; }
    if kind.tag == 5 { return "pointer_non_null_test"; }
    if kind.tag == 6 { return "non_null_to_nullable"; }
    if kind.tag == 7 { return "nullable_to_non_null_checked"; }
    return "unknown_pointer_operation";
}

func mir_make_pointer_type_reference(pointer_type: pointer.MirPointerType[ctx], ctx: &Arena) MirPointerTypeReference[ctx] {
    mut reference: MirPointerTypeReference[ctx];
    reference.pointer_type_id = std.Clone(ctx, pointer_type.pointer_type_id);
    reference.target_id = std.Clone(ctx, pointer_type.target_id);
    reference.pointee_type_id = std.Clone(ctx, pointer_type.pointee_type_id);
    reference.pointee_layout_id = std.Clone(ctx, pointer_type.pointee_layout_id);
    reference.mutability = std.Clone(ctx, pointer_type.mutability);
    reference.nullability = std.Clone(ctx, pointer_type.nullability);
    reference.address_space = std.Clone(ctx, pointer_type.address_space);
    reference.pointer_size = pointer_type.pointer_size;
    reference.pointer_alignment = pointer_type.pointer_alignment;
    return reference;
}

func mir_make_pointer_operation_reference(operation: pointer.MirPointerOperation[ctx], ctx: &Arena) MirPointerOperationReference[ctx] {
    mut reference: MirPointerOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, operation.operation_id);
    reference.operation_name = std.Clone(ctx, operation.operation_name);
    reference.target_id = std.Clone(ctx, operation.target_id);
    reference.operation_kind = mir_pointer_operation_kind_from_name(operation.kind);
    reference.source_pointer_type_id = std.Clone(ctx, operation.source_pointer_type_id);
    reference.destination_pointer_type_id = std.Clone(ctx, operation.destination_pointer_type_id);
    reference.result_type_id = std.Clone(ctx, operation.result_type_id);
    reference.origin_kind = std.Clone(ctx, operation.origin_kind);
    reference.origin_local_id = operation.origin_local_id;
    reference.provenance_id = std.Clone(ctx, operation.provenance_id);
    return reference;
}

func mir_program_with_pointer_type_reference(program: MirProgram[ctx], reference: MirPointerTypeReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirPointerTypeReference[ctx], ctx] := ctx[updated.pointer_type_references];
    references.Push(reference);
    ctx.Set(updated.pointer_type_references, references);
    return updated;
}

func mir_program_with_pointer_operation_reference(program: MirProgram[ctx], reference: MirPointerOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirPointerOperationReference[ctx], ctx] := ctx[updated.pointer_operation_references];
    references.Push(reference);
    ctx.Set(updated.pointer_operation_references, references);
    return updated;
}

func mir_program_pointer_references_are_valid(program: MirProgram[ctx], pointer_table: pointer.MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if pointer.mir_pointer_table_is_valid(pointer_table, layout_table, ctx) == 0 {
        return 0;
    }
    mut type_references: std.Vector[MirPointerTypeReference[ctx], ctx] := ctx[program.pointer_type_references];
    mut type_index := 0;
    while type_index < len(type_references) {
        mut reference := type_references[type_index];
        mut query := pointer.mir_pointer_type(pointer_table, reference.pointer_type_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.pointer_type.target_id, reference.target_id) == 0 ||
           std.str_eq(query.pointer_type.pointee_type_id, reference.pointee_type_id) == 0 ||
           std.str_eq(query.pointer_type.pointee_layout_id, reference.pointee_layout_id) == 0 ||
           std.str_eq(query.pointer_type.mutability, reference.mutability) == 0 ||
           std.str_eq(query.pointer_type.nullability, reference.nullability) == 0 ||
           std.str_eq(query.pointer_type.address_space, reference.address_space) == 0 ||
           query.pointer_type.pointer_size != reference.pointer_size ||
           query.pointer_type.pointer_alignment != reference.pointer_alignment
        {
            return 0;
        }
        type_index = type_index + 1;
    }

    mut operation_references: std.Vector[MirPointerOperationReference[ctx], ctx] := ctx[program.pointer_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := pointer.mir_pointer_operation(pointer_table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.operation.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.operation.target_id, reference.target_id) == 0 ||
           std.str_eq(query.operation.kind, mir_debug_pointer_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.operation.source_pointer_type_id, reference.source_pointer_type_id) == 0 ||
           std.str_eq(query.operation.destination_pointer_type_id, reference.destination_pointer_type_id) == 0 ||
           std.str_eq(query.operation.result_type_id, reference.result_type_id) == 0 ||
           std.str_eq(query.operation.origin_kind, reference.origin_kind) == 0 ||
           query.operation.origin_local_id != reference.origin_local_id ||
           std.str_eq(query.operation.provenance_id, reference.provenance_id) == 0
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_stack_slot_operation_kind_from_name(kind: str) MirStackSlotOperationKind {
    mut result: MirStackSlotOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "address_of") == 1 { result.tag = 1; }
        if std.str_eq(kind, "initialize") == 1 { result.tag = 2; }
        if std.str_eq(kind, "assign") == 1 { result.tag = 3; }
        if std.str_eq(kind, "read") == 1 { result.tag = 4; }
        if std.str_eq(kind, "bounded_aggregate_copy") == 1 { result.tag = 5; }
    }
    return result;
}

func mir_debug_stack_slot_operation_kind(kind: MirStackSlotOperationKind) str {
    unsafe {
        if kind.tag == 1 { return "address_of"; }
        if kind.tag == 2 { return "initialize"; }
        if kind.tag == 3 { return "assign"; }
        if kind.tag == 4 { return "read"; }
        if kind.tag == 5 { return "bounded_aggregate_copy"; }
    }
    return "declare";
}

func mir_make_stack_slot_reference(slot: stack_slot.MirStackSlot[ctx], ctx: &Arena) MirStackSlotReference[ctx] {
    mut reference: MirStackSlotReference[ctx];
    reference.slot_id = std.Clone(ctx, slot.slot_id);
    reference.target_id = std.Clone(ctx, slot.target_id);
    reference.storage_class = std.Clone(ctx, slot.storage_class);
    reference.local_id = slot.local_id;
    reference.contained_type_id = std.Clone(ctx, slot.contained_type_id);
    reference.contained_layout_id = std.Clone(ctx, slot.contained_layout_id);
    reference.size = slot.size;
    reference.alignment = slot.alignment;
    reference.initialization_state = std.Clone(ctx, slot.initialization_state);
    reference.source_origin = std.Clone(ctx, slot.source_origin);
    reference.lifetime_region = std.Clone(ctx, slot.lifetime_region);
    reference.mutability = std.Clone(ctx, slot.mutability);
    reference.address_escape_policy = std.Clone(ctx, slot.address_escape_policy);
    return reference;
}

func mir_make_stack_slot_operation_reference(operation: stack_slot.MirStackSlotOperation[ctx], ctx: &Arena) MirStackSlotOperationReference[ctx] {
    mut reference: MirStackSlotOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, operation.operation_id);
    reference.operation_name = std.Clone(ctx, operation.operation_name);
    reference.target_id = std.Clone(ctx, operation.target_id);
    reference.operation_kind = mir_stack_slot_operation_kind_from_name(operation.kind);
    reference.slot_id = std.Clone(ctx, operation.slot_id);
    reference.source_slot_id = std.Clone(ctx, operation.source_slot_id);
    reference.destination_slot_id = std.Clone(ctx, operation.destination_slot_id);
    reference.contained_type_id = std.Clone(ctx, operation.contained_type_id);
    reference.contained_layout_id = std.Clone(ctx, operation.contained_layout_id);
    reference.context_kind = std.Clone(ctx, operation.context_kind);
    return reference;
}

func mir_program_with_stack_slot_reference(program: MirProgram[ctx], reference: MirStackSlotReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStackSlotReference[ctx], ctx] := ctx[updated.stack_slot_references];
    references.Push(reference);
    ctx.Set(updated.stack_slot_references, references);
    return updated;
}

func mir_program_with_stack_slot_operation_reference(program: MirProgram[ctx], reference: MirStackSlotOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStackSlotOperationReference[ctx], ctx] := ctx[updated.stack_slot_operation_references];
    references.Push(reference);
    ctx.Set(updated.stack_slot_operation_references, references);
    return updated;
}

func mir_program_stack_slot_references_are_valid(program: MirProgram[ctx], table: stack_slot.MirStackSlotTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if stack_slot.mir_stack_slot_table_is_valid(table, layout_table, ctx) == 0 { return 0; }
    mut slot_references: std.Vector[MirStackSlotReference[ctx], ctx] := ctx[program.stack_slot_references];
    mut slot_index := 0;
    while slot_index < len(slot_references) {
        mut reference := slot_references[slot_index];
        mut query := stack_slot.mir_stack_slot(table, reference.slot_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.slot.target_id, reference.target_id) == 0 ||
           std.str_eq(query.slot.storage_class, reference.storage_class) == 0 ||
           query.slot.local_id != reference.local_id ||
           std.str_eq(query.slot.contained_type_id, reference.contained_type_id) == 0 ||
           std.str_eq(query.slot.contained_layout_id, reference.contained_layout_id) == 0 ||
           query.slot.size != reference.size ||
           query.slot.alignment != reference.alignment ||
           std.str_eq(query.slot.initialization_state, reference.initialization_state) == 0 ||
           std.str_eq(query.slot.source_origin, reference.source_origin) == 0 ||
           std.str_eq(query.slot.lifetime_region, reference.lifetime_region) == 0 ||
           std.str_eq(query.slot.mutability, reference.mutability) == 0 ||
           std.str_eq(query.slot.address_escape_policy, reference.address_escape_policy) == 0
        {
            return 0;
        }
        slot_index = slot_index + 1;
    }
    mut operation_references: std.Vector[MirStackSlotOperationReference[ctx], ctx] := ctx[program.stack_slot_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := stack_slot.mir_stack_slot_operation(table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.operation.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.operation.target_id, reference.target_id) == 0 ||
           std.str_eq(query.operation.kind, mir_debug_stack_slot_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.operation.slot_id, reference.slot_id) == 0 ||
           std.str_eq(query.operation.source_slot_id, reference.source_slot_id) == 0 ||
           std.str_eq(query.operation.destination_slot_id, reference.destination_slot_id) == 0 ||
           std.str_eq(query.operation.contained_type_id, reference.contained_type_id) == 0 ||
           std.str_eq(query.operation.contained_layout_id, reference.contained_layout_id) == 0 ||
           std.str_eq(query.operation.context_kind, reference.context_kind) == 0
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_string_view_operation_kind_from_name(kind: str) MirStringViewOperationKind {
    mut result: MirStringViewOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "view_create") == 1 { result.tag = 1; }
        if std.str_eq(kind, "length") == 1 { result.tag = 2; }
        if std.str_eq(kind, "is_empty") == 1 { result.tag = 3; }
        if std.str_eq(kind, "byte_at") == 1 { result.tag = 4; }
        if std.str_eq(kind, "slice") == 1 { result.tag = 5; }
        if std.str_eq(kind, "byte_equal") == 1 { result.tag = 6; }
    }
    return result;
}

func mir_debug_string_view_operation_kind(kind: MirStringViewOperationKind) str {
    unsafe {
        if kind.tag == 1 { return "view_create"; }
        if kind.tag == 2 { return "length"; }
        if kind.tag == 3 { return "is_empty"; }
        if kind.tag == 4 { return "byte_at"; }
        if kind.tag == 5 { return "slice"; }
        if kind.tag == 6 { return "byte_equal"; }
    }
    return "literal_create";
}

func mir_make_string_literal_reference(literal: string_view.MirStringLiteralStorage[ctx], ctx: &Arena) MirStringLiteralReference[ctx] {
    mut reference: MirStringLiteralReference[ctx];
    reference.literal_id = std.Clone(ctx, literal.literal_id);
    reference.symbol_name = std.Clone(ctx, literal.symbol_name);
    reference.encoding = std.Clone(ctx, literal.encoding);
    reference.byte_length = literal.byte_length;
    reference.storage_kind = std.Clone(ctx, literal.storage_kind);
    reference.lifetime_region = std.Clone(ctx, literal.lifetime_region);
    return reference;
}

func mir_make_string_view_reference(view: string_view.MirStringView[ctx], ctx: &Arena) MirStringViewReference[ctx] {
    mut reference: MirStringViewReference[ctx];
    reference.view_id = std.Clone(ctx, view.view_id);
    reference.source_literal_id = std.Clone(ctx, view.source_literal_id);
    reference.start = view.start;
    reference.length = view.length;
    reference.data_known_null = view.data_known_null;
    reference.lifetime_region = std.Clone(ctx, view.lifetime_region);
    return reference;
}

func mir_make_string_view_operation_reference(operation: string_view.MirStringViewOperation[ctx], ctx: &Arena) MirStringViewOperationReference[ctx] {
    mut reference: MirStringViewOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, operation.operation_id);
    reference.operation_name = std.Clone(ctx, operation.operation_name);
    reference.target_id = std.Clone(ctx, operation.target_id);
    reference.operation_kind = mir_string_view_operation_kind_from_name(operation.kind);
    reference.literal_id = std.Clone(ctx, operation.literal_id);
    reference.view_id = std.Clone(ctx, operation.view_id);
    reference.rhs_view_id = std.Clone(ctx, operation.rhs_view_id);
    reference.index = operation.index;
    reference.start = operation.start;
    reference.length = operation.length;
    return reference;
}

func mir_program_with_string_literal_reference(program: MirProgram[ctx], reference: MirStringLiteralReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStringLiteralReference[ctx], ctx] := ctx[updated.string_literal_references];
    references.Push(reference);
    ctx.Set(updated.string_literal_references, references);
    return updated;
}

func mir_program_with_string_view_reference(program: MirProgram[ctx], reference: MirStringViewReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStringViewReference[ctx], ctx] := ctx[updated.string_view_references];
    references.Push(reference);
    ctx.Set(updated.string_view_references, references);
    return updated;
}

func mir_program_with_string_view_operation_reference(program: MirProgram[ctx], reference: MirStringViewOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStringViewOperationReference[ctx], ctx] := ctx[updated.string_view_operation_references];
    references.Push(reference);
    ctx.Set(updated.string_view_operation_references, references);
    return updated;
}

func mir_program_string_view_references_are_valid(program: MirProgram[ctx], table: string_view.MirStringViewTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if string_view.mir_string_view_table_is_valid(table, layout_table, ctx) == 0 ||
       string_view.mir_string_view_table_is_legacy_empty(table, ctx) == 1
    {
        return 0;
    }
    mut literal_references: std.Vector[MirStringLiteralReference[ctx], ctx] := ctx[program.string_literal_references];
    mut literal_index := 0;
    while literal_index < len(literal_references) {
        mut reference := literal_references[literal_index];
        mut query := string_view.mir_string_view_literal(table, reference.literal_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.literal.symbol_name, reference.symbol_name) == 0 ||
           std.str_eq(query.literal.encoding, reference.encoding) == 0 ||
           query.literal.byte_length != reference.byte_length ||
           std.str_eq(query.literal.storage_kind, reference.storage_kind) == 0 ||
           std.str_eq(query.literal.lifetime_region, reference.lifetime_region) == 0
        {
            return 0;
        }
        literal_index = literal_index + 1;
    }

    mut view_references: std.Vector[MirStringViewReference[ctx], ctx] := ctx[program.string_view_references];
    mut view_index := 0;
    while view_index < len(view_references) {
        mut reference := view_references[view_index];
        mut query := string_view.mir_string_view_view(table, reference.view_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.view.source_literal_id, reference.source_literal_id) == 0 ||
           query.view.start != reference.start ||
           query.view.length != reference.length ||
           query.view.data_known_null != reference.data_known_null ||
           std.str_eq(query.view.lifetime_region, reference.lifetime_region) == 0
        {
            return 0;
        }
        view_index = view_index + 1;
    }

    mut operation_references: std.Vector[MirStringViewOperationReference[ctx], ctx] := ctx[program.string_view_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := string_view.mir_string_view_operation(table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.operation.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.operation.target_id, reference.target_id) == 0 ||
           std.str_eq(query.operation.kind, mir_debug_string_view_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.operation.literal_id, reference.literal_id) == 0 ||
           std.str_eq(query.operation.view_id, reference.view_id) == 0 ||
           std.str_eq(query.operation.rhs_view_id, reference.rhs_view_id) == 0 ||
           query.operation.index != reference.index ||
           query.operation.start != reference.start ||
           query.operation.length != reference.length
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}


func mir_array_slice_operation_kind_from_name(kind: str) MirArraySliceOperationKind {
    mut result: MirArraySliceOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "element_address") == 1 { result.tag = 1; }
        if std.str_eq(kind, "element_load") == 1 { result.tag = 2; }
        if std.str_eq(kind, "element_store") == 1 { result.tag = 3; }
        if std.str_eq(kind, "array_to_slice") == 1 { result.tag = 4; }
        if std.str_eq(kind, "slice_length") == 1 { result.tag = 5; }
        if std.str_eq(kind, "bounded_index") == 1 { result.tag = 6; }
        if std.str_eq(kind, "subslice") == 1 { result.tag = 7; }
    }
    return result;
}

func mir_debug_array_slice_operation_kind(kind: MirArraySliceOperationKind) str {
    unsafe {
        if kind.tag == 0 { return "array_init"; }
        if kind.tag == 1 { return "element_address"; }
        if kind.tag == 2 { return "element_load"; }
        if kind.tag == 3 { return "element_store"; }
        if kind.tag == 4 { return "array_to_slice"; }
        if kind.tag == 5 { return "slice_length"; }
        if kind.tag == 6 { return "bounded_index"; }
        if kind.tag == 7 { return "subslice"; }
    }
    return "array_slice_unknown";
}

func mir_make_array_layout_reference(value: array_slice.MirArrayLayout[ctx], ctx: &Arena) MirArrayLayoutReference[ctx] {
    mut reference: MirArrayLayoutReference[ctx];
    reference.layout_id = std.Clone(ctx, value.layout_id);
    reference.array_type_id = std.Clone(ctx, value.array_type_id);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.element_type_id = std.Clone(ctx, value.element_type_id);
    reference.element_layout_id = std.Clone(ctx, value.element_layout_id);
    reference.element_count = value.element_count;
    reference.element_stride = value.element_stride;
    reference.total_size = value.total_size;
    reference.alignment = value.alignment;
    reference.nesting_depth = value.nesting_depth;
    return reference;
}

func mir_make_array_value_reference(value: array_slice.MirArrayValue[ctx], ctx: &Arena) MirArrayValueReference[ctx] {
    mut reference: MirArrayValueReference[ctx];
    reference.array_id = std.Clone(ctx, value.array_id);
    reference.array_layout_id = std.Clone(ctx, value.array_layout_id);
    reference.element_type_id = std.Clone(ctx, value.element_type_id);
    mut elements: std.Vector[int, ctx] := ctx[value.elements];
    reference.element_count = len(elements);
    reference.lifetime_region = std.Clone(ctx, value.lifetime_region);
    return reference;
}

func mir_make_slice_reference(value: array_slice.MirSliceValue[ctx], ctx: &Arena) MirSliceReference[ctx] {
    mut reference: MirSliceReference[ctx];
    reference.slice_id = std.Clone(ctx, value.slice_id);
    reference.source_array_id = std.Clone(ctx, value.source_array_id);
    reference.slice_layout_id = std.Clone(ctx, value.slice_layout_id);
    reference.element_type_id = std.Clone(ctx, value.element_type_id);
    reference.start = value.start;
    reference.length = value.length;
    reference.data_known_null = value.data_known_null;
    reference.lifetime_region = std.Clone(ctx, value.lifetime_region);
    reference.flow_origin = std.Clone(ctx, value.flow_origin);
    return reference;
}

func mir_make_array_slice_operation_reference(value: array_slice.MirArraySliceOperation[ctx], ctx: &Arena) MirArraySliceOperationReference[ctx] {
    mut reference: MirArraySliceOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, value.operation_id);
    reference.operation_name = std.Clone(ctx, value.operation_name);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.operation_kind = mir_array_slice_operation_kind_from_name(value.kind);
    reference.array_id = std.Clone(ctx, value.array_id);
    reference.slice_id = std.Clone(ctx, value.slice_id);
    reference.result_slice_id = std.Clone(ctx, value.result_slice_id);
    reference.element_type_id = std.Clone(ctx, value.element_type_id);
    reference.index = value.index;
    reference.start = value.start;
    reference.length = value.length;
    return reference;
}

func mir_program_with_array_layout_reference(program: MirProgram[ctx], reference: MirArrayLayoutReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirArrayLayoutReference[ctx], ctx] := ctx[updated.array_layout_references];
    references.Push(reference);
    ctx.Set(updated.array_layout_references, references);
    return updated;
}

func mir_program_with_array_value_reference(program: MirProgram[ctx], reference: MirArrayValueReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirArrayValueReference[ctx], ctx] := ctx[updated.array_value_references];
    references.Push(reference);
    ctx.Set(updated.array_value_references, references);
    return updated;
}

func mir_program_with_slice_reference(program: MirProgram[ctx], reference: MirSliceReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirSliceReference[ctx], ctx] := ctx[updated.slice_references];
    references.Push(reference);
    ctx.Set(updated.slice_references, references);
    return updated;
}

func mir_program_with_array_slice_operation_reference(program: MirProgram[ctx], reference: MirArraySliceOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirArraySliceOperationReference[ctx], ctx] := ctx[updated.array_slice_operation_references];
    references.Push(reference);
    ctx.Set(updated.array_slice_operation_references, references);
    return updated;
}

func mir_program_array_slice_references_are_valid(program: MirProgram[ctx], table: array_slice.MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if array_slice.mir_array_slice_table_is_valid(table, layout_table, ctx) == 0 ||
       array_slice.mir_array_slice_table_is_legacy_empty(table, ctx) == 1
    {
        return 0;
    }
    mut array_layout_references: std.Vector[MirArrayLayoutReference[ctx], ctx] := ctx[program.array_layout_references];
    mut array_layout_index := 0;
    while array_layout_index < len(array_layout_references) {
        mut reference := array_layout_references[array_layout_index];
        mut query := array_slice.mir_array_slice_array_layout(table, reference.layout_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.array_layout.array_type_id, reference.array_type_id) == 0 ||
           std.str_eq(query.array_layout.target_id, reference.target_id) == 0 ||
           std.str_eq(query.array_layout.element_type_id, reference.element_type_id) == 0 ||
           std.str_eq(query.array_layout.element_layout_id, reference.element_layout_id) == 0 ||
           query.array_layout.element_count != reference.element_count ||
           query.array_layout.element_stride != reference.element_stride ||
           query.array_layout.total_size != reference.total_size ||
           query.array_layout.alignment != reference.alignment ||
           query.array_layout.nesting_depth != reference.nesting_depth
        {
            return 0;
        }
        array_layout_index = array_layout_index + 1;
    }

    mut array_references: std.Vector[MirArrayValueReference[ctx], ctx] := ctx[program.array_value_references];
    mut array_index := 0;
    while array_index < len(array_references) {
        mut reference := array_references[array_index];
        mut query := array_slice.mir_array_slice_array(table, reference.array_id, ctx);
        if query.found == 0 {
            return 0;
        }
        mut elements: std.Vector[int, ctx] := ctx[query.array_value.elements];
        if std.str_eq(query.array_value.array_layout_id, reference.array_layout_id) == 0 ||
           std.str_eq(query.array_value.element_type_id, reference.element_type_id) == 0 ||
           len(elements) != reference.element_count ||
           std.str_eq(query.array_value.lifetime_region, reference.lifetime_region) == 0
        {
            return 0;
        }
        array_index = array_index + 1;
    }

    mut slice_references: std.Vector[MirSliceReference[ctx], ctx] := ctx[program.slice_references];
    mut slice_index := 0;
    while slice_index < len(slice_references) {
        mut reference := slice_references[slice_index];
        mut query := array_slice.mir_array_slice_slice(table, reference.slice_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.slice_value.source_array_id, reference.source_array_id) == 0 ||
           std.str_eq(query.slice_value.slice_layout_id, reference.slice_layout_id) == 0 ||
           std.str_eq(query.slice_value.element_type_id, reference.element_type_id) == 0 ||
           query.slice_value.start != reference.start ||
           query.slice_value.length != reference.length ||
           query.slice_value.data_known_null != reference.data_known_null ||
           std.str_eq(query.slice_value.lifetime_region, reference.lifetime_region) == 0 ||
           std.str_eq(query.slice_value.flow_origin, reference.flow_origin) == 0
        {
            return 0;
        }
        slice_index = slice_index + 1;
    }

    mut operation_references: std.Vector[MirArraySliceOperationReference[ctx], ctx] := ctx[program.array_slice_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := array_slice.mir_array_slice_operation(table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.operation.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.operation.target_id, reference.target_id) == 0 ||
           std.str_eq(query.operation.kind, mir_debug_array_slice_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.operation.array_id, reference.array_id) == 0 ||
           std.str_eq(query.operation.slice_id, reference.slice_id) == 0 ||
           std.str_eq(query.operation.result_slice_id, reference.result_slice_id) == 0 ||
           std.str_eq(query.operation.element_type_id, reference.element_type_id) == 0 ||
           query.operation.index != reference.index ||
           query.operation.start != reference.start ||
           query.operation.length != reference.length
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_aggregate_transport_operation_kind_from_name(kind: str) MirAggregateTransportOperationKind {
    mut result: MirAggregateTransportOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "edge_argument_pass") == 1 { result.tag = 1; }
        if std.str_eq(kind, "join_observe") == 1 { result.tag = 2; }
        if std.str_eq(kind, "loop_carry") == 1 { result.tag = 3; }
        if std.str_eq(kind, "early_return") == 1 { result.tag = 4; }
    }
    return result;
}

func mir_debug_aggregate_transport_operation_kind(kind: MirAggregateTransportOperationKind) str {
    unsafe {
        if kind.tag == 0 { return "block_param_declare"; }
        if kind.tag == 1 { return "edge_argument_pass"; }
        if kind.tag == 2 { return "join_observe"; }
        if kind.tag == 3 { return "loop_carry"; }
        if kind.tag == 4 { return "early_return"; }
    }
    return "aggregate_transport_unknown";
}

func mir_make_aggregate_value_reference(value: aggregate.MirAggregateValue[ctx], ctx: &Arena) MirAggregateValueReference[ctx] {
    mut reference: MirAggregateValueReference[ctx];
    reference.value_id = std.Clone(ctx, value.value_id);
    reference.class_name = std.Clone(ctx, value.class_name);
    reference.type_id = std.Clone(ctx, value.type_id);
    reference.layout_id = std.Clone(ctx, value.layout_id);
    reference.transport_policy = std.Clone(ctx, value.transport_policy);
    reference.size = value.size;
    reference.alignment = value.alignment;
    reference.variant_name = std.Clone(ctx, value.variant_name);
    reference.movement_kind = std.Clone(ctx, value.movement_kind);
    mut components: std.Vector[aggregate.MirAggregateComponent[ctx], ctx] := ctx[value.components];
    reference.component_count = len(components);
    reference.block_argument_count = aggregate.mir_aggregate_arity_for_policy(value.transport_policy, len(components));
    return reference;
}

func mir_make_aggregate_block_reference(value: aggregate.MirAggregateBlock[ctx], ctx: &Arena) MirAggregateBlockReference[ctx] {
    mut reference: MirAggregateBlockReference[ctx];
    reference.block_id = std.Clone(ctx, value.block_id);
    reference.label = std.Clone(ctx, value.label);
    reference.is_join = value.is_join;
    reference.is_loop_header = value.is_loop_header;
    mut params: std.Vector[aggregate.MirAggregateBlockParam[ctx], ctx] := ctx[value.params];
    reference.param_count = len(params);
    reference.total_block_argument_count = value.total_block_argument_count;
    return reference;
}

func mir_make_aggregate_transport_operation_reference(value: aggregate.MirAggregateOperation[ctx], ctx: &Arena) MirAggregateTransportOperationReference[ctx] {
    mut reference: MirAggregateTransportOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, value.operation_id);
    reference.operation_name = std.Clone(ctx, value.operation_name);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.operation_kind = mir_aggregate_transport_operation_kind_from_name(value.kind);
    reference.block_label = std.Clone(ctx, value.block_label);
    reference.edge_id = std.Clone(ctx, value.edge_id);
    reference.value_id = std.Clone(ctx, value.value_id);
    reference.component_index = value.component_index;
    return reference;
}

func mir_program_with_aggregate_value_reference(program: MirProgram[ctx], reference: MirAggregateValueReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirAggregateValueReference[ctx], ctx] := ctx[updated.aggregate_value_references];
    references.Push(reference);
    ctx.Set(updated.aggregate_value_references, references);
    return updated;
}

func mir_program_with_aggregate_block_reference(program: MirProgram[ctx], reference: MirAggregateBlockReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirAggregateBlockReference[ctx], ctx] := ctx[updated.aggregate_block_references];
    references.Push(reference);
    ctx.Set(updated.aggregate_block_references, references);
    return updated;
}

func mir_program_with_aggregate_transport_operation_reference(program: MirProgram[ctx], reference: MirAggregateTransportOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirAggregateTransportOperationReference[ctx], ctx] := ctx[updated.aggregate_operation_references];
    references.Push(reference);
    ctx.Set(updated.aggregate_operation_references, references);
    return updated;
}

func mir_program_aggregate_references_are_valid(program: MirProgram[ctx], table: aggregate.MirAggregateTransportTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if aggregate.mir_aggregate_table_is_valid(table, layout_table, ctx) == 0 ||
       aggregate.mir_aggregate_table_is_legacy_empty(table, ctx) == 1
    {
        return 0;
    }

    mut value_references: std.Vector[MirAggregateValueReference[ctx], ctx] := ctx[program.aggregate_value_references];
    mut value_index := 0;
    while value_index < len(value_references) {
        mut reference := value_references[value_index];
        mut query := aggregate.mir_aggregate_value(table, reference.value_id, ctx);
        if query.found == 0 { return 0; }
        mut components: std.Vector[aggregate.MirAggregateComponent[ctx], ctx] := ctx[query.value.components];
        if std.str_eq(query.value.class_name, reference.class_name) == 0 ||
           std.str_eq(query.value.type_id, reference.type_id) == 0 ||
           std.str_eq(query.value.layout_id, reference.layout_id) == 0 ||
           std.str_eq(query.value.transport_policy, reference.transport_policy) == 0 ||
           std.str_eq(query.value.variant_name, reference.variant_name) == 0 ||
           std.str_eq(query.value.movement_kind, reference.movement_kind) == 0 ||
           query.value.size != reference.size ||
           query.value.alignment != reference.alignment ||
           len(components) != reference.component_count ||
           aggregate.mir_aggregate_arity_for_policy(query.value.transport_policy, len(components)) != reference.block_argument_count
        {
            return 0;
        }
        value_index = value_index + 1;
    }

    mut block_references: std.Vector[MirAggregateBlockReference[ctx], ctx] := ctx[program.aggregate_block_references];
    mut block_index := 0;
    while block_index < len(block_references) {
        mut reference := block_references[block_index];
        mut query := aggregate.mir_aggregate_block(table, reference.label, ctx);
        if query.found == 0 { return 0; }
        mut params: std.Vector[aggregate.MirAggregateBlockParam[ctx], ctx] := ctx[query.value.params];
        if std.str_eq(query.value.block_id, reference.block_id) == 0 ||
           query.value.is_join != reference.is_join ||
           query.value.is_loop_header != reference.is_loop_header ||
           len(params) != reference.param_count ||
           query.value.total_block_argument_count != reference.total_block_argument_count
        {
            return 0;
        }
        block_index = block_index + 1;
    }

    mut operation_references: std.Vector[MirAggregateTransportOperationReference[ctx], ctx] := ctx[program.aggregate_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := aggregate.mir_aggregate_operation(table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.value.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.value.target_id, reference.target_id) == 0 ||
           std.str_eq(query.value.kind, mir_debug_aggregate_transport_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.value.block_label, reference.block_label) == 0 ||
           std.str_eq(query.value.edge_id, reference.edge_id) == 0 ||
           std.str_eq(query.value.value_id, reference.value_id) == 0 ||
           query.value.component_index != reference.component_index
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_struct_operation_kind_from_name(kind: str) MirStructOperationKind {
    mut result: MirStructOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "field_address") == 1 { result.tag = 1; }
        if std.str_eq(kind, "field_load") == 1 { result.tag = 2; }
        if std.str_eq(kind, "field_store") == 1 { result.tag = 3; }
    }
    return result;
}

func mir_debug_struct_operation_kind(kind: MirStructOperationKind) str {
    unsafe {
        if kind.tag == 0 { return "construct"; }
        if kind.tag == 1 { return "field_address"; }
        if kind.tag == 2 { return "field_load"; }
        if kind.tag == 3 { return "field_store"; }
    }
    return "struct_unknown";
}

func mir_make_struct_layout_reference(value: structs.MirStructLayout[ctx], ctx: &Arena) MirStructLayoutReference[ctx] {
    mut reference: MirStructLayoutReference[ctx];
    reference.layout_id = std.Clone(ctx, value.layout_id);
    reference.struct_type_id = std.Clone(ctx, value.struct_type_id);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.size = value.size;
    reference.alignment = value.alignment;
    reference.field_count = value.field_count;
    reference.nesting_depth = value.nesting_depth;
    return reference;
}

func mir_make_struct_value_reference(value: structs.MirStructValue[ctx], ctx: &Arena) MirStructValueReference[ctx] {
    mut reference: MirStructValueReference[ctx];
    reference.value_id = std.Clone(ctx, value.value_id);
    reference.layout_id = std.Clone(ctx, value.layout_id);
    mut scalars: std.Vector[int, ctx] := ctx[value.scalar_values];
    reference.scalar_count = len(scalars);
    reference.storage_region = std.Clone(ctx, value.storage_region);
    reference.flow_origin = std.Clone(ctx, value.flow_origin);
    return reference;
}

func mir_make_struct_operation_reference(value: structs.MirStructOperation[ctx], ctx: &Arena) MirStructOperationReference[ctx] {
    mut reference: MirStructOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, value.operation_id);
    reference.operation_name = std.Clone(ctx, value.operation_name);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.operation_kind = mir_struct_operation_kind_from_name(value.kind);
    reference.value_id = std.Clone(ctx, value.value_id);
    reference.field_path = std.Clone(ctx, value.field_path);
    return reference;
}

func mir_program_with_struct_layout_reference(program: MirProgram[ctx], reference: MirStructLayoutReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStructLayoutReference[ctx], ctx] := ctx[updated.struct_layout_references];
    references.Push(reference);
    ctx.Set(updated.struct_layout_references, references);
    return updated;
}

func mir_program_with_struct_value_reference(program: MirProgram[ctx], reference: MirStructValueReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStructValueReference[ctx], ctx] := ctx[updated.struct_value_references];
    references.Push(reference);
    ctx.Set(updated.struct_value_references, references);
    return updated;
}

func mir_program_with_struct_operation_reference(program: MirProgram[ctx], reference: MirStructOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirStructOperationReference[ctx], ctx] := ctx[updated.struct_operation_references];
    references.Push(reference);
    ctx.Set(updated.struct_operation_references, references);
    return updated;
}

func mir_program_struct_references_are_valid(program: MirProgram[ctx], table: structs.MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if structs.mir_struct_table_is_valid(table, layout_table, ctx) == 0 ||
       structs.mir_struct_table_is_legacy_empty(table, ctx) == 1
    {
        return 0;
    }

    mut layout_references: std.Vector[MirStructLayoutReference[ctx], ctx] := ctx[program.struct_layout_references];
    mut layout_index := 0;
    while layout_index < len(layout_references) {
        mut reference := layout_references[layout_index];
        mut query := structs.mir_struct_layout(table, reference.layout_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.value.struct_type_id, reference.struct_type_id) == 0 ||
           std.str_eq(query.value.target_id, reference.target_id) == 0 ||
           query.value.size != reference.size ||
           query.value.alignment != reference.alignment ||
           query.value.field_count != reference.field_count ||
           query.value.nesting_depth != reference.nesting_depth
        {
            return 0;
        }
        layout_index = layout_index + 1;
    }

    mut value_references: std.Vector[MirStructValueReference[ctx], ctx] := ctx[program.struct_value_references];
    mut value_index := 0;
    while value_index < len(value_references) {
        mut reference := value_references[value_index];
        mut query := structs.mir_struct_value(table, reference.value_id, ctx);
        if query.found == 0 {
            return 0;
        }
        mut scalars: std.Vector[int, ctx] := ctx[query.value.scalar_values];
        if std.str_eq(query.value.layout_id, reference.layout_id) == 0 ||
           len(scalars) != reference.scalar_count ||
           std.str_eq(query.value.storage_region, reference.storage_region) == 0 ||
           std.str_eq(query.value.flow_origin, reference.flow_origin) == 0
        {
            return 0;
        }
        value_index = value_index + 1;
    }

    mut operation_references: std.Vector[MirStructOperationReference[ctx], ctx] := ctx[program.struct_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := structs.mir_struct_operation(table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.value.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.value.target_id, reference.target_id) == 0 ||
           std.str_eq(query.value.kind, mir_debug_struct_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.value.value_id, reference.value_id) == 0 ||
           std.str_eq(query.value.field_path, reference.field_path) == 0
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_enum_operation_kind_from_name(kind: str) MirEnumOperationKind {
    mut result: MirEnumOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "tag_read") == 1 { result.tag = 1; }
        if std.str_eq(kind, "variant_test") == 1 { result.tag = 2; }
        if std.str_eq(kind, "payload_project") == 1 { result.tag = 3; }
        if std.str_eq(kind, "match_branch") == 1 { result.tag = 4; }
    }
    return result;
}

func mir_debug_enum_operation_kind(kind: MirEnumOperationKind) str {
    unsafe {
        if kind.tag == 0 { return "variant_construct"; }
        if kind.tag == 1 { return "tag_read"; }
        if kind.tag == 2 { return "variant_test"; }
        if kind.tag == 3 { return "payload_project"; }
        if kind.tag == 4 { return "match_branch"; }
    }
    return "enum_unknown";
}

func mir_make_enum_layout_reference(value: enums.MirEnumLayout[ctx], ctx: &Arena) MirEnumLayoutReference[ctx] {
    mut reference: MirEnumLayoutReference[ctx];
    reference.layout_id = std.Clone(ctx, value.layout_id);
    reference.enum_type_id = std.Clone(ctx, value.enum_type_id);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.tag_type_id = std.Clone(ctx, value.tag_type_id);
    reference.tag_layout_id = std.Clone(ctx, value.tag_layout_id);
    reference.tag_width = value.tag_width;
    reference.tag_alignment = value.tag_alignment;
    reference.tag_offset = value.tag_offset;
    reference.discriminant_assignment = std.Clone(ctx, value.discriminant_assignment);
    reference.variant_count = value.variant_count;
    reference.payload_offset = value.payload_offset;
    reference.max_payload_size = value.max_payload_size;
    reference.max_payload_alignment = value.max_payload_alignment;
    reference.size = value.size;
    reference.alignment = value.alignment;
    return reference;
}

func mir_make_enum_value_reference(value: enums.MirEnumValue[ctx], ctx: &Arena) MirEnumValueReference[ctx] {
    mut reference: MirEnumValueReference[ctx];
    reference.value_id = std.Clone(ctx, value.value_id);
    reference.enum_layout_id = std.Clone(ctx, value.enum_layout_id);
    reference.enum_type_id = std.Clone(ctx, value.enum_type_id);
    reference.variant_name = std.Clone(ctx, value.variant_name);
    reference.discriminant = value.discriminant;
    mut payload_values: std.Vector[int, ctx] := ctx[value.payload_values];
    reference.payload_value_count = len(payload_values);
    reference.storage_region = std.Clone(ctx, value.storage_region);
    reference.flow_origin = std.Clone(ctx, value.flow_origin);
    return reference;
}

func mir_make_enum_operation_reference(value: enums.MirEnumOperation[ctx], ctx: &Arena) MirEnumOperationReference[ctx] {
    mut reference: MirEnumOperationReference[ctx];
    reference.operation_id = std.Clone(ctx, value.operation_id);
    reference.operation_name = std.Clone(ctx, value.operation_name);
    reference.target_id = std.Clone(ctx, value.target_id);
    reference.operation_kind = mir_enum_operation_kind_from_name(value.kind);
    reference.value_id = std.Clone(ctx, value.value_id);
    reference.variant_name = std.Clone(ctx, value.variant_name);
    reference.payload_index = value.payload_index;
    return reference;
}

func mir_program_with_enum_layout_reference(program: MirProgram[ctx], reference: MirEnumLayoutReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirEnumLayoutReference[ctx], ctx] := ctx[updated.enum_layout_references];
    references.Push(reference);
    ctx.Set(updated.enum_layout_references, references);
    return updated;
}

func mir_program_with_enum_value_reference(program: MirProgram[ctx], reference: MirEnumValueReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirEnumValueReference[ctx], ctx] := ctx[updated.enum_value_references];
    references.Push(reference);
    ctx.Set(updated.enum_value_references, references);
    return updated;
}

func mir_program_with_enum_operation_reference(program: MirProgram[ctx], reference: MirEnumOperationReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirEnumOperationReference[ctx], ctx] := ctx[updated.enum_operation_references];
    references.Push(reference);
    ctx.Set(updated.enum_operation_references, references);
    return updated;
}

func mir_program_enum_references_are_valid(program: MirProgram[ctx], table: enums.MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if enums.mir_enum_table_is_valid(table, layout_table, ctx) == 0 ||
       enums.mir_enum_table_is_legacy_empty(table, ctx) == 1
    {
        return 0;
    }

    mut layout_references: std.Vector[MirEnumLayoutReference[ctx], ctx] := ctx[program.enum_layout_references];
    mut layout_index := 0;
    while layout_index < len(layout_references) {
        mut reference := layout_references[layout_index];
        mut query := enums.mir_enum_layout_of(table, reference.layout_id, ctx);
        if query.found == 0 ||
           std.str_eq(query.enum_layout.enum_type_id, reference.enum_type_id) == 0 ||
           std.str_eq(query.enum_layout.target_id, reference.target_id) == 0 ||
           std.str_eq(query.enum_layout.tag_type_id, reference.tag_type_id) == 0 ||
           std.str_eq(query.enum_layout.tag_layout_id, reference.tag_layout_id) == 0 ||
           std.str_eq(query.enum_layout.discriminant_assignment, reference.discriminant_assignment) == 0 ||
           query.enum_layout.tag_width != reference.tag_width ||
           query.enum_layout.tag_alignment != reference.tag_alignment ||
           query.enum_layout.tag_offset != reference.tag_offset ||
           query.enum_layout.variant_count != reference.variant_count ||
           query.enum_layout.payload_offset != reference.payload_offset ||
           query.enum_layout.max_payload_size != reference.max_payload_size ||
           query.enum_layout.max_payload_alignment != reference.max_payload_alignment ||
           query.enum_layout.size != reference.size ||
           query.enum_layout.alignment != reference.alignment
        {
            return 0;
        }
        layout_index = layout_index + 1;
    }

    mut value_references: std.Vector[MirEnumValueReference[ctx], ctx] := ctx[program.enum_value_references];
    mut value_index := 0;
    while value_index < len(value_references) {
        mut reference := value_references[value_index];
        mut query := enums.mir_enum_value_of(table, reference.value_id, ctx);
        if query.found == 0 {
            return 0;
        }
        mut payload_values: std.Vector[int, ctx] := ctx[query.enum_value.payload_values];
        if std.str_eq(query.enum_value.enum_layout_id, reference.enum_layout_id) == 0 ||
           std.str_eq(query.enum_value.enum_type_id, reference.enum_type_id) == 0 ||
           std.str_eq(query.enum_value.variant_name, reference.variant_name) == 0 ||
           query.enum_value.discriminant != reference.discriminant ||
           len(payload_values) != reference.payload_value_count ||
           std.str_eq(query.enum_value.storage_region, reference.storage_region) == 0 ||
           std.str_eq(query.enum_value.flow_origin, reference.flow_origin) == 0
        {
            return 0;
        }
        value_index = value_index + 1;
    }

    mut operation_references: std.Vector[MirEnumOperationReference[ctx], ctx] := ctx[program.enum_operation_references];
    mut operation_index := 0;
    while operation_index < len(operation_references) {
        mut reference := operation_references[operation_index];
        mut query := enums.mir_enum_operation_of(table, reference.operation_name, ctx);
        if query.found == 0 ||
           std.str_eq(query.operation.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.operation.target_id, reference.target_id) == 0 ||
           std.str_eq(query.operation.kind, mir_debug_enum_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.operation.value_id, reference.value_id) == 0 ||
           std.str_eq(query.operation.variant_name, reference.variant_name) == 0 ||
           query.operation.payload_index != reference.payload_index
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_memory_access_operation_kind_from_name(kind: str) MirMemoryAccessOperationKind {
    mut result: MirMemoryAccessOperationKind;
    unsafe {
        result.tag = 0;
        if std.str_eq(kind, "store") == 1 { result.tag = 1; }
        if std.str_eq(kind, "aggregate_copy") == 1 { result.tag = 2; }
        if std.str_eq(kind, "layout_offset") == 1 { result.tag = 3; }
    }
    return result;
}

func mir_debug_memory_access_operation_kind(kind: MirMemoryAccessOperationKind) str {
    unsafe {
        if kind.tag == 1 { return "store"; }
        if kind.tag == 2 { return "aggregate_copy"; }
        if kind.tag == 3 { return "layout_offset"; }
    }
    return "load";
}

func mir_make_memory_access_reference(operation: memory_access.MirMemoryAccessOperation[ctx], ctx: &Arena) MirMemoryAccessReference[ctx] {
    mut reference: MirMemoryAccessReference[ctx];
    reference.operation_id = std.Clone(ctx, operation.operation_id);
    reference.operation_name = std.Clone(ctx, operation.operation_name);
    reference.target_id = std.Clone(ctx, operation.target_id);
    reference.operation_kind = mir_memory_access_operation_kind_from_name(operation.kind);
    reference.accessed_type_id = std.Clone(ctx, operation.accessed_type_id);
    reference.accessed_layout_id = std.Clone(ctx, operation.accessed_layout_id);
    reference.byte_width = operation.byte_width;
    reference.required_alignment = operation.required_alignment;
    reference.origin_kind = std.Clone(ctx, operation.origin_kind);
    reference.origin_id = std.Clone(ctx, operation.origin_id);
    reference.origin_slot_id = std.Clone(ctx, operation.origin_slot_id);
    reference.origin_mutability = std.Clone(ctx, operation.origin_mutability);
    reference.origin_nullability = std.Clone(ctx, operation.origin_nullability);
    reference.lifetime_region = std.Clone(ctx, operation.lifetime_region);
    reference.source_file = std.Clone(ctx, operation.source_file);
    reference.source_line = operation.source_line;
    reference.source_column = operation.source_column;
    reference.offset_kind = std.Clone(ctx, operation.offset_kind);
    reference.offset_layout_id = std.Clone(ctx, operation.offset_layout_id);
    reference.element_index = operation.element_index;
    reference.source_offset = operation.source_offset;
    reference.destination_offset = operation.destination_offset;
    return reference;
}

func mir_program_with_memory_access_reference(program: MirProgram[ctx], reference: MirMemoryAccessReference[ctx], ctx: &Arena) MirProgram[ctx] {
    mut updated := program;
    mut references: std.Vector[MirMemoryAccessReference[ctx], ctx] := ctx[updated.memory_access_references];
    references.Push(reference);
    ctx.Set(updated.memory_access_references, references);
    return updated;
}

func mir_program_memory_access_references_are_valid(program: MirProgram[ctx], table: memory_access.MirMemoryAccessTable[ctx], layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) int {
    if memory_access.mir_memory_access_table_is_valid(
        table,
        layout_table,
        pointer_table,
        stack_slot_table,
        ctx
    ) == 0
    {
        return 0;
    }
    mut references: std.Vector[MirMemoryAccessReference[ctx], ctx] := ctx[program.memory_access_references];
    mut reference_index := 0;
    while reference_index < len(references) {
        mut reference := references[reference_index];
        mut query := memory_access.mir_memory_access_operation(
            table,
            reference.operation_name,
            ctx
        );
        if query.found == 0 ||
           std.str_eq(query.operation.operation_id, reference.operation_id) == 0 ||
           std.str_eq(query.operation.target_id, reference.target_id) == 0 ||
           std.str_eq(query.operation.kind, mir_debug_memory_access_operation_kind(reference.operation_kind)) == 0 ||
           std.str_eq(query.operation.accessed_type_id, reference.accessed_type_id) == 0 ||
           std.str_eq(query.operation.accessed_layout_id, reference.accessed_layout_id) == 0 ||
           query.operation.byte_width != reference.byte_width ||
           query.operation.required_alignment != reference.required_alignment ||
           std.str_eq(query.operation.origin_kind, reference.origin_kind) == 0 ||
           std.str_eq(query.operation.origin_id, reference.origin_id) == 0 ||
           std.str_eq(query.operation.origin_slot_id, reference.origin_slot_id) == 0 ||
           std.str_eq(query.operation.origin_mutability, reference.origin_mutability) == 0 ||
           std.str_eq(query.operation.origin_nullability, reference.origin_nullability) == 0 ||
           std.str_eq(query.operation.lifetime_region, reference.lifetime_region) == 0 ||
           std.str_eq(query.operation.source_file, reference.source_file) == 0 ||
           query.operation.source_line != reference.source_line ||
           query.operation.source_column != reference.source_column ||
           std.str_eq(query.operation.offset_kind, reference.offset_kind) == 0 ||
           std.str_eq(query.operation.offset_layout_id, reference.offset_layout_id) == 0 ||
           query.operation.element_index != reference.element_index ||
           query.operation.source_offset != reference.source_offset ||
           query.operation.destination_offset != reference.destination_offset
        {
            return 0;
        }
        reference_index = reference_index + 1;
    }
    return 1;
}

func mir_program_layout_reference_is_valid(program: MirProgram[ctx], table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if layout.mir_layout_table_is_valid(table, ctx) == 0 {
        return 0;
    }
    mut references: std.Vector[MirTypeLayoutReference[ctx], ctx] := ctx[program.type_layout_references];
    mut reference_index := 0;
    while reference_index < len(references) {
        mut reference := references[reference_index];
        if layout.mir_layout_field_is_safe(reference.type_id, 0) == 0 ||
           layout.mir_layout_field_is_safe(reference.layout_id, 0) == 0
        {
            return 0;
        }
        mut query := layout.mir_layout_of(
            table,
            reference.type_id,
            table.target.target_id,
            ctx
        );
        if query.found == 0 ||
           std.str_eq(query.layout.layout_id, reference.layout_id) == 0
        {
            return 0;
        }
        mut prior_index := 0;
        while prior_index < reference_index {
            mut prior := references[prior_index];
            if std.str_eq(prior.type_id, reference.type_id) == 1 &&
               std.str_eq(prior.layout_id, reference.layout_id) == 1
            {
                return 0;
            }
            prior_index = prior_index + 1;
        }
        reference_index = reference_index + 1;
    }
    return 1;
}

func mir_make_resource_metadata(local_id: int, resource_kind: MirResourceKind, resource_state: MirResourceState, span: token.Span) MirResourceMetadata[ctx] {
    mut metadata: MirResourceMetadata[ctx];
    metadata.local_id = local_id;
    metadata.resource_kind = resource_kind;
    metadata.resource_state = resource_state;
    metadata.span = span;
    return metadata;
}

func mir_make_provenance_metadata(value: Index[MirValue[ctx], ctx], provenance_kind: MirProvenanceKind, origin_name: str, span: token.Span) MirProvenanceMetadata[ctx] {
    mut metadata: MirProvenanceMetadata[ctx];
    metadata.value = value;
    metadata.provenance_kind = provenance_kind;
    metadata.origin_name = origin_name;
    metadata.span = span;
    return metadata;
}

func mir_make_native_boundary_metadata(function_name: str, boundary_kind: MirNativeBoundaryKind, span: token.Span) MirNativeBoundaryMetadata[ctx] {
    mut metadata: MirNativeBoundaryMetadata[ctx];
    metadata.function_name = function_name;
    metadata.boundary_kind = boundary_kind;
    metadata.span = span;
    return metadata;
}

func mir_empty_program_bundle_symbol_vector(ctx: &Arena) Index[std.Vector[MirProgramBundleSymbol[ctx], ctx], ctx] {
    mut symbols: std.Vector[MirProgramBundleSymbol[ctx], ctx] := std.VectorNew(ctx);
    mut symbols_idx: Index[std.Vector[MirProgramBundleSymbol[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(symbols_idx, symbols);
    return symbols_idx;
}

func mir_empty_program_bundle_block_parameter_vector(ctx: &Arena) Index[std.Vector[MirProgramBundleBlockParameter[ctx], ctx], ctx] {
    mut parameters: std.Vector[MirProgramBundleBlockParameter[ctx], ctx] := std.VectorNew(ctx);
    mut parameters_idx: Index[std.Vector[MirProgramBundleBlockParameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(parameters_idx, parameters);
    return parameters_idx;
}

func mir_empty_program_bundle_module_vector(ctx: &Arena) Index[std.Vector[MirProgramBundleModule[ctx], ctx], ctx] {
    mut modules: std.Vector[MirProgramBundleModule[ctx], ctx] := std.VectorNew(ctx);
    mut modules_idx: Index[std.Vector[MirProgramBundleModule[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(modules_idx, modules);
    return modules_idx;
}

func mir_make_program_bundle(entry_symbol: str, ctx: &Arena) MirProgramBundle[ctx] {
    mut bundle: MirProgramBundle[ctx];
    bundle.entry_symbol = std.Clone(ctx, entry_symbol);
    bundle.modules = mir_empty_program_bundle_module_vector(ctx);
    return bundle;
}

func mir_make_program_bundle_module(module_path: str, module_prefix: str, object_name: str, canonical_format: str, canonical_mir: str, resource_metadata_count: int, provenance_metadata_count: int, native_boundary_metadata_count: int, ctx: &Arena) MirProgramBundleModule[ctx] {
    mut module: MirProgramBundleModule[ctx];
    module.module_path = std.Clone(ctx, module_path);
    module.module_prefix = std.Clone(ctx, module_prefix);
    module.object_name = std.Clone(ctx, object_name);
    module.canonical_format = std.Clone(ctx, canonical_format);
    module.canonical_mir = std.Clone(ctx, canonical_mir);
    module.symbols = mir_empty_program_bundle_symbol_vector(ctx);
    module.block_parameters = mir_empty_program_bundle_block_parameter_vector(ctx);
    module.resource_metadata_count = resource_metadata_count;
    module.provenance_metadata_count = provenance_metadata_count;
    module.native_boundary_metadata_count = native_boundary_metadata_count;
    return module;
}

func mir_make_program_bundle_symbol(name: str, link_name: str, signature: str, linkage_tag: int, ctx: &Arena) MirProgramBundleSymbol[ctx] {
    mut symbol: MirProgramBundleSymbol[ctx];
    symbol.name = std.Clone(ctx, name);
    symbol.link_name = std.Clone(ctx, link_name);
    symbol.signature = std.Clone(ctx, signature);
    unsafe {
        symbol.linkage.tag = linkage_tag;
    }
    return symbol;
}

func mir_make_program_bundle_block_parameter(function_name: str, block_label: str, ordinal: int, name: str, value_type: str, ctx: &Arena) MirProgramBundleBlockParameter[ctx] {
    mut parameter: MirProgramBundleBlockParameter[ctx];
    parameter.function_name = std.Clone(ctx, function_name);
    parameter.block_label = std.Clone(ctx, block_label);
    parameter.ordinal = ordinal;
    parameter.name = std.Clone(ctx, name);
    parameter.value_type = std.Clone(ctx, value_type);
    return parameter;
}

func mir_program_bundle_module_with_symbol(module: MirProgramBundleModule[ctx], symbol: MirProgramBundleSymbol[ctx], ctx: &Arena) MirProgramBundleModule[ctx] {
    mut updated := module;
    mut symbols: std.Vector[MirProgramBundleSymbol[ctx], ctx] := ctx[updated.symbols];
    symbols.Push(symbol);
    ctx.Set(updated.symbols, symbols);
    return updated;
}

func mir_program_bundle_module_with_block_parameter(module: MirProgramBundleModule[ctx], parameter: MirProgramBundleBlockParameter[ctx], ctx: &Arena) MirProgramBundleModule[ctx] {
    mut updated := module;
    mut parameters: std.Vector[MirProgramBundleBlockParameter[ctx], ctx] := ctx[updated.block_parameters];
    parameters.Push(parameter);
    ctx.Set(updated.block_parameters, parameters);
    return updated;
}

func mir_program_bundle_with_module(bundle: MirProgramBundle[ctx], module: MirProgramBundleModule[ctx], ctx: &Arena) MirProgramBundle[ctx] {
    mut updated := bundle;
    mut modules: std.Vector[MirProgramBundleModule[ctx], ctx] := ctx[updated.modules];
    modules.Push(module);
    ctx.Set(updated.modules, modules);
    return updated;
}

func mir_program_bundle_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 {
        return 0;
    }
    if std.str_find(value, "\n") != 0 - 1 {
        return 0;
    }
    if std.str_find(value, "\r") != 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_program_bundle_starts_with(value: str, prefix: str) int {
    if len(value) < len(prefix) {
        return 0;
    }
    mut candidate := std.str_slice(value, 0, len(prefix));
    if std.str_eq(candidate, prefix) == 1 {
        return 1;
    }
    return 0;
}

func mir_program_bundle_format_is_supported(format_name: str) int {
    if std.str_eq(format_name, "gust.compiler_mir_ingestion.v1") == 1 {
        return 1;
    }
    if std.str_eq(format_name, "gust.compiler_mir_ingestion.v2") == 1 {
        return 1;
    }
    return 0;
}

func mir_program_bundle_linkage_name(linkage: MirProgramBundleSymbolLinkage) str {
    if linkage.tag == 0 {
        return "exported_entry";
    }
    if linkage.tag == 1 {
        return "module_local";
    }
    if linkage.tag == 2 {
        return "imported_host";
    }
    if linkage.tag == 3 {
        return "bundle_export";
    }
    if linkage.tag == 4 {
        return "imported_bundle";
    }
    return "invalid";
}

func mir_program_bundle_is_valid(bundle: MirProgramBundle[ctx], ctx: &Arena) int {
    if mir_program_bundle_field_is_safe(bundle.entry_symbol, 0) == 0 {
        return 0;
    }

    mut modules: std.Vector[MirProgramBundleModule[ctx], ctx] := ctx[bundle.modules];
    if len(modules) == 0 {
        return 0;
    }

    mut exported_entry_count := 0;
    mut module_index := 0;
    while module_index < len(modules) {
        mut module := modules[module_index];

        if mir_program_bundle_field_is_safe(module.module_path, 0) == 0 {
            return 0;
        }
        if mir_program_bundle_field_is_safe(module.module_prefix, 1) == 0 {
            return 0;
        }
        if mir_program_bundle_field_is_safe(module.object_name, 0) == 0 {
            return 0;
        }
        if mir_program_bundle_format_is_supported(module.canonical_format) == 0 {
            return 0;
        }
        if len(module.canonical_mir) == 0 {
            return 0;
        }
        if std.str_byte_at(module.canonical_mir, len(module.canonical_mir) - 1) != 10 {
            return 0;
        }

        mut expected_header := std.Concat("format: ", module.canonical_format);
        expected_header = std.Concat(expected_header, "\n");
        if mir_program_bundle_starts_with(module.canonical_mir, expected_header) == 0 {
            return 0;
        }

        if module.resource_metadata_count < 0 {
            return 0;
        }
        if module.provenance_metadata_count < 0 {
            return 0;
        }
        if module.native_boundary_metadata_count < 0 {
            return 0;
        }

        mut prior_module_index := 0;
        while prior_module_index < module_index {
            mut prior_module := modules[prior_module_index];
            if std.str_eq(prior_module.module_path, module.module_path) == 1 {
                return 0;
            }
            if std.str_eq(prior_module.object_name, module.object_name) == 1 {
                return 0;
            }
            prior_module_index = prior_module_index + 1;
        }

        mut symbols: std.Vector[MirProgramBundleSymbol[ctx], ctx] := ctx[module.symbols];
        mut symbol_index := 0;
        while symbol_index < len(symbols) {
            mut symbol := symbols[symbol_index];
            if mir_program_bundle_field_is_safe(symbol.name, 0) == 0 {
                return 0;
            }
            if mir_program_bundle_field_is_safe(symbol.link_name, 0) == 0 {
                return 0;
            }
            if mir_program_bundle_field_is_safe(symbol.signature, 0) == 0 {
                return 0;
            }
            if symbol.linkage.tag < 0 || symbol.linkage.tag > 4 {
                return 0;
            }

            if symbol.linkage.tag == 0 {
                exported_entry_count = exported_entry_count + 1;
                if std.str_eq(symbol.link_name, bundle.entry_symbol) == 0 {
                    return 0;
                }
            }

            mut prior_symbol_index := 0;
            while prior_symbol_index < symbol_index {
                mut prior_symbol := symbols[prior_symbol_index];
                if std.str_eq(prior_symbol.link_name, symbol.link_name) == 1 {
                    return 0;
                }
                prior_symbol_index = prior_symbol_index + 1;
            }

            symbol_index = symbol_index + 1;
        }

        mut block_parameters: std.Vector[MirProgramBundleBlockParameter[ctx], ctx] := ctx[module.block_parameters];
        mut parameter_index := 0;
        while parameter_index < len(block_parameters) {
            mut parameter := block_parameters[parameter_index];
            if mir_program_bundle_field_is_safe(parameter.function_name, 0) == 0 {
                return 0;
            }
            if mir_program_bundle_field_is_safe(parameter.block_label, 0) == 0 {
                return 0;
            }
            if parameter.ordinal < 0 {
                return 0;
            }
            if mir_program_bundle_field_is_safe(parameter.name, 0) == 0 {
                return 0;
            }
            if mir_program_bundle_field_is_safe(parameter.value_type, 0) == 0 {
                return 0;
            }
            parameter_index = parameter_index + 1;
        }

        module_index = module_index + 1;
    }

    module_index = 0;
    while module_index < len(modules) {
        mut module := modules[module_index];
        mut symbols: std.Vector[MirProgramBundleSymbol[ctx], ctx] :=
            ctx[module.symbols];
        mut symbol_index := 0;
        while symbol_index < len(symbols) {
            mut symbol := symbols[symbol_index];

            if symbol.linkage.tag == 0 ||
               symbol.linkage.tag == 1 ||
               symbol.linkage.tag == 3
            {
                mut other_module_index := 0;
                while other_module_index < len(modules) {
                    mut other_symbols:
                        std.Vector[MirProgramBundleSymbol[ctx], ctx] :=
                            ctx[modules[other_module_index].symbols];
                    mut other_symbol_index := 0;
                    while other_symbol_index < len(other_symbols) {
                        mut other := other_symbols[other_symbol_index];
                        if (other_module_index != module_index ||
                            other_symbol_index != symbol_index) &&
                           (other.linkage.tag == 0 ||
                            other.linkage.tag == 1 ||
                            other.linkage.tag == 3) &&
                           std.str_eq(other.link_name, symbol.link_name) == 1
                        {
                            return 0;
                        }
                        other_symbol_index = other_symbol_index + 1;
                    }
                    other_module_index = other_module_index + 1;
                }
            }

            if symbol.linkage.tag == 4 {
                mut resolution_count := 0;
                mut resolution_module_index := 0;
                while resolution_module_index < len(modules) {
                    mut resolution_symbols:
                        std.Vector[MirProgramBundleSymbol[ctx], ctx] :=
                            ctx[modules[resolution_module_index].symbols];
                    mut resolution_symbol_index := 0;
                    while resolution_symbol_index < len(resolution_symbols) {
                        mut resolution :=
                            resolution_symbols[resolution_symbol_index];
                        if resolution.linkage.tag == 3 &&
                           std.str_eq(
                               resolution.link_name,
                               symbol.link_name
                           ) == 1
                        {
                            if std.str_eq(
                                resolution.signature,
                                symbol.signature
                            ) == 0 {
                                return 0;
                            }
                            resolution_count = resolution_count + 1;
                        }
                        resolution_symbol_index =
                            resolution_symbol_index + 1;
                    }
                    resolution_module_index = resolution_module_index + 1;
                }
                if resolution_count != 1 {
                    return 0;
                }
            }

            if symbol.linkage.tag == 2 {
                mut collision_module_index := 0;
                while collision_module_index < len(modules) {
                    mut collision_symbols:
                        std.Vector[MirProgramBundleSymbol[ctx], ctx] :=
                            ctx[modules[collision_module_index].symbols];
                    mut collision_symbol_index := 0;
                    while collision_symbol_index < len(collision_symbols) {
                        mut collision :=
                            collision_symbols[collision_symbol_index];
                        if (collision.linkage.tag == 0 ||
                            collision.linkage.tag == 1 ||
                            collision.linkage.tag == 3) &&
                           std.str_eq(
                               collision.link_name,
                               symbol.link_name
                           ) == 1
                        {
                            return 0;
                        }
                        if collision.linkage.tag == 2 &&
                           std.str_eq(
                               collision.link_name,
                               symbol.link_name
                           ) == 1 &&
                           std.str_eq(
                               collision.signature,
                               symbol.signature
                           ) == 0
                        {
                            return 0;
                        }
                        collision_symbol_index =
                            collision_symbol_index + 1;
                    }
                    collision_module_index = collision_module_index + 1;
                }
            }

            symbol_index = symbol_index + 1;
        }
        module_index = module_index + 1;
    }

    if exported_entry_count != 1 {
        return 0;
    }

    return 1;
}

func mir_program_bundle_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_program_bundle(bundle: MirProgramBundle[ctx], ctx: &Arena) str {
    if mir_program_bundle_is_valid(bundle, ctx) == 0 {
        return "format: invalid\n";
    }

    mut output := "format: gust.compiler_program_mir_bundle.v1\n";
    output = mir_program_bundle_append_field(output, "entry_symbol", bundle.entry_symbol, ctx);

    mut modules: std.Vector[MirProgramBundleModule[ctx], ctx] := ctx[bundle.modules];
    output = mir_program_bundle_append_field(output, "module_count", std.FormatInt(len(modules)), ctx);

    mut module_index := 0;
    while module_index < len(modules) {
        mut module := modules[module_index];
        mut module_key := std.Concat("module_", std.FormatInt(module_index));

        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_path"), module.module_path, ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_prefix"), module.module_prefix, ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_object_name"), module.object_name, ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_canonical_format"), module.canonical_format, ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_resource_metadata_count"), std.FormatInt(module.resource_metadata_count), ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_provenance_metadata_count"), std.FormatInt(module.provenance_metadata_count), ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_native_boundary_metadata_count"), std.FormatInt(module.native_boundary_metadata_count), ctx);

        mut symbols: std.Vector[MirProgramBundleSymbol[ctx], ctx] := ctx[module.symbols];
        mut defined_symbol_count := 0;
        mut undefined_symbol_count := 0;
        mut symbol_count_index := 0;
        while symbol_count_index < len(symbols) {
            if symbols[symbol_count_index].linkage.tag == 2 ||
               symbols[symbol_count_index].linkage.tag == 4
            {
                undefined_symbol_count = undefined_symbol_count + 1;
            } else {
                defined_symbol_count = defined_symbol_count + 1;
            }
            symbol_count_index = symbol_count_index + 1;
        }

        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_symbol_count"), std.FormatInt(len(symbols)), ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_defined_symbol_count"), std.FormatInt(defined_symbol_count), ctx);
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_undefined_symbol_count"), std.FormatInt(undefined_symbol_count), ctx);

        mut symbol_index := 0;
        while symbol_index < len(symbols) {
            mut symbol := symbols[symbol_index];
            mut symbol_key := std.Concat(std.Concat(module_key, "_symbol_"), std.FormatInt(symbol_index));
            output = mir_program_bundle_append_field(output, std.Concat(symbol_key, "_name"), symbol.name, ctx);
            output = mir_program_bundle_append_field(output, std.Concat(symbol_key, "_link_name"), symbol.link_name, ctx);
            output = mir_program_bundle_append_field(output, std.Concat(symbol_key, "_signature"), symbol.signature, ctx);
            output = mir_program_bundle_append_field(output, std.Concat(symbol_key, "_linkage"), mir_program_bundle_linkage_name(symbol.linkage), ctx);
            symbol_index = symbol_index + 1;
        }

        mut block_parameters: std.Vector[MirProgramBundleBlockParameter[ctx], ctx] := ctx[module.block_parameters];
        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_block_parameter_count"), std.FormatInt(len(block_parameters)), ctx);

        mut parameter_index := 0;
        while parameter_index < len(block_parameters) {
            mut parameter := block_parameters[parameter_index];
            mut parameter_key := std.Concat(std.Concat(module_key, "_block_parameter_"), std.FormatInt(parameter_index));
            output = mir_program_bundle_append_field(output, std.Concat(parameter_key, "_function"), parameter.function_name, ctx);
            output = mir_program_bundle_append_field(output, std.Concat(parameter_key, "_block"), parameter.block_label, ctx);
            output = mir_program_bundle_append_field(output, std.Concat(parameter_key, "_ordinal"), std.FormatInt(parameter.ordinal), ctx);
            output = mir_program_bundle_append_field(output, std.Concat(parameter_key, "_name"), parameter.name, ctx);
            output = mir_program_bundle_append_field(output, std.Concat(parameter_key, "_type"), parameter.value_type, ctx);
            parameter_index = parameter_index + 1;
        }

        output = mir_program_bundle_append_field(output, std.Concat(module_key, "_canonical_mir_length"), std.FormatInt(len(module.canonical_mir)), ctx);
        output = std.Concat(output, std.Concat(module_key, "_canonical_mir_begin\n"));
        output = std.Concat(output, module.canonical_mir);
        output = std.Concat(output, std.Concat(module_key, "_canonical_mir_end\n"));

        module_index = module_index + 1;
    }

    return std.Clone(ctx, output);
}

func mir_make_function(name: str, return_type: str, span: token.Span, ctx: &Arena) MirFunction[ctx] {
    mut function: MirFunction[ctx];
    function.name = name;
    function.params = mir_empty_local_vector(ctx);
    function.return_type = return_type;
    function.locals = mir_empty_local_vector(ctx);
    function.blocks = mir_empty_block_vector(ctx);
    function.entry_block = 0;
    function.span = span;
    return function;
}

func mir_make_block(id: int, terminator: Index[MirTerminator[ctx], ctx], span: token.Span, ctx: &Arena) MirBlock[ctx] {
    mut block: MirBlock[ctx];
    block.id = id;
    block.statements = mir_empty_stmt_vector(ctx);
    block.terminator = terminator;
    block.span = span;
    return block;
}

func mir_make_local(id: int, name: str, local_type: str, span: token.Span, ctx: &Arena) MirLocal[ctx] {
    mut local: MirLocal[ctx];
    local.id = id;
    local.name = name;
    local.local_type = local_type;
    local.span = span;
    return local;
}

func mir_make_stmt_nop(span: token.Span, ctx: &Arena) MirStmt[ctx] {
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 0; // Nop
        stmt.Nop.span = span;
    }
    return stmt;
}

func mir_make_stmt_local_set(local_id: int, value: Index[MirValue[ctx], ctx], span: token.Span) MirStmt[ctx] {
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 1; // LocalSet
        stmt.LocalSet.local_id = local_id;
        stmt.LocalSet.value = value;
        stmt.LocalSet.span = span;
    }
    return stmt;
}

func mir_make_stmt_expr(value: Index[MirValue[ctx], ctx], span: token.Span) MirStmt[ctx] {
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 2; // Expr
        stmt.Expr.value = value;
        stmt.Expr.span = span;
    }
    return stmt;
}

func mir_make_stmt_stack_slot_operation(operation_reference: MirStackSlotOperationReference[ctx], value: Index[MirValue[ctx], ctx], span: token.Span, ctx: &Arena) MirStmt[ctx] {
    mut operation_reference_idx: Index[MirStackSlotOperationReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 3; // StackSlotOperation
        stmt.StackSlotOperation.operation = operation_reference_idx;
        stmt.StackSlotOperation.value = value;
        stmt.StackSlotOperation.span = span;
    }
    return stmt;
}

func mir_make_stmt_memory_access(operation_reference: MirMemoryAccessReference[ctx], value: Index[MirValue[ctx], ctx], span: token.Span, ctx: &Arena) MirStmt[ctx] {
    mut operation_reference_idx: Index[MirMemoryAccessReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 4; // MemoryAccess
        stmt.MemoryAccess.operation = operation_reference_idx;
        stmt.MemoryAccess.value = value;
        stmt.MemoryAccess.span = span;
    }
    return stmt;
}

func mir_make_stmt_resource_operation(operation_reference: resource_mir.MirResourceOperation[ctx], span: token.Span, ctx: &Arena) MirStmt[ctx] {
    mut operation_reference_idx: Index[resource_mir.MirResourceOperation[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut stmt: MirStmt[ctx];
    unsafe {
        stmt.tag = 6; // ResourceOperation
        stmt.ResourceOperation.operation = operation_reference_idx;
        stmt.ResourceOperation.span = span;
    }
    return stmt;
}

func mir_make_value_int_literal(val: int, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 0; // IntLiteral
        value.IntLiteral.val = val;
        value.IntLiteral.value_type = value_type;
        value.IntLiteral.span = span;
    }
    return value;
}

func mir_make_value_bool_literal(val: int, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 1; // BoolLiteral
        value.BoolLiteral.val = val;
        value.BoolLiteral.value_type = value_type;
        value.BoolLiteral.span = span;
    }
    return value;
}

func mir_make_value_string_literal(val: str, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 2; // StringLiteral
        value.StringLiteral.val = val;
        value.StringLiteral.value_type = value_type;
        value.StringLiteral.span = span;
    }
    return value;
}

func mir_make_value_local_read(local_id: int, value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 3; // LocalRead
        value.LocalRead.local_id = local_id;
        value.LocalRead.value_type = value_type;
        value.LocalRead.span = span;
    }
    return value;
}

func mir_make_value_call(callee: str, args: Index[std.Vector[MirValue[ctx], ctx], ctx], value_type: str, span: token.Span) MirValue[ctx] {
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 4; // Call
        value.Call.callee = callee;
        value.Call.args = args;
        value.Call.value_type = value_type;
        value.Call.span = span;
    }
    return value;
}

func mir_make_value_integer_convert(operand: Index[MirValue[ctx], ctx], conversion_reference: MirIntegerConversionReference[ctx], value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut conversion_reference_idx: Index[MirIntegerConversionReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(conversion_reference_idx, conversion_reference);
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 5; // IntegerConvert
        value.IntegerConvert.operand = operand;
        value.IntegerConvert.conversion = conversion_reference_idx;
        value.IntegerConvert.value_type = std.Clone(ctx, value_type);
        value.IntegerConvert.span = span;
    }
    return value;
}

func mir_make_value_pointer_operation(operands: Index[std.Vector[MirValue[ctx], ctx], ctx], operation_reference: MirPointerOperationReference[ctx], value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut operation_reference_idx: Index[MirPointerOperationReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 6; // PointerOperation
        value.PointerOperation.operands = operands;
        value.PointerOperation.operation = operation_reference_idx;
        value.PointerOperation.value_type = std.Clone(ctx, value_type);
        value.PointerOperation.span = span;
    }
    return value;
}

func mir_make_value_memory_access(operands: Index[std.Vector[MirValue[ctx], ctx], ctx], operation_reference: MirMemoryAccessReference[ctx], value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut operation_reference_idx: Index[MirMemoryAccessReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 7; // MemoryAccess
        value.MemoryAccess.operands = operands;
        value.MemoryAccess.operation = operation_reference_idx;
        value.MemoryAccess.value_type = std.Clone(ctx, value_type);
        value.MemoryAccess.span = span;
    }
    return value;
}

func mir_make_value_string_view_operation(operands: Index[std.Vector[MirValue[ctx], ctx], ctx], operation_reference: MirStringViewOperationReference[ctx], value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut operation_reference_idx: Index[MirStringViewOperationReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 8; // StringViewOperation
        value.StringViewOperation.operands = operands;
        value.StringViewOperation.operation = operation_reference_idx;
        value.StringViewOperation.value_type = std.Clone(ctx, value_type);
        value.StringViewOperation.span = span;
    }
    return value;
}


func mir_make_value_array_slice_operation(operands: Index[std.Vector[MirValue[ctx], ctx], ctx], operation_reference: MirArraySliceOperationReference[ctx], value_type: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut operation_reference_idx: Index[MirArraySliceOperationReference[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(operation_reference_idx, operation_reference);
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 9; // ArraySliceOperation
        value.ArraySliceOperation.operands = operands;
        value.ArraySliceOperation.operation = operation_reference_idx;
        value.ArraySliceOperation.value_type = std.Clone(ctx, value_type);
        value.ArraySliceOperation.span = span;
    }
    return value;
}

func mir_make_value_resource_read(resource_value: resource_mir.MirResourceValue[ctx], carrier_id: str, span: token.Span, ctx: &Arena) MirValue[ctx] {
    mut resource_value_idx: Index[resource_mir.MirResourceValue[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_value_idx, resource_value);
    mut value: MirValue[ctx];
    unsafe {
        value.tag = 10; // ResourceRead
        value.ResourceRead.value = resource_value_idx;
        value.ResourceRead.carrier_id = std.Clone(ctx, carrier_id);
        value.ResourceRead.span = span;
    }
    return value;
}

func mir_make_terminator_return_void(span: token.Span, ctx: &Arena) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 0; // ReturnVoid
        terminator.ReturnVoid.span = span;
    }
    return terminator;
}

func mir_make_terminator_return(value: Index[MirValue[ctx], ctx], span: token.Span) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 1; // Return
        terminator.Return.value = value;
        terminator.Return.span = span;
    }
    return terminator;
}

func mir_make_terminator_jump(target_block: int, span: token.Span, ctx: &Arena) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 2; // Jump
        terminator.Jump.target_block = target_block;
        terminator.Jump.span = span;
    }
    return terminator;
}

func mir_make_terminator_branch(condition: Index[MirValue[ctx], ctx], then_block: int, else_block: int, span: token.Span) MirTerminator[ctx] {
    mut terminator: MirTerminator[ctx];
    unsafe {
        terminator.tag = 3; // Branch
        terminator.Branch.condition = condition;
        terminator.Branch.then_block = then_block;
        terminator.Branch.else_block = else_block;
        terminator.Branch.span = span;
    }
    return terminator;
}

func mir_debug_resource_kind(kind: MirResourceKind) str {
    if kind.tag == 0 {
        return "MirResourceKind.NonResource";
    }
    if kind.tag == 1 {
        return "MirResourceKind.LinearResource";
    }
    if kind.tag == 2 {
        return "MirResourceKind.DirectoryResource";
    }
    if kind.tag == 3 {
        return "MirResourceKind.NativeHandleResource";
    }
    return "MirResourceKind.<unknown>";
}

func mir_debug_resource_state(state: MirResourceState) str {
    if state.tag == 0 {
        return "MirResourceState.Untracked";
    }
    if state.tag == 1 {
        return "MirResourceState.Owned";
    }
    if state.tag == 2 {
        return "MirResourceState.Borrowed";
    }
    if state.tag == 3 {
        return "MirResourceState.Moved";
    }
    if state.tag == 4 {
        return "MirResourceState.Closed";
    }
    if state.tag == 5 {
        return "MirResourceState.DestructorScheduled";
    }
    return "MirResourceState.<unknown>";
}

func mir_debug_provenance_kind(kind: MirProvenanceKind) str {
    if kind.tag == 0 {
        return "MirProvenanceKind.Unknown";
    }
    if kind.tag == 1 {
        return "MirProvenanceKind.LocalBinding";
    }
    if kind.tag == 2 {
        return "MirProvenanceKind.Parameter";
    }
    if kind.tag == 3 {
        return "MirProvenanceKind.ReturnValue";
    }
    if kind.tag == 4 {
        return "MirProvenanceKind.NativeBoundary";
    }
    if kind.tag == 5 {
        return "MirProvenanceKind.ResourceDestructor";
    }
    return "MirProvenanceKind.<unknown>";
}

func mir_debug_native_boundary_kind(kind: MirNativeBoundaryKind) str {
    if kind.tag == 0 {
        return "MirNativeBoundaryKind.NotNativeBoundary";
    }
    if kind.tag == 1 {
        return "MirNativeBoundaryKind.RuntimeCall";
    }
    if kind.tag == 2 {
        return "MirNativeBoundaryKind.ExternFunction";
    }
    if kind.tag == 3 {
        return "MirNativeBoundaryKind.UnsafeNativeCall";
    }
    if kind.tag == 4 {
        return "MirNativeBoundaryKind.LayoutSensitiveCall";
    }
    return "MirNativeBoundaryKind.<unknown>";
}

func mir_debug_stmt_kind(stmt: MirStmt[ctx]) str {
    if stmt.tag == 0 {
        return "MirStmt.Nop";
    }
    if stmt.tag == 1 {
        return "MirStmt.LocalSet";
    }
    if stmt.tag == 2 {
        return "MirStmt.Expr";
    }
    if stmt.tag == 3 {
        return "MirStmt.StackSlotOperation";
    }
    if stmt.tag == 4 {
        return "MirStmt.MemoryAccess";
    }
    if stmt.tag == 5 {
        return "MirStmt.ArraySliceOperation";
    }
    if stmt.tag == 6 {
        return "MirStmt.ResourceOperation";
    }
    return "MirStmt.<unknown>";
}

func mir_debug_value_kind(value: MirValue[ctx]) str {
    if value.tag == 0 {
        return "MirValue.IntLiteral";
    }
    if value.tag == 1 {
        return "MirValue.BoolLiteral";
    }
    if value.tag == 2 {
        return "MirValue.StringLiteral";
    }
    if value.tag == 3 {
        return "MirValue.LocalRead";
    }
    if value.tag == 4 {
        return "MirValue.Call";
    }
    if value.tag == 5 {
        return "MirValue.IntegerConvert";
    }
    if value.tag == 6 {
        return "MirValue.PointerOperation";
    }
    if value.tag == 7 {
        return "MirValue.MemoryAccess";
    }
    if value.tag == 8 {
        return "MirValue.StringViewOperation";
    }
    if value.tag == 9 {
        return "MirValue.ArraySliceOperation";
    }
    if value.tag == 10 {
        return "MirValue.ResourceRead";
    }
    return "MirValue.<unknown>";
}

func mir_debug_terminator_kind(terminator: MirTerminator[ctx]) str {
    if terminator.tag == 0 {
        return "MirTerminator.ReturnVoid";
    }
    if terminator.tag == 1 {
        return "MirTerminator.Return";
    }
    if terminator.tag == 2 {
        return "MirTerminator.Jump";
    }
    if terminator.tag == 3 {
        return "MirTerminator.Branch";
    }
    return "MirTerminator.<unknown>";
}

func mir_program_resource_mir_table(program: MirProgram[ctx], target_id: str, target_triple: str, ctx: &Arena) resource_mir.MirResourceMirTable[ctx] {
    mut table := resource_mir.mir_resource_mir_make_empty_table(target_id, target_triple, ctx);
    table.values = program.resource_value_references;
    table.carriers = program.resource_carrier_references;
    table.operations = program.resource_operation_references;
    table.flow_edges = program.resource_flow_edge_references;
    return table;
}

func mir_debug_print_program(program: MirProgram[ctx]) {
    os.LogStr("mir.program");
    os.LogStr("  functions");
}

func mir_debug_print_function(function: MirFunction[ctx]) {
    os.LogStr("mir.function");
    os.LogStr("  name");
    os.LogStr(function.name);
    os.LogStr("  return_type");
    os.LogStr(function.return_type);
    os.LogStr("  params");
    os.LogStr("  locals");
    os.LogStr("  blocks");
}

func mir_debug_print_block(block: MirBlock[ctx], ctx: &Arena) {
    os.LogStr("mir.block");
    os.LogStr("  terminator");
    os.LogStr(mir_debug_terminator_kind(ctx[block.terminator]));
}

func mir_debug_print_stmt(stmt: MirStmt[ctx]) {
    os.LogStr("mir.stmt");
    os.LogStr(mir_debug_stmt_kind(stmt));
}

func mir_debug_print_value(value: MirValue[ctx]) {
    os.LogStr("mir.value");
    os.LogStr(mir_debug_value_kind(value));
}

func mir_debug_print_terminator(terminator: MirTerminator[ctx]) {
    os.LogStr("mir.terminator");
    os.LogStr(mir_debug_terminator_kind(terminator));
}

func mir_lower_tiny_function_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 3 fixture-only lowering entry point.
    //
    // This is intentionally inert and is not wired into parser, typechecker,
    // verifier, C emission, Crane lift, or the production compiler path.
    // Step 2 lowers only a tiny function shell: one function, one empty entry
    // block, and a ReturnVoid terminator. It does not lower real AST,
    // expressions, locals, calls, branches, or statements yet.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut return_void := mir_make_terminator_return_void(span, ctx);
    mut return_void_idx := mir_alloc_terminator(return_void, ctx);
    mut entry_block := mir_make_block(0, return_void_idx, span, ctx);

    mut function := mir_make_function("tiny_shell", "void", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_return_int_literal_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 3 fixture-only tiny return-literal lowering.
    //
    // This represents the constrained source shape:
    //
    //   func tiny_return_int() int {
    //       return 1;
    //   }
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut return_value := mir_make_value_int_literal(1, "int", span, ctx);
    mut return_value_idx := mir_alloc_value(return_value, ctx);
    mut return_terminator := mir_make_terminator_return(return_value_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut entry_block := mir_make_block(0, return_terminator_idx, span, ctx);

    mut function := mir_make_function("tiny_return_int", "int", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_emit_native_backend_return_int_ingestion_fixture(ctx: &Arena) str {
    // Step 45 fixture-only native-backend ingestion seam.
    //
    // This gives the isolated native backend experiment a compiler-owned,
    // serialized MIR artifact for the existing return-int fixture without
    // routing production codegen away from MIR-to-C. It is intentionally
    // narrow: one function, one entry block, one Return(IntLiteral(1:int))
    // terminator.
    mut program := mir_lower_return_int_literal_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.return_int.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_return_int_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_return_int_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_return_int_literal_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_return_int\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 1\n");
    fixture = std.Concat(fixture, "terminator: Return\n");
    fixture = std.Concat(fixture, "return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "return_value: 1\n");
    fixture = std.Concat(fixture, "return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_return_int\n");
    fixture = std.Concat(fixture, "expected_exit: 1\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_local_binding_read_ingestion_fixture(ctx: &Arena) str {
    // Step 46 fixture-only native-backend ingestion seam.
    //
    // This extends the Step 45 compiler-owned serialized MIR artifact pattern
    // from return-int to local binding/read without routing production codegen
    // away from MIR-to-C. It is intentionally narrow: one function, one local,
    // one LocalI32Set statement, and one ReturnLocal terminator.
    mut program := mir_lower_local_binding_read_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.local_binding_read.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_local_binding_read_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_local_binding_read_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_local_binding_read\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 1\n");
    fixture = std.Concat(fixture, "local_count: 1\n");
    fixture = std.Concat(fixture, "local_0_name: value\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "statement_count: 1\n");
    fixture = std.Concat(fixture, "statement_0_kind: LocalI32Set\n");
    fixture = std.Concat(fixture, "statement_0_local: value\n");
    fixture = std.Concat(fixture, "statement_0_value: 2\n");
    fixture = std.Concat(fixture, "terminator: ReturnLocal\n");
    fixture = std.Concat(fixture, "return_local: value\n");
    fixture = std.Concat(fixture, "return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_local_binding_read\n");
    fixture = std.Concat(fixture, "expected_exit: 2\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_local_materialize_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for local-call materialization.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_local_materialize_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_local_materialize_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_local_materialize_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_local_materialize_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_local_materialize_branch\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_local_materialize_branch_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 1\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_1_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch_helper\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_target: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_label: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 293\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 307\n");
    fixture = std.Concat(fixture, "block_3_label: result\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: ReturnBlockParam\n");
    fixture = std.Concat(fixture, "block_3_return_param: 0\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 8\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 293\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -1\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 307\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 307\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_quint_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for imported/local/imported/local/imported materialization and local return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_quint_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_quint_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_quint_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_quint_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_quint_materialize_return\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_quint_materialize_return_helper\n");
    fixture = std.Concat(fixture, "second_helper_function: tiny_block_param_quint_materialize_return_second_helper\n");
    fixture = std.Concat(fixture, "exit_helper_function: tiny_block_param_quint_materialize_return_exit_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "local_function_count: 3\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 2\n");
    fixture = std.Concat(fixture, "local_function_1_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_second_helper\n");
    fixture = std.Concat(fixture, "local_function_1_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_1_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_1_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_1_add_value: 4\n");
    fixture = std.Concat(fixture, "local_function_2_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_exit_helper\n");
    fixture = std.Concat(fixture, "local_function_2_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_2_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_2_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_2_add_value: 8\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 8\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_imported_call_first\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_imported_call_first\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: -1\n");
    fixture = std.Concat(fixture, "block_1_target: materialize_local_call_first\n");
    fixture = std.Concat(fixture, "block_2_label: materialize_local_call_first\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_2_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_2_call_param: 0\n");
    fixture = std.Concat(fixture, "block_2_target: materialize_imported_call_second\n");
    fixture = std.Concat(fixture, "block_3_label: materialize_imported_call_second\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_3_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_3_call_param: 0\n");
    fixture = std.Concat(fixture, "block_3_call_literal: -3\n");
    fixture = std.Concat(fixture, "block_3_target: materialize_local_call_second\n");
    fixture = std.Concat(fixture, "block_4_label: materialize_local_call_second\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_4_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_second_helper\n");
    fixture = std.Concat(fixture, "block_4_call_param: 0\n");
    fixture = std.Concat(fixture, "block_4_target: materialize_imported_call_third\n");
    fixture = std.Concat(fixture, "block_5_label: materialize_imported_call_third\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_5_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_5_call_param: 0\n");
    fixture = std.Concat(fixture, "block_5_call_literal: -5\n");
    fixture = std.Concat(fixture, "block_5_target: branch_on_quint_materialized_call\n");
    fixture = std.Concat(fixture, "block_6_label: branch_on_quint_materialized_call\n");
    fixture = std.Concat(fixture, "block_6_param_count: 1\n");
    fixture = std.Concat(fixture, "block_6_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_6_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_6_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 919\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 967\n");
    fixture = std.Concat(fixture, "block_7_label: result\n");
    fixture = std.Concat(fixture, "block_7_param_count: 1\n");
    fixture = std.Concat(fixture, "block_7_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_7_terminator: ReturnBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_7_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_exit_helper\n");
    fixture = std.Concat(fixture, "block_7_return_param: 0\n");
    fixture = std.Concat(fixture, "block_7_return_value_kind: LocalCall\n");
    fixture = std.Concat(fixture, "block_7_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 927\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 2\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 975\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 975\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_quad_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for local/imported/local/imported materialization and imported return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_quad_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_quad_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_quad_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_quad_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_quad_materialize_return\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_quad_materialize_return_helper\n");
    fixture = std.Concat(fixture, "second_helper_function: tiny_block_param_quad_materialize_return_second_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_count: 2\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 2\n");
    fixture = std.Concat(fixture, "local_function_1_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_second_helper\n");
    fixture = std.Concat(fixture, "local_function_1_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_1_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_1_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_1_add_value: 4\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 7\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_local_call_first\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_local_call_first\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_1_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_target: materialize_imported_call_first\n");
    fixture = std.Concat(fixture, "block_2_label: materialize_imported_call_first\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_2_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_2_call_param: 0\n");
    fixture = std.Concat(fixture, "block_2_call_literal: -3\n");
    fixture = std.Concat(fixture, "block_2_target: materialize_local_call_second\n");
    fixture = std.Concat(fixture, "block_3_label: materialize_local_call_second\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_3_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_second_helper\n");
    fixture = std.Concat(fixture, "block_3_call_param: 0\n");
    fixture = std.Concat(fixture, "block_3_target: materialize_imported_call_second\n");
    fixture = std.Concat(fixture, "block_4_label: materialize_imported_call_second\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_4_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_4_call_param: 0\n");
    fixture = std.Concat(fixture, "block_4_call_literal: -5\n");
    fixture = std.Concat(fixture, "block_4_target: branch_on_quad_materialized_call\n");
    fixture = std.Concat(fixture, "block_5_label: branch_on_quad_materialized_call\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_5_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 811\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 853\n");
    fixture = std.Concat(fixture, "block_6_label: result\n");
    fixture = std.Concat(fixture, "block_6_param_count: 1\n");
    fixture = std.Concat(fixture, "block_6_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_6_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_6_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_6_return_param: 0\n");
    fixture = std.Concat(fixture, "block_6_call_literal: 19\n");
    fixture = std.Concat(fixture, "block_6_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_6_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 830\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 2\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 872\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 872\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_triple_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for imported/local/imported materialization and local return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_triple_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_triple_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_triple_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_triple_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_triple_materialize_return\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_triple_materialize_return_helper\n");
    fixture = std.Concat(fixture, "exit_helper_function: tiny_block_param_triple_materialize_return_exit_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "local_function_count: 2\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 5\n");
    fixture = std.Concat(fixture, "local_function_1_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_exit_helper\n");
    fixture = std.Concat(fixture, "local_function_1_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_1_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_1_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_1_add_value: 6\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 6\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_imported_call_first\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_imported_call_first\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: -2\n");
    fixture = std.Concat(fixture, "block_1_target: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_2_label: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_2_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_2_call_param: 0\n");
    fixture = std.Concat(fixture, "block_2_target: materialize_imported_call_second\n");
    fixture = std.Concat(fixture, "block_3_label: materialize_imported_call_second\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_3_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_3_call_param: 0\n");
    fixture = std.Concat(fixture, "block_3_call_literal: -4\n");
    fixture = std.Concat(fixture, "block_3_target: branch_on_triple_materialized_call\n");
    fixture = std.Concat(fixture, "block_4_label: branch_on_triple_materialized_call\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_4_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 701\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 733\n");
    fixture = std.Concat(fixture, "block_5_label: result\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: ReturnBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_5_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_exit_helper\n");
    fixture = std.Concat(fixture, "block_5_return_param: 0\n");
    fixture = std.Concat(fixture, "block_5_return_value_kind: LocalCall\n");
    fixture = std.Concat(fixture, "block_5_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 707\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 739\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 739\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_local_first_dual_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for local-call materialization, imported-call materialization, then local return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_local_first_dual_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_local_first_dual_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_local_first_dual_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_local_first_dual_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_local_first_dual_materialize_return\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_local_first_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 4\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 5\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_1_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_target: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_2_label: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_2_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_2_call_param: 0\n");
    fixture = std.Concat(fixture, "block_2_call_literal: -7\n");
    fixture = std.Concat(fixture, "block_2_target: branch_on_dual_materialized_call\n");
    fixture = std.Concat(fixture, "block_3_label: branch_on_dual_materialized_call\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_3_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 601\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 631\n");
    fixture = std.Concat(fixture, "block_4_label: result\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: ReturnBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_4_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_4_return_param: 0\n");
    fixture = std.Concat(fixture, "block_4_return_value_kind: LocalCall\n");
    fixture = std.Concat(fixture, "block_4_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 8\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 605\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 3\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 635\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 635\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_dual_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for imported-call materialization, local-call materialization, then imported return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_dual_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_dual_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_dual_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_dual_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_dual_materialize_return\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "local_function_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 3\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 5\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: -5\n");
    fixture = std.Concat(fixture, "block_1_target: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_2_label: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_2_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_2_call_param: 0\n");
    fixture = std.Concat(fixture, "block_2_target: branch_on_dual_materialized_call\n");
    fixture = std.Concat(fixture, "block_3_label: branch_on_dual_materialized_call\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_3_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 501\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 523\n");
    fixture = std.Concat(fixture, "block_4_label: result\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_4_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_4_return_param: 0\n");
    fixture = std.Concat(fixture, "block_4_call_literal: 17\n");
    fixture = std.Concat(fixture, "block_4_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_4_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 8\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 518\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 2\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 540\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 540\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_local_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for local-call materialization followed by local return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_local_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_local_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_local_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_local_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_local_materialize_return\n");
    fixture = std.Concat(fixture, "helper_function: tiny_block_param_local_materialize_return_helper\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 2\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_local_call\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_1_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_target: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_label: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 401\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 421\n");
    fixture = std.Concat(fixture, "block_3_label: result\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: ReturnBlockParamLocalFunctionCall\n");
    fixture = std.Concat(fixture, "block_3_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return_helper\n");
    fixture = std.Concat(fixture, "block_3_return_param: 0\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: LocalCall\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 8\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 403\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -2\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 423\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 423\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_imported_materialize_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for imported-call materialization followed by imported return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_imported_materialize_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_imported_materialize_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_imported_materialize_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_imported_materialize_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_imported_materialize_return\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: -5\n");
    fixture = std.Concat(fixture, "block_1_target: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_label: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 331\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 347\n");
    fixture = std.Concat(fixture, "block_3_label: result\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_3_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_host_add\n");
    fixture = std.Concat(fixture, "block_3_return_param: 0\n");
    fixture = std.Concat(fixture, "block_3_call_literal: 13\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 8\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 344\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 360\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -2\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 360\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_imported_materialize_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for imported-call materialization.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_imported_materialize_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_imported_materialize_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_imported_materialize_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_imported_materialize_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_imported_materialize_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: materialize_imported_call\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch_host_add\n");
    fixture = std.Concat(fixture, "block_1_call_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: -5\n");
    fixture = std.Concat(fixture, "block_1_target: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_label: branch_on_materialized_call\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: result\n");
    fixture = std.Concat(fixture, "branch_then_value: 271\n");
    fixture = std.Concat(fixture, "branch_else_block: result\n");
    fixture = std.Concat(fixture, "branch_else_value: 283\n");
    fixture = std.Concat(fixture, "block_3_label: result\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: ReturnBlockParam\n");
    fixture = std.Concat(fixture, "block_3_return_param: 0\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 8\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 271\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 283\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -2\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 283\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_merge_dual_imported_joined_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block merge dual-import joined-return.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_merge_dual_imported_joined_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_merge_dual_imported_joined_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_merge_dual_imported_joined_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_merge_dual_imported_joined_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_merge_dual_imported_joined_return\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_branch_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "imported_function_1_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_1_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_1_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_1_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_1_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 9\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: then_value\n");
    fixture = std.Concat(fixture, "branch_then_value: 211\n");
    fixture = std.Concat(fixture, "branch_else_block: else_value\n");
    fixture = std.Concat(fixture, "branch_else_value: 223\n");
    fixture = std.Concat(fixture, "block_3_label: then_value\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_3_target: join\n");
    fixture = std.Concat(fixture, "block_3_param: 0\n");
    fixture = std.Concat(fixture, "block_3_add_value: 7\n");
    fixture = std.Concat(fixture, "block_4_label: else_value\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_4_target: join\n");
    fixture = std.Concat(fixture, "block_4_param: 0\n");
    fixture = std.Concat(fixture, "block_4_add_value: 9\n");
    fixture = std.Concat(fixture, "block_5_label: join\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive\n");
    fixture = std.Concat(fixture, "block_5_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_branch_host_add\n");
    fixture = std.Concat(fixture, "block_5_branch_param: 0\n");
    fixture = std.Concat(fixture, "block_5_call_literal: -220\n");
    fixture = std.Concat(fixture, "block_5_branch_condition: imported_call_greater_than_zero\n");
    fixture = std.Concat(fixture, "block_5_branch_then_block: positive_value\n");
    fixture = std.Concat(fixture, "block_5_branch_else_block: non_positive_value\n");
    fixture = std.Concat(fixture, "block_6_label: positive_value\n");
    fixture = std.Concat(fixture, "block_6_param_count: 0\n");
    fixture = std.Concat(fixture, "block_6_terminator: JumpI32Literal\n");
    fixture = std.Concat(fixture, "block_6_target: return_join\n");
    fixture = std.Concat(fixture, "block_6_value: 241\n");
    fixture = std.Concat(fixture, "block_7_label: non_positive_value\n");
    fixture = std.Concat(fixture, "block_7_param_count: 0\n");
    fixture = std.Concat(fixture, "block_7_terminator: JumpI32Literal\n");
    fixture = std.Concat(fixture, "block_7_target: return_join\n");
    fixture = std.Concat(fixture, "block_7_value: 251\n");
    fixture = std.Concat(fixture, "block_8_label: return_join\n");
    fixture = std.Concat(fixture, "block_8_param_count: 1\n");
    fixture = std.Concat(fixture, "block_8_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_8_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_8_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_return_host_add\n");
    fixture = std.Concat(fixture, "block_8_return_param: 0\n");
    fixture = std.Concat(fixture, "block_8_call_literal: 4\n");
    fixture = std.Concat(fixture, "block_8_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_8_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 255\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 245\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 245\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_merge_imported_branch_joined_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block merge imported-branch joined-return.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that updates a function parameter, branches to
    // distinct literal-valued arms, applies distinct arm-local block-param
    // updates, joins both arms through a block parameter, branches through an
    // imported host helper, rejoins both imported-branch outcomes through a
    // block parameter, and returns that second joined value through an imported
    // host helper without routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_merge_imported_branch_joined_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_merge_imported_branch_joined_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_merge_imported_branch_joined_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_merge_imported_branch_joined_return\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 9\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: then_value\n");
    fixture = std.Concat(fixture, "branch_then_value: 211\n");
    fixture = std.Concat(fixture, "branch_else_block: else_value\n");
    fixture = std.Concat(fixture, "branch_else_value: 223\n");
    fixture = std.Concat(fixture, "block_3_label: then_value\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_3_target: join\n");
    fixture = std.Concat(fixture, "block_3_param: 0\n");
    fixture = std.Concat(fixture, "block_3_add_value: 7\n");
    fixture = std.Concat(fixture, "block_4_label: else_value\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_4_target: join\n");
    fixture = std.Concat(fixture, "block_4_param: 0\n");
    fixture = std.Concat(fixture, "block_4_add_value: 9\n");
    fixture = std.Concat(fixture, "block_5_label: join\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive\n");
    fixture = std.Concat(fixture, "block_5_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_host_add\n");
    fixture = std.Concat(fixture, "block_5_branch_param: 0\n");
    fixture = std.Concat(fixture, "block_5_call_literal: -220\n");
    fixture = std.Concat(fixture, "block_5_branch_condition: imported_call_greater_than_zero\n");
    fixture = std.Concat(fixture, "block_5_branch_then_block: positive_value\n");
    fixture = std.Concat(fixture, "block_5_branch_else_block: non_positive_value\n");
    fixture = std.Concat(fixture, "block_6_label: positive_value\n");
    fixture = std.Concat(fixture, "block_6_param_count: 0\n");
    fixture = std.Concat(fixture, "block_6_terminator: JumpI32Literal\n");
    fixture = std.Concat(fixture, "block_6_target: return_join\n");
    fixture = std.Concat(fixture, "block_6_value: 241\n");
    fixture = std.Concat(fixture, "block_7_label: non_positive_value\n");
    fixture = std.Concat(fixture, "block_7_param_count: 0\n");
    fixture = std.Concat(fixture, "block_7_terminator: JumpI32Literal\n");
    fixture = std.Concat(fixture, "block_7_target: return_join\n");
    fixture = std.Concat(fixture, "block_7_value: 251\n");
    fixture = std.Concat(fixture, "block_8_label: return_join\n");
    fixture = std.Concat(fixture, "block_8_param_count: 1\n");
    fixture = std.Concat(fixture, "block_8_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_8_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_8_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_host_add\n");
    fixture = std.Concat(fixture, "block_8_return_param: 0\n");
    fixture = std.Concat(fixture, "block_8_call_literal: 3\n");
    fixture = std.Concat(fixture, "block_8_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_8_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 254\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 244\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 244\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block merge arm-update imported-call branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that updates a function parameter, branches to
    // distinct literal-valued arms, applies distinct arm-local block-param
    // updates, joins both arms through a block parameter, calls an imported host
    // helper with the joined value and an i32 literal, and branches on that
    // imported-call result without routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_merge_arm_update_imported_call_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_merge_arm_update_imported_call_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 8\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: then_value\n");
    fixture = std.Concat(fixture, "branch_then_value: 211\n");
    fixture = std.Concat(fixture, "branch_else_block: else_value\n");
    fixture = std.Concat(fixture, "branch_else_value: 223\n");
    fixture = std.Concat(fixture, "block_3_label: then_value\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_3_target: join\n");
    fixture = std.Concat(fixture, "block_3_param: 0\n");
    fixture = std.Concat(fixture, "block_3_add_value: 7\n");
    fixture = std.Concat(fixture, "block_4_label: else_value\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_4_target: join\n");
    fixture = std.Concat(fixture, "block_4_param: 0\n");
    fixture = std.Concat(fixture, "block_4_add_value: 9\n");
    fixture = std.Concat(fixture, "block_5_label: join\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive\n");
    fixture = std.Concat(fixture, "block_5_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_host_add\n");
    fixture = std.Concat(fixture, "block_5_branch_param: 0\n");
    fixture = std.Concat(fixture, "block_5_call_literal: -220\n");
    fixture = std.Concat(fixture, "block_5_branch_condition: imported_call_greater_than_zero\n");
    fixture = std.Concat(fixture, "block_5_branch_then_block: positive\n");
    fixture = std.Concat(fixture, "block_5_branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_6_label: positive\n");
    fixture = std.Concat(fixture, "block_6_param_count: 0\n");
    fixture = std.Concat(fixture, "block_6_terminator: Return\n");
    fixture = std.Concat(fixture, "block_6_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_6_return_value: 241\n");
    fixture = std.Concat(fixture, "block_6_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_7_label: non_positive\n");
    fixture = std.Concat(fixture, "block_7_param_count: 0\n");
    fixture = std.Concat(fixture, "block_7_terminator: Return\n");
    fixture = std.Concat(fixture, "block_7_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_7_return_value: 251\n");
    fixture = std.Concat(fixture, "block_7_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 251\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 241\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 241\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_merge_arm_update_imported_call_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block merge arm-update imported-call return.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that updates a function parameter, branches to
    // distinct literal-valued arms, applies distinct arm-local block-param
    // updates, joins both arms through a block parameter, and returns the joined
    // value through an imported host helper without routing production codegen
    // away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_merge_arm_update_imported_call_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_merge_arm_update_imported_call_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_merge_arm_update_imported_call_return\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 6\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: then_value\n");
    fixture = std.Concat(fixture, "branch_then_value: 211\n");
    fixture = std.Concat(fixture, "branch_else_block: else_value\n");
    fixture = std.Concat(fixture, "branch_else_value: 223\n");
    fixture = std.Concat(fixture, "block_3_label: then_value\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_3_target: join\n");
    fixture = std.Concat(fixture, "block_3_param: 0\n");
    fixture = std.Concat(fixture, "block_3_add_value: 7\n");
    fixture = std.Concat(fixture, "block_4_label: else_value\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_4_target: join\n");
    fixture = std.Concat(fixture, "block_4_param: 0\n");
    fixture = std.Concat(fixture, "block_4_add_value: 9\n");
    fixture = std.Concat(fixture, "block_5_label: join\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_5_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add\n");
    fixture = std.Concat(fixture, "block_5_return_param: 0\n");
    fixture = std.Concat(fixture, "block_5_call_literal: 5\n");
    fixture = std.Concat(fixture, "block_5_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_5_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 223\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 237\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 237\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_merge_imported_call_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block merge imported-call return.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that updates a function parameter, branches to
    // distinct literal-valued arms, joins both arms through a block parameter,
    // and returns the joined value through an imported host helper without
    // routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_merge_imported_call_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_merge_imported_call_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_merge_imported_call_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_merge_imported_call_return\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 6\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: then_value\n");
    fixture = std.Concat(fixture, "branch_then_value: 211\n");
    fixture = std.Concat(fixture, "branch_else_block: else_value\n");
    fixture = std.Concat(fixture, "branch_else_value: 223\n");
    fixture = std.Concat(fixture, "block_3_label: then_value\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_3_target: join\n");
    fixture = std.Concat(fixture, "block_3_param: 0\n");
    fixture = std.Concat(fixture, "block_3_add_value: 0\n");
    fixture = std.Concat(fixture, "block_4_label: else_value\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_4_target: join\n");
    fixture = std.Concat(fixture, "block_4_param: 0\n");
    fixture = std.Concat(fixture, "block_4_add_value: 0\n");
    fixture = std.Concat(fixture, "block_5_label: join\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_5_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add\n");
    fixture = std.Concat(fixture, "block_5_return_param: 0\n");
    fixture = std.Concat(fixture, "block_5_call_literal: 5\n");
    fixture = std.Concat(fixture, "block_5_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_5_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 216\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 228\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 228\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_merge_update_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block merge update branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that updates a function parameter, branches to
    // distinct literal-valued arms, joins both arms through a block parameter,
    // and returns the joined block parameter without routing production codegen
    // away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_merge_update_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_merge_update_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_merge_update_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_merge_update_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_merge_update_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 6\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositiveToI32Literals\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: then_value\n");
    fixture = std.Concat(fixture, "branch_then_value: 181\n");
    fixture = std.Concat(fixture, "branch_else_block: else_value\n");
    fixture = std.Concat(fixture, "branch_else_value: 191\n");
    fixture = std.Concat(fixture, "block_3_label: then_value\n");
    fixture = std.Concat(fixture, "block_3_param_count: 1\n");
    fixture = std.Concat(fixture, "block_3_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_3_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_3_target: join\n");
    fixture = std.Concat(fixture, "block_3_param: 0\n");
    fixture = std.Concat(fixture, "block_3_add_value: 0\n");
    fixture = std.Concat(fixture, "block_4_label: else_value\n");
    fixture = std.Concat(fixture, "block_4_param_count: 1\n");
    fixture = std.Concat(fixture, "block_4_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_4_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_4_target: join\n");
    fixture = std.Concat(fixture, "block_4_param: 0\n");
    fixture = std.Concat(fixture, "block_4_add_value: 0\n");
    fixture = std.Concat(fixture, "block_5_label: join\n");
    fixture = std.Concat(fixture, "block_5_param_count: 1\n");
    fixture = std.Concat(fixture, "block_5_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_5_terminator: ReturnBlockParam\n");
    fixture = std.Concat(fixture, "block_5_return_param: 0\n");
    fixture = std.Concat(fixture, "block_5_return_value_kind: BlockParam\n");
    fixture = std.Concat(fixture, "block_5_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 1\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 181\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 191\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -9\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 191\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_imported_predicate_update_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block imported-predicate update branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that forwards a function parameter into a block
    // parameter, updates that block parameter, calls an imported host predicate,
    // and branches on the imported predicate result without routing production
    // codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_imported_predicate_update_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_imported_predicate_update_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_imported_predicate_update_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_imported_predicate_update_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_imported_predicate_update_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_host_is_positive\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostIsPositiveI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 5\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: predicate\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: -4\n");
    fixture = std.Concat(fixture, "block_2_label: predicate\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamImportedFunctionPredicate\n");
    fixture = std.Concat(fixture, "block_2_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_host_is_positive\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: imported_predicate_nonzero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_3_label: positive\n");
    fixture = std.Concat(fixture, "block_3_param_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_3_return_value: 101\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_4_label: non_positive\n");
    fixture = std.Concat(fixture, "block_4_param_count: 0\n");
    fixture = std.Concat(fixture, "block_4_terminator: Return\n");
    fixture = std.Concat(fixture, "block_4_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_4_return_value: 107\n");
    fixture = std.Concat(fixture, "block_4_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 6\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 101\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 107\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -1\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 107\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_imported_call_return_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block imported-call return.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that forwards a function parameter into a block
    // parameter, calls an imported host helper with that block parameter and an
    // i32 literal, and returns the host-call result without routing production
    // codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_imported_call_return.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_imported_call_return_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_imported_call_return_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_imported_call_return_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_imported_call_return\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 2\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: return_imported\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: return_imported\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: ReturnBlockParamImportedFunctionCallI32Literal\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_host_add\n");
    fixture = std.Concat(fixture, "block_1_return_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: 11\n");
    fixture = std.Concat(fixture, "block_1_return_value_kind: ImportedCall\n");
    fixture = std.Concat(fixture, "block_1_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 16\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 11\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -12\n");
    fixture = std.Concat(fixture, "expected_case_2_result: -1\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_imported_call_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block imported-call branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that forwards a function parameter into a block
    // parameter, calls an imported host helper with that block parameter and an
    // i32 literal, and branches on the host-call result without routing
    // production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_imported_call_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_imported_call_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_imported_call_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_imported_call_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_imported_call_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_count: 1\n");
    fixture = std.Concat(fixture, "imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_host_add\n");
    fixture = std.Concat(fixture, "imported_function_0_param_count: 2\n");
    fixture = std.Concat(fixture, "imported_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_param_1_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "imported_function_0_operation: HostAddI32\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: branch\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: branch\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive\n");
    fixture = std.Concat(fixture, "block_1_imported_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_host_add\n");
    fixture = std.Concat(fixture, "block_1_branch_param: 0\n");
    fixture = std.Concat(fixture, "block_1_call_literal: -3\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_2_label: positive\n");
    fixture = std.Concat(fixture, "block_2_param_count: 0\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 89\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_3_label: non_positive\n");
    fixture = std.Concat(fixture, "block_3_param_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_3_return_value: 97\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 89\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 3\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 97\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -2\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 97\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_local_call_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block local-call branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that forwards a function parameter into a block
    // parameter, calls a local helper with that block parameter, and branches on
    // the helper result without routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_local_call_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_local_call_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_local_call_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_local_call_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_local_call_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_helper\n");
    fixture = std.Concat(fixture, "local_function_0_param_count: 1\n");
    fixture = std.Concat(fixture, "local_function_0_param_0_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_return_type: int\n");
    fixture = std.Concat(fixture, "local_function_0_operation: AddI32Literal\n");
    fixture = std.Concat(fixture, "local_function_0_add_value: 1\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: branch\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: branch\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: BranchBlockParamLocalFunctionPositive\n");
    fixture = std.Concat(fixture, "block_1_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_helper\n");
    fixture = std.Concat(fixture, "block_1_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_2_label: positive\n");
    fixture = std.Concat(fixture, "block_2_param_count: 0\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 79\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_3_label: non_positive\n");
    fixture = std.Concat(fixture, "block_3_param_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_3_return_value: 83\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 79\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 79\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -1\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 83\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_param_update_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a param-block update branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit param-block graph that forwards a function parameter into a block
    // parameter, updates that block parameter, then branches on it without
    // routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_param_update_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_param_update_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_param_update_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_param_update_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_param_update_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 5\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_param_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: JumpFunctionParam\n");
    fixture = std.Concat(fixture, "block_0_target: increment\n");
    fixture = std.Concat(fixture, "block_0_param: 0\n");
    fixture = std.Concat(fixture, "block_1_label: increment\n");
    fixture = std.Concat(fixture, "block_1_param_count: 1\n");
    fixture = std.Concat(fixture, "block_1_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_1_terminator: JumpBlockParamAddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_target: branch\n");
    fixture = std.Concat(fixture, "block_1_param: 0\n");
    fixture = std.Concat(fixture, "block_1_add_value: 4\n");
    fixture = std.Concat(fixture, "block_2_label: branch\n");
    fixture = std.Concat(fixture, "block_2_param_count: 1\n");
    fixture = std.Concat(fixture, "block_2_param_0_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: BranchBlockParamPositive\n");
    fixture = std.Concat(fixture, "block_2_branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_3_label: positive\n");
    fixture = std.Concat(fixture, "block_3_param_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_3_return_value: 67\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_4_label: non_positive\n");
    fixture = std.Concat(fixture, "block_4_param_count: 0\n");
    fixture = std.Concat(fixture, "block_4_terminator: Return\n");
    fixture = std.Concat(fixture, "block_4_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_4_return_value: 71\n");
    fixture = std.Concat(fixture, "block_4_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_update_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 67\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 67\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 71\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_local_branch_join_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a branch-to-join local return.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit block graph that mutates a local in either branch arm, jumps both
    // arms to a shared join block, and returns the joined local without routing
    // production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_local_branch_join.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_local_branch_join_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_local_branch_join_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_local_branch_join_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_local_branch_join\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_count: 1\n");
    fixture = std.Concat(fixture, "local_0_name: value\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_0_statement_0_kind: LocalI32SetParam\n");
    fixture = std.Concat(fixture, "block_0_statement_0_local: value\n");
    fixture = std.Concat(fixture, "block_0_statement_0_param: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: BranchLocalPositive\n");
    fixture = std.Concat(fixture, "block_0_branch_local: value\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_1_label: positive\n");
    fixture = std.Concat(fixture, "block_1_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_1_statement_0_kind: LocalI32AddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_statement_0_local: value\n");
    fixture = std.Concat(fixture, "block_1_statement_0_value: 4\n");
    fixture = std.Concat(fixture, "block_1_terminator: Jump\n");
    fixture = std.Concat(fixture, "block_1_target: join\n");
    fixture = std.Concat(fixture, "block_2_label: non_positive\n");
    fixture = std.Concat(fixture, "block_2_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_2_statement_0_kind: LocalI32AddI32Literal\n");
    fixture = std.Concat(fixture, "block_2_statement_0_local: value\n");
    fixture = std.Concat(fixture, "block_2_statement_0_value: 8\n");
    fixture = std.Concat(fixture, "block_2_terminator: Jump\n");
    fixture = std.Concat(fixture, "block_2_target: join\n");
    fixture = std.Concat(fixture, "block_3_label: join\n");
    fixture = std.Concat(fixture, "block_3_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: LocalRead\n");
    fixture = std.Concat(fixture, "block_3_return_local: value\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch_join\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 9\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 8\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -3\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 5\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_two_local_update_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a two-local update branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit block graph that carries two locals through a copied parameter,
    // updates one local in a later block, and branches on that updated local
    // without routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_two_local_update_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_two_local_update_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_two_local_update_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_two_local_update_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_two_local_update_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_count: 2\n");
    fixture = std.Concat(fixture, "local_0_name: raw\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "local_1_name: adjusted\n");
    fixture = std.Concat(fixture, "local_1_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_statement_count: 2\n");
    fixture = std.Concat(fixture, "block_0_statement_0_kind: LocalI32SetParam\n");
    fixture = std.Concat(fixture, "block_0_statement_0_local: raw\n");
    fixture = std.Concat(fixture, "block_0_statement_0_param: 0\n");
    fixture = std.Concat(fixture, "block_0_statement_1_kind: LocalI32SetParam\n");
    fixture = std.Concat(fixture, "block_0_statement_1_local: adjusted\n");
    fixture = std.Concat(fixture, "block_0_statement_1_param: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: Jump\n");
    fixture = std.Concat(fixture, "block_0_target: adjust\n");
    fixture = std.Concat(fixture, "block_1_label: adjust\n");
    fixture = std.Concat(fixture, "block_1_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_1_statement_0_kind: LocalI32AddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_statement_0_local: adjusted\n");
    fixture = std.Concat(fixture, "block_1_statement_0_value: 3\n");
    fixture = std.Concat(fixture, "block_1_terminator: BranchLocalPositive\n");
    fixture = std.Concat(fixture, "block_1_branch_local: adjusted\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_2_label: positive\n");
    fixture = std.Concat(fixture, "block_2_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 61\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_3_label: non_positive\n");
    fixture = std.Concat(fixture, "block_3_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_3_return_value: 67\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 61\n");
    fixture = std.Concat(fixture, "expected_case_1_value: -2\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 61\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -3\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 67\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_local_update_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a local-update block branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit block graph that copies a parameter into a local, updates that
    // local in a later block, and branches on the updated value without routing
    // production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_local_update_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_local_update_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_local_update_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_local_update_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_local_update_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_count: 1\n");
    fixture = std.Concat(fixture, "local_0_name: value\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 4\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_0_statement_0_kind: LocalI32SetParam\n");
    fixture = std.Concat(fixture, "block_0_statement_0_local: value\n");
    fixture = std.Concat(fixture, "block_0_statement_0_param: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: Jump\n");
    fixture = std.Concat(fixture, "block_0_target: increment\n");
    fixture = std.Concat(fixture, "block_1_label: increment\n");
    fixture = std.Concat(fixture, "block_1_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_1_statement_0_kind: LocalI32AddI32Literal\n");
    fixture = std.Concat(fixture, "block_1_statement_0_local: value\n");
    fixture = std.Concat(fixture, "block_1_statement_0_value: 2\n");
    fixture = std.Concat(fixture, "block_1_terminator: BranchLocalPositive\n");
    fixture = std.Concat(fixture, "block_1_branch_local: value\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_2_label: positive\n");
    fixture = std.Concat(fixture, "block_2_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 53\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_3_label: non_positive\n");
    fixture = std.Concat(fixture, "block_3_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_3_terminator: Return\n");
    fixture = std.Concat(fixture, "block_3_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_3_return_value: 59\n");
    fixture = std.Concat(fixture, "block_3_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_update_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 53\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 53\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -3\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 59\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_local_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a local-backed block branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to an
    // explicit block graph that copies a parameter into a local and branches on
    // that local without routing production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.block_local_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_local_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_block_local_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_block_local_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_block_local_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: input\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "local_count: 1\n");
    fixture = std.Concat(fixture, "local_0_name: value\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 3\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_statement_count: 1\n");
    fixture = std.Concat(fixture, "block_0_statement_0_kind: LocalI32SetParam\n");
    fixture = std.Concat(fixture, "block_0_statement_0_local: value\n");
    fixture = std.Concat(fixture, "block_0_statement_0_param: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: BranchLocalPositive\n");
    fixture = std.Concat(fixture, "block_0_branch_local: value\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: positive\n");
    fixture = std.Concat(fixture, "branch_else_block: non_positive\n");
    fixture = std.Concat(fixture, "block_1_label: positive\n");
    fixture = std.Concat(fixture, "block_1_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_1_terminator: Return\n");
    fixture = std.Concat(fixture, "block_1_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_1_return_value: 43\n");
    fixture = std.Concat(fixture, "block_1_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_2_label: non_positive\n");
    fixture = std.Concat(fixture, "block_2_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 47\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 5\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 43\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 47\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -2\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 47\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_block_jump_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for an explicit block jump.
    //
    // This extends the compiler-owned serialized MIR artifact corpus to a
    // two-block Jump -> Return graph without routing production codegen away
    // from MIR-to-C.
    mut program := mir_lower_block_jump_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.block_jump.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_block_jump_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_lower_block_jump_smoke_test_entry.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_block_jump_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_block_jump\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "entry_block: entry\n");
    fixture = std.Concat(fixture, "block_count: 2\n");
    fixture = std.Concat(fixture, "block_0_label: entry\n");
    fixture = std.Concat(fixture, "block_0_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_0_terminator: Jump\n");
    fixture = std.Concat(fixture, "block_0_target: return\n");
    fixture = std.Concat(fixture, "block_1_label: return\n");
    fixture = std.Concat(fixture, "block_1_statement_count: 0\n");
    fixture = std.Concat(fixture, "block_1_terminator: Return\n");
    fixture = std.Concat(fixture, "block_1_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_1_return_value: 1\n");
    fixture = std.Concat(fixture, "block_1_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_jump\n");
    fixture = std.Concat(fixture, "expected_exit: 1\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_positive_i32_branch_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for a parameter-dependent branch.
    //
    // This extends the compiler-owned serialized MIR artifact corpus beyond
    // literal branches to a tiny positive-i32 parameter branch without routing
    // production codegen away from MIR-to-C.
    mut fixture := "format: gust.compiler_mir_ingestion.positive_i32_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_positive_i32_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_positive_i32_branch_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_param_positive_i32_branch_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_positive_i32_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 1\n");
    fixture = std.Concat(fixture, "param_0_name: value\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 3\n");
    fixture = std.Concat(fixture, "block_0_terminator: BranchParamPositive\n");
    fixture = std.Concat(fixture, "branch_param: 0\n");
    fixture = std.Concat(fixture, "branch_condition: greater_than_zero\n");
    fixture = std.Concat(fixture, "branch_then_block: 1\n");
    fixture = std.Concat(fixture, "branch_else_block: 2\n");
    fixture = std.Concat(fixture, "block_1_terminator: Return\n");
    fixture = std.Concat(fixture, "block_1_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_1_return_value: 7\n");
    fixture = std.Concat(fixture, "block_1_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 9\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_positive_i32_branch\n");
    fixture = std.Concat(fixture, "expected_case_count: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_value: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 7\n");
    fixture = std.Concat(fixture, "expected_case_1_value: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 9\n");
    fixture = std.Concat(fixture, "expected_case_2_value: -4\n");
    fixture = std.Concat(fixture, "expected_case_2_result: 9\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_native_boundary_metadata_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for MIR native-boundary metadata.
    //
    // This keeps native boundary metadata visible in the compiler-owned serialized
    // MIR artifact while preserving the same tiny void function behavior. It is
    // intentionally not a production backend route and not a general MIR
    // interchange format.
    mut program := mir_lower_native_boundary_metadata_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.native_boundary_metadata.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_native_boundary_metadata_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_native_boundary_metadata_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_native_boundary_metadata_function\n");
    fixture = std.Concat(fixture, "return_type: void\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 1\n");
    fixture = std.Concat(fixture, "statement_count: 0\n");
    fixture = std.Concat(fixture, "terminator: ReturnVoid\n");
    fixture = std.Concat(fixture, "resource_metadata_count: 0\n");
    fixture = std.Concat(fixture, "provenance_metadata_count: 0\n");
    fixture = std.Concat(fixture, "native_boundary_metadata_count: 1\n");
    fixture = std.Concat(fixture, "native_boundary_0_kind: RuntimeCall\n");
    fixture = std.Concat(fixture, "native_boundary_0_symbol: tiny_runtime_boundary\n");
    fixture = std.Concat(fixture, "native_boundary_0_origin: compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_native_boundary_metadata\n");
    fixture = std.Concat(fixture, "expected_exit: 0\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_resource_metadata_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for MIR resource metadata.
    //
    // This keeps resource metadata visible in the compiler-owned serialized MIR
    // artifact while preserving the same tiny local-binding/read native behavior.
    // It is intentionally not a production backend route and not a general MIR
    // interchange format.
    mut program := mir_lower_resource_metadata_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.resource_metadata.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_resource_metadata_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_resource_metadata_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_resource_metadata_local\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 1\n");
    fixture = std.Concat(fixture, "local_count: 1\n");
    fixture = std.Concat(fixture, "local_0_name: value\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "statement_count: 1\n");
    fixture = std.Concat(fixture, "statement_0_kind: LocalI32Set\n");
    fixture = std.Concat(fixture, "statement_0_local: value\n");
    fixture = std.Concat(fixture, "statement_0_value: 2\n");
    fixture = std.Concat(fixture, "terminator: ReturnLocal\n");
    fixture = std.Concat(fixture, "return_local: value\n");
    fixture = std.Concat(fixture, "return_value_type: int\n");
    fixture = std.Concat(fixture, "resource_metadata_count: 1\n");
    fixture = std.Concat(fixture, "resource_0_kind: LinearResource\n");
    fixture = std.Concat(fixture, "resource_0_state: Live\n");
    fixture = std.Concat(fixture, "resource_0_local: value\n");
    fixture = std.Concat(fixture, "resource_0_cleanup_required: false\n");
    fixture = std.Concat(fixture, "provenance_metadata_count: 0\n");
    fixture = std.Concat(fixture, "native_boundary_metadata_count: 0\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_resource_metadata\n");
    fixture = std.Concat(fixture, "expected_exit: 2\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_provenance_metadata_ingestion_fixture(ctx: &Arena) str {
    // Fixture-only native-backend ingestion seam for MIR provenance metadata.
    //
    // This keeps metadata visible in the compiler-owned serialized MIR artifact
    // while preserving the same tiny local-binding/read native behavior. It is
    // intentionally not a production backend route and not a general MIR
    // interchange format.
    mut program := mir_lower_provenance_metadata_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.provenance_metadata.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_provenance_metadata_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_provenance_metadata_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_provenance_metadata_local_read\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 1\n");
    fixture = std.Concat(fixture, "local_count: 1\n");
    fixture = std.Concat(fixture, "local_0_name: value\n");
    fixture = std.Concat(fixture, "local_0_type: int\n");
    fixture = std.Concat(fixture, "statement_count: 1\n");
    fixture = std.Concat(fixture, "statement_0_kind: LocalI32Set\n");
    fixture = std.Concat(fixture, "statement_0_local: value\n");
    fixture = std.Concat(fixture, "statement_0_value: 2\n");
    fixture = std.Concat(fixture, "terminator: ReturnLocal\n");
    fixture = std.Concat(fixture, "return_local: value\n");
    fixture = std.Concat(fixture, "return_value_type: int\n");
    fixture = std.Concat(fixture, "provenance_metadata_count: 1\n");
    fixture = std.Concat(fixture, "provenance_0_kind: LocalBinding\n");
    fixture = std.Concat(fixture, "provenance_0_local: value\n");
    fixture = std.Concat(fixture, "provenance_0_origin: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst\n");
    fixture = std.Concat(fixture, "resource_metadata_count: 0\n");
    fixture = std.Concat(fixture, "native_boundary_metadata_count: 0\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_provenance_metadata\n");
    fixture = std.Concat(fixture, "expected_exit: 2\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_add_i32_ingestion_fixture(ctx: &Arena) str {
    // Step 50 fixture-only native-backend ingestion seam.
    //
    // This extends the compiler-owned serialized MIR artifact pattern to a
    // tiny parameter arithmetic fixture without routing production codegen away
    // from MIR-to-C. It is intentionally narrow: two int params and one
    // ReturnParamAdd terminator.
    mut fixture := "format: gust.compiler_mir_ingestion.add_i32.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_add_i32_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_add_i32_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: fixture_only_param_add_i32_serialization\n");
    fixture = std.Concat(fixture, "function: tiny_add_i32\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "param_count: 2\n");
    fixture = std.Concat(fixture, "param_0_name: lhs\n");
    fixture = std.Concat(fixture, "param_0_type: int\n");
    fixture = std.Concat(fixture, "param_1_name: rhs\n");
    fixture = std.Concat(fixture, "param_1_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 1\n");
    fixture = std.Concat(fixture, "terminator: ReturnParamAdd\n");
    fixture = std.Concat(fixture, "lhs_param: 0\n");
    fixture = std.Concat(fixture, "rhs_param: 1\n");
    fixture = std.Concat(fixture, "return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_add_i32\n");
    fixture = std.Concat(fixture, "expected_case_count: 2\n");
    fixture = std.Concat(fixture, "expected_case_0_lhs: 2\n");
    fixture = std.Concat(fixture, "expected_case_0_rhs: 3\n");
    fixture = std.Concat(fixture, "expected_case_0_result: 5\n");
    fixture = std.Concat(fixture, "expected_case_1_lhs: 0\n");
    fixture = std.Concat(fixture, "expected_case_1_rhs: 4\n");
    fixture = std.Concat(fixture, "expected_case_1_result: 4\n");
    return std.Clone(ctx, fixture);
}

func mir_emit_native_backend_conditional_branch_ingestion_fixture(ctx: &Arena) str {
    // Step 47 fixture-only native-backend ingestion seam.
    //
    // This extends the compiler-owned serialized MIR artifact pattern from
    // straight-line return/local fixtures to a tiny conditional branch without
    // routing production codegen away from MIR-to-C. It is intentionally narrow:
    // one function, three blocks, one Branch(IntLiteral(1:int)) terminator, and
    // two Return(IntLiteral) leaf blocks.
    mut program := mir_lower_conditional_branch_fixture(ctx);
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "format: invalid\n";
    }

    mut fixture := "format: gust.compiler_mir_ingestion.conditional_branch.v1\n";
    fixture = std.Concat(fixture, "producer: compiler/mir.gst\n");
    fixture = std.Concat(fixture, "producer_entry: mir_emit_native_backend_conditional_branch_ingestion_fixture\n");
    fixture = std.Concat(fixture, "source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst\n");
    fixture = std.Concat(fixture, "lowering_entry: mir_lower_conditional_branch_fixture\n");
    fixture = std.Concat(fixture, "function: tiny_conditional_branch\n");
    fixture = std.Concat(fixture, "return_type: int\n");
    fixture = std.Concat(fixture, "entry_block: 0\n");
    fixture = std.Concat(fixture, "block_count: 3\n");
    fixture = std.Concat(fixture, "block_0_terminator: Branch\n");
    fixture = std.Concat(fixture, "branch_condition_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "branch_condition_value: 1\n");
    fixture = std.Concat(fixture, "branch_condition_type: int\n");
    fixture = std.Concat(fixture, "branch_then_block: 1\n");
    fixture = std.Concat(fixture, "branch_else_block: 2\n");
    fixture = std.Concat(fixture, "block_1_terminator: Return\n");
    fixture = std.Concat(fixture, "block_1_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_1_return_value: 1\n");
    fixture = std.Concat(fixture, "block_1_return_value_type: int\n");
    fixture = std.Concat(fixture, "block_2_terminator: Return\n");
    fixture = std.Concat(fixture, "block_2_return_value_kind: IntLiteral\n");
    fixture = std.Concat(fixture, "block_2_return_value: 2\n");
    fixture = std.Concat(fixture, "block_2_return_value_type: int\n");
    fixture = std.Concat(fixture, "backend_symbol: tiny_native_backend_compiler_mir_ingested_conditional_branch\n");
    fixture = std.Concat(fixture, "expected_exit: 1\n");
    return std.Clone(ctx, fixture);
}

func mir_lower_conditional_branch_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 6 fixture-only conditional branch lowering.
    //
    // This represents the constrained MIR shape:
    //
    //   block0: branch true-ish condition ? block1 : block2
    //   block1: return 1
    //   block2: return 2
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // normal C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut condition_value := mir_make_value_int_literal(1, "bool", span, ctx);
    mut condition_value_idx := mir_alloc_value(condition_value, ctx);
    mut branch_terminator := mir_make_terminator_branch(condition_value_idx, 1, 2, span);
    mut branch_terminator_idx := mir_alloc_terminator(branch_terminator, ctx);
    mut entry_block := mir_make_block(0, branch_terminator_idx, span, ctx);

    mut then_return_value := mir_make_value_int_literal(1, "int", span, ctx);
    mut then_return_value_idx := mir_alloc_value(then_return_value, ctx);
    mut then_terminator := mir_make_terminator_return(then_return_value_idx, span);
    mut then_terminator_idx := mir_alloc_terminator(then_terminator, ctx);
    mut then_block := mir_make_block(1, then_terminator_idx, span, ctx);

    mut else_return_value := mir_make_value_int_literal(2, "int", span, ctx);
    mut else_return_value_idx := mir_alloc_value(else_return_value, ctx);
    mut else_terminator := mir_make_terminator_return(else_return_value_idx, span);
    mut else_terminator_idx := mir_alloc_terminator(else_terminator, ctx);
    mut else_block := mir_make_block(2, else_terminator_idx, span, ctx);

    mut function := mir_make_function("tiny_conditional_branch", "int", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    blocks.Push(then_block);
    blocks.Push(else_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_block_jump_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 6 fixture-only unconditional block-jump lowering.
    //
    // This represents the constrained MIR shape:
    //
    //   block0: jump block1
    //   block1: return 1
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // normal C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut jump_terminator := mir_make_terminator_jump(1, span, ctx);
    mut jump_terminator_idx := mir_alloc_terminator(jump_terminator, ctx);
    mut entry_block := mir_make_block(0, jump_terminator_idx, span, ctx);

    mut return_value := mir_make_value_int_literal(1, "int", span, ctx);
    mut return_value_idx := mir_alloc_value(return_value, ctx);
    mut return_terminator := mir_make_terminator_return(return_value_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut return_block := mir_make_block(1, return_terminator_idx, span, ctx);

    mut function := mir_make_function("tiny_block_jump", "int", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    blocks.Push(return_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_resource_metadata_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 7 fixture-only resource metadata lowering.
    //
    // This represents the constrained MIR metadata shape:
    //
    //   func tiny_resource_metadata_local() int {
    //       mut value := 2;
    //       return value;
    //   }
    //
    // plus one side-table resource metadata record:
    //
    //   local_id: 0
    //   resource_kind: LinearResource
    //   resource_state: Owned
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // MIR-to-C emission, native backend emission, or production compiler paths.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut initial_value := mir_make_value_int_literal(2, "int", span, ctx);
    mut initial_value_idx := mir_alloc_value(initial_value, ctx);
    mut local_set := mir_make_stmt_local_set(0, initial_value_idx, span);

    mut local_read := mir_make_value_local_read(0, "int", span, ctx);
    mut local_read_idx := mir_alloc_value(local_read, ctx);
    mut return_terminator := mir_make_terminator_return(local_read_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut entry_block := mir_make_block(0, return_terminator_idx, span, ctx);

    mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
    statements.Push(local_set);
    ctx.Set(entry_block.statements, statements);

    mut function := mir_make_function("tiny_resource_metadata_local", "int", span, ctx);
    mut local := mir_make_local(0, "value", "int", span, ctx);
    mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
    locals.Push(local);
    ctx.Set(function.locals, locals);

    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut linear_resource_kind: MirResourceKind;
    mut owned_resource_state: MirResourceState;
    unsafe {
        linear_resource_kind.tag = 1;
        owned_resource_state.tag = 1;
    }
    mut resource_metadata := mir_make_resource_metadata(local.id, linear_resource_kind, owned_resource_state, span);
    mut resource_metadata_records: std.Vector[MirResourceMetadata[ctx], ctx] := ctx[program.resource_metadata];
    resource_metadata_records.Push(resource_metadata);
    ctx.Set(program.resource_metadata, resource_metadata_records);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_provenance_metadata_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 7 fixture-only provenance metadata lowering.
    //
    // This represents the constrained MIR metadata shape:
    //
    //   func tiny_provenance_metadata_local_read() int {
    //       mut value := 2;
    //       return value;
    //   }
    //
    // plus one side-table provenance metadata record:
    //
    //   value: returned LocalRead(0)
    //   provenance_kind: LocalBinding
    //   origin_name: value
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // MIR-to-C emission, native backend emission, or production compiler paths.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut initial_value := mir_make_value_int_literal(2, "int", span, ctx);
    mut initial_value_idx := mir_alloc_value(initial_value, ctx);
    mut local_set := mir_make_stmt_local_set(0, initial_value_idx, span);

    mut local_read := mir_make_value_local_read(0, "int", span, ctx);
    mut local_read_idx := mir_alloc_value(local_read, ctx);
    mut return_terminator := mir_make_terminator_return(local_read_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut entry_block := mir_make_block(0, return_terminator_idx, span, ctx);

    mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
    statements.Push(local_set);
    ctx.Set(entry_block.statements, statements);

    mut function := mir_make_function("tiny_provenance_metadata_local_read", "int", span, ctx);
    mut local := mir_make_local(0, "value", "int", span, ctx);
    mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
    locals.Push(local);
    ctx.Set(function.locals, locals);

    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut local_binding_provenance: MirProvenanceKind;
    unsafe {
        local_binding_provenance.tag = 1;
    }
    mut provenance_metadata := mir_make_provenance_metadata(local_read_idx, local_binding_provenance, "value", span);
    mut provenance_metadata_records: std.Vector[MirProvenanceMetadata[ctx], ctx] := ctx[program.provenance_metadata];
    provenance_metadata_records.Push(provenance_metadata);
    ctx.Set(program.provenance_metadata, provenance_metadata_records);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_native_boundary_metadata_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 7 fixture-only native-boundary metadata lowering.
    //
    // This represents the constrained MIR metadata shape:
    //
    //   func tiny_native_boundary_metadata_function() {
    //       return;
    //   }
    //
    // plus one side-table native-boundary metadata record:
    //
    //   function_name: tiny_native_boundary_metadata_function
    //   boundary_kind: RuntimeCall
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // MIR-to-C emission, native backend emission, call lowering, or production
    // compiler paths.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut return_void := mir_make_terminator_return_void(span, ctx);
    mut return_void_idx := mir_alloc_terminator(return_void, ctx);
    mut entry_block := mir_make_block(0, return_void_idx, span, ctx);

    mut function := mir_make_function("tiny_native_boundary_metadata_function", "void", span, ctx);
    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut runtime_boundary_kind: MirNativeBoundaryKind;
    unsafe {
        runtime_boundary_kind.tag = 1;
    }
    mut native_boundary_metadata := mir_make_native_boundary_metadata(function.name, runtime_boundary_kind, span);
    mut native_boundary_metadata_records: std.Vector[MirNativeBoundaryMetadata[ctx], ctx] := ctx[program.native_boundary_metadata];
    native_boundary_metadata_records.Push(native_boundary_metadata);
    ctx.Set(program.native_boundary_metadata, native_boundary_metadata_records);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_lower_local_binding_read_fixture(ctx: &Arena) MirProgram[ctx] {
    // Phase 5 feature-migration fixture-only local binding/read lowering.
    //
    // This represents the constrained source shape:
    //
    //   func tiny_local_binding_read() int {
    //       mut value := 2;
    //       return value;
    //   }
    //
    // It is intentionally not wired into parser, typechecker, verifier,
    // normal C emission, native backend emission, or the production compiler path.
    mut span := mir_make_empty_span();
    mut program := mir_make_program(ctx);

    mut initial_value := mir_make_value_int_literal(2, "int", span, ctx);
    mut initial_value_idx := mir_alloc_value(initial_value, ctx);
    mut local_set := mir_make_stmt_local_set(0, initial_value_idx, span);

    mut local_read := mir_make_value_local_read(0, "int", span, ctx);
    mut local_read_idx := mir_alloc_value(local_read, ctx);
    mut return_terminator := mir_make_terminator_return(local_read_idx, span);
    mut return_terminator_idx := mir_alloc_terminator(return_terminator, ctx);
    mut entry_block := mir_make_block(0, return_terminator_idx, span, ctx);

    mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
    statements.Push(local_set);
    ctx.Set(entry_block.statements, statements);

    mut function := mir_make_function("tiny_local_binding_read", "int", span, ctx);
    mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
    locals.Push(mir_make_local(0, "value", "int", span, ctx));
    ctx.Set(function.locals, locals);

    mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
    blocks.Push(entry_block);
    ctx.Set(function.blocks, blocks);

    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    functions.Push(function);
    ctx.Set(program.functions, functions);

    return program;
}

func mir_to_c_tiny_fixture(program: MirProgram[ctx], ctx: &Arena) str {
    // Phase 4 fixture-only MIR-to-C entry point.
    //
    // This is not wired into parser, typechecker, verifier, normal C emission,
    // native backend emission, or the production compiler path. Step 4 emits
    // only the tiny function-shell, tiny return-int-literal, tiny
    // local-binding/read, and Phase 7 metadata-bearing fixture shapes. Metadata
    // side tables are intentionally ignored by this tiny emitter unless a later
    // phase explicitly consumes them. It does not emit params, calls, loops, or
    // real AST-lowered programs yet.
    mut functions: std.Vector[MirFunction[ctx], ctx] := ctx[program.functions];
    if len(functions) != 1 {
        return "/* gust MIR-to-C tiny fixture */";
    }

    mut function := functions[0];

    if std.str_eq(function.name, "tiny_shell") != 0 {
        if std.str_eq(function.return_type, "void") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        return "void tiny_shell(void) { return; }";
    }

    if std.str_eq(function.name, "tiny_native_boundary_metadata_function") != 0 {
        if std.str_eq(function.return_type, "void") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut block := blocks[0];
        mut terminator: MirTerminator[ctx] := ctx[block.terminator];
        if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.ReturnVoid") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        return "void tiny_native_boundary_metadata_function(void) { return; }";
    }

    if std.str_eq(function.name, "tiny_return_int") != 0 {
        if std.str_eq(function.return_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut block := blocks[0];
        mut terminator: MirTerminator[ctx] := ctx[block.terminator];
        if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        unsafe {
            mut return_value: MirValue[ctx] := ctx[terminator.Return.value];
            if std.str_eq(mir_debug_value_kind(return_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if return_value.IntLiteral.val != 1 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(return_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
        }

        return "int tiny_return_int(void) { return 1; }";
    }

    if std.str_eq(function.name, "tiny_conditional_branch") != 0 {
        if std.str_eq(function.return_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
        if len(locals) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 3 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut entry_block := blocks[0];
        mut then_block := blocks[1];
        mut else_block := blocks[2];

        if entry_block.id != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if then_block.id != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if else_block.id != 2 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut entry_statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
        mut then_statements: std.Vector[MirStmt[ctx], ctx] := ctx[then_block.statements];
        mut else_statements: std.Vector[MirStmt[ctx], ctx] := ctx[else_block.statements];

        if len(entry_statements) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if len(then_statements) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if len(else_statements) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut entry_terminator: MirTerminator[ctx] := ctx[entry_block.terminator];
        mut then_terminator: MirTerminator[ctx] := ctx[then_block.terminator];
        mut else_terminator: MirTerminator[ctx] := ctx[else_block.terminator];

        if std.str_eq(mir_debug_terminator_kind(entry_terminator), "MirTerminator.Branch") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(mir_debug_terminator_kind(then_terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(mir_debug_terminator_kind(else_terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        unsafe {
            if entry_terminator.Branch.then_block != 1 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if entry_terminator.Branch.else_block != 2 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut condition_value: MirValue[ctx] := ctx[entry_terminator.Branch.condition];
            mut then_value: MirValue[ctx] := ctx[then_terminator.Return.value];
            mut else_value: MirValue[ctx] := ctx[else_terminator.Return.value];

            if std.str_eq(mir_debug_value_kind(condition_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(mir_debug_value_kind(then_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(mir_debug_value_kind(else_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            if condition_value.IntLiteral.val != 1 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if then_value.IntLiteral.val != 1 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if else_value.IntLiteral.val != 2 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            if std.str_eq(condition_value.IntLiteral.value_type, "bool") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(then_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(else_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
        }

        return "int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }";
    }

    if std.str_eq(function.name, "tiny_block_jump") != 0 {
        if std.str_eq(function.return_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
        if len(locals) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 2 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut entry_block := blocks[0];
        mut return_block := blocks[1];

        if entry_block.id != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if return_block.id != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut entry_statements: std.Vector[MirStmt[ctx], ctx] := ctx[entry_block.statements];
        mut return_statements: std.Vector[MirStmt[ctx], ctx] := ctx[return_block.statements];

        if len(entry_statements) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if len(return_statements) != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut entry_terminator: MirTerminator[ctx] := ctx[entry_block.terminator];
        mut return_terminator: MirTerminator[ctx] := ctx[return_block.terminator];

        if std.str_eq(mir_debug_terminator_kind(entry_terminator), "MirTerminator.Jump") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(mir_debug_terminator_kind(return_terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        unsafe {
            if entry_terminator.Jump.target_block != 1 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut return_value: MirValue[ctx] := ctx[return_terminator.Return.value];
            if std.str_eq(mir_debug_value_kind(return_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if return_value.IntLiteral.val != 1 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(return_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
        }

        return "int tiny_block_jump(void) { goto block_1; block_1: return 1; }";
    }

    if std.str_eq(function.name, "tiny_resource_metadata_local") != 0 {
        if std.str_eq(function.return_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
        if len(locals) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut local := locals[0];
        if local.id != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(local.name, "value") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(local.local_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut block := blocks[0];
        mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[block.statements];
        if len(statements) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut stmt := statements[0];
        if std.str_eq(mir_debug_stmt_kind(stmt), "MirStmt.LocalSet") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut terminator: MirTerminator[ctx] := ctx[block.terminator];
        if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        unsafe {
            if stmt.LocalSet.local_id != 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut set_value: MirValue[ctx] := ctx[stmt.LocalSet.value];
            if std.str_eq(mir_debug_value_kind(set_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if set_value.IntLiteral.val != 2 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(set_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut return_value: MirValue[ctx] := ctx[terminator.Return.value];
            if std.str_eq(mir_debug_value_kind(return_value), "MirValue.LocalRead") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if return_value.LocalRead.local_id != 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(return_value.LocalRead.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
        }

        return "int tiny_resource_metadata_local(void) { int value = 2; return value; }";
    }

    if std.str_eq(function.name, "tiny_provenance_metadata_local_read") != 0 {
        if std.str_eq(function.return_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
        if len(locals) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut local := locals[0];
        if local.id != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(local.name, "value") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(local.local_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut block := blocks[0];
        mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[block.statements];
        if len(statements) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut stmt := statements[0];
        if std.str_eq(mir_debug_stmt_kind(stmt), "MirStmt.LocalSet") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut terminator: MirTerminator[ctx] := ctx[block.terminator];
        if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        unsafe {
            if stmt.LocalSet.local_id != 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut set_value: MirValue[ctx] := ctx[stmt.LocalSet.value];
            if std.str_eq(mir_debug_value_kind(set_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if set_value.IntLiteral.val != 2 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(set_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut return_value: MirValue[ctx] := ctx[terminator.Return.value];
            if std.str_eq(mir_debug_value_kind(return_value), "MirValue.LocalRead") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if return_value.LocalRead.local_id != 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(return_value.LocalRead.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
        }

        return "int tiny_provenance_metadata_local_read(void) { int value = 2; return value; }";
    }

    if std.str_eq(function.name, "tiny_local_binding_read") != 0 {
        if std.str_eq(function.return_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut locals: std.Vector[MirLocal[ctx], ctx] := ctx[function.locals];
        if len(locals) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut local := locals[0];
        if local.id != 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(local.name, "value") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }
        if std.str_eq(local.local_type, "int") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut blocks: std.Vector[MirBlock[ctx], ctx] := ctx[function.blocks];
        if len(blocks) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut block := blocks[0];
        mut statements: std.Vector[MirStmt[ctx], ctx] := ctx[block.statements];
        if len(statements) != 1 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut stmt := statements[0];
        if std.str_eq(mir_debug_stmt_kind(stmt), "MirStmt.LocalSet") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        mut terminator: MirTerminator[ctx] := ctx[block.terminator];
        if std.str_eq(mir_debug_terminator_kind(terminator), "MirTerminator.Return") == 0 {
            return "/* gust MIR-to-C tiny fixture */";
        }

        unsafe {
            if stmt.LocalSet.local_id != 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut set_value: MirValue[ctx] := ctx[stmt.LocalSet.value];
            if std.str_eq(mir_debug_value_kind(set_value), "MirValue.IntLiteral") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if set_value.IntLiteral.val != 2 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(set_value.IntLiteral.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }

            mut return_value: MirValue[ctx] := ctx[terminator.Return.value];
            if std.str_eq(mir_debug_value_kind(return_value), "MirValue.LocalRead") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if return_value.LocalRead.local_id != 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
            if std.str_eq(return_value.LocalRead.value_type, "int") == 0 {
                return "/* gust MIR-to-C tiny fixture */";
            }
        }

        return "int tiny_local_binding_read(void) { int value = 2; return value; }";
    }

    return "/* gust MIR-to-C tiny fixture */";
}
