-module(xmlan_c14n_test).

% Generic canonicalization contracts extracted from Signerl; see NOTICE.

-include_lib("eunit/include/eunit.hrl").

%% Basic

empty_element_expansion_test() ->
    Input = {<<"doc">>, [], []},
    ?assertEqual(<<"<doc></doc>">>, xmlan_c14n:canonicalize(Input)).

self_closing_to_start_end_test() ->
    Input = {<<"doc">>, [], [{<<"e1">>, [], []}, {<<"e2">>, [], []}]},
    Expected = <<"<doc><e1></e1><e2></e2></doc>">>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

preserves_text_content_test() ->
    Input = {<<"doc">>, [], ["Hello, world!"]},
    ?assertEqual(<<"<doc>Hello, world!</doc>">>, xmlan_c14n:canonicalize(Input)).

preserves_whitespace_in_text_test() ->
    Input = {<<"doc">>, [], ["  spaces  and\nnewlines  "]},
    ?assertEqual(<<"<doc>  spaces  and\nnewlines  </doc>">>, xmlan_c14n:canonicalize(Input)).

nested_elements_test() ->
    Input = {<<"a">>, [], [{<<"b">>, [], [{<<"c">>, [], ["text"]}]}]},
    ?assertEqual(<<"<a><b><c>text</c></b></a>">>, xmlan_c14n:canonicalize(Input)).

multiple_children_test() ->
    Input = {<<"doc">>, [], ["text1", {<<"child">>, [], []}, "text2"]},
    ?assertEqual(<<"<doc>text1<child></child>text2</doc>">>, xmlan_c14n:canonicalize(Input)).

%% Namespace

sorts_namespace_declarations_test() ->
    Input =
        {<<"e5">>,
            [
                {<<"xmlns:b">>, "http://www.ietf.org"},
                {<<"xmlns:a">>, "http://www.w3.org"},
                {<<"xmlns">>, "http://example.org"}
            ],
            []},
    Expected = <<
        "<e5 xmlns=\"http://example.org\""
        " xmlns:a=\"http://www.w3.org\""
        " xmlns:b=\"http://www.ietf.org\"></e5>"
    >>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

eliminates_superfluous_ns_decls_test() ->
    Input =
        {<<"root">>, [{<<"xmlns:a">>, "http://a.com"}], [
            {<<"child">>, [{<<"xmlns:a">>, "http://a.com"}], ["text"]}
        ]},
    Expected = <<"<root xmlns:a=\"http://a.com\"><child>text</child></root>">>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

namespace_inheritance_test() ->
    Input =
        {<<"root">>, [{<<"xmlns:p">>, "urn:example"}], [
            {<<"p:Child">>, [], ["content"]}
        ]},
    Expected = <<
        "<root xmlns:p=\"urn:example\">"
        "<p:Child>content</p:Child></root>"
    >>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

default_namespace_test() ->
    Input =
        {<<"root">>, [{<<"xmlns">>, "http://example.org"}], [
            {<<"child">>, [], ["text"]}
        ]},
    Expected = <<"<root xmlns=\"http://example.org\"><child>text</child></root>">>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

namespace_context_edges_test_() ->
    EmptyDefault = {<<"root">>, [{<<"xmlns">>, ""}], []},
    Undeclaration =
        {<<"root">>, [{<<"xmlns">>, "urn:parent"}], [
            {<<"child">>, [{<<"xmlns">>, ""}], [{<<"leaf">>, [], []}]}
        ]},
    XmlAttributes =
        {<<"root">>, [{<<"xml:a">>, "1"}, {<<"b">>, "2"}], []},
    ExplicitXml =
        {<<"root">>, [{<<"xmlns:xml">>, "http://www.w3.org/XML/1998/namespace"}], []},
    BinaryNamespace =
        {<<"p:root">>, [{<<"xmlns:p">>, <<"urn:p">>}], [
            {<<"p:child">>, [{<<"xmlns:p">>, "urn:p"}], []}
        ]},
    Cases = [
        {"omits empty default namespace at root", EmptyDefault, <<"<root></root>">>},
        {"preserves default namespace undeclaration", Undeclaration,
            <<"<root xmlns=\"urn:parent\"><child xmlns=\"\"><leaf></leaf></child></root>">>},
        {"sorts implicit XML namespace attributes", XmlAttributes,
            <<"<root b=\"2\" xml:a=\"1\"></root>">>},
        {"omits reserved XML namespace declaration", ExplicitXml, <<"<root></root>">>},
        {"normalizes binary namespace values", BinaryNamespace,
            <<"<p:root xmlns:p=\"urn:p\"><p:child></p:child></p:root>">>}
    ],
    [
        {
            atom_to_list(Mode) ++ " " ++ Name,
            ?_assertEqual(Expected, xmlan_c14n:canonicalize(Tree, Mode))
        }
     || Mode <- [c14n11, exc_c14n], {Name, Tree, Expected} <- Cases
    ].

