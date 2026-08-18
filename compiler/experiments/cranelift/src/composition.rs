//! Phase 17.14 cross-feature composition cases.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_composition.v1";
const WITNESS_FORMAT: &str = "gust.composition_witness.v1";
const LINKAGE: &str = "every_migrated_authority_participates_in_at_least_one_composition";

/// The eight nested combinations Patch 17.14 requires. All must be present:
/// a partial inventory leaves some interaction between capabilities unproven.
const COMPOSITION_KINDS: [&str; 8] = [
    "allocation_then_string_formatting_and_output",
    "resource_bearing_aggregate_across_runtime_call",
    "directory_acquire_branch_early_return_cleanup",
    "gust_runtime_helper_calling_stable_import",
    "rust_and_retained_c_in_one_package",
    "thread_helper_using_resource_cleanup",
    "compatible_package_from_target_candidates",
    "incompatible_version_preserving_sentinel",
];
const SENTINEL_POLICIES: [&str; 2] = [
    "sentinel_output_preserved_on_failure",
    "case_cannot_fail_no_output_to_preserve",
];

#[derive(Debug)]
pub struct CompositionError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for CompositionError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_composition_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for CompositionError {}

fn error(reason: &'static str, detail: impl Into<String>) -> CompositionError {
    CompositionError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct CompositionCase {
    pub composition_kind: String,
    pub participants: Vec<String>,
    pub differential_owner: String,
    pub sentinel_policy: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, CompositionError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_composition_malformed_case", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, CompositionError> {
    let body = line
        .strip_prefix("composition_case:")
        .ok_or_else(|| error("runtime_composition_malformed_case", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_composition_malformed_case", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_composition_missing_sentinel_policy", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, CompositionError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_composition_malformed_case", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<CompositionCase, CompositionError> {
    for key in ["id", "kind", "participants"] {
        if field(f, key).is_err() {
            return Err(error("runtime_composition_malformed_case", format!("missing {key}")));
        }
    }
    if field(f, "target")? != target {
        return Err(error("runtime_composition_malformed_case", "target disagrees with request"));
    }
    let composition_kind = field(f, "kind")?;
    if !COMPOSITION_KINDS.contains(&composition_kind) {
        return Err(error(
            "runtime_composition_unknown_kind",
            format!("{composition_kind} is not a required nested combination"),
        ));
    }

    // A case with nobody accountable for its differential is not evidence.
    let differential_owner = f.get("owner").cloned().unwrap_or_default();
    if differential_owner.is_empty() {
        return Err(error(
            "runtime_composition_no_differential_owner",
            format!("{composition_kind} names no differential owner"),
        ));
    }
    let sentinel_policy = field(f, "sentinel")?;
    if !SENTINEL_POLICIES.contains(&sentinel_policy) {
        return Err(error(
            "runtime_composition_missing_sentinel_policy",
            format!("{composition_kind} declares no sentinel policy"),
        ));
    }

    // A composition of one is not a composition.
    let participants: Vec<String> = field(f, "participants")?
        .split(',')
        .map(str::to_owned)
        .collect();
    if participants.len() < 2 || participants.iter().any(|p| p == "none" || p.is_empty()) {
        return Err(error(
            "runtime_composition_not_composed",
            format!("{composition_kind} composes {} authorities", participants.len()),
        ));
    }
    Ok(CompositionCase {
        composition_kind: composition_kind.to_owned(),
        participants,
        differential_owner,
        sentinel_policy: sentinel_policy.to_owned(),
    })
}

pub fn parse_composition_request(
    request: &str,
) -> Result<(String, Vec<CompositionCase>), CompositionError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_composition_malformed_case", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<CompositionCase> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("composition_case:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.composition_kind == component.composition_kind {
                return Err(error(
                    "runtime_composition_duplicate_case",
                    format!("{} is composed twice", component.composition_kind),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_composition_malformed_case", "no declared composition cases"));
    }
    // A partial inventory leaves some interaction between capabilities unproven.
    if components.len() != COMPOSITION_KINDS.len() {
        return Err(error(
            "runtime_composition_incomplete_inventory",
            format!("{} of {} combinations declared", components.len(), COMPOSITION_KINDS.len()),
        ));
    }
    // The failure case must state that existing output survives.
    let sentinel_case = components
        .iter()
        .find(|c| c.composition_kind == "incompatible_version_preserving_sentinel");
    match sentinel_case {
        Some(c) if c.sentinel_policy == "sentinel_output_preserved_on_failure" => {}
        _ => {
            return Err(error(
                "runtime_composition_missing_sentinel_policy",
                "the incompatible-version case must preserve sentinel output",
            ))
        }
    }
    Ok((target, components))
}

pub fn render_composition_witness(target: &str, components: &[CompositionCase]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("case:");
        out.push_str(&format!("kind={};", c.composition_kind));
        out.push_str(&format!("participants={};", c.participants.join(",")));
        out.push_str(&format!("owner={};", c.differential_owner));
        out.push_str(&format!("sentinel={};", c.sentinel_policy));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_composition_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_composition_request(&request)?;
    Ok(render_composition_witness(&target, &components))
}
