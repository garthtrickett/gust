# Mobile native deployment — Gust, Swift, and Kotlin

Status: **PROPOSAL for OD-12, not an implementation claim or semantic decision**

Written: 2026-08-21

Scope: iOS and Android application deployment; server and browser targets appear
only where they constrain the mobile design.

## 1. Recommendation

Compile the Gust application ahead of time to device machine code and package it
inside an ordinary iOS or Android application. Let a small, generated host use the
platform's native application lifecycle and UI framework:

- Swift plus SwiftUI/UIKit on Apple platforms;
- Kotlin plus Jetpack Compose/Android Views on Android;
- a narrow, versioned C-shaped ABI between that host and the Gust application;
- one compiler-owned mobile `View` and action model above both renderers.

Swift and Kotlin should therefore be **inside Gust's platform implementation, not
inside the normal application programming model**. A developer writes Gust. The
toolchain generates the Xcode or Gradle host, links the Gust binary, pins the
adapter version, and produces the store artifact. Gust owns and tests the Swift
and Kotlin adapters as part of a platform release.

Application-authored Swift or Kotlin may eventually exist as a deliberately
declared native escape hatch for a platform facility Gust does not expose. It
must not be the routine answer to a missing widget or device API, and it cannot
inherit the guarantee of an out-of-process supplier.

This recommendation is recorded as **OPEN**, not adopted. `docs/VISION.md` §0.15
is the authoritative status register and now names the question as OD-12.

### The short answer to “like S3?”

Only in one respect: application code should call a Gust-owned interface and
should not import a provider SDK directly. The trust boundary is different.
S3 is a remote service; Swift/Kotlin UI code is privileged code in the application
process. The former can be data-minimized and revoked at a network boundary. The
latter participates in lifecycle, memory, UI-thread, and process integrity. It
belongs in the trusted platform base or in an explicitly labelled escape hatch,
not in the supplier category.

## 2. What “native performance” means here

“Native” should be an observable deployment property, not a slogan:

1. Gust application logic is ahead-of-time compiled for the device ABI. No
   WebView, downloaded program, JIT, or embedded language interpreter is needed
   for the recommended path.
2. The user interface is presented through platform UI primitives, so text,
   input, accessibility, navigation, focus, and lifecycle participate in the
   operating system normally.
3. The Gust/native-host boundary is coarse. One state transition may exchange a
   view update and an action; it must not make a foreign call per pixel, layout
   node, collection element, or animation frame.
4. Performance is measured against an equivalent native control application on
   representative devices: cold start, warm start, p50/p95 frame time, missed
   frames, memory, binary size, boundary calls, and copied bytes.

The existing backend rationale must not be rewritten to fit this proposal.
`README.md:45-53` says Cranelift exists to preserve Gust's memory model rather than
as a performance play. AOT device code is still the right mobile deployment
shape, but no document should promise that it is faster than Swift or Kotlin
without measurements.

## 3. Ground truth checked before proposing a design

### 3.1 What the vision already requires

- Gust provides one official way for common application parts and says the
  platform owns UI and rendering (`docs/VISION.md:622-626`).
- External suppliers are genuinely external services, and applications call
  Gust-owned capability interfaces rather than supplier SDKs
  (`docs/VISION.md:628-630`).
- The preferred supplier execution order is remote, sandboxed local, then
  in-process only when strictly necessary (`docs/VISION.md:638-650`).
- S3-compatible storage is platform infrastructure behind a Gust-owned API
  (`docs/VISION.md:652-658`).
- The currently proposed client model is browser-only and is explicitly
  speculative: no Wasm target, templates, SAM runtime, or RPC layer exists
  (`docs/VISION.md:1276-1292`).
- The intended UI is a compiler-owned typed template plus SAM actions and effects
  (`docs/VISION.md:1294-1330`).
- In-process native code weakens memory-safety and process-integrity guarantees
  for the application instance (`docs/VISION.md:2065-2073`).
