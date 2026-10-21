const ZLIB_TEST_REGISTRY: RegisteredPackage = RegisteredPackage {
    id: "gust_zlib_1_3_2_test",
    exports: &["gust_zlib_bound", "gust_zlib_compress", "gust_zlib_decompress"],
};

fn prepare_real_zlib_test_package(fixture: &Fixture) {
    let input = PathBuf::from(std::env::var_os("GUST_R3_PACKAGE_DIR")
        .expect("focused R3 runner must bind the pinned zlib package"));
    let sources = [
        ("source", "zlib-1.3.2.tar.gz"),
        ("source", "gust_zlib_adapter.c"),
        ("header", "gust_zlib_adapter.h"),
        ("header", "zlib.h"),
        ("header", "zconf.h"),
        ("source", "zlib-LICENSE"),
        ("build_options", "build-options.txt"),
        ("object", "gust_zlib_adapter.o"),
        ("archive", "libz.a"),
    ];
    for entry in fs::read_dir(&fixture.package).unwrap() {
        fs::remove_file(entry.unwrap().path()).unwrap();
    }
    let mut manifest = format!(
        "format: {BYTE_SPAN_FORMAT}\nrepository: {REPOSITORY}\nrelease: test-release\npackage_id: {}\nepoch: 2\nsigner: fixture-key\ntarget: {TARGET}\nobject_format: Elf\nlicense: Zlib\nartifact_count: {}\n",
        ZLIB_TEST_REGISTRY.id, sources.len());
    for (kind, name) in sources {
        let bytes = fs::read(input.join(name)).unwrap();
        if name == "zlib-1.3.2.tar.gz" {
            assert_eq!(hex(&Sha256::digest(&bytes)),
                "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16");
        }
        if name == "gust_zlib_adapter.c" {
            assert_eq!(bytes, include_bytes!("../ffi-zlib/gust_zlib_adapter.c"));
        }
        if name == "gust_zlib_adapter.h" {
            assert_eq!(bytes, include_bytes!("../ffi-zlib/gust_zlib_adapter.h"));
        }
        fs::write(fixture.package.join(name), &bytes).unwrap();
        manifest.push_str(&format!("artifact: {kind}|{name}|{}\n",
            hex(&Sha256::digest(&bytes))));
    }
    let pointer = hex(b"RawPointer(Byte)");
    manifest.push_str("symbol_count: 3\n");
    manifest.push_str("symbol: gust_zlib_bound|496e74|value|1|496e74@value|-\n");
    manifest.push_str(&format!(
        "symbol: gust_zlib_compress|496e74|value|5|{pointer}@borrow_read_call,496e74@value,{pointer}@borrow_write_call,496e74@value,496e74@value|0@1@read,2@3@write\n"));
    manifest.push_str(&format!(
        "symbol: gust_zlib_decompress|496e74|value|4|{pointer}@borrow_read_call,496e74@value,{pointer}@borrow_write_call,496e74@value|0@1@read,2@3@write\n"));
    fixture.sign(manifest.as_bytes());
}

#[test]
#[ignore = "requires pinned zlib source, static build, and compiler-owned runtime archive"]
fn actual_pinned_zlib_adapter_links_signed_scoped_calls() {
    let fixture = Fixture::new();
    prepare_real_zlib_test_package(&fixture);
    let runtime = RuntimeSibling::stage();
    let cases = [
        ("compress", include_str!("testdata/phase26_r3_zlib_compress.canonical"), 10),
        ("decompress", include_str!("testdata/phase26_r3_zlib_decompress.canonical"), 2),
        ("empty_decompress",
            include_str!("testdata/phase26_r3_zlib_empty_decompress.canonical"), 0),
    ];
    for (name, canonical, expected_exit) in cases {
        let program = crate::full_program::parse(canonical).unwrap();
        verify_foreign_coverage(&program, &[ZLIB_TEST_REGISTRY],
            Some(&runtime.0), &runtime.0, &[]).unwrap();
        let object = fixture.root.join(format!("{name}.o"));
        crate::full_program::lower_program(&program, &object).unwrap();
        let output = fixture.root.join(format!("{name}-linked"));
        let package = VerifiedPackage::admit(&fixture.package, &ZLIB_TEST_REGISTRY,
            &program, &fixture.snapshot(), &output).unwrap();
        let staged = package.link_inputs().to_vec();
        let mut request = link_request(package, object, output.clone());
        request.runtime_package = Some(runtime.0.clone());
        let report = crate::run_compiler_mir_link_request(request).unwrap();
        assert!(report.published);
        assert_eq!(report.approved_package_id.as_deref(), Some(ZLIB_TEST_REGISTRY.id));
        assert!(staged.iter().all(|path| !path.exists()));
        let status = std::process::Command::new(&output)
            .env_clear().env("PATH", "/usr/bin:/bin").status().unwrap();
        assert_eq!(status.code(), Some(expected_exit), "{name}");
        let retained = PathBuf::from(std::env::var_os("GUST_R3_LINKED_EXECUTABLE_DIR")
            .expect("focused R3 runner must own linked executable retention"))
            .join(name);
        assert!(!retained.exists());
        fs::copy(&output, &retained).unwrap();
        assert!(fs::read(&retained).unwrap().starts_with(b"\x7fELF"));
    }
    let program = crate::full_program::parse(cases[0].1).unwrap();
    let output = fixture.root.join("tampered-never-published");
    for name in ["zlib-1.3.2.tar.gz", "gust_zlib_adapter.o", "libz.a"] {
        let path = fixture.package.join(name);
        let original = fs::read(&path).unwrap();
        let mut changed = original.clone();
        changed.push(0);
        fs::write(&path, changed).unwrap();
        assert!(VerifiedPackage::admit(&fixture.package, &ZLIB_TEST_REGISTRY,
            &program, &fixture.snapshot(), &output).is_err(), "{name}");
        assert!(!output.exists(), "{name}");
        fs::write(path, original).unwrap();
    }
}
