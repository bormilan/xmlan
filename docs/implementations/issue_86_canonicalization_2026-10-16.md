# Generic canonicalization extraction — Signerl #86

Tracking: https://github.com/bormilan/signerl/issues/86

## Implementation and boundary

Starting xmlan revision: `003c1ff9b4bc26fb2848ec36746bdffa8c0b9c29`
(merged parser extraction PR #2). The source baseline is Signerl
`5927e41bab8674b875c51df1a1ec956d42676992`, with the approved
[#83 contract](https://github.com/bormilan/signerl/blob/dev/docs/xmlan_migration_contract.md).
The parser prerequisite (#85) is merged and its actual issue state is closed.

`src/xmlan_c14n.erl` owns the generic C14N 1.1/Exclusive engines, namespace
tracking/value normalization, namespace/attribute sorting, escaping, and rendering.
Public exports are `canonicalize/1,2` and the transparent
`c14n_mode/0` type (`c14n11 | exc_c14n`). Specifications refer to
`xmlan:simplified_xml/0`; the existing shared `xmlan.hrl` supplies XML constants.

The implementation is copied without algorithm changes. Preprocessed AST review
confirms all **30 generic function bodies match Signerl exactly**, ignoring source
locations. The module/header/type references change; the signature-removal export
and body are excluded. No new traversal is introduced; the existing recursive
canonicalization depth behavior is retained, without adding an arbitrary-depth
canonicalization guarantee. The 10,000-level parser/export/projection contracts
from #85 still run separately.

XMLDSig algorithm-URI selection, enveloped-signature removal, digests, signatures,
and XAdES processing stay in Signerl. Production sources contain no such imports,
constants, or element-name predicates. No Signerl production file changes here;
its pinned dependency switch and removal of generic bodies are #87.
The extraction preserves the existing supported profile and invalid-input
boundaries, rather than expanding standards/conformance claims.

`elvis.config` includes `xmlan_c14n` in the existing, narrowly scoped public-type
exception: the canonicalization mode is an exported consumer type. No function
body is exempted from lint, coverage, or type analysis. Runtime dependencies are
unchanged; xmllint is a test tool only.

## Contracts and fixtures

`test/xmlan_c14n_test.erl` retains every original generic unit test function:
59 cases after excluding four signature-removal cases. It also restores 11 pure
canonical-byte cases split from parser tests during #85 (caller-built trees,
value representations, whitespace/CDATA/line endings/references), and adds nine
invalid-mode/malformed-shape/detached-context cases. Expected bytes are explicit
or read from the original frozen corpus; tests are not limited to idempotence.

`test/xmlan_c14n_interop_SUITE.erl` retains all ten original integration cases
and adds detached-fragment comparison. All nine original fixture files now run
against both `xmllint --c14n11` and `--exc-c14n`, as do generated namespace edges
and the inherited-context fragment. Preserved-content cases also canonicalize
re-exported XML with xmllint. Only Windows C-stdio LF/CRLF transport in xmllint
stdout is normalized, exactly as in the baseline helper; production/golden bytes
and referenced XML CR values are untouched.

The DSig-shaped fixture is arbitrary XML data: the engine never interprets its
names or URI attributes as protocol instructions. Independently signed protocol
fixtures and keys stay in Signerl. All nine interop XML files and both frozen
canonical outputs match their original baseline bytes; the SHA256 manifest adds
only the two corresponding original entries. No expected result is recaptured.

The standalone consumer exercises both exported canonicalization arities and
`xmlan_c14n:c14n_mode/0`, alongside the existing transparent tuple types and all
generic APIs. The warmed fresh-VM name probe now includes both canonical modes
and still requires persistent atom growth `[0, 0]` across two disjoint batches.

## Tooling and documentation

Missing xmllint now fails interop initialization instead of skipping its tests.
CI installs Linux `libxml2-utils` and requires `xmllint --version` in every matrix
job before `rebar3 tall`. A negative executable probe removes executable lookup
from PATH and confirms that the actual init callback fails with
`xmllint_not_available`, rather than returning a skip.

`README.md`, `test/TESTS.md`, both fixture READMEs, and `NOTICE` document the new
API, public mode type, inherited-context requirements, existing errors, supported
profile, provenance, and test-tool prerequisite. These docs change because public
canonicalization is now available from xmlan. The runtime library needs no
xmllint executable or cryptographic dependencies.

Review simplified duplicated test setup: the consumer reuses its loaded oracle
tree, and interop cases share a two-mode comparison helper. A long expected-byte
literal was split without changing its bytes. All lint rules remain enabled.

## Validation

Native runtime: OTP 28.4.2, rebar3 3.25.1, xmllint/libxml 2.9.13. User-global
plugins are isolated; project plugin pins and the six-job OTP 26/27/28
Ubuntu/Windows matrix are unchanged.

- Test-first missing-engine run: 62 `undef` failures, confirming unavailable API;
  not counted as a passing gate. Review then verified the complete original generic
  test inventory before running the extracted implementation.
- `rebar3 eunit`: 236 passed.
- `rebar3 ct`: 23 passed, including all 11 interoperability cases; no skips.
- `rebar3 test` and `rebar3 as test cover`: 259 total cases, both production
  modules and combined total at 100% coverage.
- `rebar3 flint`: passed after review simplifications; no ignored findings.
- `rebar3 dialyzer`: passed for both production modules.
- External `erlc` consumer: both modes and all public types execute against
  production BEAMs without Signerl; full dependency-PLT Dialyzer analysis passes.
- Each frozen canonical golden was changed in a separate copy. The consumer
  rejected the C14N 1.1 and Exclusive changes at their actual byte assertions.
  Original fixtures are unchanged.
- Missing-xmllint negative probe: passed, with mandatory failure rather than skip.
- Disposable Unicode regression gate probe: passed through the real failing test.
- Final native `rebar3 tall`: passed before commit/push with 259 cases, 100%
  coverage, formatting/lint, Xref, and Dialyzer; no skipped checks.

All six latest-head CI jobs must pass with the same 259 cases and 100% coverage
before reporting merge readiness. Exact-commit job logs and a clean HTTPS-pinned
dependency consumer will be recorded in the PR after publication. No automatic
merge is performed.

## Recovery

Persistent source: `/Users/milanbor/projects/xmlan`, branch
`codex/issue-86-canonicalization`.

Tracked diffs and untracked source files are saved outside temporary storage in
`/Users/milanbor/projects/signerl/.recovery/issue-86/`, with native logs, source-AST
and fixture checks, external type/runtime output, and negative controls. A source
archive and Git recovery bundle are retained before yielding. Existing unrelated
Signerl checkout changes are preserved.
