use super::*;
use object::{Object, ObjectSymbol};
use std::os::unix::process::ExitStatusExt;
use std::process::Command;

struct Example {
    program: Program,
    statements: Vec<usize>,
    vector_type: String,
    element: String,
}
impl Example {
    fn node(&mut self, kind: &str, ty: &str, text: &str, children: Vec<usize>) -> usize {
        let index = self.program.nodes.len();
        self.program.nodes.push(Node {
            kind: kind.into(),
            ty: ty.into(),
            text: text.into(),
            second_text: String::new(),
            integer: 0,
            second_integer: 0,
            isolated_call_plan: None,
            collection_intrinsic: None,
            source_line: 1,
            source_column: 1,
            source_start: 0,
            source_end: 1,
            children,
        });
        index
    }
    fn local(&mut self, name: &str, ty: &str) -> usize {
        self.node("LocalRead", ty, name, vec![])
    }
    fn integer(&mut self, value: i32) -> usize {
        let index = self.node("IntegerLiteral", "Int", "", vec![]);
        self.program.nodes[index].integer = value;
        index
    }
    fn declare(&mut self, name: &str, ty: &str, value: usize) {
        let index = self.node("LocalDeclare", ty, name, vec![value]);
        self.statements.push(index);
    }
    fn evaluate(&mut self, value: usize) {
        let index = self.node("Evaluate", "Void", "", vec![value]);
        self.statements.push(index);
    }
    fn new(element: &str) -> Self {
        let erased = "std_Vector_QualifiedElement";
        let vector_type = format!("Struct(\"{erased}\", None)");
        let program = Program {
            target_triple: "x86_64-unknown-linux-gnu".into(),
            object_format: "Elf".into(),
            modules: vec![("checked-storage.gst".into(), String::new())],
            layouts: vec![Layout {
                name: format!("{erased}_arena"),
                erased_name: erased.into(),
                brand: "arena".into(),
                repr_c: false,
                packed: false,
                abi: String::new(),
                fields: vec![
                    LayoutField {
                        name: "arena".into(),
                        ty: "RawPointer(Arena)".into(),
                    },
                    LayoutField {
                        name: "capacity".into(),
                        ty: "Int".into(),
                    },
                    LayoutField {
                        name: "data".into(),
                        ty: format!("RawPointer({element})"),
                    },
                    LayoutField {
                        name: "len".into(),
                        ty: "Int".into(),
                    },
                ],
            }],
            enumerations: vec![],
            functions: vec![],
            nodes: vec![],
            entry_function: 0,
        };
        let mut example = Self {
            program,
            statements: vec![],
            vector_type,
            element: element.into(),
        };
        let callee = example.local("os_Arena_New", "Void");
        let arena = example.node("Call", "Arena", "os_Arena_New", vec![callee]);
        example.declare("arena", "Arena", arena);
        let arena = example.local("arena", "Arena");
        let ty = example.vector_type.clone();
        // The constructor's existing inline identity is a member selector.
        let module = example.local("std", "Void");
        let callee = example.node("FieldOrMethodSelect", "Void", "VectorNew", vec![module]);
        let new = example.node("Call", &ty, "std.VectorNew", vec![callee, arena]);
        example.declare("values", &ty, new);
        example
    }
    fn method(&mut self, receiver: &str, name: &str, result: &str, args: Vec<usize>) -> usize {
        let ty = self.vector_type.clone();
        let receiver = self.local(receiver, &ty);
        let callee = self.node("FieldOrMethodSelect", "Void", name, vec![receiver]);
        let mut children = vec![callee];
        children.extend(args);
        let index = self.node("Call", result, name, children);
        if name == "Pop" {
            self.program.nodes[index].collection_intrinsic = Some(CollectionIntrinsicPlan {
                opcode: "PopCopy".into(),
                receiver_type: ty,
                element_type: self.element.clone(),
                layout_id: self.program.layouts[0].name.clone(),
                brand: "arena".into(),
            });
        }
        index
    }
    fn push(&mut self, value: i32) {
        let scalar = self.integer(value);
        let element = self.element.clone();
        let value = if element == "Int" {
            scalar
        } else {
            self.node("ExplicitCast", &element, "", vec![scalar])
        };
        let push = self.method("values", "Push", "Void", vec![value]);
        self.evaluate(push);
    }
    fn read(&mut self, name: &str, index: i32) -> usize {
        let ty = self.vector_type.clone();
        let element = self.element.clone();
        let receiver = self.local(name, &ty);
        let index = self.integer(index);
        self.node("IndexRead", &element, "", vec![receiver, index])
    }
    fn finish(mut self, result: usize) -> Program {
        let result = if self.element == "Int" {
            result
        } else {
            self.node("ExplicitCast", "Int", "", vec![result])
        };
        let ret = self.node("Return", "Void", "", vec![result]);
        self.statements.push(ret);
        let body = self.node("Block", "Void", "", self.statements.clone());
        self.program.entry_function = self.program.functions.len();
        self.program.functions.push(Function {
            module_index: 0,
            source_name: "main".into(),
            qualified_name: "main".into(),
            is_extern: false,
            extern_symbol: String::new(),
            result_type: "Int".into(),
            body_node: Some(body),
            parameters: vec![],
            ffi_contract: None,
            scoped_byte_copy: None,
        });
        self.program
    }
}

