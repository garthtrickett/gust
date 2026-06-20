use std::env;
use std::path::Path;
use std::process::Command;

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
