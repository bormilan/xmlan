# Generic XML extraction — Signerl #85

Tracking: https://github.com/bormilan/signerl/issues/85

## Boundary and implementation

Starting xmlan revision: `cd1ce795a8fe845de6b1aa3a8e8d5cf3b3a04b2e`
(merged bootstrap PR #1). Generic code comes from Signerl's completed XML
foundation at `5927e41bab8674b875c51df1a1ec956d42676992`, under the approved
[#83 contract](https://github.com/bormilan/signerl/blob/dev/docs/xmlan_migration_contract.md).

- `src/xmlan.erl` now owns all 16 generic exports: binary/file parsing, prolog
  extraction, export/fragment/file output, lexical and expanded selectors,
  namespace context/materialization/projection, child insertion, text and
  attribute lookup. SAX callbacks, complete-document consumption, encoding,
  escaping, and namespace validation move with their existing control flow.
- `include/xmlan.hrl` contains all nine unchanged shared XML constants/regexes.
  The empty-`xmlns:` raw lexical guard still skips comments/CDATA/quoted values.
- `src/xmlan.app.src` declares OTP `xmerl`, which owns SAX parsing and basic
  escaping. No Signerl application/source or third-party runtime dependency is
  required, and the library starts no operation servers.
- XMLDSig identity predicates and their header are excluded. Generic selectors
  and namespace contexts provide the needed protocol-neutral API.
  Canonicalization remains #86; Signerl's dependency switch/removal remains #87.
  No Signerl production file changes in this PR. Its original bodies are removed
  by #87 rather than replaced piecemeal before the dependency is complete.
- `to_file/2`'s specification now includes its existing `{error, Reason}` result;
  its unchanged body still returns `file:write_file/2` directly. No function's
  runtime behavior or error handling is redesigned.
- `README.md`, `test/TESTS.md`, `NOTICE`, and fixture provenance document current
  API behavior and ownership. Documentation updates are required because parser,
  export, and namespace APIs are now available to consumers.

Transparent tuple types, UTF-8 names/values, lexical prefixes/order, mixed text,
SAX text boundaries, CR/reference normalization, default undeclaration, inherited
context, and ambiguous lookup behavior are retained. Parser DTD/entity/PI and
namespace restrictions are unchanged. Parser validation is not silently applied
to caller-constructed tuples. Existing explicit work stacks remain in validation,
export, and expanded projection; no new production traversal is introduced.

## Tests and review

The test-first port reproduced `undef` failures for missing parser/export APIs
in the bootstrap. That expected-failure run was terminated while formatting the
10,000-level tree argument; it is not counted as a successful gate.

`xmlan_parser_test.erl` adapts pure XML contracts from `signerl_xml_test.erl`.
Signature identity cases stay in Signerl; helper cases already covered by the
bootstrap are retained in `xmlan_test.erl`. C14N assertions remain in Signerl
until #86, while xmlan checks parsed values and exact serializer bytes directly.
Generic namespace examples use `urn:example` and ordinary element names.
Additional tests exercise BOM acceptance versus prolog rejection, malformed
complete documents/declarations, ordered `find_children/2`, detached default
undeclaration, and 10,000-level parse/export/projection.

`xmlan_xml_SUITE.erl` ports file/error and external-resource tests. Its controlled
HTTP endpoint has a positive request control followed by rejected external
SYSTEM/PUBLIC subsets, general entities, and parameter entities, with no request.
The file canary is generated test data and also covers relative-path file input.
The atom probe runs in a warmed, isolated VM, exercises binary/fragment export and
fresh valid/rejected names, and requires growth `[0, 0]` in two disjoint batches.
Signature/C14N operations are excluded from this standalone probe.

`xmlan_consumer.erl` uses every exported API and all five public types outside
the library's test VM. CT runs the consumer in a fresh VM with only xmlan and OTP
on its application path, and checks that Signerl is not loaded.
`test/examples/xmlan_migration/` contains the original input, parsed tree,
export/fragment bytes, and original SHA256 entries from #83. The two existing XML
file fixtures are also unchanged. `.gitattributes` disables XML text conversion
and fixes term/hash line endings for Windows. No key/signature material is copied.

Review compared preprocessed function syntax trees (ignoring source locations):
all **41 generic functions match Signerl exactly**. All nine macros and six XML/
term fixtures match the baseline bytes; the four frozen SHA256 hashes match their
original manifest. There are no protocol imports/constants in production code.
The unchanged `books.xml` fixture retains its baseline trailing blank line; Git
whitespace checking excludes that one verified byte-identical fixture rather
than changing its content. All other added/changed files pass `git diff --check`.
The only non-renaming production metadata changes are the xmerl dependency and
the accurate file-error return specification.

Review also caught that the disposable Unicode failure probe needed to copy the
new `include/` directory. An executable pre-fix run failed at compilation rather
than its intended test; after fixing the copy list, it rejects the real Unicode
regression. Lint findings in new tests were corrected without suppressing rules:
a redundant wrapper became a function reference, test logging uses `ct:log/2`,
and the undeclaration control preserves a text child as well as the binding.

## Validation

Native runtime: OTP 28.4.2, rebar3 3.25.1; project plugin pins unchanged.
User-global plugins are isolated with an empty config directory. Development/CI
pins remain OTP 28.5.0.7, with the existing six OTP 26/27/28 Ubuntu/Windows jobs.

- `rebar3 eunit`: 157 passed.
- `rebar3 ct`: 12 passed, no skips.
- `rebar3 test` and `rebar3 as test cover`: 169 passed overall, 100% production coverage.
- `rebar3 flint`: passed after the review fixes.
- `rebar3 dialyzer`: passed; first PLT expansion compiled Homebrew's OTP xmerl
  debug information and printed vendor missing-specification compiler warnings,
  with no project Dialyzer findings.
- External `erlc` consumer plus production BEAMs: executes frozen contracts and a
  file round trip, starts `[xmerl, xmlan]`, and confirms Signerl is not loaded.
  Dialyzer against the full dependency PLT and both BEAMs passes.
- Deliberately changed exported-byte golden in a separate copy: consumer rejects
  it at the actual `xmlan:export/2` assertion. No baseline golden was regenerated.
- `scripts/check_failure_probe.sh`: passed; `tall` rejects the injected Unicode
  defect through the real test assertion.
- Final native aggregate `rebar3 tall`: passed with all 169 tests, 100% coverage,
  formatting/lint, Xref, and Dialyzer; no skipped tests or checks.

The first full-suite attempt timed out starting a peer VM and ended during the
session interruption; it is not counted as passing. The resumed standalone CT
run and subsequent complete test/coverage run pass without bypasses or skips.

All six CI jobs must pass on the final PR commit before declaring the PR ready
to merge. Latest-commit CI and clean HTTPS dependency-consumer evidence will be
recorded in the PR after publication. No automatic merge is authorized.

## Recovery

Persistent source checkout: `/Users/milanbor/projects/xmlan`, branch
`codex/issue-85-xml-parser`.

Before publication, the tracked diff and source-file archive are saved outside
temporary storage under
`/Users/milanbor/projects/signerl/.recovery/issue-85/`, alongside native gate logs,
source-equivalence evidence, external consumer output, and negative controls.
The original Signerl checkout's existing tracked/untracked changes are preserved.
