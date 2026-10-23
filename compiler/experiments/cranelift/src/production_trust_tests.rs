#[test]
fn enrolled_signature_and_snapshot_fail_closed() {
    let bytes = production_trust::MANIFEST;
    let signature = include_bytes!("../production/manifest.sig");
    let manifest = parse_manifest(bytes).unwrap();
    let snapshot = production_trust::SNAPSHOT;
    let now = snapshot.issued_unix_seconds;
    assert!(verify_signature_at(bytes, signature, &manifest, &snapshot, now).is_ok());
    assert_eq!(snapshot.release_epoch, 1);
    assert_eq!(snapshot.minimum_package_epoch, 1);
    assert_eq!(snapshot.keys.len(), 1);
    assert_eq!((snapshot.keys[0].first_epoch, snapshot.keys[0].last_epoch), (1, 1));
    assert_eq!(snapshot.expires_unix_seconds - now, 604800);
    for time in [0, now - 1, snapshot.expires_unix_seconds, u64::MAX] {
        assert!(verify_signature_at(bytes, signature, &manifest, &snapshot, time).is_err());
    }
    let too_long = TrustSnapshot { expires_unix_seconds: now + 604801,
        ..production_trust::SNAPSHOT };
    assert!(verify_signature_at(bytes, signature, &manifest, &too_long, now).is_err());
    let unknown_bytes = String::from_utf8(bytes.to_vec()).unwrap()
        .replace("signer: gust-native-release-1", "signer: unregistered-key").into_bytes();
    assert_ne!(unknown_bytes, bytes);
    let unknown_manifest = parse_manifest(&unknown_bytes).unwrap();
    assert!(verify_signature_at(&unknown_bytes, signature, &unknown_manifest, &snapshot, now)
        .unwrap_err().to_string().contains("unknown signer"));
    let unknown = TrustSnapshot { keys: &[], ..production_trust::SNAPSHOT };
    assert!(verify_signature_at(bytes, signature, &manifest, &unknown, now).is_err());
    let revoked = TrustSnapshot { revoked_keys: &["gust-native-release-1"],
        ..production_trust::SNAPSHOT };
    assert!(verify_signature_at(bytes, signature, &manifest, &revoked, now).is_err());
    let digests = [Sha256::digest(bytes).into()];
    let withdrawn = TrustSnapshot { withdrawn_digests: &digests,
        ..production_trust::SNAPSHOT };
    assert!(verify_signature_at(bytes, signature, &manifest, &withdrawn, now).is_err());
    let mut changed = *signature;
    changed[0] ^= 1;
    assert!(verify_signature_at(bytes, &changed, &manifest, &snapshot, now).is_err());
    for value in [b"".as_slice(), &signature[..63]] {
        assert!(verify_signature_at(bytes, value, &manifest, &snapshot, now).is_err());
    }
}

#[test]
#[ignore = "requires exact signed production package and pinned runtime; offline"]
fn enrolled_production_package_links_and_executes_offline() {
    let package_dir = PathBuf::from(std::env::var_os("GUST_PRODUCTION_PACKAGE_DIR").unwrap());
    let fixture = Fixture::new();
    let runtime = RuntimeSibling::stage();
    let registry = &PRODUCTION_REGISTRY[0];
    let mut prior = None;
    for (name, canonical, expected) in [
        ("compress", include_str!("testdata/phase26_r3_zlib_compress.canonical"), 10),
        ("compress-again", include_str!("testdata/phase26_r3_zlib_compress.canonical"), 10),
        ("decompress", include_str!("testdata/phase26_r3_zlib_decompress.canonical"), 2),
        ("empty", include_str!("testdata/phase26_r3_zlib_empty_decompress.canonical"), 0),
    ] {
        let program = crate::full_program::parse(canonical).unwrap();
        verify_foreign_coverage(&program, PRODUCTION_REGISTRY,
            Some(&runtime.0), &runtime.0, &[]).unwrap();
        let object = fixture.root.join(format!("{name}.o"));
        crate::full_program::lower_program(&program, &object).unwrap();
        let output = fixture.root.join(name);
        let package = VerifiedPackage::admit(&package_dir, registry, &program,
            &PRODUCTION_SNAPSHOT, &output).unwrap();
        let profile = package.production_link().unwrap();
        // The signed public provenance must describe the arguments the worker
        // actually constructs, including startup and archive-group ordering.
        // This is a test of the fixed canonical JSON emitted by our assembler,
        // not a second metadata admission parser.
        let provenance = fs::read_to_string(package_dir.join("link-provenance.json")).unwrap();
        let section = provenance.split("\"link_order\": [").nth(1).unwrap()
            .split(']').next().unwrap();
        let declared: Vec<_> = section.lines().map(str::trim)
            .filter(|line| !line.is_empty())
            .map(|line| line.trim_end_matches(',').strip_prefix('"').unwrap()
                .strip_suffix('"').unwrap().to_string()).collect();
        let filename = |path: &Path| path.file_name().unwrap().to_str().unwrap().to_string();
        let mut actual: Vec<_> = profile.prefix().iter().map(|path| filename(path)).collect();
        actual.push("<generated-object>".into());
        actual.extend(package.link_inputs().iter().map(|path| filename(path)));
        actual.push(filename(&profile.runtime()));
        actual.extend(profile.suffix().iter().map(|arg| filename(Path::new(arg))));
        assert_eq!(declared, actual, "signed provenance disagrees with actual worker link order");
        let mut request = link_request(package, object, output.clone());
        request.runtime_package = Some(runtime.0.clone());
        let report = crate::run_compiler_mir_link_request(request).unwrap();
        assert!(report.published);
        let bytes = fs::read(&output).unwrap();
        if name == "compress" { prior = Some(bytes.clone()); }
        if name == "compress-again" { assert_eq!(prior.as_ref().unwrap(), &bytes); }
        assert_eq!(std::process::Command::new(&output).env_clear()
            .env("LD_PRELOAD", "/untrusted/not-a-library.so")
            .env("LD_LIBRARY_PATH", "/untrusted").status().unwrap().code(), Some(expected));
        let retain = PathBuf::from(std::env::var_os("GUST_PRODUCTION_EXECUTABLE_DIR").unwrap());
        fs::copy(&output, retain.join(name)).unwrap();
    }
}

