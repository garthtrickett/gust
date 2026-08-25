// Phase 21.2 inert compiler-owned records for tenant-scoped typed queries.
//
// This module is deliberately not imported by parser.gst, typechecker.gst,
// codegen.gst, or a compiler entrypoint.  The records describe the semantic
// identities that later Phase 21 patches will populate, but this patch does not
// attach them to source syntax, diagnostics, MIR, or either backend.
//
// Every record is opaque and every constructor is private.  Ordinary source
// can name these types if it explicitly imports this compiler module, but it
// cannot construct a value or call a constructor.  The public self-test below
// returns only an integer and never exposes a trusted Scope origin value.

#[opaque]
type ScopedEntityDeclaration[ctx] struct {
    entity_identity: str,
    scope_type_identity: str,
    declaration_identity: str
}

#[opaque]
type CanonicalQueryRoot[ctx] struct {
    query_identity: str,
    root_identity: str,
    entity_identity: str,
    root_kind: str,
    source_order: int
}

#[opaque]
type PerRootScopeObligation[ctx] struct {
    obligation_identity: str,
    query_identity: str,
    root_identity: str,
    required_scope_type_identity: str,
    inert_state: str
}

#[opaque]
type PredicateProvenance[ctx] struct {
    predicate_identity: str,
    query_identity: str,
    root_identity: str,
    origin_identity: str,
    provenance_kind: str,
    predicate_spelling: str
}

#[opaque]
type NestedQueryIdentity[ctx] struct {
    query_identity: str,
    parent_query_identity: str,
    nesting_kind: str,
    source_order: int
}

#[opaque]
type CrossTenantMarker[ctx] struct {
    marker_identity: str,
    query_identity: str,
    call_site_identity: str,
    capability_origin_identity: str
}

#[opaque]
type TrustedScopeOrigin[ctx] struct {
    origin_identity: str,
    scope_type_identity: str,
    trusted_context_identity: str,
    origin_kind: str
}

#[opaque]
type InertScopedQuerySemanticRecords[ctx] struct {
    scoped_entities: Index[std.Vector[ScopedEntityDeclaration[ctx], ctx], ctx],
    query_roots: Index[std.Vector[CanonicalQueryRoot[ctx], ctx], ctx],
    root_obligations: Index[std.Vector[PerRootScopeObligation[ctx], ctx], ctx],
    predicate_provenance: Index[std.Vector[PredicateProvenance[ctx], ctx], ctx],
    nested_queries: Index[std.Vector[NestedQueryIdentity[ctx], ctx], ctx],
    cross_tenant_markers: Index[std.Vector[CrossTenantMarker[ctx], ctx], ctx],
    trusted_scope_origins: Index[std.Vector[TrustedScopeOrigin[ctx], ctx], ctx]
}

#[private]
func make_scoped_entity_declaration(entity_identity: str, scope_type_identity: str, declaration_identity: str, ctx: &Arena) ScopedEntityDeclaration[ctx] {
    mut record: ScopedEntityDeclaration[ctx];
    record.entity_identity = std.Clone(ctx, entity_identity);
    record.scope_type_identity = std.Clone(ctx, scope_type_identity);
    record.declaration_identity = std.Clone(ctx, declaration_identity);
    return record;
}

#[private]
func make_canonical_query_root(query_identity: str, root_identity: str, entity_identity: str, root_kind: str, source_order: int, ctx: &Arena) CanonicalQueryRoot[ctx] {
    mut record: CanonicalQueryRoot[ctx];
    record.query_identity = std.Clone(ctx, query_identity);
    record.root_identity = std.Clone(ctx, root_identity);
    record.entity_identity = std.Clone(ctx, entity_identity);
    record.root_kind = std.Clone(ctx, root_kind);
    record.source_order = source_order;
    return record;
}

#[private]
func make_per_root_scope_obligation(obligation_identity: str, query_identity: str, root_identity: str, required_scope_type_identity: str, ctx: &Arena) PerRootScopeObligation[ctx] {
    mut record: PerRootScopeObligation[ctx];
    record.obligation_identity = std.Clone(ctx, obligation_identity);
    record.query_identity = std.Clone(ctx, query_identity);
    record.root_identity = std.Clone(ctx, root_identity);
    record.required_scope_type_identity = std.Clone(ctx, required_scope_type_identity);
    record.inert_state = std.Clone(ctx, "recorded_not_enforced");
    return record;
}