rejects_relative_namespace_uris_test_() ->
    [
        {
            atom_to_list(Mode) ++ " " ++ Name,
            ?_assertException(
                error,
                {badmatch, _},
                xmlan_c14n:canonicalize({<<"root">>, [{<<"xmlns:p">>, Uri}], []}, Mode)
            )
        }
     || Mode <- [c14n11, exc_c14n],
        {Name, Uri} <- [
            {"relative path", "relative"},
            {"absolute path without scheme", "/namespace"},
            {"fragment without scheme", <<"#namespace">>},
            {"authority without scheme", "//example.test/namespace"}
        ]
    ].

accepts_absolute_namespace_uris_test_() ->
    [
        {
            atom_to_list(Mode) ++ " " ++ Uri,
            ?_assertEqual(
                unicode:characters_to_binary(["<p:root xmlns:p=\"", Uri, "\"></p:root>"]),
                xmlan_c14n:canonicalize({<<"p:root">>, [{<<"xmlns:p">>, Uri}], []}, Mode)
            )
        }
     || Mode <- [c14n11, exc_c14n],
        Uri <- ["https://example.test/namespace", "urn:example:namespace"]
    ].

attribute_sorting_by_ns_uri_test() ->
    Input =
        {<<"e5">>,
            [
                {<<"xmlns">>, "http://example.org"},
                {<<"xmlns:a">>, "http://www.w3.org"},
                {<<"xmlns:b">>, "http://www.ietf.org"},
                {<<"a:attr">>, "out"},
                {<<"b:attr">>, "sorted"},
                {<<"attr2">>, "all"},
                {<<"attr">>, "I'm"}
            ],
            []},
    %% Sort order: unprefixed attrs by local name (empty NS URI),
    %% then prefixed attrs by (NS URI, local name)
    %% attr (empty,"attr"), attr2 (empty,"attr2"),
    %% b:attr ("http://www.ietf.org","attr"), a:attr ("http://www.w3.org","attr")
    Expected = <<
        "<e5"
        " xmlns=\"http://example.org\""
        " xmlns:a=\"http://www.w3.org\""
        " xmlns:b=\"http://www.ietf.org\""
        " attr=\"I'm\""
        " attr2=\"all\""
        " b:attr=\"sorted\""
        " a:attr=\"out\""
        "></e5>"
    >>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

mixed_ns_and_regular_attrs_test() ->
    Input =
        {<<"elem">>,
            [
                {<<"xmlns:z">>, "http://z.com"},
                {<<"id">>, "1"},
                {<<"name">>, "test"}
            ],
            []},
    Expected = <<"<elem xmlns:z=\"http://z.com\" id=\"1\" name=\"test\"></elem>">>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

unprefixed_attrs_sort_before_prefixed_test() ->
    Input =
        {<<"elem">>,
            [
                {<<"xmlns:ns">>, "http://ns.com"},
                {<<"ns:b">>, "2"},
                {<<"a">>, "1"}
            ],
            []},
    Expected = <<"<elem xmlns:ns=\"http://ns.com\" a=\"1\" ns:b=\"2\"></elem>">>,
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Input)).

%% Escaping

