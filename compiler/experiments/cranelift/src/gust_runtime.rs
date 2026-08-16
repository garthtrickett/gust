//! Phase 17.8 pure Gust runtime modules.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_gust_runtime.v1";
const WITNESS_FORMAT: &str = "gust.gust_runtime_witness.v1";
const LINKAGE: &str = "generic_canonical_mir_route_no_bespoke_recognition";

const GENERIC_ROUTE: &str = "generic_parse_typecheck_canonical_mir_abi_cranelift";
const MODULE_SOURCE_PREFIX: &str = "src/runtime/gust/";
const INITIALIZATION_POLICIES: [&str; 2] = [
    "none_required_pure_functions",
    "explicit_caller_invoked_initializer",
];

#[derive(Debug)]
pub struct GustRuntimeError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for GustRuntimeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_runtime_module_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for GustRuntimeError {}

fn error(reason: &'static str, detail: impl Into<String>) -> GustRuntimeError {
    GustRuntimeError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct GustModule {
    pub component_id: String,
    pub source: String,
    pub exports: Vec<String>,
    pub lowering_route: String,
    pub initialization_policy: String,
    pub failure_policy: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, GustRuntimeError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_gust_missing_requirement", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, GustRuntimeError> {
    let body = line
        .strip_prefix("gust_module:")
        .ok_or_else(|| error("runtime_gust_missing_requirement", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_gust_missing_requirement", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_gust_circular_dependency", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, GustRuntimeError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_gust_missing_requirement", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<GustModule, GustRuntimeError> {
    for key in ["id", "component", "source", "exports"] {
        if field(f, key).is_err() {
            return Err(error("runtime_gust_missing_requirement", format!("missing {key}")));
        }
    }
    let row_target = field(f, "target")?;
    if row_target != target {
        return Err(error(
            "runtime_gust_abi_or_target_mismatch",
            format!("{row_target} disagrees with request target"),
        ));
    }

    // Only the generic route is legal. Anything else means the compiler
    // recognised this module, which is exactly what Patch 17.8 forbids.
    let lowering_route = field(f, "lowering_route")?;
    if lowering_route != GENERIC_ROUTE {
        return Err(error(
            "runtime_gust_non_generic_lowering",
            format!("non-generic lowering route {lowering_route}"),
        ));
    }
    let initialization_policy = field(f, "initialization")?;
    if !INITIALIZATION_POLICIES.contains(&initialization_policy) {
        return Err(error(
            "runtime_gust_missing_requirement",
            format!("undeclared initialization policy {initialization_policy}"),
        ));
    }

    // Runtime Gust source is repository Gust, never generated C.
    let source = field(f, "source")?;
    if !source.starts_with(MODULE_SOURCE_PREFIX) || !source.ends_with(".gst") {
        return Err(error(
            "runtime_gust_hidden_generated_c",
            format!("{source} is not a repository Gust runtime module"),
        ));
    }

    // A module may not depend on its own component.
    let component_id = field(f, "component")?;
    let dependencies = field(f, "dependencies")?;
    if dependencies.split(',').any(|d| d == component_id) {
        return Err(error(
            "runtime_gust_circular_dependency",
            format!("{component_id} depends on itself"),
        ));
    }

    let exports: Vec<String> = field(f, "exports")?.split(',').map(str::to_owned).collect();
    if exports.iter().any(|e| e == "none" || e.is_empty()) {
        return Err(error("runtime_gust_missing_requirement", "module exports nothing"));
    }
    Ok(GustModule {
        component_id: component_id.to_owned(),
        source: source.to_owned(),
        exports,
        lowering_route: lowering_route.to_owned(),
        initialization_policy: initialization_policy.to_owned(),
        failure_policy: field(f, "failure")?.to_owned(),
    })
}

pub fn parse_gust_runtime_request(
    request: &str,
) -> Result<(String, Vec<GustModule>), GustRuntimeError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_gust_missing_requirement", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<GustModule> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("gust_module:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.component_id == component.component_id
                || existing.exports.iter().any(|e| component.exports.contains(e))
            {
                return Err(error(
                    "runtime_gust_circular_dependency",
                    format!("{} duplicates an earlier provider", component.component_id),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_gust_missing_requirement", "no declared components"));
    }
    Ok((target, components))
}

pub fn render_gust_runtime_witness(target: &str, components: &[GustModule]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("module:");
        out.push_str(&format!("component={};", c.component_id));
        out.push_str(&format!("source={};", c.source));
        out.push_str(&format!("exports={};", c.exports.join(",")));
        out.push_str(&format!("lowering_route={};", c.lowering_route));
        out.push_str(&format!("initialization={};", c.initialization_policy));
        out.push_str(&format!("failure={};", c.failure_policy));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_gust_runtime_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_gust_runtime_request(&request)?;
    Ok(render_gust_runtime_witness(&target, &components))
}
