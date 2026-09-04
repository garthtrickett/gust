# WebAssembly-to-DOM architecture

**Status:** proposed browser architecture, recorded 2026-08-27. This note does
not activate WebAssembly, browser, template, RPC, or Stdlib work; assign an
active roadmap lane; authorize runtime symbols; or settle OD-4. `docs/VISION.md`
Part IX and `docs/WEB_SLICE_0.md` remain authoritative for product sequencing.

## Proposal

Gust targets browser WebAssembly through a small generated JavaScript bridge.
The browser does not provide ambient DOM access to a core WebAssembly module;
the module reaches browser APIs only through host functions supplied by the
embedder.

Use focused upstream references rather than porting a framework:

1. The WebAssembly Web/JavaScript APIs, Web IDL, DOM, HTML, URL, Events, Fetch,
   and related web standards are normative.
2. [`wasm-bindgen`][wasm-bindgen] and [`web-sys`][web-sys] are the primary
   worked references for the Wasm-to-JavaScript ABI and generated Web API
   bindings.
3. [Lit's renderer design][lit-design] is the primary worked reference for
   static template skeletons, dynamic parts, and incremental updates.
4. TanStack [`query-core`][tanstack-query] is the primary worked reference for
   transport-independent frontend query lifecycle and race behavior.
5. [Vite][vite] is the development-server and invalidation reference;
   [esbuild][esbuild] is the focused production asset-graph/output reference;
   [Lightning CSS][lightning-css] is the CSS transformation reference; and
   [Vue scoped CSS][vue-scoped-css] is the scope-attribute worked reference.
6. The [WHATWG URL][whatwg-url] and [URLPattern][url-pattern] standards govern
   routing; [TanStack Router][tanstack-router] is the typed-routing, loader, and
   code-split-boundary reference.
7. HTML constraint validation, WCAG, and WAI-ARIA govern forms and
   accessibility; [Conform][conform] is the progressively enhanced typed-form
   reference.
8. [Playwright][playwright] drives real-browser E2E tests and accessibility-tree
   snapshots; [axe-core][axe-core] supplies automated accessibility checks;
   [Web Platform Tests][wpt] provide cross-browser platform evidence.
9. Gust owns the application API, browser capabilities, typed templates, SAM
   actions, memory transfers, handle lifetime, error model, and generated glue.

`wasm-bindgen`, `web-sys`, and Lit are references, not application dependencies
or authorities over Gust syntax. Do not import their Rust, Cargo, JavaScript
directive, component, reflection, or package-runtime models.

## The boundary

```text
typed Gust component and SAM action
  -> Gust Wasm module
  -> generated narrow imports/exports
  -> generated JavaScript bridge
  -> browser DOM and Web APIs
```

The bridge is generated platform code. An application developer does not write
JavaScript for ordinary UI, RPC, or event handling, and a basic application does
not ship a general JavaScript framework runtime.

The bridge owns:

- module loading and instantiation;
- WebAssembly import/export wiring;
- UTF-8 string and bounded byte transfer;
- browser-object handle retention and release;
- JavaScript exception capture and translation;
- event-listener registration and deterministic removal;
- calls into DOM and other approved Web APIs;
- callback entry into one bounded Wasm dispatch surface.

The Gust module owns:

- typed view descriptions and compiler-generated part metadata;
- SAM actions, acceptors, model updates, presenters, and effects;
- the decision that a DOM update is required;
- serializable event payloads and RPC values;
- capability declarations and the distinction between internal renderer
  authority and explicit direct-browser authority.

Neither side exposes a raw pointer into the other's memory. JavaScript cannot
retain an unbounded view into resizable Wasm memory, and Gust cannot treat a
browser object as an arena address.

## Reference hierarchy in detail

### Standards are normative

The [WebAssembly Web API][wasm-web-api] and JavaScript embedding define module
loading and host integration. The [Web IDL][web-idl], [DOM][dom-standard], and
[HTML][html-standard] standards define browser types, conversions, exceptions,
inheritance, events, node behavior, parsing, and lifecycle.

MDN and implementation documentation may explain behavior, but a disagreement
is resolved against the applicable standard and cross-browser behavior, not
against one framework's wrapper API.

### `wasm-bindgen` is the ABI reference

Study `wasm-bindgen` for:

- compact imports and exports;
- strings, slices, arrays, optional values, and results across linear memory;
- exception translation;
- browser-object identity and lifetime;
- callback/trampoline ownership;
- feature use proportional to generated glue;
- the transition path between integer handle tables and supported WebAssembly
  reference types.

Do not copy `JsValue` as Gust's universal browser type. A dynamically typed
catch-all would erase the compiler-owned browser surface and move Web IDL errors
to runtime.

### `web-sys` is the binding-generator reference

`web-sys` generates raw bindings from Web IDL and gates most browser types behind
features. Gust should adopt the generation principle:

```text
checked-in allowlisted Web IDL subset
  -> normalized browser capability model
  -> typed compiler/runtime declarations
  -> only the JavaScript glue used by the application
```

Do not ingest the entire browser API automatically. Each admitted interface,
method, event, property, exception, and security-sensitive operation needs a
Gust capability and exposure decision. A browser adding Web IDL does not thereby
add a Gust API.

The generator must model at least:

- nullable and optional values;
- DOMString, USVString, ByteString, and bounded buffer conversions;
- inheritance and interface exposure by browser context;
- methods or getters that can throw;
- callbacks and event listener lifetime;
- overload resolution and numeric range rules;
- Promise-returning APIs as effects rather than arbitrary suspension in client
  functions;
- secure-context and permission requirements.

### Lit is the renderer reference

Gust's declared rendering model already matches Lit's useful core: static
template structure plus dynamic parts, with later renders updating only changed
parts rather than diffing a virtual tree.

Gust can do more work at compile time than Lit:

```text
typed `html { ... }` source
  -> compile-time HTML/attribute/event validation
  -> stable template ID
  -> static DOM skeleton
  -> typed ordered part table
  -> initial instantiate
  -> subsequent changed-part commits
```

The runtime does not need JavaScript tagged-template parsing, runtime reflection,
custom directives, or runtime discovery of expression positions. Template and
part identity come from compiler output.

Initial part kinds should be deliberately bounded:

- text content;
- ordinary string attribute;
- boolean attribute;
- safe property cases admitted individually;
- nested view or empty child region;
- keyed list region only after ordinary child replacement is correct;
- typed event action.

HTML, SVG, URL, style, property, and event contexts are distinct. One generic
"set dynamic value" operation must not silently collapse their escaping and
validation rules.

## Client query cache and optimistic reconciliation

Use TanStack `query-core`, rather than its React adapters, as the worked
reference for the behavior around a request: canonical identity, fresh/stale
state, in-flight deduplication, cancellation, retry eligibility, observation,
invalidation, background refetch, and bounded garbage collection.

The Gust cache is compiler-owned and typed. A query key contains at least:

- stable procedure identity and contract version;
- canonical typed input bytes or an equivalent collision-safe identity;
- resolved organisation/workspace/tenant context;
- any declared authorization or locale variance safe to include without
  storing credentials.

The first design is a query-result cache, not a normalized entity graph.
Normalizing partial entities introduces identity, merge, field-ownership, and
cross-query invalidation rules that are not required by the first browser
slice. If a later workload proves that need, it requires its own contract and
reference review rather than being implied by the word "cache."

Optimistic state follows `docs/VISION.md` §38.1. Confirmed query data remains
authoritative; a mutation appends a typed SAM action to the pending journal;
presentation folds confirmed data plus pending actions; acknowledgement updates
confirmed data and removes the matching action; rejection removes it and
refolds. TanStack supplies race cases, not authority to run arbitrary cache-
mutation callbacks or retain user-defined rollback snapshots.

The conformance model must cover cancellation during decode, simultaneous
observers, deduplication, stale responses arriving after newer ones, out-of-
order mutation acknowledgements, retry suppression for non-idempotent
mutations, logout/tenant switches, reconnect, subscription invalidation, and
bounded cache collection.

## Asset graph, scoped CSS, and development server

The compiler owns one asset graph covering the Wasm module, generated bridge,
HTML entry points, CSS, source maps, images/fonts, route chunks, and deployment
manifest. Vite is the worked development reference for graph invalidation,
on-demand transforms, diagnostics, and the rule that an invalid hot update
falls back to a correct full-page reload.

esbuild is the focused production reference for entry points, dependency
resolution behavior, tree shaking, code splitting, content hashes, source maps,
asset naming, and a machine-readable output manifest. Lightning CSS is the
reference for standards-aware CSS parsing, target transforms, bundling, and
minification. These tools may be invoked behind an explicit build-tool boundary
during bring-up; their JavaScript plugin and configuration ecosystems do not
become Gust's application API.

Scoped CSS follows Vue's useful mechanical technique, with Gust-owned identity:

```text
component/template identity
  -> stable compiler scope ID
  -> scope attribute stamped on generated DOM
  -> selectors rewritten against that attribute
```

The transform must parse CSS rather than perform textual replacement. It must
define nesting, pseudo-elements, keyframes, animation names, imported styles,
child-component roots, deliberate deep selectors, and explicit global escapes.
A scope ID is stable under reproducible builds and does not depend on an
absolute source path.

The first development server rebuilds affected artifacts and performs a full
page reload. JavaScript/CSS hot replacement may be added where lifetime is
obvious. State-preserving Wasm HMR is deferred until model layout, listener and
browser-handle ownership, pending actions, and resource cleanup are compatible
across module replacement; the server must never guess that old Wasm state is
valid for a new binary.

Production output is deterministic and content-addressed. The HTML entry and
release manifest name exact hashed artifacts, unused bindings/assets are
absent, source maps follow an explicit deployment policy, and CSP/integrity
metadata can be generated from the same graph.

## First bridge slice

The first proof should remain smaller than the final renderer. Conceptually it
needs only:

```text
dom.create_element(tag)
dom.create_text(text)
dom.append(parent, child)
dom.set_text(node, text)
dom.set_attribute(element, name, value)
dom.remove_attribute(element, name)
dom.listen(element, event, action_id)
dom.remove_listener(listener)
dom.remove(node)
```

These names describe the boundary; they are not authorized runtime symbols or
proposed public Gust functions.

For `WEB_SLICE_0`, an even narrower bridge is acceptable: load the module, bind
one button click, pass one bounded action into Wasm, receive one typed result,
and update one text node. The proof succeeds only when no application-specific
handwritten JavaScript is required.

## Browser-object representation

The first implementation must choose one explicit browser-object identity
strategy after the Wasm target baseline is fixed:

- an integer handle into a JavaScript-owned table; or
- supported WebAssembly reference types such as `externref`.

The choice is not made here. `wasm-bindgen` is the worked reference for the
tradeoff and migration path. Whichever representation wins must provide:

- stable identity while retained;
- deterministic release rather than reliance on timing-sensitive finalization;
- stale/double-release detection in development builds;
- no use after listener, node, or component teardown;
- bounded table growth under repeated mount/unmount cycles;
- no conversion of a browser handle into a safe Gust arena reference;
- no browser object in replayable SAM model or RPC state.

Browser nodes and listener registrations are linear effect-owned handles, not
ordinary clonable application data.

## Events and SAM

Generated listeners should enter Wasm through one bounded dispatcher rather
than manufacture arbitrary JavaScript closures for application components:

```text
browser event
  -> generated bridge extracts the declared payload fields
  -> wasm.dispatch(action_id, serialized bounded payload)
  -> Gust acceptor updates plain model data
  -> presenter returns a View
  -> renderer commits changed parts
```

The event contract declares exactly which fields may cross. Passing the complete
JavaScript event object would introduce an opaque browser resource into Gust and
make replay, testing, serialization, and capability review depend on ambient
host state.

Listeners are owned by the template/component instance that registered them.
Replacement, unmount, failed initialization, and panic cleanup must remove them
exactly once. Event handlers dispatch actions; they do not retain raw DOM nodes
inside the SAM model.

## Browser effects and suspension

This architecture follows `docs/VISION.md` §21.1: ordinary client functions do
not require transparent suspension. Fetch, timers, storage, permissions, and
other Promise-returning browser operations are explicit SAM effects executed by
the bridge or browser runtime. Completion re-enters Wasm as another typed
action.

The bridge therefore does not require JSPI or Asyncify for Slice 0. OD-4 remains
open for client work that later demonstrates a real non-effect suspension need.
This note does not reopen that decision.

## Security and capability boundary

The compiler-generated renderer receives only the internal operations required
to realize a checked `View`. Ordinary application code does not receive
`window`, `document`, `Node`, arbitrary selectors, arbitrary properties,
`innerHTML`, `eval`, unrestricted fetch, or unrestricted browser APIs.

Direct DOM and browser access, if exposed, is a separate explicit capability as
required by `docs/VISION.md` §39. It must not be obtained by casting a renderer
handle or calling a generated bridge import by name.

Required rules include:

- dynamic text uses text-node/text-content operations, never HTML parsing;
- dynamic tag and attribute names are not accepted in the first surface;
- URL-bearing attributes use typed URL policy and scheme checks;
- event handler source strings are never generated;
- styles use the compiler-owned scoped-CSS path rather than arbitrary style
  text where possible;
- raw HTML requires a separately named, reviewed trust boundary and cannot be
  constructed from an ordinary string;
- Content Security Policy and Trusted Types compatibility are tested;
- bridge errors redact application data and do not expose Wasm memory contents;
- imported host functions are fixed by the generated manifest and deployment
  artifact, not discovered dynamically.

## Errors and memory transfer

Every imported operation has an explicit success/error contract. JavaScript
exceptions and DOMExceptions are translated into a bounded Gust browser error
taxonomy; they do not cross as dynamic JavaScript values or strings containing
arbitrary host details.

String and byte transfers must check pointer/length overflow and current memory
bounds before constructing a JavaScript view. The bridge must not retain a
typed-array view across any operation that may grow Wasm memory. Large payloads
need explicit limits and ownership rather than repeated implicit copies.

DOM mutation is not transactional. The generated renderer must define what
happens when a multi-part commit fails: either validate all fallible conversions
before mutation or leave the component in a known state that triggers bounded
reconstruction. It must not silently continue with half the part table updated.

## Conformance corpus

The browser corpus should run in current supported Chrome, Firefox, and Safari,
not solely in a JavaScript DOM emulator. It should cover:

- module loading, imports, exports, and unsupported-feature diagnostics;
- UTF-8, embedded NUL, empty, malformed, and boundary-length transfers;
- nullable/optional values and throwing Web IDL operations;
- initial render and no-op/changed-part updates;
- text, attribute, boolean attribute, child, and event parts;
- mount, replacement, unmount, listener removal, and handle-table stability;
- duplicate and rapid events, reentrant dispatch, and panic/error cleanup;
- HTML/SVG namespace correctness;
- URL, HTML-injection, event-handler, property, and style security cases;
- accessibility semantics, focus preservation, forms, and keyboard events as
  those surfaces are admitted;
- explicit-route link/match round trips, typed path and search parameters,
  loader cancellation, pending/error boundaries, and code-split failures;
- no-JavaScript form submission, identical server/client validation, stable
  field error paths, focus-on-error, keyboard navigation, and constraint
  validation behavior;
- payload and glue size proportional to the admitted bindings;
- selected [Web Platform Tests][wpt] and Gust-owned cross-browser fixtures;
- cache races, cancellation, retry/idempotency, tenant switches, optimistic
  acknowledgement order, rollback, invalidation, and collection;
- deterministic production manifests, content hashes, missing/stale assets,
  scoped-selector correctness, source maps, CSP/integrity, full reload, and
  rejected-HMR fallback.

Pixel reftests are useful for rendering, but structural DOM, accessibility tree,
event, and focus assertions are also required. A visually identical page can
still be semantically or interactively wrong.

Playwright is the external test runner rather than a shipped runtime. Run the
same generated application in supported Chromium, Firefox, and WebKit, retain a
trace for failures, and use ARIA snapshots for structural expectations.
`axe-core` runs within those scenarios, but automated checks are partial
evidence: keyboard, focus, screen-reader, and manual WCAG review remain part of
the accessibility gate.

Routing follows WHATWG URL/URLPattern behavior. TanStack Router informs typed
route identity, path/search validation, loader dependencies, preloading, and
lazy boundaries, but Gust keeps explicit compiler-visible route declarations
and imports neither React nor filesystem routing.

Forms follow HTML submission and constraint-validation semantics. Conform
informs schema-derived field metadata, server/client validation agreement,
progressive enhancement, and accessible errors without dictating markup. Gust
owns the typed schema/RPC relationship, server authority, focus policy, and
generated DOM; Conform's React hooks and schema-library dependencies do not
cross the boundary.

## Rejected starting points

- **React, Yew, Dioxus, Leptos, and Blazor architecture:** their virtual-DOM,
  signal/runtime, component-runtime, or managed-runtime choices conflict with
  Gust's already-declared compiled Lit-style model. They may supply isolated
  test ideas, not the architecture.
- **Emscripten as the main bridge:** useful for loader and ABI edge cases, but it
  carries a broad C/C++ runtime and emulation surface that Gust does not need.
- **Handwritten application JavaScript:** acceptable only as a temporary
  diagnostic while bringing up the bridge; Slice 0 is not complete until the
  application-specific JavaScript is generated away.
- **The entire DOM as raw bindings:** contradicts compiler-owned browser
  capabilities, payload proportionality, and the single safe UI path.
- **A JavaScript renderer hidden behind Wasm:** makes the Gust compiler's typed
  part model decorative. The bridge performs host operations; Gust owns render
  decisions and part semantics.

## Sequencing

1. **Target and ABI inventory.** Fix the Wasm feature baseline, import/export
   ABI, string representation, error return, and browser-object identity options.
2. **Slice 0 bridge.** Instantiate one module, dispatch one click, perform the
   existing typed RPC loop, and update one text node with generated glue.
3. **Binding generator.** Admit a tiny checked-in Web IDL subset and generate
   typed internal bindings plus exact JavaScript imports.
4. **Static template skeleton.** Compile one template into a stable template ID,
   DOM skeleton, part table, initial creation, and deterministic teardown.
5. **Incremental parts.** Add text, attribute, boolean, child, and event updates
   with unchanged-value suppression and failure recovery.
6. **SAM integration.** Route declared event payloads through the single action
   dispatcher and refold the plain-data model into a new View.
7. **Security and cross-browser closure.** Run injection, capability, handle,
   listener, memory-growth, accessibility, WPT-derived, and three-browser gates.
8. **Asset and development loop.** Emit one deterministic hashed bundle and
   manifest, serve it locally, invalidate affected graph nodes, and use correct
   full-page reload before considering Wasm HMR.
9. **Query cache.** Add the typed query-result lifecycle, then integrate
   optimistic state through the pending SAM journal and deterministic race
   fixtures.
10. **Later surfaces.** Add lists, forms, routing, scoped CSS, hydration,
   browser capabilities, workers, or additional Web APIs one contract at a
   time.

This proves the full-stack loop without committing Gust to a general JavaScript
runtime, a virtual DOM, unrestricted Web APIs, or a browser-specific Wasm ABI.

[wasm-web-api]: https://webassembly.github.io/spec/web-api/
[web-idl]: https://webidl.spec.whatwg.org/
[dom-standard]: https://dom.spec.whatwg.org/
[html-standard]: https://html.spec.whatwg.org/multipage/
[wasm-bindgen]: https://github.com/wasm-bindgen/wasm-bindgen
[web-sys]: https://github.com/wasm-bindgen/wasm-bindgen/tree/main/crates/web-sys
[lit-design]: https://github.com/lit/lit/blob/main/dev-docs/design/how-lit-html-works.md
[wpt]: https://github.com/web-platform-tests/wpt
[tanstack-query]: https://github.com/TanStack/query/tree/main/packages/query-core
[vite]: https://vite.dev/guide/
[esbuild]: https://esbuild.github.io/
[lightning-css]: https://lightningcss.dev/
[vue-scoped-css]: https://vuejs.org/api/sfc-css-features.html#scoped-css
[whatwg-url]: https://url.spec.whatwg.org/
[url-pattern]: https://urlpattern.spec.whatwg.org/
[tanstack-router]: https://tanstack.com/router/latest/docs/framework/react/overview
[conform]: https://conform.guide/
[playwright]: https://playwright.dev/
[axe-core]: https://github.com/dequelabs/axe-core