escapes_text_ampersand_test() ->
    Input = {<<"doc">>, [], ["a&b"]},
    ?assertEqual(<<"<doc>a&amp;b</doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_text_lt_test() ->
    Input = {<<"doc">>, [], ["a<b"]},
    ?assertEqual(<<"<doc>a&lt;b</doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_text_gt_test() ->
    Input = {<<"doc">>, [], ["a>b"]},
    ?assertEqual(<<"<doc>a&gt;b</doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_text_cr_test() ->
    Input = {<<"doc">>, [], ["a\rb"]},
    ?assertEqual(<<"<doc>a&#xD;b</doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_attr_ampersand_test() ->
    Input = {<<"doc">>, [{<<"v">>, "a&b"}], []},
    ?assertEqual(<<"<doc v=\"a&amp;b\"></doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_attr_lt_test() ->
    Input = {<<"doc">>, [{<<"v">>, "a<b"}], []},
    ?assertEqual(<<"<doc v=\"a&lt;b\"></doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_attr_quot_test() ->
    Input = {<<"doc">>, [{<<"v">>, "a\"b"}], []},
    ?assertEqual(<<"<doc v=\"a&quot;b\"></doc>">>, xmlan_c14n:canonicalize(Input)).

escapes_attr_whitespace_chars_test() ->
    Input = {<<"doc">>, [{<<"v">>, "a\tb\nc\rd"}], []},
    ?assertEqual(<<"<doc v=\"a&#x9;b&#xA;c&#xD;d\"></doc>">>, xmlan_c14n:canonicalize(Input)).

no_xml_declaration_test() ->
    Input = {<<"doc">>, [], ["text"]},
    Result = xmlan_c14n:canonicalize(Input),
    ?assertNotEqual(match, re:run(Result, "^<\\?xml", [{capture, none}])).

binary_text_child_test() ->
    Input = {<<"doc">>, [], [<<"binary text">>]},
    ?assertEqual(<<"<doc>binary text</doc>">>, xmlan_c14n:canonicalize(Input)).

attr_value_types_test() ->
    Input = {<<"doc">>, [{<<"b">>, <<"bin">>}, {<<"i">>, 42}, {<<"a">>, hello}], []},
    ?assertEqual(
        <<"<doc a=\"hello\" b=\"bin\" i=\"42\"></doc>">>,
        xmlan_c14n:canonicalize(Input)
    ).

exc_c14n_omits_unused_ns_test() ->
    %% Parent declares ns1 and ns2, child only uses ns1 in tag.
    %% Exc-C14N: root emits neither (not visibly used), child emits ns1.
    Input = two_ns_input([]),
    Result = xmlan_c14n:canonicalize(Input, exc_c14n),
    ?assertEqual(
        <<"<root><ns1:child xmlns:ns1=\"http://ns1\">text</ns1:child></root>">>,
        Result
    ).

exc_c14n_keeps_visibly_used_ns_test() ->
    %% Child uses ns1 in tag and ns2 in attribute — both should be emitted.
    Input = two_ns_input([{<<"ns2:attr">>, "val"}]),
    Result = xmlan_c14n:canonicalize(Input, exc_c14n),
    ?assertNotEqual(nomatch, binary:match(Result, <<"xmlns:ns1=\"http://ns1\"">>)),
    ?assertNotEqual(nomatch, binary:match(Result, <<"xmlns:ns2=\"http://ns2\"">>)).

exc_c14n_propagates_ns_to_children_test() ->
    %% Grandchild uses ns1 but parent doesn't — exc-c14n should emit ns1 on grandchild.
    Input =
        {<<"root">>, [{<<"xmlns:ns1">>, "http://ns1"}], [
            {<<"middle">>, [], [
                {<<"ns1:leaf">>, [], ["deep"]}
            ]}
        ]},
    Result = xmlan_c14n:canonicalize(Input, exc_c14n),
    ?assertNotEqual(
        nomatch, binary:match(Result, <<"<ns1:leaf xmlns:ns1=\"http://ns1\">deep</ns1:leaf>">>)
    ).

exc_c14n_binary_text_child_test() ->
    %% Binary text child should be handled the same as list text.
    Input = {<<"root">>, [], [<<"binary text">>]},
    ?assertEqual(<<"<root>binary text</root>">>, xmlan_c14n:canonicalize(Input, exc_c14n)).

exc_c14n_default_namespace_test() ->
    %% Element using default namespace (no prefix) should emit xmlns="...".
    Input = {<<"child">>, [{<<"xmlns">>, "http://default"}], ["text"]},
    Result = xmlan_c14n:canonicalize(Input, exc_c14n),
    ?assertEqual(<<"<child xmlns=\"http://default\">text</child>">>, Result).

exc_c14n_ns_already_in_output_scope_test() ->
    %% When parent already emitted ns1, child should not re-emit it (NeedEmit=false path).
    Input =
        {<<"ns1:parent">>, [{<<"xmlns:ns1">>, "http://ns1"}], [
            {<<"ns1:child">>, [], ["text"]}
        ]},
    Result = xmlan_c14n:canonicalize(Input, exc_c14n),
    %% ns1 appears once on parent, not re-emitted on child
    ?assertEqual(
        <<"<ns1:parent xmlns:ns1=\"http://ns1\"><ns1:child>text</ns1:child></ns1:parent>">>,
        Result
    ).

c14n11_emits_all_ns_decls_test() ->
    %% C14N 1.1 should emit ns2 on root even if only used by descendants.
    Input = two_ns_input([]),
    C14N11 = xmlan_c14n:canonicalize(Input, c14n11),
    %% ns2 should appear on root but NOT re-emitted on child
    ?assertNotEqual(nomatch, binary:match(C14N11, <<"xmlns:ns2=\"http://ns2\"">>)),
    %% Verify ns2 is NOT on child element in C14N 1.1
    ChildPart =
        case binary:match(C14N11, <<"<ns1:child">>) of
            {Start, _} -> binary:part(C14N11, Start, byte_size(C14N11) - Start);
            nomatch -> <<>>
        end,
    ?assertEqual(nomatch, binary:match(ChildPart, <<"xmlns:ns2">>)).

canonicalize_1_defaults_to_c14n11_test() ->
    Input = {<<"root">>, [{<<"xmlns:ns1">>, "http://ns1"}], [{<<"ns1:child">>, [], ["text"]}]},
    ?assertEqual(
        xmlan_c14n:canonicalize(Input, c14n11),
        xmlan_c14n:canonicalize(Input)
    ).

%% Fixture helpers

two_ns_input(ChildAttrs) ->
    {<<"root">>, [{<<"xmlns:ns1">>, "http://ns1"}, {<<"xmlns:ns2">>, "http://ns2"}], [
        {<<"ns1:child">>, ChildAttrs, ["text"]}
    ]}.

utf8_canonical_bytes_test_() ->
    Text = "café árvíztűrő 東京 😀",
    Utf8 = unicode:characters_to_binary(Text),
    Expected = <<"<ár érték=\"café árvíztűrő 東京 😀\">café árvíztűrő 東京 😀</ár>"/utf8>>,
    [
        {
            atom_to_list(Mode) ++ " " ++ Kind,
            ?_assertEqual(
                Expected,
                xmlan_c14n:canonicalize(
                    {<<"ár"/utf8>>, [{<<"érték"/utf8>>, Value}], [Value]}, Mode
                )
            )
        }
     || Mode <- [c14n11, exc_c14n], {Kind, Value} <- [{"characters", Text}, {"UTF-8 bytes", Utf8}]
    ].

exclusive_c14n_rejects_missing_prefix_context_test() ->
    ?assertError(
        {undeclared_namespace_prefix, "missing"},
        xmlan_c14n:canonicalize({<<"missing:child">>, [], []}, exc_c14n)
    ).

caller_constructed_tree_test() ->
    Text = <<"árvíz & 東京"/utf8>>,
    Attrs = [{<<"label">>, <<"café & \"tea\""/utf8>>}],
    Root = {<<"root">>, Attrs, ["before ", {<<"child">>, [], [Text]}, " after"]},
    Expected = <<
        "<root label=\"café &amp; &quot;tea&quot;\">before "
        "<child>árvíz &amp; 東京</child> after</root>"/utf8
    >>,
    ?assertEqual(<<Expected/binary, "\n">>, xmlan:export([], Root)),
    ?assertEqual(
        <<"<?xml version=\"1.0\"?>", Expected/binary>>, xmlan:export_fragment(Root)
    ),
    {ok, Child} = xmlan:find_path([<<"child">>], Root),
    ?assertEqual({ok, Text}, xmlan:single_text(Child)),
    {ok, Parsed} = xmlan:parse_binary(xmlan:export([], Root)),
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Parsed)),
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Root)),
    ?assertEqual(Expected, xmlan_c14n:canonicalize(Root, exc_c14n)).

attribute_value_representations_test_() ->
    [
        {Name, fun() ->
            Attrs = [{<<"value">>, Value}],
            Root = {<<"root">>, Attrs, []},
            ?assertEqual({ok, Value}, xmlan:attr_value(<<"value">>, Attrs)),
            ?assertEqual(Value, xmlan:attr_value_or_undefined(<<"value">>, Attrs)),
            ?assertEqual(
                {ok, {<<"root">>, [{<<"value">>, ParsedValue}], []}},
                xmlan:parse_binary(xmlan:export([], Root))
            ),
            Expected = unicode:characters_to_binary(["<root value=\"", ParsedValue, "\"></root>"]),
            ?assertEqual(Expected, xmlan_c14n:canonicalize(Root)),
            ?assertEqual(Expected, xmlan_c14n:canonicalize(Root, exc_c14n))
        end}
     || {Name, Value, ParsedValue} <- [
            {"Unicode character list", "café", "café"},
            {"UTF-8 binary", <<"café"/utf8>>, "café"},
            {"integer", -42, "-42"},
            {"atom", hello, "hello"}
        ]
    ].

preserve_character_content_test_() ->
    [
        {Name,
            ?_assertEqual(
                Expected, xmlan_c14n:canonicalize(element(2, xmlan:parse_binary(Xml)))
            )}
     || {Name, Xml, Expected} <- [
            {"separating whitespace", <<"<root><a/> <b/></root>">>,
                <<"<root><a></a> <b></b></root>">>},
            {"mixed and whitespace-only content", <<"<root>  before <a> \t\n </a> after  </root>">>,
                <<"<root>  before <a> \t\n </a> after  </root>">>},
            {"CDATA characters", <<"<root>left<![CDATA[ <&>\t ]]>right</root>">>,
                <<"<root>left &lt;&amp;&gt;\t right</root>">>},
            {"text carriage-return references", <<"<root>x&#xD;&#13;y</root>">>,
                <<"<root>x&#xD;&#xD;y</root>">>},
            {"literal line endings including CDATA",
                <<"<root>x\r\ny\rz<![CDATA[a\r\nb\rc]]></root>">>,
                <<"<root>x\ny\nza\nb\nc</root>">>},
            {"xml:space preserve", <<"<root xml:space='preserve'> \t\n </root>">>,
                <<"<root xml:space=\"preserve\"> \t\n </root>">>}
        ]
    ].

invalid_mode_test() ->
    ?assertError(function_clause, xmlan_c14n:canonicalize({<<"root">>, [], []}, unsupported)).

malformed_caller_tree_test_() ->
    [
        {
            atom_to_list(Mode) ++ " " ++ Label,
            ?_assertError(function_clause, xmlan_c14n:canonicalize(Tree, Mode))
        }
     || Mode <- [c14n11, exc_c14n],
        {Label, Tree} <- [
            {"non-tree", not_a_tree},
            {"unsupported child", {<<"root">>, [], [42]}},
            {"unsupported attribute", {<<"root">>, [{<<"value">>, 1.5}], []}}
        ]
    ].

detached_namespace_context_test_() ->
    {ok, Root} = xmlan:parse_binary(<<
        "<root xmlns='urn:app' xmlns:p='urn:item' xmlns:unused='urn:unused'>"
        "<p:outer><p:item id='7'><child xmlns=''/></p:item></p:outer></root>"
    >>),
    {ok, Detached} = xmlan:find_path(
        [{<<"urn:item">>, <<"outer">>}, {<<"urn:item">>, <<"item">>}], Root
    ),
    [
        {atom_to_list(Mode), ?_assertEqual(Expected, xmlan_c14n:canonicalize(Detached, Mode))}
     || {Mode, Expected} <- [
            {c14n11, <<
                "<p:item xmlns=\"urn:app\" xmlns:p=\"urn:item\" "
                "xmlns:unused=\"urn:unused\" id=\"7\"><child xmlns=\"\"></child></p:item>"
            >>},
            {exc_c14n, <<"<p:item xmlns:p=\"urn:item\" id=\"7\"><child></child></p:item>">>}
        ]
    ].
