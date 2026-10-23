//! Phase 26.1 R1: signed, release-owned native package admission.
//!
//! A package directory is untrusted input. Only `VerifiedPackage::admit` can
//! produce link inputs, and the linker receives private copies of the bytes
//! whose hashes were verified. Production trust is pinned to the operator-owned
//! release identity and snapshot; package input cannot replace either.

use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Component, Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use ed25519_dalek::{Signature, VerifyingKey};
use object::read::archive::{ArchiveFile, ArchiveKind};
use object::{Architecture, BinaryFormat, Object, ObjectKind, ObjectSymbol};
use sha2::{Digest, Sha256};

use crate::full_program::{self, Program};

const FORMAT: &str = "gust.approved_native_package.v1";
const BYTE_SPAN_FORMAT: &str = "gust.approved_native_package.v2";
const SIGNED_DOMAIN: &[u8] = b"gust-approved-native-package-v1\0";
const BYTE_SPAN_SIGNED_DOMAIN: &[u8] = b"gust-approved-native-package-v2\0";
const MAX_MANIFEST: usize = 32 * 1024;
const MAX_ARTIFACT: u64 = 128 * 1024 * 1024;
const MAX_ARTIFACTS: usize = 16;
const MAX_SYMBOLS: usize = 64;
const REPOSITORY: &str = "garthtrickett/gust";
const TARGET: &str = "x86_64-unknown-linux-gnu";

#[derive(Debug)]
pub struct PackageError(String);

impl fmt::Display for PackageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}
impl Error for PackageError {}

fn reject(reason: impl Into<String>) -> PackageError {
    PackageError(format!(
        "approved native package rejected: {}",
        reason.into()
    ))
}

#[derive(Clone)]
pub struct TrustedKey {
    pub id: &'static str,
    pub public_key: [u8; 32],
    pub first_epoch: u64,
    pub last_epoch: u64,
}

/// The snapshot is part of the trusted worker release. Package files cannot
/// supply or update it. A separately distributed snapshot would need a new,
/// independently authenticated protocol.
pub struct TrustSnapshot<'a> {
    pub release: &'a str,
    pub release_epoch: u64,
    pub issued_unix_seconds: u64,
    pub expires_unix_seconds: u64,
    pub minimum_package_epoch: u64,
    pub keys: &'a [TrustedKey],
    pub revoked_keys: &'a [&'a str],
    pub withdrawn_digests: &'a [[u8; 32]],
}

// Dedicated operator-provisioned identity; fixture keys remain cfg(test)-only.
#[path = "production_trust.rs"]
mod production_trust;
pub const PRODUCTION_SNAPSHOT: TrustSnapshot<'static> = production_trust::SNAPSHOT;

/// This registry is release data, not a lookup derived from a request path or
/// an environment variable. The first release package is populated only after
/// its real signer and artifact are qualified. Test registries are not linked
/// into the production command path.
pub struct RegisteredPackage {
    pub id: &'static str,
    pub exports: &'static [&'static str],
}

pub const PRODUCTION_REGISTRY: &[RegisteredPackage] = production_trust::REGISTRY;

/// Versioned, exact-name projection of Phase 17 opening helper_inventory rows
/// marked runtime_public_surface/exact_c_symbol, cross-checked with current
/// helper_classifications. It is narrower than the Rust staticlib symbol
/// table, which also contains private Rust/toolchain symbols. The actual
/// archive must independently define each admitted spelling.
const PUBLIC_RUNTIME_PROJECTION: &str = include_str!("approved_runtime_exports.txt");
// R2 adds a separate, compiler-owned call-region ABI. Keep the Phase 17/R1
// projection immutable and require the owned archive to define each new name.
const R2_RUNTIME_PROJECTION: &str = include_str!("approved_r2_runtime_exports.txt");

pub fn public_runtime_definitions(path: &Path) -> Result<BTreeSet<String>, PackageError> {
    let defined = external_definitions(path, true)?;
    let mut permitted = BTreeSet::new();
    for (projection, version) in [
        (PUBLIC_RUNTIME_PROJECTION, "gust.r1.public_runtime_projection.v1"),
        (R2_RUNTIME_PROJECTION, "gust.r2.ffi_call_region_runtime_projection.v1"),
    ] {
        let mut lines = projection.lines();
        if lines.next() != Some(version) {
            return Err(reject("runtime projection version"));
        }
        for name in lines {
            if !safe_atom(name) || !permitted.insert(name.to_string()) {
                return Err(reject("runtime projection spelling or duplicate"));
            }
        }
    }
    permitted.retain(|name| defined.contains(name));
    Ok(permitted)
}

pub fn verify_foreign_coverage(
    program: &Program,
    registry: &[RegisteredPackage],
    requested_runtime: Option<&Path>,
    worker_runtime: &Path,
    historical_host_symbols: &[&str],
) -> Result<(), PackageError> {
    let selected = select(program, registry)?
        .ok_or_else(|| reject("no approved package selected"))?;
    if !historical_host_symbols.is_empty() {
        return Err(reject("approved package cannot mix historical test hosts"));
    }
    if full_program::unbound_runtime_call_symbols(program)
        .iter()
        .any(|(_, symbol)| selected.exports.contains(&symbol.as_str()))
    {
        return Err(reject("registered package call lacks an extern declaration"));
    }
    for call in program.nodes.iter().filter(|node|
        node.kind == "Call" && node.second_integer == 10) {
        let signed_extern = program.functions.iter().find(|function|
            function.is_extern && function.qualified_name == call.second_text &&
            selected.exports.contains(&function.extern_symbol.as_str()));
        if signed_extern.is_none() {
            return Err(reject("byte-span Call is outside selected package"));
        }
    }
    let mut other_externs: Vec<_> = program
        .functions
        .iter()
        .filter(|function| function.is_extern)
        .map(|function| function.extern_symbol.clone())
        .filter(|symbol| {
            !selected.exports.contains(&symbol.as_str())
                && !historical_host_symbols.contains(&symbol.as_str())
        })
        .collect();
    for (_, link_symbol) in full_program::unbound_runtime_call_symbols(program) {
        other_externs.push(link_symbol);
    }
    if requested_runtime != Some(worker_runtime) {
        return Err(reject("runtime archive differs from worker-owned package"));
    }
    if selected.id == production_trust::PACKAGE {
        let manifest = parse_manifest(production_trust::MANIFEST)?;
        let pin = manifest.artifacts.iter().find(|artifact|
            artifact.name == "gust-runtime-package.a")
            .ok_or_else(|| reject("production runtime pin absent"))?;
        let bytes = fs::read(worker_runtime).map_err(|_| reject("production runtime absent"))?;
        if <[u8; 32]>::from(Sha256::digest(bytes)) != pin.hash {
            return Err(reject("production runtime differs from signed artifact"));
        }
    }
    if other_externs.is_empty() {
        return Ok(());
    }
    let runtime_symbols = public_runtime_definitions(worker_runtime)?;
    verify_foreign_coverage_with_symbols(
        program,
        registry,
        &runtime_symbols,
        historical_host_symbols,
    )
}

fn verify_foreign_coverage_with_symbols(
    program: &Program,
    registry: &[RegisteredPackage],
    runtime_symbols: &BTreeSet<String>,
    historical_host_symbols: &[&str],
) -> Result<(), PackageError> {
    let selected = select(program, registry)?
        .ok_or_else(|| reject("no approved package selected"))?;
    if !historical_host_symbols.is_empty() {
        return Err(reject("approved package cannot mix historical test hosts"));
    }
    if full_program::unbound_runtime_call_symbols(program)
        .iter()
        .any(|(_, symbol)| selected.exports.contains(&symbol.as_str()))
    {
        return Err(reject("registered package call lacks an extern declaration"));
    }
    for call in program.nodes.iter().filter(|node|
        node.kind == "Call" && node.second_integer == 10) {
        let signed_extern = program.functions.iter().find(|function|
            function.is_extern && function.qualified_name == call.second_text &&
            selected.exports.contains(&function.extern_symbol.as_str()));
        if signed_extern.is_none() {
            return Err(reject("byte-span Call is outside selected package"));
        }
    }
    for function in program
        .functions
        .iter()
        .filter(|function| function.is_extern)
    {
        let symbol = function.extern_symbol.as_str();
        if selected.exports.contains(&symbol)
            || runtime_symbols.contains(symbol)
            || historical_host_symbols.contains(&symbol)
        {
            continue;
        }
        return Err(reject(format!(
            "unregistered foreign declaration: {symbol}"
        )));
    }
    for (source, link_symbol) in full_program::unbound_runtime_call_symbols(program) {
        if !runtime_symbols.contains(&link_symbol) {
            return Err(reject(format!(
                "unregistered runtime call: {source} -> {link_symbol}"
            )));
        }
    }
    Ok(())
}

pub fn select<'a>(
    program: &Program,
    registry: &'a [RegisteredPackage],
) -> Result<Option<&'a RegisteredPackage>, PackageError> {
    let mut selected = None;
    let unbound_calls = full_program::unbound_runtime_call_symbols(program);
    for package in registry {
        if !safe_atom(package.id)
            || package.exports.is_empty()
            || package.exports.iter().any(|name| !safe_atom(name))
        {
            return Err(reject("invalid release package registry"));
        }
        if program.functions.iter().any(|function| {
            function.is_extern && package.exports.contains(&function.extern_symbol.as_str())
        }) || unbound_calls.iter().any(|(_, symbol)| {
            package.exports.contains(&symbol.as_str())
        }) {
            if selected.is_some() {
                return Err(reject("ambiguous or mixed approved packages"));
            }
            selected = Some(package);
        }
    }
    Ok(selected)
}

