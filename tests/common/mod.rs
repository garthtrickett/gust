use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::OnceLock;
use gust_lexer::resolver::ModuleResolver;
use gust_lexer::resolver::RealFileSystem;
use gust_lexer::typechecker::TypeChecker;
use gust_lexer::codegen::Codegen;

pub fn compile_c_program(c_path: &Path, bin_path: &Path, c_code: &str) {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
    let runtime_path = Path::new(&manifest_dir).join("src/runtime.c");

    println!(
        "DEBUG: Running CC command: {} {:?} {:?}",
        std::env::var("CC").unwrap_or_else(|_| "cc".to_string()),
        runtime_path,
        c_path
    );

    // The CC environment variable is set by your nix flake, use it directly.
    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());

    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&runtime_path);
    cmd.arg(c_path);

    // Add sanitizers unless explicitly disabled
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }

    let compile_output = cmd
        .arg("-o")
        .arg(bin_path)
        .output()
        .expect("C compilation command failed");

    if !compile_output.status.success() {
        eprintln!("====================================================");
        eprintln!("❌ C COMPILATION FAILED!");
        eprintln!("====================================================");
        eprintln!("--- GENERATED C CODE ---");
        for (idx, line) in c_code.lines().enumerate() {
            eprintln!("{:4} | {}", idx + 1, line);
        }
        eprintln!("------------------------");
        eprintln!(
            "STDERR:\n{}",
            String::from_utf8_lossy(&compile_output.stderr)
        );
        eprintln!("====================================================");
        panic!(
            "Compilation failed: {}",
            String::from_utf8_lossy(&compile_output.stderr)
        );
    }
}

#[allow(dead_code)]
static COMPILED_COMPILER: OnceLock<PathBuf> = OnceLock::new();

#[allow(dead_code)]
pub fn get_compiled_compiler() -> &'static Path {
    COMPILED_COMPILER.get_or_init(|| {
        std::thread::Builder::new()
            .stack_size(104857600) // 100 MB
            .spawn(|| {
                let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
                let entry_path = Path::new(&manifest_dir).join("compiler/test_runner_entry.gst");

                let resolver = ModuleResolver::new();
                let fs_impl = RealFileSystem;

                let (order, mut modules) = resolver
                    .resolve(&entry_path, &fs_impl)
                    .expect("Failed to resolve test_runner_entry.gst dependencies");

                let mut checker = TypeChecker::new();
                for path in &order {
                    if let Some(module) = modules.get(path) {
                        let stem = path.file_stem().unwrap().to_str().unwrap();
                        let is_entry = path == order.last().unwrap();
                        let prefix = if is_entry {
                            "".to_string()
                        } else {
                            format!("{}__", stem)
                        };
                        checker
                            .check_module(&module.program, &prefix)
                            .expect("Typechecking failed during self-host bootstrap compilation");
                    } 
                }

                let mut modules_for_codegen = Vec::new();
                for path in &order {
                    if let Some(module) = modules.get_mut(path) {
                        modules_for_codegen.push((path.clone(), module.program.clone()));
                    }
                }

                let codegen = Codegen::new(
                    checker.variable_types,
                    checker.struct_registry,
                    checker.function_registry,
                    checker.enum_registry,
                    checker.resolved_names,
                    checker.resolved_types,
                );
                let c_output = codegen.generate(&modules_for_codegen);

                let temp_dir = env::temp_dir();
                let thread_id = std::thread::current().id();
                let process_id = std::process::id();

                let c_filename = format!("bootstrap_gust_v2_{:?}_{}.c", thread_id, process_id);
                let bin_filename = format!("bootstrap_gust_v2_bin_{:?}_{}", thread_id, process_id);

                let c_path = temp_dir.join(c_filename);
                let bin_path = temp_dir.join(bin_filename);

                std::fs::write(&c_path, &c_output).expect("Failed to write temporary compiler C file");

                compile_c_program(&c_path, &bin_path, &c_output);

                let _ = std::fs::remove_file(&c_path);

                bin_path
            })
            .unwrap()
            .join()
            .unwrap()
    })
}