fn run(program: &Program, label: &str) -> std::process::ExitStatus {
    // No executable from a pre-repair worker is used. Validate the copy
    // authority and lower with this test binary's checked implementation.
    for (index, node) in program.nodes.iter().enumerate() {
        if node.collection_intrinsic.is_some() {
            validate_collection_pop(program, index).unwrap();
        }
    }
    let runtime = PathBuf::from(
        std::env::var_os("GUST_R4_RUNTIME_ARCHIVE")
            .expect("owning native test requires its built runtime archive"),
    );
    let root = PathBuf::from(
        std::env::var_os("GUST_R4_TEST_OUTPUT")
            .expect("owning native test requires an isolated output directory"),
    );
    fs::create_dir_all(&root).unwrap();
    let object = root.join(format!("{label}.o"));
    let output = root.join(label);
    assert!(!output.exists(), "test output must be fresh");
    lower_program(program, &object).unwrap();
    let bytes = fs::read(&object).unwrap();
    let parsed = object::File::parse(bytes.as_slice()).unwrap();
    for name in [SLOT_CHECK, STORAGE_CHECK] {
        let symbol = parsed
            .symbols()
            .find(|symbol| symbol.name().ok() == Some(name))
            .unwrap();
        assert!(
            symbol.is_definition() && symbol.is_local() && !symbol.is_global(),
            "checked machine helper must remain object-local, outside the runtime ABI"
        );
    }

    for (prefix, expected) in [
        (
            ELEMENT_CHECK,
            program.nodes.iter().any(|node| {
                node.kind == "IndexRead" || (node.kind == "Call" && node.text == "Set")
            }),
        ),
        (
            APPEND_CHECK,
            program
                .nodes
                .iter()
                .any(|node| node.kind == "Call" && node.text == "Push"),
        ),
    ] {
        let symbols: Vec<_> = parsed
            .symbols()
            .filter(|symbol| symbol.name().is_ok_and(|name| name.starts_with(prefix)))
            .collect();
        assert!(
            !expected || !symbols.is_empty(),
            "fixture must exercise its factored machine helper"
        );
        for symbol in symbols {
            assert!(
                symbol.is_definition() && symbol.is_local() && !symbol.is_global(),
                "layout-factored helpers must remain object-local"
            );
        }
    }

    let request = crate::CompilerMirLinkRequest {
        output_path: output.clone(),
        ordered_object_inputs: vec![object],
        c_source: None,
        host_object: None,
        runtime_package: Some(runtime),
        approved_package: None,
        additional_libraries: vec!["pthread".into(), "dl".into(), "m".into()],
        additional_linker_args: vec![],
        trailing_linker_args: vec![],
        linker_driver: "/usr/bin/cc".into(),
        link_via_rustc: false,
        environment_overrides: vec![],
        expected_result: crate::CompilerMirLinkExpectedResult::Success,
        expected_failure_kind: None,
    };
    let report = crate::run_compiler_mir_link_request(request).unwrap();
    assert!(report.published, "native link did not publish: {report:?}");
    Command::new("/bin/sh")
        .args(["-c", "ulimit -c 0; exec \"$1\"", "checked-collection"])
        .arg(output)
        .env_clear()
        .env("PATH", "/usr/bin:/bin")
        .status()
        .unwrap()
}