pub fn installed_directory(package_id: &str) -> Result<PathBuf, PackageError> {
    if !safe_atom(package_id) {
        return Err(reject("invalid selected package ID"));
    }
    let binary = std::env::current_exe().map_err(|_| reject("worker location"))?;
    let parent = binary
        .parent()
        .ok_or_else(|| reject("worker has no parent directory"))?;
    Ok(parent.join("approved-packages").join(package_id))
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum ArtifactKind {
    Source,
    Header,
    BuildOptions,
    Object,
    Archive,
}

impl ArtifactKind {
    fn parse(value: &str) -> Result<Self, PackageError> {
        match value {
            "source" => Ok(Self::Source),
            "header" => Ok(Self::Header),
            "build_options" => Ok(Self::BuildOptions),
            "object" => Ok(Self::Object),
            "archive" => Ok(Self::Archive),
            _ => Err(reject("unknown artifact kind")),
        }
    }
    fn is_link_input(self) -> bool {
        matches!(self, Self::Object | Self::Archive)
    }
}

struct Artifact {
    kind: ArtifactKind,
    name: String,
    hash: [u8; 32],
}

struct SymbolContract {
    name: String,
    result_type: String,
    result_policy: String,
    parameters: Vec<(String, String)>,
    byte_spans: Vec<ByteSpanContract>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct ByteSpanContract {
    pointer_index: usize,
    count_index: usize,
    direction: &'static str,
}

struct Manifest {
    release: String,
    package_id: String,
    epoch: u64,
    signer: String,
    artifacts: Vec<Artifact>,
    symbols: Vec<SymbolContract>,
}

fn safe_atom(value: &str) -> bool {
    !value.is_empty()
        && value != "."
        && value != ".."
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-' | b'.'))
}

fn safe_file_name(value: &str) -> bool {
    safe_atom(value)
        && value != "."
        && value != ".."
        && Path::new(value)
            .components()
            .all(|part| matches!(part, Component::Normal(_)))
}

fn hex_bytes(value: &str, length: usize) -> Result<Vec<u8>, PackageError> {
    if value.len() != length * 2
        || !value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        return Err(reject("noncanonical hex length or character"));
    }
    let mut result = Vec::with_capacity(length);
    for pair in value.as_bytes().chunks_exact(2) {
        let high = (pair[0] as char)
            .to_digit(16)
            .ok_or_else(|| reject("bad hex"))?;
        let low = (pair[1] as char)
            .to_digit(16)
            .ok_or_else(|| reject("bad hex"))?;
        result.push(((high << 4) | low) as u8);
    }
    Ok(result)
}

fn hash32(value: &str) -> Result<[u8; 32], PackageError> {
    hex_bytes(value, 32)?
        .try_into()
        .map_err(|_| reject("bad digest width"))
}

pub fn hex_digest(digest: [u8; 32]) -> String {
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn decoded_text(value: &str) -> Result<String, PackageError> {
    if value.len() > 2048 || value.len() % 2 != 0 {
        return Err(reject("invalid text encoding"));
    }
    let bytes = hex_bytes(value, value.len() / 2)?;
    let text = String::from_utf8(bytes).map_err(|_| reject("invalid UTF-8 in ABI"))?;
    if text.is_empty()
        || text
            .bytes()
            .any(|byte| byte == 0 || byte == b'\n' || byte == b'\r')
    {
        return Err(reject("invalid ABI text"));
    }
    Ok(text)
}

fn field<'a>(
    lines: &mut impl Iterator<Item = &'a str>,
    name: &str,
) -> Result<&'a str, PackageError> {
    let line = lines
        .next()
        .ok_or_else(|| reject(format!("missing {name}")))?;
    line.strip_prefix(name)
        .and_then(|rest| rest.strip_prefix(": "))
        .ok_or_else(|| reject(format!("expected {name}")))
}

fn count(value: &str, maximum: usize) -> Result<usize, PackageError> {
    if value.is_empty()
        || !value.bytes().all(|byte| byte.is_ascii_digit())
        || value.starts_with('0') && value != "0"
    {
        return Err(reject("noncanonical count"));
    }
    let count: usize = value.parse().map_err(|_| reject("bad count"))?;
    if count > maximum {
        return Err(reject("count exceeds limit"));
    }
    Ok(count)
}

fn parse_manifest(bytes: &[u8]) -> Result<Manifest, PackageError> {
    if bytes.len() > MAX_MANIFEST || bytes.last() != Some(&b'\n') || bytes.contains(&b'\r') {
        return Err(reject("manifest size or line ending"));
    }
    let text = std::str::from_utf8(bytes).map_err(|_| reject("manifest is not UTF-8"))?;
    let mut lines = text.trim_end_matches('\n').split('\n');
    let format = field(&mut lines, "format")?;
    if !matches!(format, FORMAT | BYTE_SPAN_FORMAT)
        || field(&mut lines, "repository")? != REPOSITORY {
        return Err(reject("manifest format or repository"));
    }
    let release = field(&mut lines, "release")?.to_string();
    let package_id = field(&mut lines, "package_id")?.to_string();
    let epoch_text = field(&mut lines, "epoch")?;
    let signer = field(&mut lines, "signer")?.to_string();
    let target = field(&mut lines, "target")?;
    let object_format = field(&mut lines, "object_format")?;
    let license = field(&mut lines, "license")?;
    if !safe_atom(&release)
        || !safe_atom(&package_id)
        || !safe_atom(&signer)
        || !safe_atom(license)
        || target != TARGET
        || object_format != "Elf"
    {
        return Err(reject("manifest identity, target, or license"));
    }
    let epoch = count(epoch_text, usize::MAX)? as u64;
    let artifact_count = count(field(&mut lines, "artifact_count")?, MAX_ARTIFACTS)?;
    let mut artifacts = Vec::with_capacity(artifact_count);
    let mut names = BTreeSet::new();
    for _ in 0..artifact_count {
        let line = field(&mut lines, "artifact")?;
        let parts: Vec<_> = line.split('|').collect();
        if parts.len() != 3 {
            return Err(reject("artifact field count"));
        }
        let kind = ArtifactKind::parse(parts[0])?;
        let name = parts[1].to_string();
        if !safe_file_name(&name)
            || name == "manifest.txt"
            || name == "manifest.sig"
            || !names.insert(name.clone())
        {
            return Err(reject("artifact name or duplicate"));
        }
        artifacts.push(Artifact {
            kind,
            name,
            hash: hash32(parts[2])?,
        });
    }
    if !artifacts
        .iter()
        .any(|artifact| artifact.kind == ArtifactKind::Source)
        || !artifacts
            .iter()
            .any(|artifact| artifact.kind == ArtifactKind::Header)
        || !artifacts
            .iter()
            .any(|artifact| artifact.kind == ArtifactKind::BuildOptions)
        || !artifacts
            .iter()
            .any(|artifact| artifact.kind == ArtifactKind::Object)
        || !artifacts
            .iter()
            .any(|artifact| artifact.kind == ArtifactKind::Archive)
    {
        return Err(reject("incomplete source/header/build/link artifact set"));
    }
    let symbol_count = count(field(&mut lines, "symbol_count")?, MAX_SYMBOLS)?;
    if symbol_count == 0 {
        return Err(reject("empty export contract"));
    }
    let mut symbols = Vec::with_capacity(symbol_count);
    let mut prior_symbol = String::new();
    for _ in 0..symbol_count {
        let line = field(&mut lines, "symbol")?;
        let parts: Vec<_> = line.split('|').collect();
        if parts.len() != if format == BYTE_SPAN_FORMAT { 6 } else { 5 } {
            return Err(reject("symbol field count"));
        }
        let name = parts[0].to_string();
        if !safe_atom(&name) || name <= prior_symbol || !safe_atom(parts[2]) {
            return Err(reject("symbol name/order/policy"));
        }
        prior_symbol = name.clone();
        let parameter_count = count(parts[3], 32)?;
        let mut parameters = Vec::new();
        if parameter_count > 0 {
            let fields: Vec<_> = parts[4].split(',').collect();
            if fields.len() != parameter_count {
                return Err(reject("parameter count"));
            }
            for item in fields {
                let pair: Vec<_> = item.split('@').collect();
                if pair.len() != 2 || !safe_atom(pair[1]) {
                    return Err(reject("parameter ABI"));
                }
                parameters.push((decoded_text(pair[0])?, pair[1].to_string()));
            }
        } else if parts[4] != "-" {
            return Err(reject("zero-parameter encoding"));
        }
        let mut byte_spans = Vec::new();
        if format == BYTE_SPAN_FORMAT && parts[5] != "-" {
            let mut pointer_indices = BTreeSet::new();
            let mut count_indices = BTreeSet::new();
            for span in parts[5].split(',') {
                let fields: Vec<_> = span.split('@').collect();
                if fields.len() != 3 || byte_spans.len() >= 2 {
                    return Err(reject("byte span field count"));
                }
                let pointer_index = count(fields[0], 31)?;
                let count_index = count(fields[1], 31)?;
                let direction = match fields[2] {
                    "read" => "read",
                    "write" => "write",
                    _ => return Err(reject("byte span direction")),
                };
                if pointer_index >= parameter_count || count_index >= parameter_count ||
                    count_index != pointer_index + 1 ||
                    !pointer_indices.insert(pointer_index) ||
                    !count_indices.insert(count_index) ||
                    parameters[pointer_index].0 != "RawPointer(Byte)" ||
                    parameters[pointer_index].1 != if direction == "read" {
                        "borrow_read_call"
                    } else { "borrow_write_call" } ||
                    parameters[count_index].0 != "Int" ||
                    parameters[count_index].1 != "value" {
                    return Err(reject("byte span indices, type, or policy"));
                }
                byte_spans.push(ByteSpanContract { pointer_index, count_index, direction });
            }
            if byte_spans.windows(2).any(|pair| pair[0].pointer_index >= pair[1].pointer_index) {
                return Err(reject("byte span order"));
            }
        }
        if format == BYTE_SPAN_FORMAT && parameters.iter().enumerate().any(|(index, (_, policy))|
            matches!(policy.as_str(), "borrow_read_call" | "borrow_write_call") &&
            !byte_spans.iter().any(|span| span.pointer_index == index)) {
            return Err(reject("byte pointer lacks signed span association"));
        }
        symbols.push(SymbolContract {
            name,
            result_type: decoded_text(parts[1])?,
            result_policy: parts[2].to_string(),
            parameters,
            byte_spans,
        });
    }
    if lines.next().is_some() {
        return Err(reject("trailing manifest field"));
    }
    Ok(Manifest {
        release,
        package_id,
        epoch,
        signer,
        artifacts,
        symbols,
    })
}

