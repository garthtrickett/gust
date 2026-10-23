//! Operator-enrolled, worker-pinned production profile. No input updates trust.
use super::*;

pub const RELEASE: &str = "phase26-native-release-1";
pub const PACKAGE: &str = "gust_zlib_1_3_2_production";
pub const MAXIMUM_VALIDITY_SECONDS: u64 = 604800;
pub const MANIFEST: &[u8] = include_bytes!("../production/manifest.txt");
pub const SNAPSHOT: TrustSnapshot<'static> = TrustSnapshot {
    release: RELEASE,
    release_epoch: 1,
    issued_unix_seconds: 1792723172,
    expires_unix_seconds: 1793327972,
    minimum_package_epoch: 1,
    keys: &[TrustedKey {
        id: "gust-native-release-1",
        public_key: [0x67,0x78,0xb0,0x5d,0x2e,0xf8,0xf7,0xaf,
            0x4f,0x55,0x39,0x18,0xb2,0xb5,0x65,0x8e,
            0xba,0x1d,0x79,0x19,0x53,0x6a,0xb3,0xb6,
            0x4c,0x69,0xe6,0x3f,0xd5,0xe0,0xb5,0x50],
        first_epoch: 1, last_epoch: 1,
    }],
    revoked_keys: &[], withdrawn_digests: &[],
};
pub const REGISTRY: &[RegisteredPackage] = &[RegisteredPackage {
    id: PACKAGE,
    exports: &["gust_zlib_bound", "gust_zlib_compress", "gust_zlib_decompress"],
}];

const MEMBERS: &[&str] = &["crt1.o", "crti.o", "crtbeginT.o", "libc.a",
    "libm-2.39.a", "libmvec.a", "libgcc.a", "libgcc_eh.a", "crtend.o", "crtn.o"];
const LINKER_SHA256: &str = "e9ceb054c12207970f2726dfc07e9a66b411602748628baf27399f02a9bbb31b";

#[derive(Debug)]
pub struct StaticLink {
    directory: PathBuf,
    hashes: Vec<(PathBuf, [u8; 32])>,
}

impl StaticLink {
    pub fn verify_executable(&self, path: &Path) -> Result<(), PackageError> {
        let bytes = fs::read(path).map_err(|_| reject("production executable absent"))?;
        if bytes.len() < 64 || &bytes[..7] != b"\x7fELF\x02\x01\x01" ||
            bytes[16..20] != [2, 0, 62, 0] {
            return Err(reject("production executable target or ELF kind"));
        }
        let offset = usize::try_from(u64::from_le_bytes(bytes[32..40].try_into().unwrap()))
            .map_err(|_| reject("production ELF offset overflow"))?;
        let width = usize::from(u16::from_le_bytes(bytes[54..56].try_into().unwrap()));
        let count = usize::from(u16::from_le_bytes(bytes[56..58].try_into().unwrap()));
        if width != 56 || count == 0 || count > 128 {
            return Err(reject("production ELF program-header shape"));
        }
        let end = offset.checked_add(width * count)
            .ok_or_else(|| reject("production ELF header overflow"))?;
        let headers = bytes.get(offset..end)
            .ok_or_else(|| reject("production ELF header bounds"))?;
        for header in headers.chunks_exact(width) {
            if matches!(u32::from_le_bytes(header[..4].try_into().unwrap()), 2 | 3) {
                return Err(reject("production executable has dynamic dependencies"));
            }
        }
        Ok(())
    }

    pub fn stage(directory: &Path) -> Result<Self, PackageError> {
        let archive = fs::read(directory.join("link-closure.a"))
            .map_err(|_| reject("production static closure absent"))?;
        let parsed = ArchiveFile::parse(archive.as_slice())
            .map_err(|_| reject("production static closure archive"))?;
        if parsed.is_thin() { return Err(reject("production closure is thin")); }
        let mut seen = BTreeSet::new();
        let mut hashes = Vec::new();
        for entry in parsed.members() {
            let entry = entry.map_err(|_| reject("production closure member"))?;
            let name = std::str::from_utf8(entry.name())
                .map_err(|_| reject("production closure member name"))?;
            if !MEMBERS.contains(&name) || !seen.insert(name.to_string()) {
                return Err(reject("production closure unknown or duplicate member"));
            }
            let bytes = entry.data(archive.as_slice())
                .map_err(|_| reject("production closure member bounds"))?;
            let path = directory.join(name);
            let mut file = OpenOptions::new().write(true).create_new(true).open(&path)
                .map_err(|_| reject("production closure private member creation"))?;
            file.write_all(bytes).map_err(|_| reject("production closure member write"))?;
            hashes.push((path, Sha256::digest(bytes).into()));
        }
        if seen.len() != MEMBERS.len() { return Err(reject("production closure incomplete")); }
        let runtime = directory.join("gust-runtime-package.a");
        hashes.push((runtime.clone(), Sha256::digest(fs::read(runtime)
            .map_err(|_| reject("production runtime absent"))?).into()));
        Ok(Self { directory: directory.to_path_buf(), hashes })
    }

    pub fn recheck(&self) -> Result<(), PackageError> {
        for (path, expected) in &self.hashes {
            let bytes = fs::read(path).map_err(|_| reject("production link input missing"))?;
            if <[u8; 32]>::from(Sha256::digest(bytes)) != *expected {
                return Err(reject("production staged link input changed"));
            }
        }
        let linker = fs::read("/usr/bin/ld").map_err(|_| reject("production linker absent"))?;
        if hex_digest(Sha256::digest(linker).into()) != LINKER_SHA256 {
            return Err(reject("production linker differs from pinned tool"));
        }
        Ok(())
    }

    pub fn prefix(&self) -> Vec<PathBuf> {
        ["crt1.o", "crti.o", "crtbeginT.o"].map(|n| self.directory.join(n)).to_vec()
    }
    pub fn runtime(&self) -> PathBuf { self.directory.join("gust-runtime-package.a") }
    pub fn suffix(&self) -> Vec<std::ffi::OsString> {
        let mut args = vec!["--start-group".into()];
        for name in ["libc.a", "libm-2.39.a", "libmvec.a", "libgcc.a", "libgcc_eh.a"] {
            args.push(self.directory.join(name).into_os_string());
        }
        args.push("--end-group".into());
        args.push(self.directory.join("crtend.o").into_os_string());
        args.push(self.directory.join("crtn.o").into_os_string());
        args
    }
}

pub fn check_snapshot(snapshot: &TrustSnapshot<'_>) -> Result<(), PackageError> {
    if snapshot.release == RELEASE && snapshot.expires_unix_seconds
        .checked_sub(snapshot.issued_unix_seconds)
        .is_none_or(|duration| duration == 0 || duration > MAXIMUM_VALIDITY_SECONDS) {
        return Err(reject("production snapshot exceeds offline freshness limit"));
    }
    Ok(())
}
