"""Pure current-source evidence for lexical allocator lifecycle transport.

This replaces two retired implementation anchors, not Phase20 authority.
Physical source and validator pins are enforced separately by owning enrollment.
"""
import re
import hashlib
from phase20_resource_declaration_migration import gust_code_without_comments_or_literals

RETIRED = (
    'env_arena_lifecycle_record_binding(env, name, declaration_arena_identity, ctx)',
    'env, assignment_lifecycle_binding, assignment_arena_identity, ctx',
)


def require(ok, message):
    if not ok:
        raise ValueError('allocator lifecycle evidence: ' + message)


def compact(source):
    return ' '.join(source.split())


def function_source(code, name):
    starts = list(re.finditer(r'^func ' + re.escape(name) + r'\(', code, re.M))
    require(len(starts) == 1, 'missing or duplicate function ' + name)
    following = re.search(r'^func ', code[starts[0].end():], re.M)
    end = starts[0].end() + following.start() if following else len(code)
    return code[starts[0].start():end]


def statement_source(code, tag, payload):
    # Statement tags identify the existing AST variants, not source coordinates.
    matches = list(re.finditer(r'if stmt\.tag == ' + str(tag) + r' \{', code))
    require(len(matches) == 1, 'missing or duplicate statement ' + payload)
    start = matches[0].end(); depth = 1; end = start
    while depth and end < len(code):
        depth += (code[end] == '{') - (code[end] == '}')
        end += 1
    require(depth == 0 and 'stmt.' + payload in code[start:end], 'statement body ' + payload)
    return compact(code[start:end - 1])