fn signature_message(manifest: &[u8]) -> Vec<u8> {
    // The format field is itself signed. Distinct domains prevent a v2 span
    // package from being interpreted under the historical scalar ABI protocol.
    let domain = if manifest.starts_with(b"format: gust.approved_native_package.v2\n") {
        BYTE_SPAN_SIGNED_DOMAIN
    } else { SIGNED_DOMAIN };
    let mut message = Vec::with_capacity(domain.len() + manifest.len());
    message.extend_from_slice(domain);
    message.extend_from_slice(manifest);
    message
}

fn verify_signature_at(
    manifest_bytes: &[u8],
    signature_bytes: &[u8],
    manifest: &Manifest,
    snapshot: &TrustSnapshot<'_>,
    now_unix_seconds: u64,
) -> Result<[u8; 32], PackageError> {
    production_trust::check_snapshot(snapshot)?;
    if snapshot.keys.is_empty()
        || snapshot.release == "unassigned"
        || snapshot.issued_unix_seconds == 0
        || snapshot.issued_unix_seconds >= snapshot.expires_unix_seconds
        || now_unix_seconds < snapshot.issued_unix_seconds
        || now_unix_seconds >= snapshot.expires_unix_seconds
        || manifest.release != snapshot.release
        || manifest.epoch < snapshot.minimum_package_epoch
        || manifest.epoch > snapshot.release_epoch
    {
        return Err(reject("untrusted release or stale/rollback/future epoch"));
    }
    let digest: [u8; 32] = Sha256::digest(manifest_bytes).into();
    if snapshot.withdrawn_digests.contains(&digest)
        || snapshot.revoked_keys.contains(&manifest.signer.as_str())
    {
        return Err(reject("withdrawn package or revoked signer"));
    }
    let key = snapshot
        .keys
        .iter()
        .find(|key| key.id == manifest.signer)
        .ok_or_else(|| reject("unknown signer"))?;
    if manifest.epoch < key.first_epoch || manifest.epoch > key.last_epoch {
        return Err(reject("signer epoch"));
    }
    let signature: [u8; 64] = signature_bytes
        .try_into()
        .map_err(|_| reject("signature width"))?;
    let signature = Signature::from_bytes(&signature);
    let key = VerifyingKey::from_bytes(&key.public_key).map_err(|_| reject("public key"))?;
    key.verify_strict(&signature_message(manifest_bytes), &signature)
        .map_err(|_| reject("invalid signature"))?;
    Ok(digest)
}

fn verify_signature(
    manifest_bytes: &[u8],
    signature_bytes: &[u8],
    manifest: &Manifest,
    snapshot: &TrustSnapshot<'_>,
) -> Result<[u8; 32], PackageError> {
    // Wall-clock rollback on a compromised host is outside the offline
    // snapshot's authority. Production still refuses without a release root.
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| reject("system time"))?
        .as_secs();
    verify_signature_at(manifest_bytes, signature_bytes, manifest, snapshot, now)
}

fn verify_program(
    manifest: &Manifest,
    program: &Program,
    registry: &RegisteredPackage,
) -> Result<(), PackageError> {
    if program.target_triple != TARGET || program.object_format != "Elf" {
        return Err(reject("canonical program target"));
    }
    let mut seen = BTreeSet::new();
    if manifest.symbols.len() != registry.exports.len()
        || manifest
            .symbols
            .iter()
            .any(|symbol| !registry.exports.contains(&symbol.name.as_str()))
    {
        return Err(reject("signed exports differ from release registry"));
    }
    for contract in &manifest.symbols {
        let mut matching = program
            .functions
            .iter()
            .filter(|function| function.is_extern && function.extern_symbol == contract.name);
        let Some(function) = matching.next() else {
            continue;
        };
        if matching.next().is_some() || !seen.insert(contract.name.as_str()) {
            return Err(reject("duplicate canonical extern"));
        }
        let ffi = function
            .ffi_contract
            .as_ref()
            .ok_or_else(|| reject("extern has no policy"))?;
        let byte_spans = !contract.byte_spans.is_empty();
        if function.result_type != contract.result_type
            || ffi.result_policy != contract.result_policy
            || function.parameters.len() != contract.parameters.len()
            || ffi.parameter_policies.len() != contract.parameters.len()
            || !ffi.destructor.is_empty()
            || ffi.result_policy != "value"
            || if byte_spans { function.result_type != "Int" } else {
                !matches!(function.result_type.as_str(), "Int" | "Byte" | "Bool" | "Void")
            }
        {
            return Err(reject(
                "canonical extern ABI or unsupported package profile",
            ));
        }
        for (index, (ty, policy)) in contract.parameters.iter().enumerate() {
            let signed_pointer = contract.byte_spans.iter().any(|span| span.pointer_index == index);
            if function.parameters[index].1 != *ty
                || ffi.parameter_policies[index] != *policy
                || if signed_pointer {
                    ty != "RawPointer(Byte)" || !matches!(policy.as_str(),
                        "borrow_read_call" | "borrow_write_call")
                } else {
                    policy != "value" || !matches!(ty.as_str(), "Int" | "Byte" | "Bool")
                }
            {
                return Err(reject("canonical extern parameter or policy mismatch"));
            }
        }
        if byte_spans {
            let calls: Vec<_> = program.nodes.iter().filter(|node|
                node.kind == "Call" && node.second_text == function.qualified_name).collect();
            if calls.is_empty() {
                return Err(reject("signed byte-span export has no canonical call"));
            }
            for call in calls {
                let plan = call.isolated_call_plan.as_ref()
                    .ok_or_else(|| reject("signed byte-span call lacks plan"))?;
                if call.second_integer != 10 || plan.positions.len() != contract.byte_spans.len() ||
                    plan.target_triple != TARGET || plan.cleanup != "synchronous_call" {
                    return Err(reject("signed byte-span call plan shape"));
                }
                for (position, signed) in plan.positions.iter().zip(&contract.byte_spans) {
                    if position.index != signed.pointer_index ||
                        position.count_index != Some(signed.count_index) ||
                        position.direction != signed.direction ||
                        position.aggregate_type != "Byte" || position.size != 1 ||
                        position.align != 1 || position.provenance != "direct_raw_byte_span" {
                        return Err(reject("canonical byte-span pair differs from signed ABI"));
                    }
                }
            }
        }
    }
    if seen.is_empty() {
        return Err(reject("package exports unused by canonical program"));
    }
    Ok(())
}

fn regular_file(path: &Path) -> Result<File, PackageError> {
    let metadata = fs::symlink_metadata(path).map_err(|_| reject("missing package input"))?;
    if !metadata.file_type().is_file() || metadata.len() > MAX_ARTIFACT {
        return Err(reject("nonregular, symlink, or oversized package input"));
    }
    let opened = File::open(path).map_err(|_| reject("package input could not be opened"))?;
    let opened_metadata = opened
        .metadata()
        .map_err(|_| reject("package input metadata"))?;
    if !opened_metadata.file_type().is_file() || opened_metadata.len() > MAX_ARTIFACT {
        return Err(reject("package input changed type or size during open"));
    }
    Ok(opened)
}

fn validate_object(bytes: &[u8]) -> Result<BTreeSet<String>, PackageError> {
    let object = object::File::parse(bytes).map_err(|_| reject("link member is not an object"))?;
    if object.format() != BinaryFormat::Elf
        || object.kind() != ObjectKind::Relocatable
        || object.architecture() != Architecture::X86_64
        || object.is_64() != true
        || object.endianness() != object::Endianness::Little
    {
        return Err(reject("link member target/format mismatch"));
    }
    let mut definitions = BTreeSet::new();
    for symbol in object.symbols() {
        if symbol.is_definition() && symbol.is_global() && !symbol.is_weak() {
            let name = symbol.name().map_err(|_| reject("bad object symbol"))?;
            if !name.is_empty() && !definitions.insert(name.to_string()) {
                return Err(reject("duplicate object definition"));
            }
        }
    }
    Ok(definitions)
}