#[test]
fn user_symbols_cannot_impersonate_checked_helpers() {
    // Exercise declaration admission only: no colliding object is defined,
    // written, linked, or executed, even if an assertion regresses.
    for route in ["qualified", "extern", "synthetic"] {
        for reserved in [false, true] {
            let name = if reserved {
                ".gust.checked_probe"
            } else {
                "ordinary_probe"
            };
            let mut example = Example::new("Int");
            let result = example.integer(0);
            if route == "synthetic" {
                let callee = example.local(name, "Void");
                let call = example.node("Call", "Int", name, vec![callee]);
                example.evaluate(call);
            }
            let mut program = example.finish(result);
            if route == "qualified" {
                let mut function = program.functions[program.entry_function].clone();
                function.source_name = name.into();
                function.qualified_name = name.into();
                program.functions.push(function);
            } else if route == "extern" {
                program.functions.push(Function {
                    module_index: 0,
                    source_name: "ordinary_external".into(),
                    qualified_name: "ordinary_external".into(),
                    is_extern: true,
                    extern_symbol: name.into(),
                    result_type: "Int".into(),
                    body_node: None,
                    parameters: vec![],
                    ffi_contract: None,
                    scoped_byte_copy: None,
                });
            }
            let mut compiler = FullProgramCompiler::new(&program).unwrap();
            let declared = compiler.declare_program();
            if reserved {
                assert_eq!(
                    declared.unwrap_err().to_string(),
                    "checked collection helper namespace is compiler-private",
                    "{route}"
                );
            } else {
                declared.unwrap();
            }
        }
    }
}

#[test]
#[ignore = "owning R4 native guard supplies isolated output and exact runtime"]
fn valid_stride_growth_set_and_pop_preserve_copy() {
    for element in ["Int", "Byte", "Bool"] {
        let mut example = Example::new(element);
        for value in 0..9 {
            example.push(if element == "Bool" { 1 } else { value });
        }
        let at = example.integer(0);
        let value = example.integer(1);
        let value = if element == "Int" {
            value
        } else {
            example.node("ExplicitCast", element, "", vec![value])
        };
        let set = example.method("values", "Set", "Void", vec![at, value]);
        example.evaluate(set);
        let ty = example.vector_type.clone();
        let snapshot = example.local("values", &ty);
        example.declare("snapshot", &ty, snapshot);
        let popped = example.method("values", "Pop", element, vec![]);
        example.evaluate(popped);
        let result = example.read("snapshot", 8);
        assert_eq!(
            run(&example.finish(result), &format!("copy-{element}")).code(),
            Some(if element == "Bool" { 1 } else { 8 })
        );
    }
}