- The dependency reconciliation gives the pinned platform its full guarantee,
  puts S3 behind an out-of-process certified capability, and places in-process
  native code in the escape-hatch category
  (`docs/VISION_RECONCILIATION.md:336-352`).

Those facts support a Gust-owned mobile adapter, but they do not already decide
it.

### 3.2 What the compiler supports today

There is no mobile target today.

The compiler's declared target list contains five desktop/server triples:
`x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`,
`i686-unknown-linux-gnu`, `x86_64-apple-darwin`, and
`aarch64-apple-darwin` (`compiler/mir_primitive_layout.gst:143-152`). The live
target diagnostics call only `x86_64-unknown-linux-gnu` supported; the other four
are unsupported for a missing linker
(`scripts/cranelift_feature_registry.json:6138-6156`). Neither an iOS target nor
an Android target is in that set. A macOS Darwin triple is not an iOS triple, and
a GNU/Linux triple is not an Android ABI.

The compiler correctly treats target support as a conjunction of compiler,
runtime package, linker, and ABI evidence, not merely an instruction-set claim
(`compiler/mir_target_authority.gst:224-294`). Mobile therefore requires new
complete target tuples and runners, not relabelling the existing AArch64 rows.

The only directly relevant language boundary already enforced is narrower:
direct external/native calls require `unsafe`
(`compiler/typechecker.gst:4042-4048`). The broader signed-adapter, capability,
isolation, provenance, and guarantee-ledger machinery does not exist; the vision
records that absence at `docs/VISION.md:2059-2077`.

The credibility ledger is equally direct: authority, dependencies, external
services, client/server RPC, and rendering are absent; the backend is partial;
native-code governance is partial (`docs/ONE_WAY_LEDGER.md:82-101`). This report
does not upgrade any of those scores.

### 3.3 Two document conflicts this proposal exposes

Do not silently resolve either conflict:

1. `docs/VISION.md:1286-1290` fixes client functions to the browser. A mobile
   client execution location would amend that model; it is not an implementation
   detail under the existing words.
2. `docs/VISION_RECONCILIATION.md:347-352` gives platform code the full guarantee,
   while `docs/VISION.md:2065-2071` says in-process native code weakens the whole
   instance. A Gust-owned Swift/Kotlin adapter is both platform code and
   in-process native code unless the trusted platform base is defined explicitly.

The proposed resolution is to make the reviewed, version-pinned Gust mobile
adapter part of the platform trusted computing base, while any application-owned
or third-party native module remains an escape hatch. That resolution belongs to
OD-12 and requires operator authority.

## 4. Why Swift and Kotlin belong in the host

iOS and Android are not just CPU targets. Their application models own startup,
scene/activity lifecycle, UI-thread rules, backgrounding, restoration,
permissions, accessibility, signing, packaging, and store submission.