fn validate_link_artifact(
    kind: ArtifactKind,
    bytes: &[u8],
) -> Result<BTreeSet<String>, PackageError> {
    if kind == ArtifactKind::Object {
        return validate_object(bytes);
    }
    let archive = ArchiveFile::parse(bytes).map_err(|_| reject("invalid static archive"))?;
    if archive.is_thin() || !matches!(archive.kind(), ArchiveKind::Gnu | ArchiveKind::Gnu64) {
        return Err(reject("thin archive is unsupported"));
    }
    let mut definitions = BTreeSet::new();
    let mut members = 0usize;
    for member in archive.members() {
        let member = member.map_err(|_| reject("invalid archive member"))?;
        members += 1;
        if members > 4096 {
            return Err(reject("too many archive members"));
        }
        let member_bytes = member
            .data(bytes)
            .map_err(|_| reject("archive member outside archive"))?;
        for name in validate_object(member_bytes)? {
            if !definitions.insert(name) {
                return Err(reject("duplicate strong package definition"));
            }
        }
    }
    if members == 0 {
        return Err(reject("empty static archive"));
    }
    Ok(definitions)
}

/// Detect strong definitions that would shadow or conflict with the approved
/// package. The existing runtime archive may contain internal repeated names;
/// only intersections with package definitions are relevant here.
pub fn external_definitions(path: &Path, archive: bool) -> Result<BTreeSet<String>, PackageError> {
    let bytes = fs::read(path).map_err(|_| reject("existing link input unreadable"))?;
    if !archive {
        return validate_object(&bytes);
    }
    let parsed =
        ArchiveFile::parse(bytes.as_slice()).map_err(|_| reject("runtime archive invalid"))?;
    if parsed.is_thin() {
        return Err(reject("runtime archive is thin"));
    }
    let mut definitions = BTreeSet::new();
    for member in parsed.members() {
        let member = member.map_err(|_| reject("runtime archive member"))?;
        let payload = member
            .data(bytes.as_slice())
            .map_err(|_| reject("runtime archive member bounds"))?;
        if let Ok(member_definitions) = validate_object(payload) {
            definitions.extend(member_definitions);
        }
    }
    Ok(definitions)
}

/// The staged paths cannot be constructed by request parsing. They remain
/// alive through the linker call and are removed on success and failure.
#[derive(Debug)]
pub struct VerifiedPackage {
    package_id: String,
    release: String,
    staged_dir: PathBuf,
    link_inputs: Vec<PathBuf>,
    link_hashes: Vec<[u8; 32]>,
    definitions: BTreeSet<String>,
    manifest_digest: [u8; 32],
    production_link: Option<production_trust::StaticLink>,
}

impl VerifiedPackage {
    pub fn production_link(&self) -> Option<&production_trust::StaticLink> {
        self.production_link.as_ref()
    }
    pub fn package_id(&self) -> &str {
        &self.package_id
    }
    pub fn release(&self) -> &str {
        &self.release
    }
    pub fn link_inputs(&self) -> &[PathBuf] {
        &self.link_inputs
    }
    pub fn definitions(&self) -> &BTreeSet<String> {
        &self.definitions
    }
    pub fn manifest_digest(&self) -> [u8; 32] {
        self.manifest_digest
    }
    pub fn recheck_staged_bytes(&self) -> Result<(), PackageError> {
        if let Some(profile) = &self.production_link { profile.recheck()?; }
        for (path, expected) in self.link_inputs.iter().zip(&self.link_hashes) {
            let mut input = regular_file(path)?;
            let mut hash = Sha256::new();
            let mut buffer = [0u8; 32768];
            loop {
                let read = input.read(&mut buffer).map_err(|_| reject("staged read"))?;
                if read == 0 {
                    break;
                }
                hash.update(&buffer[..read]);
            }
            let actual: [u8; 32] = hash.finalize().into();
            if &actual != expected {
                return Err(reject("staged package bytes changed"));
            }
        }
        Ok(())
    }

    pub fn admit(
        package_dir: &Path,
        registry: &RegisteredPackage,
        program: &Program,
        snapshot: &TrustSnapshot<'_>,
        output_path: &Path,
    ) -> Result<Self, PackageError> {
        if !safe_atom(registry.id) {
            return Err(reject("invalid package ID"));
        }
        let root_meta = fs::symlink_metadata(package_dir).map_err(|_| reject("missing package"))?;
        if !root_meta.file_type().is_dir() {
            return Err(reject("package root is not a directory"));
        }
        let mut manifest_bytes = Vec::new();
        regular_file(&package_dir.join("manifest.txt"))?
            .take((MAX_MANIFEST + 1) as u64)
            .read_to_end(&mut manifest_bytes)
            .map_err(|_| reject("manifest read"))?;
        let manifest = parse_manifest(&manifest_bytes)?;
        let production = registry.id == production_trust::PACKAGE;
        if production && manifest_bytes != production_trust::MANIFEST {
            return Err(reject("production manifest differs from worker-pinned artifact set"));
        }
        if manifest.package_id != registry.id {
            return Err(reject("package ID mismatch"));
        }
        let mut signature_bytes = Vec::new();
        regular_file(&package_dir.join("manifest.sig"))?
            .take(65)
            .read_to_end(&mut signature_bytes)
            .map_err(|_| reject("signature read"))?;
        let manifest_digest =
            verify_signature(&manifest_bytes, &signature_bytes, &manifest, snapshot)?;
        verify_program(&manifest, program, registry)?;

        let parent = output_path
            .parent()
            .ok_or_else(|| reject("output has no parent"))?;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|_| reject("system time"))?
            .as_nanos();
        let stage = parent.join(format!(
            ".gust-approved-package-{}-{now}",
            std::process::id()
        ));
        #[cfg(unix)]
        {
            use std::os::unix::fs::DirBuilderExt;
            let mut builder = fs::DirBuilder::new();
            builder.mode(0o700);
            builder
                .create(&stage)
                .map_err(|_| reject("private staging creation"))?;
        }
        #[cfg(not(unix))]
        return Err(reject("approved package staging requires Unix permissions"));
        let result = (|| {
            let mut link_inputs = Vec::new();
            let mut link_hashes = Vec::new();
            let mut definitions = BTreeSet::new();
            for artifact in &manifest.artifacts {
                let mut source = regular_file(&package_dir.join(&artifact.name))?;
                let staged = stage.join(&artifact.name);
                let mut destination = OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .open(&staged)
                    .map_err(|_| reject("staged file creation"))?;
                let mut hasher = Sha256::new();
                let mut bytes = Vec::new();
                let mut total = 0u64;
                let mut buffer = [0u8; 32768];
                loop {
                    let read = source
                        .read(&mut buffer)
                        .map_err(|_| reject("artifact read"))?;
                    if read == 0 {
                        break;
                    }
                    total = total
                        .checked_add(read as u64)
                        .ok_or_else(|| reject("artifact size overflow"))?;
                    if total > MAX_ARTIFACT {
                        return Err(reject("artifact too large"));
                    }
                    hasher.update(&buffer[..read]);
                    destination
                        .write_all(&buffer[..read])
                        .map_err(|_| reject("staged write"))?;
                    if artifact.kind.is_link_input() {
                        bytes.extend_from_slice(&buffer[..read]);
                    }
                }
                destination.sync_all().map_err(|_| reject("staged sync"))?;
                let actual: [u8; 32] = hasher.finalize().into();
                if actual != artifact.hash {
                    return Err(reject("artifact digest mismatch"));
                }
                if artifact.kind.is_link_input() {
                    for name in validate_link_artifact(artifact.kind, &bytes)? {
                        if !definitions.insert(name) {
                            return Err(reject("strong symbol conflict in package"));
                        }
                    }
                    link_inputs.push(staged);
                    link_hashes.push(actual);
                }
            }
            for symbol in &manifest.symbols {
                if !definitions.contains(&symbol.name) {
                    return Err(reject("signed exported symbol absent"));
                }
            }
            let production_link = if production {
                Some(production_trust::StaticLink::stage(&stage)?)
            } else { None };
            Ok(Self {
                production_link,
                package_id: manifest.package_id.clone(),
                release: manifest.release.clone(),
                staged_dir: stage.clone(),
                link_inputs,
                link_hashes,
                definitions,
                manifest_digest,
            })
        })();
        if result.is_err() {
            let _ = fs::remove_dir_all(&stage);
        }
        result
    }
}