def validate(source):
    code = gust_code_without_comments_or_literals(source)
    flat = compact(code)
    for anchor in RETIRED:
        require(anchor not in flat, 'retired call re-admitted: ' + anchor)
    check = function_source(code, 'check_statement_impl')
    declaration = statement_source(check, 4, 'VarDecl')
    assignment = statement_source(check, 5, 'Assignment')
    capture = 'mut declaration_allocator_proof := env_allocator_declaration_proof(val_idx, val_type, env, ctx);'
    record = 'env_allocator_record_binding(env, name, declaration_allocator_proof, ctx);'
    inserts = ('scope_insert(scope, std.Clone(ctx, name), resolved_explicit, ctx);',
               'scope_insert(scope, std.Clone(ctx, name), val_type, ctx);')
    require(declaration.count(capture) == declaration.count(record) == 1,
            'declaration capture/registration count')
    require(all(declaration.count(item) == 1 for item in inserts), 'declaration insertion population')
    require(all(declaration.index(capture) < declaration.index(item) < declaration.index(record)
                for item in inserts), 'declaration capture before insertion and registration after')
    proof = compact(function_source(code, 'allocator_identity_proof'))
    require('proof.unresolved = unresolved;' in proof and 'proof.present = 1;' in proof,
            'proof preserves presence and uncertainty')
    binding = compact(function_source(code, 'env_allocator_record_binding'))
    require(all(item in binding for item in (
        'env_allocator_binding_scope(env, binding, ctx)',
        'if ctx[declaration].allocator_bindings.Get(binding).Ok { return; }',
        'ctx[declaration].allocator_bindings.Insert(std.Clone(ctx, binding), proof);',
        'if len(proof.identity) > 0 { env_arena_lifecycle_ensure(env, proof.identity, ctx);',
        '(*env).arena_lifecycle_bindings.Insert(std.Clone(ctx, key), std.Clone(ctx, proof.identity));')),
        'immutable lexical proof and lifecycle registration')
    lookup = compact(function_source(code, 'env_allocator_binding_proof'))
    require(all(item in lookup for item in (
        'if ctx[current].bindings.Get(root).Ok {',
        'ctx[current].allocator_bindings.Get(binding)',
        'if local.Ok { return local.Val; }',
        'return allocator_identity_proof( , 1, ctx);',
        'current = ctx[current].parent;')), 'nearest declaration preserves unknown proof')
    expression = compact(function_source(code, 'env_allocator_expression_proof'))
    require('if exact.Ok { return exact.Val; }' in expression and
            expression.index('if exact.Ok { return exact.Val; }') <
            expression.index('get_root_variable(expr_idx, ctx)'), 'exact-path unknown cannot fall back to root')
    initializer = compact(function_source(code, 'env_allocator_declaration_proof'))
    require('if proof.present == 0 {' in initializer and
            'env_allocator_binding_proof(env, brand.arena_identity, ctx)' in initializer,
            'initializer fallback only when absent')
    fields = compact(function_source(code, 'env_capture_resource_field_allocator_constraints'))
    require('if actual_fact.Ok { proof = actual_fact.Val; source_fact_present = 1; }' in fields and
            'if source_fact_present == 0 && len(proof.identity) == 0 &&' in fields,
            'explicit field fact cannot fall back to root')
    require(all(item in assignment for item in (
        'mut assignment_expected_allocator := env_allocator_binding_proof(env, assignment_lifecycle_binding, ctx);',
        'mut assignment_actual_allocator := env_allocator_expression_proof(val_idx, env, ctx);',
        'if assignment_requires_allocator_constraint == 1 &&',
        'assignment_expected_allocator.unresolved == 0',
        'if assignment_actual_allocator.unresolved == 1 ||',
        'std.str_eq(assignment_expected_allocator.identity, assignment_actual_allocator.identity) == 0',
        'env_validate_resource_field_allocator_assignment(env, assignment_allocator_scope,')),
        'strict assignment validates declared context and fields')
    require('if assignment_requires_allocator_constraint == 0 &&' in assignment and
            'env_allocator_taint_observed_assignment(env, assignment_allocator_scope, assignment_lifecycle_binding, assignment_actual_allocator, ctx);' in assignment,
            'ordinary assignment retains conservative taint')
    taint = compact(function_source(code, 'env_allocator_taint_observed_assignment'))
    require(all(item in taint for item in (
        'if previous.Val.unresolved == 1 || actual.unresolved == 1 ||',
        'std.str_eq(previous.Val.identity, actual.identity) == 0 { merged.unresolved = 1; }',
        'ctx[scope].allocator_bindings.Insert(std.Clone(ctx, root), merged);')),
        'ordinary mutation never refines uncertainty')
    require(flat.count('env_arena_lifecycle_record_binding(env, param.name, param_arena_identity, ctx);') == 1,
            'parameter lifecycle transport')
    observer = compact(function_source(code, 'env_arena_lifecycle_observe_identity'))
    require('state.state = arena_lifecycle_state_freed()' not in observer and 'report_error(' not in observer,
            'inert observer remains non-enforcing')
    return dict(declaration='captured before insertion, immutable after',
                assignment='strict contexts validated; ordinary observations tainted',
                lookup='nearest declaration and exact path preserve uncertainty',
                parameter='existing transport retained', observer='inert')