#[test]
#[ignore = "owning R4 native guard supplies isolated output and exact runtime"]
fn invalid_index_and_empty_pop_trap_before_access() {
    for (label, index) in [("negative-read", -1), ("equal-length-read", 1)] {
        let mut example = Example::new("Int");
        example.push(7);
        let result = example.read("values", index);
        let status = run(&example.finish(result), label);
        assert_eq!(
            status.signal(),
            Some(4),
            "expected native trap, not invalid-memory signal: {status}"
        );
    }
    for (label, index) in [("negative-set", -1), ("equal-length-set", 1)] {
        let mut example = Example::new("Int");
        example.push(7);
        let at = example.integer(index);
        let value = example.integer(3);
        let set = example.method("values", "Set", "Void", vec![at, value]);
        example.evaluate(set);
        let result = example.integer(0);
        assert_eq!(run(&example.finish(result), label).signal(), Some(4));
    }
    let mut example = Example::new("Int");
    let result = example.method("values", "Pop", "Int", vec![]);
    assert_eq!(run(&example.finish(result), "empty-pop").signal(), Some(4));
}

#[test]
#[ignore = "owning R4 native guard supplies isolated output and exact runtime"]
fn pop_preserves_a_live_reference_value_in_a_copy() {
    let element = "Reference(Int, None)";
    let mut example = Example::new(element);
    let value = example.integer(17);
    example.declare("cell", "Int", value);
    let cell = example.local("cell", "Int");
    let borrowed = example.node("AddressOf", element, "", vec![cell]);
    let push = example.method("values", "Push", "Void", vec![borrowed]);
    example.evaluate(push);
    let ty = example.vector_type.clone();
    let snapshot = example.local("values", &ty);
    example.declare("snapshot", &ty, snapshot);
    let pop = example.method("values", "Pop", element, vec![]);
    example.evaluate(pop);
    let reference = example.read("snapshot", 0);
    let observed = example.node("Dereference", "Int", "", vec![reference]);
    assert_eq!(
        run(&example.finish(observed), "copy-live-reference").code(),
        Some(17)
    );
}

#[test]
#[ignore = "owning R4 native guard supplies isolated output and exact runtime"]
fn operands_snapshot_after_a_value_operand_grows_the_same_receiver() {
    for method in ["Push", "Set"] {
        let mut example = Example::new("Int");
        for value in 0..8 {
            example.push(value);
        }
        // Build a separately declared function whose argument is an actual
        // borrowed collection. It appends while the outer Push evaluates its value.
        let ty = example.vector_type.clone();
        let borrowed_ty = format!("Reference({ty}, None)");
        let borrowed = example.local("borrowed", &borrowed_ty);
        let callee = example.node("FieldOrMethodSelect", "Void", "Push", vec![borrowed]);
        let eleven = example.integer(11);
        let push = example.node("Call", "Void", "Push", vec![callee, eleven]);
        let evaluate = example.node("Evaluate", "Void", "", vec![push]);
        let forty_two = example.integer(42);
        let ret = example.node("Return", "Void", "", vec![forty_two]);
        let body = example.node("Block", "Void", "", vec![evaluate, ret]);
        example.program.functions.push(Function {
            module_index: 0,
            source_name: "append_then_value".into(),
            qualified_name: "append_then_value".into(),
            is_extern: false,
            extern_symbol: String::new(),
            result_type: "Int".into(),
            body_node: Some(body),
            parameters: vec![("borrowed".into(), borrowed_ty.clone())],
            ffi_contract: None,
            scoped_byte_copy: None,
        });
        let values = example.local("values", &ty);
        let address = example.node("AddressOf", &borrowed_ty, "", vec![values]);
        let callee = example.local("append_then_value", "Void");
        let value = example.node("Call", "Int", "append_then_value", vec![callee, address]);
        example.program.nodes[value].second_text = "append_then_value".into();
        let at = example.integer(8);
        let args = if method == "Push" {
            vec![value]
        } else {
            vec![at, value]
        };
        let operation = example.method("values", method, "Void", args);
        example.evaluate(operation);
        let first = example.read("values", 8);
        let result = if method == "Push" {
            let second = example.read("values", 9);
            example.node("BinaryOperation", "Int", "+", vec![first, second])
        } else {
            first
        };
        assert_eq!(
            run(
                &example.finish(result),
                &format!("operand-reentrant-{method}")
            )
            .code(),
            Some(if method == "Push" { 53 } else { 42 })
        );
    }
}

