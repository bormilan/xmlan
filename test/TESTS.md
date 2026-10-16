# Test responsibilities

| File | Cases | Responsibility |
| --- | ---: | --- |
| `xmlan_test.erl` | 19 | Child append/order, Unicode text extraction, supported attribute values, exact/missing names, and first duplicate lookup. |
| `xmlan_parser_test.erl` | 138 | UTF-8/prologs, exact serialization, content/reference normalization, DTD/PI/encoding/trailing-input rejection, namespace validation/selection/scope, and 10,000-level parsing/export/projection. |
| `xmlan_c14n_test.erl` | 79 | Both canonical modes, exact byte oracles, sorting/escaping, implicit/default/binary namespaces, Unicode/value types, detached context, and invalid-input boundaries. |
| `xmlan_c14n_interop_SUITE.erl` | 11 | Both-mode xmllint comparisons for all nine original fixtures, generated namespace edges, detached fragments, and re-exported content. |
| `xmlan_SUITE.erl` | 2 | A fresh-VM consumer using only xmlan/OTP, and frozen pre-extraction parsed/exported/canonical byte contracts. |
| `xmlan_xml_SUITE.erl` | 10 | File round trips/errors, unsupported file input, controlled external-file/HTTP entity rejection, and zero persistent atom growth in two fresh-name parse/export/C14N batches. |
| `xmlan_consumer.erl` | Consumer support | Construct/pattern-match public types; exercise every exported API through ordinary tuples and frozen XML fixtures. |

Total: 236 EUnit + 23 Common Test = 259 cases. No skipped required tests.
The pure XML cases are adapted from Signerl's completed XML foundation; signature
predicates and signing/verification probes stay in Signerl. All 59 original
generic C14N unit cases are retained; 11 canonical-byte cases split from parser
tests in #85 and nine invalid-input/detached-context cases also run here. Namespace
selectors use generic example names/URIs. Parser content assertions compare exact exported bytes without
requiring a canonicalizer. The standalone atom probe warms code paths, then checks
two disjoint batches of fresh element, attribute, prefix, and local names. Both
batches must add zero persistent atoms, including rejected fresh-name input.
The HTTP canary first verifies a real loopback request, then rejects external
SYSTEM/PUBLIC subsets, general entities, and parameter entities without a request.
The file canary uses a generated test-only file and relative-path input.
See [NOTICE](../NOTICE) for provenance and
[frozen fixture ownership](examples/xmlan_migration/README.md).

`rebar3 test` resets coverage once, runs both frameworks with coverage, and
requires 100% combined production coverage. `rebar3 tall` additionally checks
lint, Xref, and Dialyzer; all six OTP 26/27/28 Ubuntu/Windows jobs must pass.
OTP/rebar3 and `xmllint` on PATH are required for the full gate; xmerl is an OTP
runtime dependency. No OpenSSL, Signerl source, certificates, or keys are needed.
The interoperability suite fails initialization when xmllint is unavailable;
CI verifies its availability before running tall. All nine original C14N fixtures
run against both `--c14n11` and `--exc-c14n`, as do generated namespace-edge and
detached-fragment cases. Only Windows C-stdio CRLF transport is normalized in
xmllint stdout; XML/production/golden bytes and referenced CRs are unchanged.
The DSig-shaped XML fixture is arbitrary data: no protocol interpretation or
algorithm-URI selection is implemented by xmlan.

`xmlan_consumer.erl` also compiles outside rebar's test profile. After
`rebar3 compile`, a POSIX-shell probe from the checkout root is:

```sh
xmlan_consumer_dir=$(mktemp -d)
erlc +debug_info -o "$xmlan_consumer_dir" test/xmlan_consumer.erl
erl -noshell -pa "$xmlan_consumer_dir" _build/default/lib/xmlan/ebin \
  -eval 'ok = xmlan_consumer:run("test/examples/xmlan_migration"), halt().'
```

Analyze the consumer alongside production BEAMs with the full dependency PLT
from `rebar3 dialyzer` to verify public type compatibility. An opaque-only copy
must reject tuple construction. The native bootstrap log records that type
control; extraction repeats the expanded external consumer and a clean
HTTPS/Git dependency consumer, including `xmlan_c14n:c14n_mode/0`. Golden output
mismatch must fail the consumer.

Run `scripts/check_failure_probe.sh` to prove `tall` catches a real Unicode
regression in a disposable copy. This diagnostic requires POSIX shell tools and
the pinned rebar3 on PATH (or `REBAR3=/absolute/path`). The runtime library needs
OTP only; the six-job CI test gate also requires xmllint.
