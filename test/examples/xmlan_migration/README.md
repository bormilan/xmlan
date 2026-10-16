# Frozen generic XML corpus

Copied byte-for-byte from Signerl's #83 migration corpus. The originals were
captured on 14 October 2026 from unchanged Signerl `dev`
`5927e41bab8674b875c51df1a1ec956d42676992`, using OTP 28.4.2.

- `input.xml`: UTF-8 mixed content, Unicode text/attributes, `xml:space`, unused
  and inherited namespaces, default undeclaration, prefix rebinding, character
  references, CDATA, and a legal trailing comment.
- `parsed.term`: exact parsed transparent tuple/value representation.
- `export.xml` and `fragment.xml`: exact serialization, including prolog,
  escaping, ordering, and the differing final-newline contracts.
- `SHA256SUMS`: the corresponding original hashes, copied without recapturing
  output from xmlan. XML files have Git text conversion disabled on all platforms.

The consumer reads expected values as files; it never regenerates goldens from
the current implementation. These outputs freeze prior behavior, not independent
standards conformance. C14N fixtures remain part of #86; signed output and key
fixtures remain owned by Signerl. No cryptographic material is needed here.

Run `rebar3 ct --suite test/xmlan_SUITE`; the same consumer runs outside the test
profile as described in [test responsibilities](../../TESTS.md). A changed golden
must fail the consumer. Investigate any migration difference before changing an
expected file.

`../base/books.xml` and `../preserved_content.xml` are also copied unchanged
from Signerl's `test/examples/base/books.xml` and
`test/examples/c14n/preserved_content.xml` at the same baseline. They test file
I/O, Unicode/whitespace, and entity/reference normalization without a canonicalizer.