#[test]
#[ignore = "owning R4 native guard supplies isolated output and exact runtime"]
fn growth_boundaries_use_allocator_bytes_without_i32_byte_ceiling() {
    let root = PathBuf::from(std::env::var_os("GUST_R4_TEST_OUTPUT").unwrap());
    fs::create_dir_all(&root).unwrap();
    for (label, cap, stride, fails) in [
        ("large-valid-byte-count", 1 << 28, 8, false),
        ("growth-count-overflow", 1 << 30, 1, true),
        ("growth-byte-overflow", 1 << 28, 16, true),
    ] {
        let target = target_object_builder(&Example::new("Int").program).unwrap();
        let mut module = ObjectModule::new(target);
        let mut context = module.make_context();
        context
            .func
            .signature
            .returns
            .push(AbiParam::new(types::I32));
        let id = module
            .declare_function("main", Linkage::Export, &context.func.signature)
            .unwrap();
        let mut frontend = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut context.func, &mut frontend);
            let entry = builder.create_block();
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let capacity = builder.ins().iconst(types::I32, cap);
            let arena_capacity = builder.ins().iconst(types::I64, 1i64 << 32);
            let stride = builder.ins().iconst(types::I64, i64::from(stride));
            let (_, bytes) = checked_growth(&mut builder, capacity, stride, arena_capacity);
            if !fails {
                let exact = builder.ins().icmp_imm(IntCC::Equal, bytes, 1i64 << 32);
                builder.ins().trapz(exact, trap());
            }
            let result = builder.ins().iconst(types::I32, 7);
            builder.ins().return_(&[result]);
            builder.finalize();
        }
        // Read back the emitted mechanism before interpreting a failure:
        // this probe contains native trap checks and no loads, stores or allocator call.
        let ir = context.func.display().to_string();
        assert!(ir.contains("trapz"));
        assert!(!ir.contains("load"));
        assert!(!ir.contains("store"));
        assert!(!ir.contains("call"));
        module.define_function(id, &mut context).unwrap();
        let object = root.join(format!("{label}.o"));
        fs::write(&object, module.finish().emit().unwrap()).unwrap();
        let output = root.join(label);
        assert!(!output.exists());
        let linked = Command::new("/usr/bin/cc")
            .arg(&object)
            .arg("-o")
            .arg(&output)
            .output()
            .unwrap();
        assert!(
            linked.status.success(),
            "{}",
            String::from_utf8_lossy(&linked.stderr)
        );
        let status = Command::new("/bin/sh")
            .args(["-c", "ulimit -c 0; exec \"$1\"", "growth-probe"])
            .arg(&output)
            .status()
            .unwrap();
        if fails {
            assert_eq!(
                status.signal(),
                Some(4),
                "{label}: expected native overflow trap"
            );
        } else {
            assert_eq!(status.code(), Some(7));
        }
    }
}

#[test]
fn copy_pop_rejects_operand_layout_and_brand_substitution() {
    let mut example = Example::new("Int");
    example.push(7);
    let pop = example.method("values", "Pop", "Int", vec![]);
    let mut program = example.finish(pop);
    validate_collection_pop(&program, pop).unwrap();
    for field in ["receiver", "element", "layout", "brand", "opcode"] {
        let original = program.nodes[pop].collection_intrinsic.clone();
        let plan = program.nodes[pop].collection_intrinsic.as_mut().unwrap();
        match field {
            "receiver" => plan.receiver_type = "Int".into(),
            "element" => plan.element_type = "Byte".into(),
            "layout" => plan.layout_id.push_str("_substituted"),
            "brand" => plan.brand.push_str("_substituted"),
            _ => plan.opcode = "Clear".into(),
        }
        assert!(
            validate_collection_pop(&program, pop).is_err(),
            "accepted {field} mutation"
        );
        program.nodes[pop].collection_intrinsic = original;
    }
}
