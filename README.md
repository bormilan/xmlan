# xmlan

An ordinary Erlang library for UTF-8 XML parsing, serialization, namespace
selection, and transparent XML trees, extracted from
[Signerl](https://github.com/bormilan/signerl). It uses OTP's `xmerl` without
Signerl sources, operation servers, cryptographic tools, or third-party runtime
dependencies. Generic canonicalization follows in
[Signerl #86](https://github.com/bormilan/signerl/issues/86); Signerl's dependency
integration and removal of its original generic bodies follow in
[Signerl #87](https://github.com/bormilan/signerl/issues/87).

## Parse and serialize

```erlang
{ok, Tree} = xmlan:parse_binary(
    <<"<?xml version='1.0'?><root xmlns:p='urn:item'><p:item>hello</p:item></root>">>),
{ok, Item} = xmlan:find_path([{<<"urn:item">>, <<"item">>}], Tree),
{ok, <<"hello">>} = xmlan:single_text(Item),
Fragment = xmlan:export_fragment(Item),
{ok, Prolog} = xmlan:parse_prolog(<<"<?xml version='1.0'?><root/>">>),
Bytes = xmlan:export(Prolog, Tree),
ok = xmlan:to_file("output.xml", Bytes),
Tree = xmlan:parse_file("output.xml").
```

`parse_binary/1` returns `{ok, Tree}` or `{error, invalid_xml}`. It consumes a
complete UTF-8 document, with or without a declaration (and with a UTF-8 BOM).
Malformed UTF-8, NUL/UTF-16/32 input, non-UTF-8 declarations, DTDs, custom or
undeclared entities, processing instructions, and trailing documents/garbage are
rejected. External files and HTTP resources are never retrieved. Predefined
entities and character references are supported. Comments are omitted; CDATA,
mixed content, whitespace, Unicode, XML line-ending normalization, and character
references retain the existing parsed-value contract.

Namespace validation rejects unbound/invalid QNames, reserved bindings, duplicate
expanded attributes, and relative namespace URIs. An empty default namespace
undeclaration is allowed. Lexical prefixes and child/attribute order are retained.
The parser does not create atoms from XML names.

`parse_file/1` accepts a character-list path and returns the tree directly;
failed file reads or invalid documents raise the existing badmatch exception.
`to_file/2` returns `ok` or the unchanged `file:write_file/2` error result.

`parse_prolog/1` only extracts and validates the leading declaration, returning
its original spelling as `{ok, [String]}` or `{error, invalid_prolog}`. It requires
a declaration at byte zero and rejects a BOM. It does not validate the document
body. `export/2` emits the supplied prolog and appends one LF; `export_fragment/1`
prefixes `<?xml version="1.0"?>` and appends no LF. Both escape text/attributes,
encode Unicode as UTF-8, and preserve referenced CRs and attribute tabs/newlines.
Export rejects a supplied non-UTF-8 encoding declaration. Export and namespace
projection use explicit work stacks, and tests retain 10,000-level trees.

## Public values and tree helpers

`xmlan:simplified_xml/0` is a transparent tuple type:
`{BinaryName, [{BinaryName, Value}], Children}`. Names and binary values are UTF-8;
character lists contain Unicode code points. Parsed attribute values and text
are character lists. Caller-built attributes may also be binaries, integers, or
atoms; children may be trees, character lists, or binaries. Callers can construct
and pattern-match tuples without conversion to an opaque representation.
`attribute_value/0`, `expanded_name/0`, `expanded_xml/0`, and
`namespace_context/0` are also public transparent types.

```erlang
Tree = {<<"root">>, [{<<"id">>, "7"}], [<<"hello">>]},
{ok, <<"hello">>} = xmlan:single_text(Tree),
{ok, "7"} = xmlan:attr_value(<<"id">>, element(2, Tree)),
undefined = xmlan:attr_value_or_undefined(<<"missing">>, element(2, Tree)),
WithChild = xmlan:add_new_element({<<"child">>, [], []}, Tree).
```

`add_new_element/2` appends a child after existing content. `single_text/1`
accepts exactly one binary or Unicode character-list child and returns UTF-8
bytes; missing, multiple, or element children return `{error, not_found}`.
Attribute lookup uses exact binary names and the first matching entry.
`attr_value/2` returns `{error, missing_attribute}` when absent; the optional form
returns `undefined`. Existing values, including explicit `undefined`, are returned
unchanged. Tree helpers/export accept caller-built tuples; parser validation is
not an implicit validation pass over those tuples.

## Namespace helpers

| API | Behavior |
| --- | --- |
| `find_path(Path, Tree)` | A nonempty path selects unique direct children at each step. Binary selectors match lexical names; `{URI, Local}` selectors match expanded element names. Missing or ambiguous paths return `{error, not_found}`. |
| `find_children({URI, Local}, Tree)` | Returns matching direct children in content order; no matches return `[]`. |
| `namespace_context(Attrs, ParentMap)` | Applies local declarations over inherited bindings, including implicit `xml` and empty default bindings. |
| `with_namespace_context(Tree, ParentMap)` | Appends missing, nonempty inherited declarations; local declarations and default undeclaration win. |
| `expanded_name(Tree, ParentMap)` | Returns `{URI, Local}`; undeclared prefixes on caller-built trees yield `undefined`. |
| `expanded_names(Tree)` | Projects element names with inherited scope, retaining lexical attributes, values, text, and order. |

Expanded-name selectors materialize inherited namespace declarations on detached
results. Lexical selectors retain the original tuple without adding context.
Namespace helpers preserve prefixes rather than rewriting them. XMLDSig/XAdES
identities, signature-removal rules, and cryptography belong to Signerl.

## Build and validate

Supported runtimes: OTP 26, 27, and 28. Development pins in `.tool-versions` are
OTP 28.5.0.7 and rebar3 3.25.1. Project plugins are erlfmt 1.8.0 and
rebar3_lint/Elvis 5.0.4. Runtime applications are OTP kernel, stdlib, and xmerl.

```sh
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 test
rebar3 as test cover
rebar3 flint
rebar3 dialyzer
rebar3 tall
```

`test` checks formatting, resets coverage, runs EUnit and CT with coverage, and
requires 100% total production coverage. `flint` checks formatting/lint without
rewriting source; `tall` adds lint, Xref, and Dialyzer to the full test gate.
Run `rebar3 fmt` deliberately when formatting changes are needed. No required
tests or checks may be skipped. All six OTP/OS CI jobs run `rebar3 tall`.
CI isolates global rebar configuration and reports every matrix job.
See [test responsibilities](test/TESTS.md) and [AGENTS.md](AGENTS.md).

To isolate user-global plugins on a POSIX shell, run with an empty configuration:

```sh
xmlan_global_config=$(mktemp -d)
REBAR_GLOBAL_CONFIG_DIR="$xmlan_global_config" rebar3 tall
```

The executable negative probe injects a Unicode conversion defect into a
disposable copy and requires the real `tall` tests to reject it. It leaves this
checkout unchanged; a formatting/download failure is not accepted as proof.

```sh
scripts/check_failure_probe.sh
# Optional absolute rebar3 executable:
REBAR3=/absolute/path/to/rebar3 scripts/check_failure_probe.sh
```

## Consume the library

Pin a reviewed full Git commit in your application's `rebar.config` and commit
rebar's resulting lockfile:

```erlang
{deps, [{xmlan, {git, "https://github.com/bormilan/xmlan.git",
                     {ref, "<reviewed-full-commit-SHA>"}}}]}.
```

Replace the placeholder with the validated revision. Add `xmlan` to the consumer's
application dependencies. No local path override, sibling checkout, or Signerl
source is required. Extraction PRs target `dev`; `main` remains the release branch.
A release/tag or Hex publication is not part of this extraction.

## Provenance

The implementation and adapted tests come from Signerl's XML foundation at
`5927e41bab8674b875c51df1a1ec956d42676992`. The migration boundary was approved in
[Signerl #83](https://github.com/bormilan/signerl/issues/83); tree/value helpers
were bootstrapped in [#84](https://github.com/bormilan/signerl/issues/84), and
parser/export/namespace extraction tracks
[#85](https://github.com/bormilan/signerl/issues/85). Frozen generic XML outputs
from #83 are preserved with their
[original hashes and provenance](test/examples/xmlan_migration/README.md).
See [NOTICE](NOTICE) and the preserved [Apache-2.0 license](LICENSE.md).