def inversions(source, predecessor):
    validate(source)
    controls = []
    def refusal(label,mutant,expected):
     assert mutant!=source,'mutation did not move: '+label
     try:validate(mutant)
     except ValueError as error:
      outcome='REJECTED (expected assertion)' if str(error)=='allocator lifecycle evidence: '+expected else 'REJECTED (different assertion)'
      controls.append(dict(label=label,outcome=outcome,assertion=str(error),source_sha256=hashlib.sha256(mutant.encode()).hexdigest()));assert outcome=='REJECTED (expected assertion)',controls[-1]
     else:raise AssertionError(label+': ACCEPTED')
    def changed(old,new):
     assert source.count(old)==1,(old,source.count(old));return source.replace(old,new,1)
    def body_change(name,old,new):
     body=function_source(source,name);assert body.count(old)==1,(name,old);return source.replace(body,body.replace(old,new,1),1)
    capture='mut declaration_allocator_proof := env_allocator_declaration_proof(val_idx, val_type, env, ctx);'
    record='env_allocator_record_binding(env, name, declaration_allocator_proof, ctx);'
    refusal('missing declaration capture',changed(capture,''),'declaration capture/registration count')
    refusal('missing declaration registration',changed(record,''),'declaration capture/registration count')
    refusal('duplicate declaration registration',changed(record,record+record),'declaration capture/registration count')
    insert='scope_insert(scope, std.Clone(ctx, name), resolved_explicit, ctx);'
    refusal('capture after insertion',source.replace(capture,'',1).replace(insert,insert+capture,1),'declaration capture before insertion and registration after')
    refusal('discarded uncertainty',changed('proof.unresolved = unresolved;','proof.unresolved = 0;'),'proof preserves presence and uncertainty')
    refusal('overwrite immutable declaration',changed('if ctx[declaration].allocator_bindings.Get(binding).Ok { return; }',''),'immutable lexical proof and lifecycle registration')
    refusal('omit lifecycle registration',changed('env_arena_lifecycle_ensure(env, proof.identity, ctx);',''),'immutable lexical proof and lifecycle registration')
    refusal('nearest unknown becomes absent',body_change('env_allocator_binding_proof','return allocator_identity_proof("", 1, ctx);','return allocator_identity_absent(ctx);'),'nearest declaration preserves unknown proof')
    refusal('exact unknown falls back to root',changed('if exact.Ok { return exact.Val; }','if exact.Ok && len(exact.Val.identity) > 0 { return exact.Val; }'),'exact-path unknown cannot fall back to root')
    refusal('initializer unknown becomes known',body_change('env_allocator_declaration_proof','if proof.present == 0 {','if len(proof.identity) == 0 {'),'initializer fallback only when absent')
    refusal('explicit field unknown falls back to root',changed('if source_fact_present == 0 && len(proof.identity) == 0 && std.str_eq(brand, root_brand) == 1 {','if len(proof.identity) == 0 && std.str_eq(brand, root_brand) == 1 {'),'explicit field fact cannot fall back to root')
    refusal('bypass strict assignment',changed('if assignment_requires_allocator_constraint == 1 &&','if assignment_requires_allocator_constraint == 2 &&'),'strict assignment validates declared context and fields')
    refusal('omit field assignment validation',changed('env_validate_resource_field_allocator_assignment(env, assignment_allocator_scope,','omitted_field_validation(env, assignment_allocator_scope,'),'strict assignment validates declared context and fields')
    refusal('omit mutation taint',changed('env_allocator_taint_observed_assignment(env, assignment_allocator_scope,','omitted_mutation_taint(env, assignment_allocator_scope,'),'ordinary assignment retains conservative taint')
    refusal('refine mutation uncertainty',body_change('env_allocator_taint_observed_assignment','merged.unresolved = 1;','merged.unresolved = 0;'),'ordinary mutation never refines uncertainty')
    parameter='env_arena_lifecycle_record_binding(env, param.name, param_arena_identity, ctx);'
    refusal('remove parameter transport',changed(parameter,''),'parameter lifecycle transport')
    observer=function_source(source,'env_arena_lifecycle_observe_identity')
    for label,code in [('observer reports error','report_error(2);'),('observer marks freed','state.state = arena_lifecycle_state_freed();')]:
     mutant=source.replace(observer,observer[:observer.rfind('}')]+code+observer[observer.rfind('}'):],1)
     refusal(label,mutant,'inert observer remains non-enforcing')
    refusal('retired declaration re-admitted',changed(record,RETIRED[0]+';'),'retired call re-admitted: '+RETIRED[0])
    refusal('retired assignment re-admitted',changed('mut assignment_actual_allocator := env_allocator_expression_proof(val_idx, env, ctx);','env_arena_lifecycle_record_binding('+RETIRED[1]+');'),'retired call re-admitted: '+RETIRED[1])
    refusal('comment cannot fake declaration record',changed(record,'// '+record),'declaration capture/registration count')
    old=predecessor
    refusal('whole predecessor cannot pass new evidence',old,'retired call re-admitted: '+RETIRED[0])
    require(len(controls) == 22, "inversion population")
    return controls