#[test]
#[ignore = "requires exact signed production package; rejects before execution"]
fn enrolled_production_admission_negative_matrix() {
    fn rejected(label: &str, result: Result<VerifiedPackage, PackageError>, assertion: &str) {
        match result {
            Ok(_) => panic!("{label}: ACCEPTED"),
            Err(error) => {
                if error.to_string().contains(assertion) {
                    println!("{label}: REJECTED (expected assertion): {error}");
                } else {
                    panic!("{label}: REJECTED (different assertion): {error}");
                }
            }
        }
    }
    let original = PathBuf::from(std::env::var_os("GUST_PRODUCTION_PACKAGE_DIR").unwrap());
    let fixture = Fixture::new();
    let package = fixture.root.join("production");
    fs::create_dir(&package).unwrap();
    for entry in fs::read_dir(&original).unwrap() {
        let entry = entry.unwrap();
        fs::copy(entry.path(), package.join(entry.file_name())).unwrap();
    }
    let canonical = include_str!("testdata/phase26_r3_zlib_compress.canonical");
    let mut program = crate::full_program::parse(canonical).unwrap();
    let output = fixture.root.join("must-not-exist");
    let admit = |program: &Program| VerifiedPackage::admit(&package,
        &PRODUCTION_REGISTRY[0], program, &PRODUCTION_SNAPSHOT, &output);
    drop(admit(&program).unwrap()); // Positive baseline proves the mechanism is live.
    for entry in fs::read_dir(&package).unwrap() {
        let path = entry.unwrap().path();
        let bytes = fs::read(&path).unwrap();
        fs::remove_file(&path).unwrap();
        rejected(&format!("missing {}", path.display()), admit(&program), "missing package input");
        let mut tampered = bytes.clone(); tampered.push(0);
        fs::write(&path, tampered).unwrap();
        let assertion = match path.file_name().unwrap().to_str().unwrap() {
            "manifest.txt" => "manifest size or line ending",
            "manifest.sig" => "signature width",
            _ => "artifact digest mismatch",
        };
        rejected(&format!("tampered {}", path.display()), admit(&program), assertion);
        assert!(!output.exists());
        fs::write(path, bytes).unwrap();
    }
    program.target_triple = "x86_64-unknown-linux-musl".into();
    rejected("wrong target", admit(&program), "canonical program target");
    program.target_triple = TARGET.into();
    let runtime = fixture.root.join("untrusted-runtime.a");
    fs::write(&runtime, b"substituted").unwrap();
    let error = verify_foreign_coverage(&program, PRODUCTION_REGISTRY,
        Some(&runtime), &runtime, &[]).unwrap_err();
    assert!(error.to_string().contains("runtime differs from signed artifact"));
    assert!(verify_foreign_coverage(&program, PRODUCTION_REGISTRY,
        Some(Path::new("/environment/runtime.a")), &runtime, &[]).is_err());
    let sealed = admit(&program).unwrap();
    let profile = sealed.production_link().unwrap();
    let changed = profile.prefix()[0].clone();
    fs::write(changed, b"changed after admission").unwrap();
    assert!(sealed.recheck_staged_bytes().unwrap_err().to_string()
        .contains("production staged link input changed"));
    assert!(!output.exists());
}

#[test]
#[ignore = "compile-only source-produced canonical probe; never links or executes"]
fn source_produced_scoped_probe_records_owning_rejection() {
    let path = PathBuf::from(std::env::var_os("GUST_SCOPED_PROBE_CANONICAL").unwrap());
    let expected = std::env::var("GUST_SCOPED_PROBE_REJECTION").unwrap();
    let canonical = fs::read_to_string(path).unwrap();
    let error = crate::full_program::parse(&canonical).unwrap_err();
    assert!(error.to_string().contains(&expected), "REJECTED (different assertion): {error}");
    println!("REJECTED (expected assertion): {error}");
}
