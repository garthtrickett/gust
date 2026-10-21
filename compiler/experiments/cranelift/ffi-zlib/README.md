# Phase 26 zlib adapter

This optional C component implements the three fixed entry points in
`gust_zlib_adapter.h`. The adapter borrows spans for one synchronous call and
returns an initialized destination byte count or a negative status. It does
not prove that an arbitrary non-null caller pointer names live storage; the
unsafe caller and the R2 scoped-copy plan retain that obligation.

The pinned upstream source is the [zlib 1.3.2 release archive][zlib-source],
SHA-256
`bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16`.
The archive includes the upstream zlib license. The build script compiles its
11 compression/decompression core objects into a deterministic GNU static
archive, compiles this adapter as a separate object, and records the exact
compiler, archiver, options, source, and resulting artifact hashes. It does
not install zlib or link a shared `libz`.

```sh
bash scripts/phase26_r3_zlib_adapter.sh \
  /path/to/zlib-1.3.2.tar.gz /new/output-directory
```

The package manifest and signature are intentionally created only by the
test-profile integration in `approved_zlib_tests.rs`. Production signing key,
release epoch, and withdrawal policy are still unassigned; the production
registry and trust snapshot remain empty. Neither a local source checksum nor
the fixture signature turns this build into an approved release package.
The release package must also bind its complete target link environment under
the first-release FFI contract.

`scripts/phase26_r3_zlib_adapter_guard.sh` runs the C behavior matrix,
compares source-produced Gust canonical Programs, and admits and links the
three actual zlib entry-point cases through the signed test profile. It keeps
the ordinary command-line production route denied in the absence of a
release signer. The checked-in Gust fixtures are native integration probes;
the public safe Vector wrapper is separately owned.

[zlib-source]: https://zlib.net/zlib-1.3.2.tar.gz
