//! Phase 17.6 Rust runtime components.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_rust_runtime.v1";
const WITNESS_FORMAT: &str = "gust.rust_runtime_witness.v1";
const LINKAGE: &str = "independently_compiled_component_no_source_specific_c_generation";

const PANIC_BOUNDARIES: [&str; 2] = [
    "abort_no_unwind_across_ffi",
    "catch_unwind_converted_to_explicit_error",
];
const ALLOCATION_BOUNDARIES: [&str; 2] = [
    "no_allocation_caller_owns_all_memory",
    "allocates_in_caller_supplied_arena",
];
const OBJECT_FORMS: [&str; 2] = ["static_library", "deterministic_object_set"];

#[derive(Debug)]
pub struct RustRuntimeError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for RustRuntimeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_rust_runtime_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for RustRuntimeError {}

fn error(reason: &'static str, detail: impl Into<String>) -> RustRuntimeError {
    RustRuntimeError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct RustComponent {
    pub component_id: String,
    pub source_ownership: String,
    pub exports: Vec<String>,
    pub object_form: String,
    pub panic_boundary: String,
    pub allocation_boundary: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, RustRuntimeError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_rust_undeclared_export", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, RustRuntimeError> {
    let body = line
        .strip_prefix("rust_component:")
        .ok_or_else(|| error("runtime_rust_undeclared_export", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_rust_undeclared_export", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_rust_duplicate_symbol_provider", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, RustRuntimeError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_rust_undeclared_export", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<RustComponent, RustRuntimeError> {
    for key in ["id", "component", "ownership", "exports"] {
        if field(f, key).is_err() {
            return Err(error("runtime_rust_undeclared_export", format!("missing {key}")));
        }
    }
    let row_target = field(f, "target")?;
    if row_target != target {
        return Err(error(
            "runtime_rust_abi_or_target_mismatch",
            format!("{row_target} disagrees with request target"),
        ));
    }
    let object_form = field(f, "object_form")?;
    if !OBJECT_FORMS.contains(&object_form) {
        return Err(error(
            "runtime_rust_abi_or_target_mismatch",
            format!("unsupported object form {object_form}"),
        ));
    }
    let panic_boundary = field(f, "panic_boundary")?;
    if !PANIC_BOUNDARIES.contains(&panic_boundary) {
        return Err(error(
            "runtime_rust_unwind_boundary_violation",
            format!("unsupported panic boundary {panic_boundary}"),
        ));
    }
    let allocation_boundary = field(f, "allocation_boundary")?;
    if !ALLOCATION_BOUNDARIES.contains(&allocation_boundary) {
        return Err(error(
            "runtime_rust_unwind_boundary_violation",
            format!("unsupported allocation boundary {allocation_boundary}"),
        ));
    }
    let imports = field(f, "imports")?;
    if imports.contains("generated_c_shim") {
        return Err(error(
            "runtime_rust_generated_c_glue_dependency",
            "component imports generated C glue",
        ));
    }
    let exports: Vec<String> = field(f, "exports")?.split(',').map(str::to_owned).collect();
    if exports.iter().any(|e| e == "none" || e.is_empty()) {
        return Err(error("runtime_rust_undeclared_export", "component exports nothing"));
    }
    Ok(RustComponent {
        component_id: field(f, "component")?.to_owned(),
        source_ownership: field(f, "ownership")?.to_owned(),
        exports,
        object_form: object_form.to_owned(),
        panic_boundary: panic_boundary.to_owned(),
        allocation_boundary: allocation_boundary.to_owned(),
    })
}

pub fn parse_rust_runtime_request(
    request: &str,
) -> Result<(String, Vec<RustComponent>), RustRuntimeError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_rust_undeclared_export", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<RustComponent> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("rust_component:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.component_id == component.component_id
                || existing.exports.iter().any(|e| component.exports.contains(e))
            {
                return Err(error(
                    "runtime_rust_duplicate_symbol_provider",
                    format!("{} duplicates an earlier provider", component.component_id),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_rust_undeclared_export", "no declared components"));
    }
    Ok((target, components))
}

pub fn render_rust_runtime_witness(target: &str, components: &[RustComponent]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("component:");
        out.push_str(&format!("component={};", c.component_id));
        out.push_str(&format!("ownership={};", c.source_ownership));
        out.push_str(&format!("exports={};", c.exports.join(",")));
        out.push_str(&format!("object_form={};", c.object_form));
        out.push_str(&format!("panic_boundary={};", c.panic_boundary));
        out.push_str(&format!("allocation_boundary={};", c.allocation_boundary));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_rust_runtime_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_rust_runtime_request(&request)?;
    Ok(render_rust_runtime_witness(&target, &components))
}