impl Drop for VerifiedPackage {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.staged_dir);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::full_program::{FfiContract, Function, IsolatedCallPlan, IsolatedPosition, Node};
    use ed25519_dalek::{Signer, SigningKey};
    use object::write::{
        Object as WriteObject, Relocation as WriteRelocation, StandardSection,
        Symbol as WriteSymbol, SymbolSection,
    };
    use object::{
        Endianness, RelocationEncoding, RelocationFlags, RelocationKind, SymbolFlags, SymbolKind,
        SymbolScope,
    };
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_DIR: AtomicU64 = AtomicU64::new(0);
    const TEST_EXPORTS: &[&str] = &["gust_test"];
    const TEST_REGISTRY: RegisteredPackage = RegisteredPackage {
        id: "fixture",
        exports: TEST_EXPORTS,
    };
    const SCOPED_BYTE_EXPORTS: &[&str] = &["approved_byte_adapter"];
    const SCOPED_BYTE_REGISTRY: RegisteredPackage = RegisteredPackage {
        id: "fixture",
        exports: SCOPED_BYTE_EXPORTS,
    };

    fn test_program() -> Program {
        Program {
            target_triple: TARGET.into(),
            object_format: "Elf".into(),
            modules: vec![],
            layouts: vec![],
            enumerations: vec![],
            nodes: vec![],
            functions: vec![Function {
                module_index: 0,
                source_name: "test".into(),
                qualified_name: "test".into(),
                is_extern: true,
                extern_symbol: "gust_test".into(),
                result_type: "Int".into(),
                body_node: None,
                parameters: vec![("x".into(), "Int".into())],
                ffi_contract: Some(FfiContract {
                    result_policy: "value".into(),
                    parameter_policies: vec!["value".into()],
                    destructor: String::new(),
                }),
                scoped_byte_copy: None,
            }],
            entry_function: 0,
        }
    }

    fn object_with(name: &str) -> Vec<u8> {
        let mut object =
            WriteObject::new(BinaryFormat::Elf, Architecture::X86_64, Endianness::Little);
        let section = object.section_id(StandardSection::Text);
        let offset = object.append_section_data(section, &[0xc3], 1);
        object.add_symbol(WriteSymbol {
            name: name.as_bytes().to_vec(),
            value: offset,
            size: 1,
            kind: SymbolKind::Text,
            scope: SymbolScope::Linkage,
            weak: false,
            section: SymbolSection::Section(section),
            flags: SymbolFlags::None,
        });
        object.write().unwrap()
    }

    fn call_object(name: &str, code: &[u8], calls: &[(&str, u64)]) -> Vec<u8> {
        let mut object =
            WriteObject::new(BinaryFormat::Elf, Architecture::X86_64, Endianness::Little);
        let section = object.section_id(StandardSection::Text);
        let offset = object.append_section_data(section, code, 1);
        object.add_symbol(WriteSymbol {
            name: name.as_bytes().to_vec(),
            value: offset,
            size: code.len() as u64,
            kind: SymbolKind::Text,
            scope: SymbolScope::Linkage,
            weak: false,
            section: SymbolSection::Section(section),
            flags: SymbolFlags::None,
        });
        for &(target, displacement_offset) in calls {
            let symbol = object.add_symbol(WriteSymbol {
                name: target.as_bytes().to_vec(),
                value: 0,
                size: 0,
                kind: SymbolKind::Text,
                scope: SymbolScope::Linkage,
                weak: false,
                section: SymbolSection::Undefined,
                flags: SymbolFlags::None,
            });
            object
                .add_relocation(
                    section,
                    WriteRelocation {
                        offset: offset + displacement_offset,
                        symbol,
                        addend: -4,
                        flags: RelocationFlags::Generic {
                            kind: RelocationKind::PltRelative,
                            encoding: RelocationEncoding::X86Branch,
                            size: 32,
                        },
                    },
                )
                .unwrap();
        }
        object.write().unwrap()
    }

    fn adapter_object() -> Vec<u8> {
        // gust_test(x) aligns RSP before calling the archive helper.
        call_object(
            "gust_test",
            &[
                0x48, 0x83, 0xec, 0x08, // sub rsp, 8
                0xe8, 0, 0, 0, 0, // call zlib_internal
                0x48, 0x83, 0xc4, 0x08, // add rsp, 8
                0xc3, // ret
            ],
            &[("zlib_internal", 5)],
        )
    }

    fn archive_helper_object() -> Vec<u8> {
        // zlib_internal(x) returns x + 1. The archive must be extracted.
        call_object("zlib_internal", &[0x8d, 0x47, 0x01, 0xc3], &[])
    }

    fn main_call_object() -> Vec<u8> {
        // main returns 0 only if gust_test(41) returns 42.
        let code = [
            0x48, 0x83, 0xec, 0x08, // sub rsp, 8
            0xbf, 0x29, 0, 0, 0, // mov edi, 41
            0xe8, 0, 0, 0, 0, // call gust_test
            0x48, 0x83, 0xc4, 0x08, // add rsp, 8
            0x83, 0xf8, 0x2a, // cmp eax, 42
            0x75, 0x03, // jne failure
            0x31, 0xc0, 0xc3, // xor eax, eax; ret
            0xb8, 0x01, 0, 0, 0, 0xc3, // failure: mov eax, 1; ret
        ];
        call_object("main", &code, &[("gust_test", 10)])
    }

    fn archive_with(name: &str, symbol: &str, object: &[u8]) -> Vec<u8> {
        let mut output = b"!<arch>\n".to_vec();
        let symbol_index = {
            let mut index = Vec::new();
            index.extend_from_slice(&1u32.to_be_bytes());
            // The object header follows the 60-byte index header, index
            // payload, and its even-byte archive padding.
            let index_size = 4 + 4 + symbol.len() + 1;
            let object_header_offset = 8 + 60 + index_size + (index_size & 1);
            index.extend_from_slice(&(object_header_offset as u32).to_be_bytes());
            index.extend_from_slice(symbol.as_bytes());
            index.push(0);
            index
        };
        let index_header = format!(
            "{:<16}{:<12}{:<6}{:<6}{:<8}{:<10}`\n",
            "/",
            "0",
            "0",
            "0",
            "100644",
            symbol_index.len()
        );
        assert_eq!(index_header.len(), 60);
        output.extend_from_slice(index_header.as_bytes());
        output.extend_from_slice(&symbol_index);
        if symbol_index.len() % 2 == 1 {
            output.push(b'\n');
        }
        let header = format!(
            "{:<16}{:<12}{:<6}{:<6}{:<8}{:<10}`\n",
            format!("{name}/"),
            "0",
            "0",
            "0",
            "100644",
            object.len()
        );
        assert_eq!(header.len(), 60);
        output.extend_from_slice(header.as_bytes());
        output.extend_from_slice(object);
        if object.len() % 2 == 1 {
            output.push(b'\n');
        }
        output
    }

    #[test]
    fn executable_and_shared_objects_are_not_static_package_members() {
        let relocatable = object_with("gust_test");
        assert!(validate_object(&relocatable).is_ok());
        for elf_type in [2u16, 3u16] {
            let mut changed = relocatable.clone();
            changed[16..18].copy_from_slice(&elf_type.to_le_bytes());
            assert!(validate_object(&changed).is_err());
        }
    }

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|byte| format!("{byte:02x}")).collect()
    }

    struct Fixture {
        root: PathBuf,
        package: PathBuf,
        key: SigningKey,
        trusted_key: [TrustedKey; 1],
        program: Program,
    }

    impl Fixture {
        fn new() -> Self {
            let sequence = NEXT_DIR.fetch_add(1, Ordering::Relaxed);
            let root = std::env::temp_dir()
                .join(format!("gust-r1-test-{}-{sequence}", std::process::id()));
            fs::create_dir(&root).unwrap();
            let package = root.join("package");
            fs::create_dir(&package).unwrap();
            let key = SigningKey::from_bytes(&[7u8; 32]);
            let trusted_key = [TrustedKey {
                id: "fixture-key",
                public_key: key.verifying_key().to_bytes(),
                first_epoch: 1,
                last_epoch: 4,
            }];
            let fixture = Self {
                root,
                package,
                key,
                trusted_key,
                program: test_program(),
            };
            fixture.populate();
            fixture
        }

        fn snapshot(&self) -> TrustSnapshot<'_> {
            // Public fixture key exists only in unit tests. Production has an
            // empty registry and no verifier key until release designation.
            TrustSnapshot {
                release: "test-release",
                release_epoch: 2,
                issued_unix_seconds: 1,
                expires_unix_seconds: u64::MAX,
                minimum_package_epoch: 1,
                keys: &self.trusted_key,
                revoked_keys: &[],
                withdrawn_digests: &[],
            }
        }

        fn populate(&self) {
            let files = [
                ("source", "src.txt", b"fixture source".to_vec()),
                ("header", "header.h", b"fixture header".to_vec()),
                ("build_options", "options.txt", b"-O2".to_vec()),
                ("object", "adapter.o", adapter_object()),
                (
                    "archive",
                    "zlib.a",
                    archive_with("zlib.o", "zlib_internal", &archive_helper_object()),
                ),
            ];
            let mut manifest = format!(
                "format: {FORMAT}\nrepository: {REPOSITORY}\nrelease: test-release\npackage_id: fixture\nepoch: 2\nsigner: fixture-key\ntarget: {TARGET}\nobject_format: Elf\nlicense: Zlib\nartifact_count: {}\n",
                files.len()
            );
            for (kind, name, bytes) in files {
                fs::write(self.package.join(name), &bytes).unwrap();
                let digest: [u8; 32] = Sha256::digest(&bytes).into();
                manifest.push_str(&format!("artifact: {kind}|{name}|{}\n", hex(&digest)));
            }
            manifest.push_str("symbol_count: 1\nsymbol: gust_test|496e74|value|1|496e74@value\n");
            self.sign(manifest.as_bytes());
        }

        fn sign(&self, manifest: &[u8]) {
            fs::write(self.package.join("manifest.txt"), manifest).unwrap();
            let signature = self.key.sign(&signature_message(manifest));
            fs::write(self.package.join("manifest.sig"), signature.to_bytes()).unwrap();
        }

        fn prepare_scoped_byte_adapter(&self) {
            self.prepare_scoped_byte_adapter_source(
                b"int approved_byte_adapter(const unsigned char *input, int count, unsigned char *output, int capacity) { if (count < 0 || capacity < 0) return -1; if (count > capacity) return -3; for (int i = 0; i < count; i++) output[i] = input[i]; return count; }\n",
                false,
            );
        }

        fn prepare_scoped_byte_adapter_with_level(&self) {
            self.prepare_scoped_byte_adapter_source(
                b"int approved_byte_adapter(const unsigned char *input, int count, unsigned char *output, int capacity, int level) { if (level != 1 || count < 0 || capacity < 0) return -1; if (count > capacity) return -3; for (int i = 0; i < count; i++) output[i] = input[i]; return count; }\n",
                true,
            );
        }

        fn prepare_scoped_byte_adapter_error(&self) {
            self.prepare_scoped_byte_adapter_source(
                b"int approved_byte_adapter(const unsigned char *input, int count, unsigned char *output, int capacity) { (void)input; (void)count; (void)output; (void)capacity; return -3; }\n",
                false,
            );
        }

        fn prepare_scoped_byte_adapter_source(&self, adapter: &[u8], with_level: bool) {
            let options = b"-O0 -fno-builtin\n";
            fs::write(self.package.join("src.txt"), adapter).unwrap();
            fs::write(self.package.join("options.txt"), options).unwrap();
            let compiler = std::process::Command::new("/usr/bin/cc")
                .env_clear().env("PATH", "/usr/bin:/bin").env("LANG", "C")
                .arg("-c").arg("-x").arg("c").arg("-O0")
                .arg("-fno-builtin").arg(self.package.join("src.txt"))
                .arg("-o").arg(self.package.join("adapter.o"))
                .output().unwrap();
            assert!(compiler.status.success(), "test adapter compile: {}",
                String::from_utf8_lossy(&compiler.stderr));
            let original = String::from_utf8(
                fs::read(self.package.join("manifest.txt")).unwrap()).unwrap();
            let mut signed = original.replace(FORMAT, BYTE_SPAN_FORMAT);
            let pointer = hex(b"RawPointer(Byte)");
            let mut parameters = format!(
                "{pointer}@borrow_read_call,496e74@value,{pointer}@borrow_write_call,496e74@value");
            if with_level { parameters.push_str(",496e74@value"); }
            let arity = if with_level { 5 } else { 4 };
            let old_symbol = "symbol: gust_test|496e74|value|1|496e74@value";
            assert_eq!(original.matches(old_symbol).count(), 1);
            signed = signed.replacen(old_symbol,
                &format!("symbol: approved_byte_adapter|496e74|value|{arity}|{parameters}|0@1@read,2@3@write"), 1);
            for (kind, name) in [("source", "src.txt"),
                                 ("build_options", "options.txt"),
                                 ("object", "adapter.o")] {
                let old = original.lines().find(|line|
                    line.starts_with(&format!("artifact: {kind}|{name}|"))).unwrap();
                let bytes = fs::read(self.package.join(name)).unwrap();
                let digest: [u8; 32] = Sha256::digest(&bytes).into();
                signed = signed.replacen(old,
                    &format!("artifact: {kind}|{name}|{}", hex(&digest)), 1);
            }
            self.sign(signed.as_bytes());
        }

        fn admit(&self, snapshot: &TrustSnapshot<'_>) -> Result<VerifiedPackage, PackageError> {
            VerifiedPackage::admit(
                &self.package,
                &TEST_REGISTRY,
                &self.program,
                snapshot,
                &self.root.join("output"),
            )
        }
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    fn link_request(
        package: VerifiedPackage,
        object: PathBuf,
        output: PathBuf,
    ) -> crate::CompilerMirLinkRequest {
        crate::CompilerMirLinkRequest {
            output_path: output,
            ordered_object_inputs: vec![object],
            c_source: None,
            host_object: None,
            runtime_package: None,
            approved_package: Some(package),
            additional_libraries: vec![],
            additional_linker_args: vec![],
            trailing_linker_args: vec![],
            linker_driver: "/usr/bin/cc".into(),
            link_via_rustc: false,
            environment_overrides: vec![],
            expected_result: crate::CompilerMirLinkExpectedResult::Success,
            expected_failure_kind: None,
        }
    }

    fn assert_link_input_refusal(error: Box<dyn std::error::Error>, expected: &str) {
        let pipeline = error
            .downcast_ref::<crate::CompilerMirPipelineError>()
            .expect("link refusal must carry a pipeline stage");
        assert_eq!(
            pipeline.stage,
            crate::CompilerMirPipelineStage::LinkInputValidation
        );
        assert!(pipeline.detail.contains(expected), "{}", pipeline.detail);
    }

    #[test]
    fn signed_object_and_archive_link_through_isolated_profile() {
        let fixture = Fixture::new();
        let snapshot = fixture.snapshot();
        let original_adapter = fs::read(fixture.package.join("adapter.o")).unwrap();
        let original_archive = fs::read(fixture.package.join("zlib.a")).unwrap();
        let main_object = fixture.root.join("main.o");
        fs::write(&main_object, main_call_object()).unwrap();

        let package = fixture.admit(&snapshot).unwrap();
        let stage = package.staged_dir.clone();
        let manifest_digest = package.manifest_digest();
        let output = fixture.root.join("approved-linked");
        let report = crate::run_compiler_mir_link_request(link_request(
            package,
            main_object.clone(),
            output.clone(),
        ))
        .unwrap();
        assert!(report.published);
        assert_eq!(report.approved_package_id.as_deref(), Some("fixture"));
        assert_eq!(
            report.approved_package_release.as_deref(),
            Some("test-release")
        );
        assert_eq!(
            report.approved_package_manifest_sha256.as_deref(),
            Some(hex(&manifest_digest).as_str())
        );
        assert!(!stage.exists());
        assert!(
            std::process::Command::new(&output)
                .status()
                .unwrap()
                .success()
        );

        let package = fixture.admit(&snapshot).unwrap();
        let stage = package.staged_dir.clone();
        fs::write(&package.link_inputs()[0], b"tampered after admission").unwrap();
        let tampered_output = fixture.root.join("tampered-link");
        let error = crate::run_compiler_mir_link_request(link_request(
            package,
            main_object.clone(),
            tampered_output.clone(),
        ))
        .unwrap_err();
        assert_link_input_refusal(error, "staged package bytes changed");
        assert!(!tampered_output.exists());
        assert!(!stage.exists());

        let package = fixture.admit(&snapshot).unwrap();
        let stage = package.staged_dir.clone();
        let injected_output = fixture.root.join("injected-link");
        let mut request = link_request(package, main_object.clone(), injected_output.clone());
        request.environment_overrides.push((
            "LD_PRELOAD".into(),
            "/tmp/untrusted-package-override.so".into(),
        ));
        let error = crate::run_compiler_mir_link_request(request).unwrap_err();
        assert_link_input_refusal(error, "isolated fixed GNU linker profile");
        assert!(!injected_output.exists());
        assert!(!stage.exists());

        let conflicting_object = fixture.root.join("conflicting.o");
        fs::write(&conflicting_object, object_with("gust_test")).unwrap();
        let package = fixture.admit(&snapshot).unwrap();
        let stage = package.staged_dir.clone();
        let conflicting_output = fixture.root.join("conflicting-link");
        let error = crate::run_compiler_mir_link_request(link_request(
            package,
            conflicting_object,
            conflicting_output.clone(),
        ))
        .unwrap_err();
        assert_link_input_refusal(error, "conflicts with generated object symbol");
        assert!(!conflicting_output.exists());
        assert!(!stage.exists());

        assert_eq!(
            fs::read(fixture.package.join("adapter.o")).unwrap(),
            original_adapter
        );
        assert_eq!(
            fs::read(fixture.package.join("zlib.a")).unwrap(),
            original_archive
        );
    }

    #[test]
    fn signed_bytes_and_canonical_abi_admit_only_verified_staged_inputs() {
        let fixture = Fixture::new();
        let snapshot = fixture.snapshot();
        let package = fixture.admit(&snapshot).unwrap();
        assert_eq!(package.link_inputs().len(), 2);
        assert!(package.definitions().contains("gust_test"));
        package.recheck_staged_bytes().unwrap();
        let staged = package.link_inputs()[0].clone();
        fs::write(&staged, b"changed").unwrap();
        assert!(package.recheck_staged_bytes().is_err());
        let stage = package.staged_dir.clone();
        drop(package);
        assert!(!stage.exists());
    }

    #[test]
    fn signed_manifest_rejects_tamper_wrong_abi_and_revocation() {
        let fixture = Fixture::new();
        let snapshot = fixture.snapshot();
        fs::write(fixture.package.join("adapter.o"), b"changed").unwrap();
        assert!(fixture.admit(&snapshot).is_err());
        fixture.populate();
        let mut signature = fs::read(fixture.package.join("manifest.sig")).unwrap();
        signature[0] ^= 1;
        fs::write(fixture.package.join("manifest.sig"), signature).unwrap();
        assert!(fixture.admit(&snapshot).is_err());
        let manifest = fs::read(fixture.package.join("manifest.txt")).unwrap();
        fixture.sign(&manifest);
        let mut wrong = test_program();
        wrong.functions[0].parameters[0].1 = "Byte".into();
        assert!(
            VerifiedPackage::admit(
                &fixture.package,
                &TEST_REGISTRY,
                &wrong,
                &snapshot,
                &fixture.root.join("output")
            )
            .is_err()
        );
        let revoked = TrustSnapshot {
            revoked_keys: &["fixture-key"],
            ..snapshot
        };
        assert!(fixture.admit(&revoked).is_err());
    }

    #[test]
    fn approved_profile_denies_unknown_even_without_ffi_metadata() {
        let mut program = test_program();
        let empty = BTreeSet::new();
        let mut foreign = program.functions[0].clone();
        foreign.qualified_name = "foreign".into();
        foreign.extern_symbol = "abs".into();
        foreign.ffi_contract = None;
        program.functions.push(foreign);
        assert!(verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &empty, &[]).is_err());

        program.functions[1].extern_symbol = "os_LogInt".into();
        let runtime = BTreeSet::from(["os_LogInt".to_string()]);
        assert!(verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &runtime, &[]).is_ok());
        program.functions[1].extern_symbol = "tiny_host_read_repr_c_probe".into();
        assert!(
            verify_foreign_coverage_with_symbols(
                &program,
                &[TEST_REGISTRY],
                &empty,
                &["tiny_host_read_repr_c_probe"]
            )
            .is_err()
        );
        assert!(verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &empty, &[]).is_err());
        let unavailable = Path::new("/nonexistent/runtime.a");
        let mut legacy = test_program();
        legacy.functions[0].extern_symbol = "host_direct_alpha".into();
        assert!(select(&legacy, &[TEST_REGISTRY]).unwrap().is_none());
        assert!(
            verify_foreign_coverage(
                &program,
                &[TEST_REGISTRY],
                None,
                unavailable,
                &["tiny_host_read_repr_c_probe"],
            )
            .is_err()
        );
    }

    #[test]
    fn unbound_call_cannot_import_libc_without_a_declared_extern() {
        let mut program = test_program();
        let node = |kind: &str, symbol: &str, children: Vec<usize>| Node {
            kind: kind.into(),
            ty: "Int".into(),
            text: symbol.into(),
            second_text: symbol.into(),
            integer: 0,
            second_integer: 0,
            isolated_call_plan: None,
            collection_intrinsic: None,
            source_line: 1,
            source_column: 1,
            source_start: 0,
            source_end: 1,
            children,
        };
        program.nodes = vec![
            node("Identifier", "abs", vec![]),
            node("Call", "abs", vec![0]),
        ];
        let runtime = BTreeSet::from(["os_LogInt".to_string()]);
        assert!(verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &runtime, &[]).is_err());
        program.nodes[1].second_text = "os_LogInt".into();
        assert!(verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &runtime, &[]).is_ok());

        // Removing the extern declaration does not return a registered
        // package call to the historical linker route.
        program.functions.clear();
        program.nodes[1].second_text = "gust_test".into();
        assert_eq!(select(&program, &[TEST_REGISTRY]).unwrap().unwrap().id, "fixture");
        assert!(verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &runtime, &[]).is_err());
    }

    #[test]
    fn compiler_owned_exit_mapping_preserves_only_its_int_void_call_shape() {
        let mut program = test_program();
        let node = |kind: &str, ty: &str, symbol: &str, children: Vec<usize>| Node {
            kind: kind.into(),
            ty: ty.into(),
            text: symbol.into(),
            second_text: symbol.into(),
            integer: 0,
            second_integer: 0,
            isolated_call_plan: None,
            collection_intrinsic: None,
            source_line: 1,
            source_column: 1,
            source_start: 0,
            source_end: 1,
            children,
        };
        program.nodes = vec![
            node("Identifier", "Void", "os_Exit", vec![]),
            node("IntegerLiteral", "Int", "", vec![]),
            node("Call", "Void", "os_Exit", vec![0, 1]),
        ];
        assert!(verify_foreign_coverage_with_symbols(
            &program, &[TEST_REGISTRY], &BTreeSet::new(), &[]
        ).is_ok());
        program.nodes[2].second_text = "exit".into();
        assert!(
            verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &BTreeSet::new(), &[],).is_err()
        );
        program.nodes[2].second_text = "os_Exit".into();
        program.nodes[1].ty = "Byte".into();
        assert!(
            verify_foreign_coverage_with_symbols(&program, &[TEST_REGISTRY], &BTreeSet::new(), &[],).is_err()
        );
    }

    #[test]
    fn package_and_public_runtime_share_one_exact_foreign_boundary() {
        let fixture = Fixture::new();
        let runtime_path = fixture.root.join("runtime.a");
        fs::write(
            &runtime_path,
            archive_with("runtime.o", "os_LogInt", &object_with("os_LogInt")),
        )
        .unwrap();
        let mut program = test_program();
        let mut runtime = program.functions[0].clone();
        runtime.qualified_name = "runtime".into();
        runtime.extern_symbol = "os_LogInt".into();
        program.functions.push(runtime);
        assert!(
            verify_foreign_coverage(
                &program,
                &[TEST_REGISTRY],
                Some(&runtime_path),
                &runtime_path,
                &[],
            )
            .is_ok()
        );
        program.functions[1].extern_symbol = "abs".into();
        assert!(
            verify_foreign_coverage(
                &program,
                &[TEST_REGISTRY],
                Some(&runtime_path),
                &runtime_path,
                &[],
            )
            .is_err()
        );
        program.functions[1].extern_symbol = "os_LogInt".into();
        assert!(
            verify_foreign_coverage(
                &program,
                &[TEST_REGISTRY],
                Some(Path::new("/untrusted/runtime.a")),
                &runtime_path,
                &[],
            )
            .is_err()
        );
    }

    #[test]
    fn signed_metadata_cannot_admit_unqualified_pointer_policy() {
        let fixture = Fixture::new();
        let mut manifest =
            parse_manifest(&fs::read(fixture.package.join("manifest.txt")).unwrap()).unwrap();
        let mut program = test_program();
        manifest.symbols[0].parameters[0] = ("RawPointer(Int)".into(), "borrow_read_call".into());
        program.functions[0].parameters[0].1 = "RawPointer(Int)".into();
        program.functions[0]
            .ffi_contract
            .as_mut()
            .unwrap()
            .parameter_policies[0] = "borrow_read_call".into();
        assert!(verify_program(&manifest, &program, &TEST_REGISTRY).is_err());
    }

    #[test]
    fn signed_byte_span_pairs_bind_the_canonical_call() {
        let fixture = Fixture::new();
        let original = String::from_utf8(fs::read(fixture.package.join("manifest.txt")).unwrap()).unwrap();
        let old_symbol = "symbol: gust_test|496e74|value|1|496e74@value";
        let byte_symbol = format!(
            "symbol: gust_test|496e74|value|2|{}@borrow_read_call,496e74@value|0@1@read",
            hex(b"RawPointer(Byte)")
        );
        let signed = original.replace(FORMAT, BYTE_SPAN_FORMAT)
            .replace(old_symbol, &byte_symbol);
        assert_ne!(signed, original);
        fixture.sign(signed.as_bytes());
        let manifest = parse_manifest(signed.as_bytes()).unwrap();
        assert_eq!(manifest.symbols[0].byte_spans,
            vec![ByteSpanContract { pointer_index: 0, count_index: 1, direction: "read" }]);
        let snapshot = fixture.snapshot();
        let v2_signature = fs::read(fixture.package.join("manifest.sig")).unwrap();
        assert!(verify_signature_at(signed.as_bytes(), &v2_signature,
            &manifest, &snapshot, snapshot.issued_unix_seconds).is_ok());
        let mut old_domain_message = SIGNED_DOMAIN.to_vec();
        old_domain_message.extend_from_slice(signed.as_bytes());
        let old_domain_signature = fixture.key.sign(&old_domain_message).to_bytes();
        assert!(verify_signature_at(signed.as_bytes(), &old_domain_signature,
            &manifest, &snapshot, snapshot.issued_unix_seconds).is_err());

        let mut program = test_program();
        program.functions[0].parameters = vec![
            ("input".into(), "RawPointer(Byte)".into()),
            ("count".into(), "Int".into()),
        ];
        program.functions[0].ffi_contract.as_mut().unwrap().parameter_policies =
            vec!["borrow_read_call".into(), "value".into()];
        program.nodes.push(Node {
            kind: "Call".into(), ty: "Int".into(), text: "test".into(),
            second_text: "test".into(), integer: 0, second_integer: 10,
            isolated_call_plan: Some(Box::new(IsolatedCallPlan {
                target_triple: TARGET.into(), cleanup: "synchronous_call".into(),
                positions: vec![IsolatedPosition {
                    index: 0, direction: "read".into(), aggregate_type: "Byte".into(),
                    size: 1, align: 1, provenance: "direct_raw_byte_span".into(),
                    count_index: Some(1),
                }], retained: None,
            })),
            source_line: 0, source_column: 0, source_start: 0, source_end: 0,
            collection_intrinsic: None,
            children: Vec::new(),
        });
        assert!(verify_program(&manifest, &program, &TEST_REGISTRY).is_ok());
        program.nodes[0].isolated_call_plan.as_mut().unwrap().positions[0].count_index = Some(0);
        assert!(verify_program(&manifest, &program, &TEST_REGISTRY).is_err());
        program.nodes[0].isolated_call_plan.as_mut().unwrap().positions[0].count_index = Some(1);
        assert!(parse_manifest(signed.replace("0@1@read", "0@0@read").as_bytes()).is_err());
        assert!(parse_manifest(signed.replace("0@1@read", "0@1@write").as_bytes()).is_err());
        assert!(parse_manifest(signed.replace("0@1@read", "0@1@read,0@1@read").as_bytes()).is_err());
        let modified = signed.replace("borrow_read_call", "borrow_write_call")
            .replace("0@1@read", "0@1@write");
        let forged = parse_manifest(modified.as_bytes()).unwrap();
        assert!(verify_signature_at(
            modified.as_bytes(),
            &fs::read(fixture.package.join("manifest.sig")).unwrap(),
            &forged, &fixture.snapshot(), fixture.snapshot().issued_unix_seconds,
        ).is_err());
    }

    #[test]
    fn signed_byte_span_pairs_match_the_actual_typed_scoped_call() {
        // The object in Fixture still exports gust_test. This test binds a
        // valid v2 signature to the actual source-produced Call10 metadata;
        // installed artifact admission and link behavior are separate gates.
        let fixture = Fixture::new();
        let original = String::from_utf8(
            fs::read(fixture.package.join("manifest.txt")).unwrap()).unwrap();
        let scalar = "symbol: gust_test|496e74|value|1|496e74@value";
        let pointer = hex(b"RawPointer(Byte)");
        let scoped = format!(
            "symbol: approved_byte_adapter|496e74|value|4|{pointer}@borrow_read_call,496e74@value,{pointer}@borrow_write_call,496e74@value|0@1@read,2@3@write"
        );
        let signed = original.replace(FORMAT, BYTE_SPAN_FORMAT)
            .replace(scalar, &scoped);
        assert_ne!(signed, original);
        fixture.sign(signed.as_bytes());
        let manifest = parse_manifest(signed.as_bytes()).unwrap();
        let snapshot = fixture.snapshot();
        let signature = fs::read(fixture.package.join("manifest.sig")).unwrap();
        assert!(verify_signature_at(signed.as_bytes(), &signature,
            &manifest, &snapshot, snapshot.issued_unix_seconds).is_ok());

        let canonical = include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let mut program = crate::full_program::parse(canonical).unwrap();
        assert!(verify_program(&manifest, &program, &SCOPED_BYTE_REGISTRY).is_ok());
        let call = program.nodes.iter_mut().find(|node|
            node.kind == "Call" && node.second_integer == 10 &&
            node.second_text == "approved_byte_adapter").unwrap();
        call.isolated_call_plan.as_mut().unwrap().positions[1].count_index = Some(1);
        assert!(verify_program(&manifest, &program, &SCOPED_BYTE_REGISTRY).is_err());
    }

    #[test]
    fn actual_typed_scoped_call_admits_only_its_signed_test_object() {
        // This key and registry are cfg(test)-only. The adapter is a real
        // relocatable C object with the signed Byte pointer/count ABI; this
        // checks admission and private staging, not link or execution.
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter();
        let canonical = include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let program = crate::full_program::parse(canonical).unwrap();
        let output = fixture.root.join("scoped-output");
        let package = VerifiedPackage::admit(&fixture.package,
            &SCOPED_BYTE_REGISTRY, &program, &fixture.snapshot(), &output).unwrap();
        assert!(package.definitions().contains("approved_byte_adapter"));
        let staged = package.link_inputs().to_vec();
        assert!(staged.iter().all(|path| path.exists()));
        drop(package);
        assert!(staged.iter().all(|path| !path.exists()));

        let mut changed = fs::read(fixture.package.join("adapter.o")).unwrap();
        changed.push(0);
        fs::write(fixture.package.join("adapter.o"), changed).unwrap();
        assert!(VerifiedPackage::admit(&fixture.package,
            &SCOPED_BYTE_REGISTRY, &program, &fixture.snapshot(), &output).is_err());
    }

    struct RuntimeSibling(PathBuf);

    impl RuntimeSibling {
        fn stage() -> Self {
            let archive = PathBuf::from(std::env::var_os("GUST_R2_RUNTIME_ARCHIVE")
                .expect("focused runner must bind the compiler-owned runtime archive"));
            let expected_digest = std::env::var("GUST_R2_RUNTIME_SHA256")
                .expect("focused runner must pin the compiler-owned runtime archive");
            assert_eq!(hex(&Sha256::digest(fs::read(&archive).unwrap())), expected_digest);
            let sibling = std::env::current_exe().unwrap().parent().unwrap()
                .join("gust-runtime-package.a");
            assert!(!sibling.exists(), "isolated test target must own runtime sibling");
            fs::copy(&archive, &sibling).unwrap();
            assert_eq!(hex(&Sha256::digest(fs::read(&sibling).unwrap())), expected_digest);
            Self(sibling)
        }
    }

    impl Drop for RuntimeSibling {
        fn drop(&mut self) { let _ = fs::remove_file(&self.0); }
    }

    fn run_scoped_linked_case(fixture: &Fixture, canonical: &str,
        object_name: &str, output_name: &str, expected_exit: i32,
        expectation: &str) {
        let runtime = RuntimeSibling::stage();
        let program = crate::full_program::parse(canonical).unwrap();
        verify_foreign_coverage(&program, &[SCOPED_BYTE_REGISTRY],
            Some(&runtime.0), &runtime.0, &[]).unwrap();
        let object = fixture.root.join(object_name);
        crate::full_program::lower_program(&program, &object).unwrap();
        let output = fixture.root.join(output_name);
        let package = VerifiedPackage::admit(&fixture.package, &SCOPED_BYTE_REGISTRY,
            &program, &fixture.snapshot(), &output).unwrap();
        let staged = package.link_inputs().to_vec();
        let manifest_digest = hex(&package.manifest_digest());
        let mut request = link_request(package, object, output.clone());
        request.runtime_package = Some(runtime.0.clone());
        let report = crate::run_compiler_mir_link_request(request).unwrap();
        assert!(report.published);
        assert_eq!(report.approved_package_id.as_deref(), Some("fixture"));
        assert_eq!(report.approved_package_manifest_sha256.as_deref(),
            Some(manifest_digest.as_str()));
        assert!(staged.iter().all(|path| !path.exists()));
        let status = std::process::Command::new(&output)
            .env_clear().env("PATH", "/usr/bin:/bin").status().unwrap();
        assert_eq!(status.code(), Some(expected_exit), "{expectation}");
        let retained = PathBuf::from(std::env::var_os("GUST_R2_LINKED_EXECUTABLE_OUT")
            .expect("focused runner must own the generated executable path"));
        assert!(!retained.exists(), "focused runner output is already occupied");
        fs::copy(&output, &retained).unwrap();
        assert!(fs::read(&retained).unwrap().starts_with(b"\x7fELF"));
    }

    #[test]
    #[ignore = "requires a separately pinned compiler-owned runtime archive"]
    fn actual_typed_scoped_call_links_and_runs_with_signed_test_adapter() {
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter();
        run_scoped_linked_case(&fixture,
            include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical"),
            "scoped.o", "scoped-linked", 2,
            "the source main returns copied-byte count 2");
    }

    #[test]
    #[ignore = "requires a separately pinned compiler-owned runtime archive"]
    fn source_produced_renamed_owner_and_result_link_with_signed_test_adapter() {
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter();
        run_scoped_linked_case(&fixture,
            include_str!("testdata/scoped_byte_copy_intrinsic_renamed_types_producer.canonical"),
            "renamed-scoped.o", "renamed-scoped-linked", 2,
            "renamed opaque owner and result must preserve native count 2");
    }

    #[test]
    #[ignore = "requires a separately pinned compiler-owned runtime archive"]
    fn actual_zero_length_scoped_call_links_and_runs_with_signed_test_adapter() {
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter();
        run_scoped_linked_case(&fixture,
            include_str!("testdata/scoped_byte_copy_intrinsic_zero_length_producer.canonical"),
            "zero-scoped.o", "zero-scoped-linked", 0,
            "zero input and zero output capacity must return zero");
    }

    #[test]
    #[ignore = "requires a separately pinned compiler-owned runtime archive"]
    fn actual_five_argument_scoped_call_links_and_runs_with_signed_test_adapter() {
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter_with_level();
        run_scoped_linked_case(&fixture,
            include_str!("testdata/scoped_byte_copy_intrinsic_local_five_arg_producer.canonical"),
            "five-arg-scoped.o", "five-arg-scoped-linked", 2,
            "five-argument adapter with level one must return copied-byte count 2");
    }

    #[test]
    #[ignore = "requires a separately pinned compiler-owned runtime archive"]
    fn actual_caller_borrowed_five_argument_scoped_call_links_and_runs() {
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter_with_level();
        run_scoped_linked_case(&fixture,
            include_str!("testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical"),
            "caller-borrowed-scoped.o", "caller-borrowed-scoped-linked", 2,
            "caller-borrowed input and fifth scalar must return copied-byte count 2");
    }

    #[test]
    #[ignore = "requires a separately pinned compiler-owned runtime archive"]
    fn actual_signed_adapter_error_returns_before_output_publication() {
        let fixture = Fixture::new();
        fixture.prepare_scoped_byte_adapter_error();
        run_scoped_linked_case(&fixture,
            include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical"),
            "error-scoped.o", "error-scoped-linked", 253,
            "signed adapter error -3 must exit before output publication");
    }

    #[test]
    fn manifest_fields_and_snapshot_epochs_reject_fail_closed() {
        let fixture = Fixture::new();
        let original = fs::read(fixture.package.join("manifest.txt")).unwrap();
        let changed = String::from_utf8(original.clone())
            .unwrap()
            .replace(TARGET, "x86_64-unknown-linux-musl");
        fixture.sign(changed.as_bytes());
        assert!(fixture.admit(&fixture.snapshot()).is_err());
        fixture.sign(&original);
        let stale = TrustSnapshot {
            release_epoch: 0,
            ..fixture.snapshot()
        };
        assert!(fixture.admit(&stale).is_err());
        let signature = fs::read(fixture.package.join("manifest.sig")).unwrap();
        let parsed = parse_manifest(&original).unwrap();
        assert!(
            verify_signature_at(&original, &signature, &parsed, &fixture.snapshot(), 0,).is_err()
        );
        assert!(
            verify_signature_at(
                &original,
                &signature,
                &parsed,
                &fixture.snapshot(),
                u64::MAX,
            )
            .is_err()
        );
        let unknown = TrustSnapshot {
            keys: &[],
            ..fixture.snapshot()
        };
        assert!(fixture.admit(&unknown).is_err());
    }

    include!("approved_zlib_tests.rs");
    include!("production_trust_tests.rs");
}