A completely native Android activity is possible, but Google's NDK documentation
still says the Android framework is useful for display and UI. It packages native
libraries with managed application code. Android's JNI guidance calls JNI
reasonably efficient while warning that marshalling has non-trivial cost and that
cross-language asynchronous communication should be minimized. That is a strong
argument for a small Kotlin owner of lifecycle and UI, not for pretending Android
is ordinary Linux. See the official [NDK concepts](https://developer.android.com/ndk/guides/concepts)
and [JNI guidance](https://developer.android.com/ndk/guides/jni-tips).

On Apple platforms, Swift interoperates with C by default. Xcode can package
static libraries and headers for device and simulator variants in an XCFramework.
That supplies a conventional route from a Gust-produced native library to a
small Swift host. See Apple's [C interoperability](https://developer.apple.com/documentation/swift/c-interoperability)
and [XCFramework packaging](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle).

The declarative native UI frameworks also fit Gust's intended state direction:
Jetpack Compose documents immutable UI with state flowing down and events flowing
up, and SwiftUI watches a source of truth and updates affected views. Both provide
native accessibility semantics. See the official
[Compose architecture](https://developer.android.com/develop/ui/compose/architecture),
[SwiftUI state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state),
[Compose semantics](https://developer.android.com/develop/ui/compose/accessibility/semantics),
and [SwiftUI accessibility](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals).

That alignment is useful, not authority. Gust's SAM model remains canonical. The
SwiftUI and Compose state holders mirror a presented snapshot and send action IDs
back; they do not become second application stores.

Start the renderer spike with SwiftUI and Compose because their state/event shape
fits that contract. Keep the adapter interface renderer-neutral: if measurement
or a platform behaviour test fails, Gust can replace a primitive with UIKit or
Android Views without changing application source. Compose is a library shipped
with the Android application rather than part of the base operating system, so
its complete pinned dependency closure must be visible as Gust platform
provenance. It must not become an application-managed Gradle graph.

### Why the boundary should be C-shaped

- Swift imports C APIs directly.
- Android's standard managed/native boundary is JNI, whose native side is a C/C++
  interface.
- A tiny C ABI avoids making Gust's external contract depend on Swift ABI details,
  C++ interop evolution, Kotlin/Native, or a shared object model.
- Swift's C++ interoperability is still described as evolving and supports a
  subset of language features. Kotlin's direct Swift export is Alpha, and its C
  library import surface is Beta. Those are poor foundations for Gust's canonical
  mobile contract. See [Swift C++ interoperability](https://www.swift.org/documentation/cxx-interop/),
  [Kotlin Swift export](https://kotlinlang.org/docs/native-swift-export.html), and
  [Kotlin C interop](https://kotlinlang.org/docs/native-c-interop.html).

This does not mean exposing ordinary C pointers to application code. It means the
generated platform boundary has a C-compatible binary shape.

## 5. Proposed architecture

```text
Gust application source
        |
        v
canonical Gust program + View/action/effect plan
        |
        +--------------------------+
        | AOT mobile native core   |
        | opaque handles + buffers |
        +------------+-------------+
                     | versioned C ABI
          +----------+-----------+
          |                      |
  generated Swift host    generated Kotlin host
  Gust-owned adapter      Gust-owned adapter
  SwiftUI/UIKit           Compose/Android Views
          |                      |
  signed iOS bundle       signed Android App Bundle
```

The platform host is thin but not trivial. It owns:

- process and scene/activity lifecycle;
- the main UI thread and native view identity;
- permission prompts and operating-system callbacks;
- translation from the compiler-owned mobile `View` plan to native controls;
- delivery of typed action IDs back to the Gust state machine;
- platform capability implementations such as notifications, camera, share
  sheets, secure storage, and biometrics;
- crash-symbol and provenance metadata for both halves of the binary.

The Gust core owns:

- application state transitions and validation;
- presenters and the canonical view description;
- business logic and typed RPC;
- capability requests in business terms;
- serialization of state that must survive process death;
- the set of actions and effects the native host may deliver.

### 5.1 Boundary rules

The first ABI should be deliberately boring:

1. **Opaque application handle.** Swift/Kotlin never retain a Gust reference,
   arena pointer, string view, or resource directly.
2. **Fixed-width scalars and owned byte buffers.** Strings are UTF-8 with explicit
   lengths. Ownership and release functions are unambiguous. Android's JNI uses
   UTF-16/modified UTF-8 for some string operations, so bulk UTF-8 buffers avoid
   an implicit semantic conversion.
3. **Version handshake before start.** App ABI, adapter ABI, `View` schema,
   platform release, target tuple, and capability table must agree before the
   first screen appears.
4. **Batched transitions.** The host sends an action plus payload. Gust returns a
   view update and a list of effects. No getter-shaped chat across JNI.
5. **Queued completions, no re-entrant application calls.** A platform effect
   completes by enqueuing a typed result for the Gust event loop. Native UI code
   does not call back into arbitrary Gust frames.
6. **No unwind across the ABI.** Panic, exception, cancellation, and allocation
   failure become declared terminal or typed boundary results.
7. **UI-thread ownership is native.** Gust may compute away from the main thread,
   but the adapter applies UI work on the platform's required executor.
8. **Capabilities, not SDK objects.** A camera result or notification token crosses
   a typed Gust capability result; a UIKit, SwiftUI, Android, or Compose object
   never enters application state.
9. **One provenance record.** Store artifact, Gust compiler, platform adapter,
   native libraries, Gradle/Xcode toolchain, entitlements/permissions, and symbols
   are locked and auditable together.

### 5.2 iOS artifact

The compiler/backend work must produce explicit iOS device and simulator target
tuples, not reuse `aarch64-apple-darwin`. The build then:

1. emits and links the Gust core for each required iOS destination;
2. packages static libraries plus the generated C header in an XCFramework;
3. generates a small Swift app target and the declared entitlements/resources;
4. compiles the Gust-owned Swift adapter and links the XCFramework;
5. archives, signs, and submits through the normal Xcode toolchain.

Apple documents ARM64 device binaries and separate device/simulator library
variants in its XCFramework guidance. The final app must bundle the executable
Gust program. App Review Guideline 2.5.2 says an app may not download, install, or
execute code that introduces or changes functionality, so remote-delivered Gust
code is not the baseline iOS deployment model. See Apple's current
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

### 5.3 Android artifact

The compiler/backend work must add Android target tuples and runtime/linker
packages. Android names packaged native ABIs such as `arm64-v8a` and `x86_64`;
they are not interchangeable with the existing GNU/Linux rows. See the official
[Android ABI guide](https://developer.android.com/ndk/guides/abis).

The build then:

1. emits a Gust shared library for each selected Android ABI;
2. links a tiny JNI adapter and exports only its registration entry point where
   practical;
3. generates the Kotlin application/activity, manifest, resources, and Gradle
   project from the Gust application manifest;
4. loads the Gust library once, registers native methods at startup, and keeps
   JNI contact localized to the adapter;
5. packages ABI-specific libraries into the APK/App Bundle and signs it through
   the normal Android toolchain.

The JNI design follows Android's own advice: minimize marshalling, keep async UI
updates on the managed side, minimize threads touching JNI, and keep interface
code in a few identifiable locations.

### 5.4 Local and Gust Forge builds

The same declared mobile build must work locally and on Gust Forge. Hosted builds
are a convenience and a custody boundary, not a second architecture:

- iOS compilation, archive, and signing run on a declared macOS/Xcode worker;
- Android compilation and App Bundle signing run in a pinned Android toolchain;
- signing identities are scoped release credentials and never become application
  environment variables or agent-readable source;
- the produced archive records compiler, adapter, SDK, linker, dependencies,
  entitlements/permissions, signing identity reference, and artifact digest;
- self-hosted builders consume the same manifest and produce the same evidence.

Store submission is a separate, explicitly authorized outward action. Building a
signed candidate must not silently upload it, change a listing, or promote a
release.

## 6. Should developers be allowed to write Swift or Kotlin?

Not as an ordinary mixed-source feature.

| Code | Classification | Default | Guarantee treatment |
| --- | --- | --- | --- |
| Generated host glue | compiler output | included | part of the pinned Gust platform artifact |
| Gust-owned Swift/Kotlin renderer and capability adapter | platform implementation | included | trusted platform base; conformance-tested and versioned |
| Application-authored Swift/Kotlin component | native escape hatch | forbidden unless explicitly approved | process-integrity boundary is forfeit for that app instance |
| Arbitrary Swift Package / Gradle dependency | uncontrolled dependency graph | forbidden | not silently laundered through generated host code |

This is “closed implementation, open escape hatches,” the existing preferred
messaging (`docs/MESSAGING.md:170-180`). It also protects the model-fluency thesis:
an agent still learns one application language and one UI/state model. Requiring
it to choose among Gust, SwiftUI, UIKit, Compose, Android Views, coroutines, Swift
concurrency, and two package ecosystems would multiply the very idioms Gust is
designed to remove.

The escape hatch may be useful for an uncommon hardware SDK or a platform control
not yet represented by Gust. Certification cannot make it S3-like: it remains
in-process and privileged. The release should print the lost guarantee, the
native module identity, its permissions, and its provenance. No such machinery
exists today.

## 7. Ranked solutions

Scores use a 1–5 scale. The weighted total is out of 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Vision integrity / one application model | 20 | “One official way” is a correctness and agent-accuracy claim. |
| Native UX, lifecycle, accessibility | 15 | A fast app that behaves unlike the platform is not a good mobile app. |
| Runtime performance potential | 15 | CPU, UI, startup, memory, and boundary overhead all count. |
| Guarantee and provenance boundary | 15 | In-process foreign code can invalidate the central claim. |
| Agent writability | 10 | The generator, not developer preference, is the design lever. |
| Delivery feasibility | 10 | The route must be buildable with current store toolchains. |
| Long-term maintenance | 15 | Two changing operating systems create permanent work. |

| Rank | Option | Vision | UX | Perf | Guarantee | Agent | Delivery | Maintenance | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **1** | **AOT Gust core + generated Swift/Kotlin host + Gust-owned native UI adapters** | 5 | 5 | 5 | 4 | 5 | 3 | 4 | **90** |
| 2 | AOT Gust core + a Gust-owned custom renderer, with minimal OS shells | 5 | 3 | 5 | 4 | 5 | 1 | 2 | **74** |
| 3 | Bundled Wasm core + native Swift/Kotlin host and UI | 4 | 4 | 3 | 3 | 4 | 3 | 3 | **69** |
| 4 | AOT Gust core + constrained application-authored SwiftUI/Compose views | 3 | 5 | 5 | 2 | 3 | 4 | 2 | **68** |
| 5 | Browser application in WebView/PWA shell | 4 | 1 | 1 | 3 | 5 | 5 | 4 | **63** |
| 6 | Kotlin Multiplatform core + SwiftUI/Compose application UI | 1 | 5 | 4 | 2 | 2 | 4 | 3 | **58** |
| 7 | Transpile Gust application code to Swift and Kotlin | 3 | 4 | 4 | 2 | 3 | 1 | 1 | **53** |
| 8 | Unrestricted mixed Gust/Swift/Kotlin source and package ecosystems | 1 | 5 | 5 | 1 | 1 | 3 | 1 | **48** |

### 7.1 Why option 1 wins

It keeps application semantics in Gust while delegating the things the operating
system actually owns. The native bridge is small enough to audit and benchmark;
the UI is platform-native; generated projects remain ordinary Xcode and Gradle
artifacts; and the same compiler-owned actions, effects, and `View` schema can be
tested across both platforms.

Its score is not 100. The renderer becomes part of the trusted computing base,
mobile target/linker/runtime work is substantial, and Apple/Google framework
changes become recurring platform work.

### 7.2 Why a custom renderer is second, not first

A Skia/Metal/Vulkan-style renderer would maximize control and minimize
Swift/Kotlin surface. It would also make Gust responsible for text layout,
accessibility, input methods, navigation conventions, keyboard behaviour,
platform adaptation, and every new form factor. That is an enormous second
product. It is a viable later renderer for games, canvases, or charts, not the
default application UI.

### 7.3 Why Wasm is a fallback, not the core

Bundled Wasm gives a portable sandbox and could reuse future browser work. It
also inserts a runtime, a second ABI, memory copying, and another async boundary
while still needing Swift/Kotlin for native UI and lifecycle. It does not avoid
the mobile adapter problem. On iOS the executable module must be bundled rather
than remotely supplied. Use Wasm only if measurement proves that direct native
target maintenance is materially worse and the runtime meets startup, size, and
store-policy gates.

### 7.4 Why handwritten native UI is not the default

It is the fastest proof that a Gust core can ship in native apps, and it may be
the right temporary integration mode for an existing product. As Gust's normal
authoring model it creates two UI languages, two state systems, hand-maintained
schemas, and a large in-process authority surface. It is a bridge product, not
the destination.

### 7.5 Why transpilation and unrestricted mixing lose

Kotlin Multiplatform is a credible way to share Kotlin logic with Apple targets,
but that is precisely why it is not Gust's default: Kotlin becomes the shared
application language and Gust becomes redundant or a front end that must emit
Kotlin. Using Kotlin only for Android's generated host needs no multiplatform
runtime. Kotlin's direct Swift export is also Alpha today, so adopting it would
add an evolving Kotlin-to-Swift boundary beside the Gust boundary rather than
remove one.

Transpiling Gust to Swift/Kotlin creates two generated semantic backends whose
diagnostics, ownership, concurrency, integer behaviour, and resource cleanup must
remain identical. It moves the portability problem into generated source and
inherits two high-level toolchains without removing native hosts.

Unrestricted mixing is worse. It adds two package graphs and several competing
UI/concurrency idioms, allows direct SDK imports, and makes the guarantee a
property of code review instead of the compiler. It contradicts the one-way
ledger rather than extending it.

## 8. Delivery sequence and gates

This is a handoff plan, not authorization for this lane to change the compiler.
Target, ABI, linker, runtime, MIR, and native-boundary work belongs to the
Cranelift/semantic owner. UI surface and safe capability wrappers need an explicit
ownership split before implementation.

### M0 — decision and two throwaway packaging spikes

- Resolve OD-12's trusted-platform/escape-hatch distinction.
- Build one iOS Simulator and one Android Emulator counter with a manually tiny C
  ABI, native host UI, and no new Gust language surface.
- Record cold/warm start, frame time, memory, binary size, bridge calls and copied
  bytes against equivalent Swift-only and Kotlin-only controls.
- Prove signing/package inspection, symbolication, process-death restoration, and
  an accessibility-tree assertion.

**Gate:** evidence is written before a renderer or ABI is committed. The spike
must not be called Gust mobile support.

### M1 — compiler-owned mobile target tuples

- Add distinct iOS device/simulator and Android device/emulator targets.
- Supply compiler, runtime package, linker, ABI, object, relocation, and signing
  inputs for each selected tuple.
- Run native compile, object inspection, link, execution, diagnostics, and
  reproducibility evidence on actual platform runners, following the existing
  Phase 18 target-support standard.
- Start with ARM64 devices plus the simulator/emulator architectures required for
  development; do not claim a target merely because Cranelift knows its ISA.

**Gate:** a mobile target is supported only when its complete tuple and runner
evidence pass. No alias to a Darwin or GNU/Linux tuple.

### M2 — versioned mobile ABI and generated projects

- Freeze the opaque-handle/buffer/action/effect ABI.
- Generate one Xcode project and one Gradle project from the same manifest.
- Record all produced native code and toolchain versions in a lock/provenance
  artifact.
- Reject ABI version, target, permission, or capability disagreement before
  application start.

**Gate:** no Gust reference crosses the boundary; no unwind crosses it; all
allocated buffers have one tested owner and release path; malformed input fails
closed.

### M3 — the smallest shared mobile `View` slice

- Define a platform-neutral semantic subset: text, button, input, list, image,
  stack/layout, navigation, focus, accessibility label/value/role, and actions.
- Implement it in the Swift and Kotlin adapters without exposing SwiftUI or
  Compose types to Gust source.
- Compare semantic/accessibility trees and action traces, not pixels alone.
- Exercise rotation, background/foreground, low-memory/process death, keyboard,
  dynamic type/font scaling, dark mode, and offline transition.

**Gate:** the same Gust program and action trace produces equivalent declared
semantics on both platforms. Any intentional platform difference is explicit in
the canonical schema rather than a hidden adapter branch.

### M4 — typed device capabilities

- Add capabilities in product order, not SDK order: secure credentials,
  notifications, camera/media selection, location, sharing, deep links, and
  background work.
- Generate entitlements, permissions, purpose strings, and store declarations
  from the same capability manifest.
- Return data-minimized Gust values; never expose native framework objects.

**Gate:** undeclared capability use is rejected, manifest/store declarations agree
with code, denial/cancellation is typed, and background execution follows each
platform's lifecycle rules.

### M5 — native escape hatch, only after the guarantee ledger exists

- Define a signed, versioned native component contract and its exact lost
  guarantees.
- Require human approval and visible release provenance.
- Keep package resolution out of application builds; approve and pin the entire
  native component closure.

**Gate:** `gust guarantees` can name the module, scope, permissions, provenance,
expiry/review status, and forfeited boundary. Until that output exists,
application-authored Swift/Kotlin remains unsupported rather than informally
allowed.

## 9. Risks and falsifiers

| Risk | Required response |
| --- | --- |
| UI updates chatter across JNI | Batch action-in/view-and-effects-out; measure calls and bytes per transition. |
| SwiftUI and Compose become competing state stores | Native state mirrors only presented Gust state; all business transitions return as Gust actions. |
| Arena-backed data escapes into ARC/GC heaps | Opaque handles plus copied/owned buffers; never lend a Gust view across an event-loop turn. |
| Platform adapters silently diverge | One canonical schema, shared semantic fixtures, per-platform accessibility and lifecycle tests. |
| Platform SDK churn becomes application churn | Pin adapters to the Gust platform release; applications do not import SDKs. |
| A mobile target is inferred from AArch64 support | Require the existing complete target tuple and runner evidence for each mobile destination. |
| iOS receives executable Gust code after review | Bundle all executable code and treat remote data as data, consistent with App Review 2.5.2. |
| Native extension code launders dependencies | Treat its whole closure as an explicit escape hatch with provenance and loss-of-guarantee output. |
| Generated glue becomes impossible to debug | Emit source maps/symbols and stable action, view-node, capability, and ABI identifiers. |

Abandon option 1 as the default if a representative spike shows any of these and
the failure survives two independent adapter designs:

- the coarse ABI cannot meet an accepted frame/startup budget without exposing
  native object graphs to Gust;
- native accessibility or lifecycle correctness requires ordinary application
  logic to live in Swift/Kotlin;
- target-specific semantics leak above the compiler-owned `View`/capability
  schema often enough that “one application model” is false;
- complete, store-valid mobile target tuples cannot preserve Gust's memory and
  resource semantics.

The first fallback is a constrained handwritten native-view boundary for the
affected surface. It is not unrestricted mixing and not a reason to transpile the
whole language.

## 10. Proposed OD-12 answer

> Gust mobile applications are written in Gust and ahead-of-time compiled to
> each supported mobile target. Gust generates a thin Swift or Kotlin host and
> ships versioned, conformance-tested native UI and capability adapters as part of
> the pinned platform. Swift and Kotlin are implementation languages below the
> Gust application boundary, not normal application source languages.
>
> Application-authored Swift/Kotlin is a separately declared in-process native
> escape hatch. It forfeits the named process-integrity guarantee and may not
> introduce an uncontrolled dependency graph. The compiler and release artifact
> make that loss visible.

If adopted, Part IX must be amended from “client means browser” to an explicit
set of client targets with one canonical state, action, `View`, RPC, and
capability model. The guarantee documents must also define the Gust mobile
adapter as part of the pinned platform trusted computing base. Until the operator
sets that direction in the OD register, this remains a ranked proposal.

## 11. Official external references checked

- Apple: [C interoperability](https://developer.apple.com/documentation/swift/c-interoperability),
  [XCFramework packaging](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle),
  [SwiftUI state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state),
  [SwiftUI accessibility](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals),
  [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- Android: [NDK concepts](https://developer.android.com/ndk/guides/concepts),
  [JNI guidance](https://developer.android.com/ndk/guides/jni-tips),
  [Android ABIs](https://developer.android.com/ndk/guides/abis),
  [Compose architecture](https://developer.android.com/develop/ui/compose/architecture),
  [Compose semantics](https://developer.android.com/develop/ui/compose/accessibility/semantics).
- Language interop: [Swift C++ interoperability](https://www.swift.org/documentation/cxx-interop/),
  [Kotlin Swift export](https://kotlinlang.org/docs/native-swift-export.html),
  [Kotlin C interop](https://kotlinlang.org/docs/native-c-interop.html).