#[private]
func make_predicate_provenance(predicate_identity: str, query_identity: str, root_identity: str, origin_identity: str, provenance_kind: str, predicate_spelling: str, ctx: &Arena) PredicateProvenance[ctx] {
    mut record: PredicateProvenance[ctx];
    record.predicate_identity = std.Clone(ctx, predicate_identity);
    record.query_identity = std.Clone(ctx, query_identity);
    record.root_identity = std.Clone(ctx, root_identity);
    record.origin_identity = std.Clone(ctx, origin_identity);
    record.provenance_kind = std.Clone(ctx, provenance_kind);
    record.predicate_spelling = std.Clone(ctx, predicate_spelling);
    return record;
}

#[private]
func make_nested_query_identity(query_identity: str, parent_query_identity: str, nesting_kind: str, source_order: int, ctx: &Arena) NestedQueryIdentity[ctx] {
    mut record: NestedQueryIdentity[ctx];
    record.query_identity = std.Clone(ctx, query_identity);
    record.parent_query_identity = std.Clone(ctx, parent_query_identity);
    record.nesting_kind = std.Clone(ctx, nesting_kind);
    record.source_order = source_order;
    return record;
}

#[private]
func make_cross_tenant_marker(marker_identity: str, query_identity: str, call_site_identity: str, capability_origin_identity: str, ctx: &Arena) CrossTenantMarker[ctx] {
    mut record: CrossTenantMarker[ctx];
    record.marker_identity = std.Clone(ctx, marker_identity);
    record.query_identity = std.Clone(ctx, query_identity);
    record.call_site_identity = std.Clone(ctx, call_site_identity);
    record.capability_origin_identity = std.Clone(ctx, capability_origin_identity);
    return record;
}

#[private]
func make_trusted_scope_origin(origin_identity: str, scope_type_identity: str, trusted_context_identity: str, ctx: &Arena) TrustedScopeOrigin[ctx] {
    mut record: TrustedScopeOrigin[ctx];
    record.origin_identity = std.Clone(ctx, origin_identity);
    record.scope_type_identity = std.Clone(ctx, scope_type_identity);
    record.trusted_context_identity = std.Clone(ctx, trusted_context_identity);
    record.origin_kind = std.Clone(ctx, "trusted_request_context_scope");
    return record;
}

