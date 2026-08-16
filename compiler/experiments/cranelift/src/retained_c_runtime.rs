//! Phase 17.7 retained C runtime components.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_retained_c_runtime.v1";
const WITNESS_FORMAT: &str = "gust.retained_c_runtime_witness.v1";
const LINKAGE: &str = "separately_compiled_component_no_program_derived_c_source";

const RETENTION_REASONS: [&str; 3] = [
    "awaiting_pure_gust_migration",
    "awaiting_rust_component_migration",
    "host_platform_primitive_no_gust_equivalent",
];
const OWNED_SOURCE_PREFIX: &str = "src/runtime/";

#[derive(Debug)]
pub struct RetainedCError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for RetainedCError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_retained_c_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for RetainedCError {}

fn error(reason: &'static str, detail: impl Into<String>) -> RetainedCError {
    RetainedCError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct RetainedCComponent {
    pub component_id: String,
    pub sources: Vec<String>,
    pub exports: Vec<String>,
    pub retention_reason: String,
    pub removal_criterion: String,
    pub destination_phase: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, RetainedCError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_retained_c_anonymous_object", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, RetainedCError> {
    let body = line
        .strip_prefix("retained_c:")
        .ok_or_else(|| error("runtime_retained_c_anonymous_object", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_retained_c_anonymous_object", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_retained_c_duplicate_provider", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, RetainedCError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_retained_c_anonymous_object", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<RetainedCComponent, RetainedCError> {
    for key in ["id", "component", "sources", "exports", "build_inputs"] {
        if field(f, key).is_err() {
            return Err(error("runtime_retained_c_anonymous_object", format!("missing {key}")));
        }
    }
    let row_target = field(f, "target")?;
    if row_target != target {
        return Err(error(
            "runtime_retained_c_hidden_target_assumption",
            format!("{row_target} disagrees with request target"),
        ));
    }
    if field(f, "applicability")? != "all_declared_host_targets_from_phase14_target_authority" {
        return Err(error(
            "runtime_retained_c_hidden_target_assumption",
            "undeclared target applicability",
        ));
    }

    // Retention is temporary by contract: a justified reason, a concrete exit.
    let retention_reason = field(f, "retention_reason")?;
    if !RETENTION_REASONS.contains(&retention_reason) {
        return Err(error(
            "runtime_retained_c_anonymous_object",
            format!("unjustified retention reason {retention_reason}"),
        ));
    }
    let removal_criterion = field(f, "removal_criterion")?.to_owned();
    let destination_phase = field(f, "destination_phase")?.to_owned();

    // Sources are owned repository files, never fragments generated from a
    // compiled program's canonical MIR.
    let sources: Vec<String> = field(f, "sources")?.split(',').map(str::to_owned).collect();
    for source in &sources {
        if !source.starts_with(OWNED_SOURCE_PREFIX)
            || source.contains("generated")
            || source.contains("build/")
        {
            return Err(error(
                "runtime_retained_c_program_specific_generation",
                format!("{source} is not an owned runtime source"),
            ));
        }
    }

    let exports: Vec<String> = field(f, "exports")?.split(',').map(str::to_owned).collect();
    if exports.iter().any(|e| e == "none" || e.is_empty()) {
        return Err(error("runtime_retained_c_unversioned_export", "component exports nothing"));
    }
    Ok(RetainedCComponent {
        component_id: field(f, "component")?.to_owned(),
        sources,
        exports,
        retention_reason: retention_reason.to_owned(),
        removal_criterion,
        destination_phase,
    })
}

pub fn parse_retained_c_request(
    request: &str,
) -> Result<(String, Vec<RetainedCComponent>), RetainedCError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_retained_c_anonymous_object", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<RetainedCComponent> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("retained_c:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.component_id == component.component_id
                || existing.exports.iter().any(|e| component.exports.contains(e))
            {
                return Err(error(
                    "runtime_retained_c_duplicate_provider",
                    format!("{} duplicates an earlier provider", component.component_id),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_retained_c_anonymous_object", "no declared components"));
    }
    Ok((target, components))
}

pub fn render_retained_c_witness(target: &str, components: &[RetainedCComponent]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("component:");
        out.push_str(&format!("component={};", c.component_id));
        out.push_str(&format!("sources={};", c.sources.join(",")));
        out.push_str(&format!("exports={};", c.exports.join(",")));
        out.push_str(&format!("retention_reason={};", c.retention_reason));
        out.push_str(&format!("removal_criterion={};", c.removal_criterion));
        out.push_str(&format!("destination_phase={};", c.destination_phase));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_retained_c_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_retained_c_request(&request)?;
    Ok(render_retained_c_witness(&target, &components))
}
