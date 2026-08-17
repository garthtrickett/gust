//! Phase 17.9 generated C shim elimination.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_shim_elimination.v1";
const WITNESS_FORMAT: &str = "gust.shim_elimination_witness.v1";
const LINKAGE: &str = "native_path_emits_no_program_specific_c";

const EVIDENCE_POLICY: &str = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
const BANNED_CLASSES: [&str; 6] = [
    "runtime_call_wrapper",
    "abi_adaptation_wrapper",
    "resource_or_cleanup_wrapper",
    "allocation_or_string_helper_wrapper",
    "io_filesystem_or_threading_wrapper",
    "target_selection_wrapper_fragment",
];
const REPLACEMENT_KINDS: [&str; 3] = [
    "compiler_owned_direct_import",
    "explicit_runtime_component",
    "narrower_explicit_deferral",
];

#[derive(Debug)]
pub struct ShimEliminationError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for ShimEliminationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_shim_elimination_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for ShimEliminationError {}

fn error(reason: &'static str, detail: impl Into<String>) -> ShimEliminationError {
    ShimEliminationError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct ShimBan {
    pub banned_class: String,
    pub obsolete_family: String,
    pub replacement_kind: String,
    pub replacement_component: String,
    pub evidence_policy: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, ShimEliminationError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_shim_unclassified_ban", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, ShimEliminationError> {
    let body = line
        .strip_prefix("shim_ban:")
        .ok_or_else(|| error("runtime_shim_unclassified_ban", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_shim_unclassified_ban", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_shim_duplicate_ban", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, ShimEliminationError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_shim_unclassified_ban", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<ShimBan, ShimEliminationError> {
    for key in ["id", "banned_class", "obsolete_family"] {
        if field(f, key).is_err() {
            return Err(error("runtime_shim_unclassified_ban", format!("missing {key}")));
        }
    }
    let banned_class = field(f, "banned_class")?;
    if !BANNED_CLASSES.contains(&banned_class) {
        return Err(error(
            "runtime_shim_unclassified_ban",
            format!("unclassified wrapper class {banned_class}"),
        ));
    }
    if field(f, "target")? != target {
        return Err(error("runtime_shim_unclassified_ban", "target disagrees with request"));
    }

    // A ban is only credible if something compiler-owned replaced it.
    let replacement_kind = field(f, "replacement_kind")?;
    if !REPLACEMENT_KINDS.contains(&replacement_kind) {
        return Err(error(
            "runtime_shim_ban_without_replacement",
            format!("unsupported replacement kind {replacement_kind}"),
        ));
    }
    let replacement_component = f
        .get("replacement_component")
        .cloned()
        .unwrap_or_default();
    if replacement_kind != "narrower_explicit_deferral" && replacement_component.is_empty() {
        return Err(error(
            "runtime_shim_ban_without_replacement",
            format!("{banned_class} names no replacement component"),
        ));
    }

    // The evidence policy is load-bearing: the native path must be shown to
    // work with no C compiler available, not merely declared glue-free.
    let evidence_policy = field(f, "evidence")?;
    if evidence_policy != EVIDENCE_POLICY {
        return Err(error(
            "runtime_shim_missing_evidence",
            format!("unsupported evidence policy {evidence_policy}"),
        ));
    }
    Ok(ShimBan {
        banned_class: banned_class.to_owned(),
        obsolete_family: field(f, "obsolete_family")?.to_owned(),
        replacement_kind: replacement_kind.to_owned(),
        replacement_component,
        evidence_policy: evidence_policy.to_owned(),
    })
}

pub fn parse_shim_elimination_request(
    request: &str,
) -> Result<(String, Vec<ShimBan>), ShimEliminationError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_shim_unclassified_ban", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<ShimBan> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("shim_ban:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.banned_class == component.banned_class {
                return Err(error(
                    "runtime_shim_duplicate_ban",
                    format!("{} is banned twice", component.banned_class),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_shim_unclassified_ban", "no declared bans"));
    }
    Ok((target, components))
}

pub fn render_shim_elimination_witness(target: &str, components: &[ShimBan]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("ban:");
        out.push_str(&format!("banned_class={};", c.banned_class));
        out.push_str(&format!("obsolete_family={};", c.obsolete_family));
        out.push_str(&format!("replacement_kind={};", c.replacement_kind));
        out.push_str(&format!("replacement_component={};", c.replacement_component));
        out.push_str(&format!("evidence={};", c.evidence_policy));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_shim_elimination_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_shim_elimination_request(&request)?;
    Ok(render_shim_elimination_witness(&target, &components))
}