#[private]
func make_empty_inert_scoped_query_semantic_records(ctx: &Arena) InertScopedQuerySemanticRecords[ctx] {
    mut entities: std.Vector[ScopedEntityDeclaration[ctx], ctx] := std.VectorNew(ctx);
    mut entities_index: Index[std.Vector[ScopedEntityDeclaration[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(entities_index, entities);

    mut roots: std.Vector[CanonicalQueryRoot[ctx], ctx] := std.VectorNew(ctx);
    mut roots_index: Index[std.Vector[CanonicalQueryRoot[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(roots_index, roots);

    mut obligations: std.Vector[PerRootScopeObligation[ctx], ctx] := std.VectorNew(ctx);
    mut obligations_index: Index[std.Vector[PerRootScopeObligation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(obligations_index, obligations);

    mut provenance: std.Vector[PredicateProvenance[ctx], ctx] := std.VectorNew(ctx);
    mut provenance_index: Index[std.Vector[PredicateProvenance[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(provenance_index, provenance);

    mut nested: std.Vector[NestedQueryIdentity[ctx], ctx] := std.VectorNew(ctx);
    mut nested_index: Index[std.Vector[NestedQueryIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(nested_index, nested);

    mut markers: std.Vector[CrossTenantMarker[ctx], ctx] := std.VectorNew(ctx);
    mut markers_index: Index[std.Vector[CrossTenantMarker[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(markers_index, markers);

    mut origins: std.Vector[TrustedScopeOrigin[ctx], ctx] := std.VectorNew(ctx);
    mut origins_index: Index[std.Vector[TrustedScopeOrigin[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(origins_index, origins);

    mut records: InertScopedQuerySemanticRecords[ctx];
    records.scoped_entities = entities_index;
    records.query_roots = roots_index;
    records.root_obligations = obligations_index;
    records.predicate_provenance = provenance_index;
    records.nested_queries = nested_index;
    records.cross_tenant_markers = markers_index;
    records.trusted_scope_origins = origins_index;
    return records;
}

// Focused self-hosted evidence only.  No semantic record leaves this module.
func phase21_inert_scoped_query_records_round_trip(ctx: &Arena) int {
    mut records := make_empty_inert_scoped_query_semantic_records(ctx);

    mut entity := make_scoped_entity_declaration(
        "entity:invoice", "Scope[Workspace]", "decl:invoice", ctx
    );
    mut entities: std.Vector[ScopedEntityDeclaration[ctx], ctx] := ctx[records.scoped_entities];
    entities.Push(entity);
    ctx.Set(records.scoped_entities, entities);

    mut primary_root := make_canonical_query_root(
        "query:outer", "root:invoice", "entity:invoice", "primary", 0, ctx
    );
    mut joined_root := make_canonical_query_root(
        "query:outer", "root:payment", "entity:payment", "join", 1, ctx
    );
    mut roots: std.Vector[CanonicalQueryRoot[ctx], ctx] := ctx[records.query_roots];
    roots.Push(primary_root);
    roots.Push(joined_root);
    ctx.Set(records.query_roots, roots);

    mut primary_obligation := make_per_root_scope_obligation(
        "obligation:invoice", "query:outer", "root:invoice", "Scope[Workspace]", ctx
    );
    mut joined_obligation := make_per_root_scope_obligation(
        "obligation:payment", "query:outer", "root:payment", "Scope[Workspace]", ctx
    );
    mut obligations: std.Vector[PerRootScopeObligation[ctx], ctx] := ctx[records.root_obligations];
    obligations.Push(primary_obligation);
    obligations.Push(joined_obligation);
    ctx.Set(records.root_obligations, obligations);

    mut predicate := make_predicate_provenance(
        "predicate:invoice.workspace", "query:outer", "root:invoice",
        "scope-origin:request", "trusted_scope_origin_reference",
        "invoice.workspace == request.workspace", ctx
    );
    mut provenance: std.Vector[PredicateProvenance[ctx], ctx] := ctx[records.predicate_provenance];
    provenance.Push(predicate);
    ctx.Set(records.predicate_provenance, provenance);

    mut nested_query := make_nested_query_identity(
        "query:nested", "query:outer", "exists", 0, ctx
    );
    mut nested: std.Vector[NestedQueryIdentity[ctx], ctx] := ctx[records.nested_queries];
    nested.Push(nested_query);
    ctx.Set(records.nested_queries, nested);

    mut marker := make_cross_tenant_marker(
        "marker:outer", "query:outer", "callsite:main:1",
        "cross-tenant-capability:host", ctx
    );
    mut markers: std.Vector[CrossTenantMarker[ctx], ctx] := ctx[records.cross_tenant_markers];
    markers.Push(marker);
    ctx.Set(records.cross_tenant_markers, markers);

    mut trusted_origin := make_trusted_scope_origin(
        "scope-origin:request", "Scope[Workspace]", "trusted-context:request", ctx
    );
    mut origins: std.Vector[TrustedScopeOrigin[ctx], ctx] := ctx[records.trusted_scope_origins];
    origins.Push(trusted_origin);
    ctx.Set(records.trusted_scope_origins, origins);

    mut read_entities: std.Vector[ScopedEntityDeclaration[ctx], ctx] := ctx[records.scoped_entities];
    mut read_roots: std.Vector[CanonicalQueryRoot[ctx], ctx] := ctx[records.query_roots];
    mut read_obligations: std.Vector[PerRootScopeObligation[ctx], ctx] := ctx[records.root_obligations];
    mut read_provenance: std.Vector[PredicateProvenance[ctx], ctx] := ctx[records.predicate_provenance];
    mut read_nested: std.Vector[NestedQueryIdentity[ctx], ctx] := ctx[records.nested_queries];
    mut read_markers: std.Vector[CrossTenantMarker[ctx], ctx] := ctx[records.cross_tenant_markers];
    mut read_origins: std.Vector[TrustedScopeOrigin[ctx], ctx] := ctx[records.trusted_scope_origins];

    if len(read_entities) != 1 || len(read_roots) != 2 || len(read_obligations) != 2 ||
       len(read_provenance) != 1 || len(read_nested) != 1 || len(read_markers) != 1 ||
       len(read_origins) != 1 {
        return 0;
    }
    if std.str_eq(read_entities[0].scope_type_identity, "Scope[Workspace]") == 0 ||
       std.str_eq(read_roots[0].root_identity, "root:invoice") == 0 ||
       std.str_eq(read_roots[1].root_identity, "root:payment") == 0 ||
       std.str_eq(read_obligations[0].root_identity, "root:invoice") == 0 ||
       std.str_eq(read_obligations[1].root_identity, "root:payment") == 0 ||
       std.str_eq(read_obligations[0].inert_state, "recorded_not_enforced") == 0 ||
       std.str_eq(read_provenance[0].origin_identity, "scope-origin:request") == 0 ||
       std.str_eq(read_nested[0].parent_query_identity, "query:outer") == 0 ||
       std.str_eq(read_markers[0].call_site_identity, "callsite:main:1") == 0 ||
       std.str_eq(read_origins[0].origin_kind, "trusted_request_context_scope") == 0 {
        return 0;
    }
    if std.str_eq(read_obligations[0].obligation_identity, read_obligations[1].obligation_identity) == 1 {
        return 0;
    }
    return 1;
}
