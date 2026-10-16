-module(xmlan_parser_test).

% Pure XML contracts adapted from Signerl; see NOTICE.

-include_lib("eunit/include/eunit.hrl").

parse_test() ->
    Path = "test/examples/base/books.xml",
    {<<"library">>, [{<<"id">>, "112233"}], [
        "\n    ",
        {<<"book">>, _, _},
        "\n    ",
        {<<"book">>, _, _},
        "\n    ",
        {<<"book">>, _, _},
        "\n"
    ]} = xmlan:parse_file(Path).

add_new_test() ->
    {ok, Root} = xmlan:parse_binary(
        <<"<library id='112233'> before <book/> after </library>">>
    ),
    Expected =
        {<<"library">>, [{<<"id">>, "112233"}], [
            " before ",
            {<<"book">>, [], []},
            " after ",
            {<<"book">>, [{<<"id">>, "4"}], [{<<"title">>, [], ["My new book"]}]}
        ]},
    ?assertEqual(Expected, xmlan:add_new_element(new_test_element(), Root)).

export_test() ->
    Path = "test/examples/base/books.xml",
    Root = xmlan:parse_file(Path),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Binary = xmlan:export(Prolog, Root),

    ?assertEqual({ok, Prolog}, xmlan:parse_prolog(Binary)),
    ?assertEqual({ok, Root}, xmlan:parse_binary(Binary)).

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
    ?assertEqual(<<Expected/binary, "\n">>, xmlan:export([], Parsed)).

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
            Expected = unicode:characters_to_binary(["<root value=\"", ParsedValue, "\"/>\n"]),
            ?assertEqual(Expected, xmlan:export([], Root))
        end}
     || {Name, Value, ParsedValue} <- [
            {"Unicode character list", "café", "café"},
            {"UTF-8 binary", <<"café"/utf8>>, "café"},
            {"integer", -42, "-42"},
            {"atom", hello, "hello"}
        ]
    ].

export_nested_content_order_test() ->
    Root =
        {<<"root">>, [{<<"id">>, "a&b"}], [
            "before ",
            {<<"outer">>, [], ["left ", {<<"inner">>, [], ["<&>"]}, " right"]},
            " between ",
            {<<"empty">>, [{<<"value">>, "\t"}], []},
            " after"
        ]},
    Expected = <<
        "<root id=\"a&amp;b\">before <outer>left <inner>&lt;&amp;&gt;</inner> right</outer>"
        " between <empty value=\"&#x9;\"/> after</root>"
    >>,
    ?assertEqual(<<Expected/binary, "\n">>, xmlan:export([], Root)),
    ?assertEqual(
        <<"<?xml version=\"1.0\"?>", Expected/binary>>, xmlan:export_fragment(Root)
    ).

export_deep_tree_test() ->
    Depth = 10000,
    Root = lists:foldl(
        fun(_, Child) -> {<<"branch">>, [], [Child]} end,
        {<<"leaf">>, [], ["end<&>"]},
        lists:seq(1, Depth)
    ),
    Expected = iolist_to_binary([
        binary:copy(<<"<branch>">>, Depth),
        <<"<leaf>end&lt;&amp;&gt;</leaf>">>,
        binary:copy(<<"</branch>">>, Depth),
        "\n"
    ]),
    ?assertEqual(Expected, xmlan:export([], Root)).

parse_prolog_valid_test() ->
    Message = <<"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><root/>">>,
    ?assertEqual(
        {ok, ["<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"]},
        xmlan:parse_prolog(Message)
    ).

parse_prolog_missing_test() ->
    Message = <<"<root/>">>,
    ?assertEqual({error, invalid_prolog}, xmlan:parse_prolog(Message)).

parse_prolog_invalid_typo_test() ->
    Message = <<"<?xml versoin=\"1.0\" encoding=\"UTF-8\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, xmlan:parse_prolog(Message)).

parse_prolog_invalid_attribute_test() ->
    Message = <<"<?xml version=\"1.0\" foo=\"bar\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, xmlan:parse_prolog(Message)).

parse_prolog_invalid_malformed_declaration_test() ->
    Message = <<"<?xml version=\"1.0\" encoding=\"UTF-8\"<root/>">>,
    ?assertEqual({error, invalid_prolog}, xmlan:parse_prolog(Message)).

parse_prolog_rejects_bom_test() ->
    Message = <<16#EF, 16#BB, 16#BF, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root/>">>,
    ?assertEqual({error, invalid_prolog}, xmlan:parse_prolog(Message)).

parse_prolog_only_extracts_declaration_test() ->
    Message = <<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root><child>1</child></root>">>,
    {ok, [Prolog]} = xmlan:parse_prolog(Message),
    ?assertEqual("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", Prolog).

find_path_success_test() ->
    Leaf = {<<"p:value">>, [], ["2026-01-01T00:00:00Z"]},
    Root = {<<"root">>, [], [{<<"p:outer">>, [], [{<<"p:inner">>, [], [Leaf]}]}]},
    ?assertEqual({ok, Leaf}, xmlan:find_path([<<"p:outer">>, <<"p:inner">>, <<"p:value">>], Root)).

find_path_errors_on_missing_or_ambiguous_nodes_test_() ->
    [
        {Name, ?_assertEqual({error, not_found}, xmlan:find_path([<<"ds:Object">>], Root))}
     || {Name, Root} <- [
            {"missing", {<<"ds:Envelope">>, [], []}},
            {"ambiguous",
                {<<"ds:Envelope">>, [], [
                    {<<"ds:Object">>, [], []}, {<<"ds:Object">>, [], []}
                ]}}
        ]
    ].

export_fragment_exact_xml_test_() ->
    [
        {Name, ?_assertEqual(Expected, xmlan:export_fragment(Element))}
     || {Name, Element, Expected} <- [
            {"text content", {<<"tag">>, [], ["content"]},
                <<"<?xml version=\"1.0\"?><tag>content</tag>">>},
            {"empty element", {<<"tag">>, [], []}, <<"<?xml version=\"1.0\"?><tag/>">>},
            {"escaped attribute and text", {<<"tag">>, [{<<"id">>, "a&b"}], ["<value>"]},
                <<"<?xml version=\"1.0\"?><tag id=\"a&amp;b\">&lt;value&gt;</tag>">>}
        ]
    ].

%% Utils

new_test_element() ->
    NewTag = <<"book">>,
    NewAttrs = [{<<"id">>, "4"}],
    NewContent = [{<<"title">>, [], ["My new book"]}],
    {NewTag, NewAttrs, NewContent}.

unicode_export_roundtrip_test() ->
    Root = {<<"root">>, [{<<"value">>, "café árvíztűrő 東京 😀"}], ["café árvíztűrő 東京 😀"]},
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    Expected = <<"café árvíztűrő 東京 😀"/utf8>>,
    lists:foreach(
        fun(Binary) -> assert_export_roundtrip(Root, Expected, Binary) end,
        [xmlan:export(Prolog, Root), xmlan:export_fragment(Root)]
    ),
    ?assertEqual(
        {ok, Expected}, xmlan:single_text({<<"root">>, [], ["café árvíztűrő 東京 😀"]})
    ).

utf8_declaration_test_() ->
    [
        {Encoding, ?_assertEqual(Expected, xmlan:parse_prolog(Message))}
     || {Encoding, Expected, Message} <- [
            {"default", {ok, ["<?xml version='1.0'?>"]}, <<"<?xml version='1.0'?><root/>">>},
            {"mixed case", {ok, ["<?xml version='1.0' encoding = 'uTf-8'?>"]},
                <<"<?xml version='1.0' encoding = 'uTf-8'?><root/>">>},
            {"Latin-1", {error, invalid_prolog},
                <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>},
            {"UTF-16", {error, invalid_prolog},
                <<"<?xml version='1.0' encoding='UTF-16'?><root/>">>}
        ]
    ].

reject_non_utf8_input_test_() ->
    [
        {Name, ?_assertEqual({error, invalid_xml}, xmlan:parse_binary(Message))}
     || {Name, Message} <- [
            {"Latin-1 declaration", <<"<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>},
            {"UTF-8 BOM with Latin-1 declaration",
                <<239, 187, 191, "<?xml version='1.0' encoding='ISO-8859-1'?><root/>">>},
            {"UTF-16 bytes",
                unicode:characters_to_binary(
                    "<?xml version='1.0' encoding='UTF-16'?><root/>", unicode, {utf16, big}
                )},
            {"UTF-16 bytes with no declaration",
                unicode:characters_to_binary("<root/>", unicode, {utf16, big})},
            {"isolated continuation byte", <<"<root>", 16#80, "</root>">>},
            {"overlong encoding", <<"<root>", 16#C0, 16#AF, "</root>">>},
            {"surrogate", <<"<root>", 16#ED, 16#A0, 16#80, "</root>">>},
            {"incomplete character", <<"<root/>", 16#F0, 16#9F>>}
        ]
    ].

export_rejects_unsupported_encoding_test() ->
    ?assertException(
        error,
        _,
        xmlan:export(
            ["<?xml version='1.0' encoding='ISO-8859-1'?>"], {<<"root">>, [], ["café"]}
        )
    ).

preserve_character_content_test_() ->
    [
        {Name,
            ?_assertEqual(
                <<Expected/binary, "\n">>, xmlan:export([], element(2, xmlan:parse_binary(Xml)))
            )}
     || {Name, Xml, Expected} <- [
            {"separating whitespace", <<"<root><a/> <b/></root>">>, <<"<root><a/> <b/></root>">>},
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

export_preserves_character_references_test() ->
    Root =
        {<<"root">>,
            [{<<"tab">>, "x\ty"}, {<<"lf">>, "x\ny"}, {<<"cr">>, "x\ry"}, {<<"literal">>, "&#x9;"}],
            ["t\rt<&>"]},
    ExpectedBody = <<
        "<root tab=\"x&#x9;y\" lf=\"x&#xA;y\" cr=\"x&#xD;y\" literal=\"&amp;#x9;\">"
        "t&#xD;t&lt;&amp;&gt;</root>"
    >>,
    lists:foreach(
        fun(Output) -> assert_export_roundtrip(Root, ExpectedBody, Output) end,
        [xmlan:export([], Root), xmlan:export_fragment(Root)]
    ).

reject_processing_instructions_test_() ->
    [
        {Name, ?_assertEqual({error, invalid_xml}, xmlan:parse_binary(Xml))}
     || {Name, Xml} <- [
            {"inside root", <<"<root><?report preserved?></root>">>},
            {"before root", <<"<?report preserved?><root/>">>},
            {"after empty root", <<"<root/><?report preserved?>">>},
            {"after nonempty root", <<"<root><a/></root><?report preserved?>">>},
            {"stylesheet", <<"<?xml-stylesheet href='a.xsl'?><root/>">>}
        ]
    ].

processing_instruction_text_is_not_an_instruction_test() ->
    ?assertEqual(
        {ok, {<<"root">>, [], ["<?report preserved?>"]}},
        xmlan:parse_binary(<<"<root><![CDATA[<?report preserved?>]]></root>">>)
    ),
    ?assertEqual(
        {ok, {<<"root">>, [], ["text"]}},
        xmlan:parse_binary(<<"<root><!-- <?report preserved?> -->text</root>">>)
    ).

trailing_misc_test_() ->
    [
        {Name, ?_assertEqual(Expected, xmlan:parse_binary(Xml))}
     || {Name, Xml, Expected} <- [
            {"trailing comments and whitespace",
                <<"<root><a/></root> \t\r\n<!-- preserved profile omits comments -->">>,
                {ok, {<<"root">>, [], [{<<"a">>, [], []}]}}},
            {"second root", <<"<root><a/></root><other/>">>, {error, invalid_xml}},
            {"trailing declaration", <<"<root><a/></root><?xml version='1.0'?>">>,
                {error, invalid_xml}},
            {"trailing DTD", <<"<root><a/></root><!DOCTYPE tail>">>, {error, invalid_xml}},
            {"trailing text", <<"<root><a/></root>unexpected">>, {error, invalid_xml}},
            {"second root after empty root", <<"<root/><extra/>">>, {error, invalid_xml}},
            {"trailing text after empty root", <<"<root/>not XML">>, {error, invalid_xml}},
            {"comments after empty root", <<"<root/> \t\r\n<!-- <extra/> -->">>,
                {ok, {<<"root">>, [], []}}},
            {"garbage after a comment", <<"<root/><!-- fine -->not XML">>, {error, invalid_xml}},
            {"unterminated comment", <<"<root><a/></root><!-- unfinished">>, {error, invalid_xml}},
            {"invalid comment separator", <<"<root/><!-- invalid -- separator -->">>,
                {error, invalid_xml}},
            {"incomplete markup", <<"<root><a/></root><">>, {error, invalid_xml}},
            {"CDATA outside root", <<"<root/><![CDATA[ ]]>">>, {error, invalid_xml}},
            {"character reference outside root", <<"<root><a/></root>&#x20;">>,
                {error, invalid_xml}},
            {"non-XML whitespace", <<"<root/>", 16#C2, 16#A0>>, {error, invalid_xml}},
            {"trailing BOM", <<"<root><a/></root>", 239, 187, 191>>, {error, invalid_xml}}
        ]
    ].

assert_export_roundtrip(Root, ExpectedBytes, Output) ->
    ?assertMatch({_, _}, binary:match(Output, ExpectedBytes)),
    ?assertEqual({ok, Root}, xmlan:parse_binary(Output)).

reject_dtd_test_() ->
    [
        {Name, ?_assertEqual({error, invalid_xml}, xmlan:parse_binary(Xml))}
     || {Name, Xml} <- [
            {"bare doctype", <<"<!DOCTYPE root><root/>">>},
            {"doctype whitespace", <<"<!DOCTYPE root \t\r\n><root/>">>},
            {"empty subset", <<"<!DOCTYPE root []><root/>">>},
            {"element declaration", <<"<!DOCTYPE root [<!ELEMENT root EMPTY>]><root/>">>},
            {"default attribute",
                <<"<!DOCTYPE root [<!ATTLIST root id CDATA 'default'>]><root/>">>},
            {"internal entity",
                <<"<!DOCTYPE root [<!ENTITY value 'expanded'>]><root>&value;</root>">>},
            {"parameter entity",
                <<"<!DOCTYPE root [<!ENTITY % value '<!ELEMENT root EMPTY>'>%value;]><root/>">>},
            {"undeclared entity", <<"<root>&unknown;</root>">>}
        ]
    ].

reject_bounded_exponential_expansion_test() ->
    % A small billion-laughs shape: at most 256 characters if expanded.
    Xml = <<
        "<!DOCTYPE root [<!ENTITY a 'ha'><!ENTITY b '&a;&a;&a;&a;'>"
        "<!ENTITY c '&b;&b;&b;&b;'>]><root>&c;&c;&c;&c;&c;&c;&c;&c;</root>"
    >>,
    ?assertEqual({error, invalid_xml}, xmlan:parse_binary(Xml)).

reject_bounded_quadratic_expansion_test() ->
    % A long entity repeated many times, bounded to 32 KiB before the fix.
    Value = binary:copy(<<"a">>, 512),
    Refs = binary:copy(<<"&value;">>, 64),
    Xml =
        <<"<!DOCTYPE root [<!ENTITY value '", Value/binary, "'>]><root>", Refs/binary, "</root>">>,
    ?assertEqual({error, invalid_xml}, xmlan:parse_binary(Xml)).

predefined_entities_and_character_references_test() ->
    Xml =
        <<
            "<root value='&lt;&gt;&amp;&quot;&apos;&#65;&#x1F600;'>"
            "&lt;&gt;&amp;&quot;&apos;&#65;&#x1F600;&amp;unknown;</root>"
        >>,
    ?assertEqual(
        {ok, {<<"root">>, [{<<"value">>, "<>&\"'A😀"}], ["<>&\"'A😀&unknown;"]}},
        xmlan:parse_binary(Xml)
    ).

dtd_looking_text_is_not_a_declaration_test() ->
    Xml =
        <<
            "<!-- <!DOCTYPE root> --><root>"
            "<![CDATA[<!DOCTYPE root [<!ENTITY value 'text'>]>]]></root>"
            "<!-- <!DOCTYPE root> -->"
        >>,
    ?assertEqual(
        {ok, {<<"root">>, [], ["<!DOCTYPE root [<!ENTITY value 'text'>]>"]}},
        xmlan:parse_binary(Xml)
    ).

xml_names_are_utf8_binaries_test() ->
    Xml =
        <<
            "<ár xmlns='urn:default' xmlns:ő='urn:prefixed' érték='v'>"/utf8,
            "<ő:東京 ő:érték='w'/></ár>"/utf8
        >>,
    Expected =
        {<<"ár"/utf8>>,
            [
                {<<"xmlns">>, "urn:default"},
                {<<"xmlns:ő"/utf8>>, "urn:prefixed"},
                {<<"érték"/utf8>>, "v"}
            ],
            [{<<"ő:東京"/utf8>>, [{<<"ő:érték"/utf8>>, "w"}], []}]},
    ?assertEqual({ok, Expected}, xmlan:parse_binary(Xml)).

xml_name_longer_than_atom_limit_test() ->
    Name = binary:copy(<<"n">>, 300),
    Xml = <<"<", Name/binary, " ", Name/binary, "='v'/>">>,
    ?assertEqual({ok, {Name, [{Name, "v"}], []}}, xmlan:parse_binary(Xml)).

namespace_qualified_lookup_test_() ->
    [
        {Label, fun() ->
            {ok, Root} = xmlan:parse_binary(Xml),
            Result = xmlan:find_path(Path, Root),
            case Expected of
                not_found -> ?assertEqual({error, not_found}, Result);
                Name -> ?assertMatch({ok, {Name, _, _}}, Result)
            end
        end}
     || {Label, Xml, Path, Expected} <- [
            {"inherited alias", <<"<root xmlns:s='urn:example'><s:Entry/></root>">>,
                [{<<"urn:example">>, <<"Entry">>}], <<"s:Entry">>},
            {"default namespace", <<"<root><Entry xmlns='urn:example'/></root>">>,
                [{<<"urn:example">>, <<"Entry">>}], <<"Entry">>},
            {"nested inherited binding",
                <<"<root xmlns:s='", "urn:example",
                    "'><s:Envelope><s:Entry/></s:Envelope></root>">>,
                [{<<"urn:example">>, <<"Envelope">>}, {<<"urn:example">>, <<"Entry">>}],
                <<"s:Entry">>},
            {"wrong URI decoy",
                <<"<root xmlns:ds='urn:wrong' xmlns:s='", "urn:example",
                    "'><ds:Entry/><s:Entry/></root>">>,
                [{<<"urn:example">>, <<"Entry">>}], <<"s:Entry">>},
            {"subtree redeclaration",
                <<"<root xmlns:s='", "urn:example",
                    "'><s:Envelope><s:Entry xmlns:s='urn:wrong'/></s:Envelope></root>">>,
                [{<<"urn:example">>, <<"Envelope">>}, {<<"urn:example">>, <<"Entry">>}], not_found},
            {"aliases are ambiguous",
                <<"<root xmlns:a='", "urn:example", "' xmlns:b='", "urn:example",
                    "'><a:Entry/><b:Entry/></root>">>,
                [{<<"urn:example">>, <<"Entry">>}], not_found},
            {"default undeclaration", <<"<root xmlns='urn:app'><child xmlns=''/></root>">>,
                [{<<>>, <<"child">>}], <<"child">>},
            {"wrong default URI", <<"<root xmlns='urn:app'><Entry/></root>">>,
                [{<<"urn:example">>, <<"Entry">>}], not_found},
            {"missing intermediate node", <<"<root/>">>,
                [{<<"urn:example">>, <<"Envelope">>}, {<<"urn:example">>, <<"Entry">>}], not_found}
        ]
    ].

namespace_lookup_preserves_context_test() ->
    {ok, Root} = xmlan:parse_binary(<<
        "<root xmlns='urn:app' xmlns:s='urn:example' xmlns:q='urn:outer'>"
        "<s:Envelope xmlns:q='urn:inner'><s:Entry><q:child/>"
        "</s:Entry></s:Envelope></root>"
    >>),
    {ok, {<<"s:Entry">>, Attrs, _} = Child} = xmlan:find_path(
        [{<<"urn:example">>, <<"Envelope">>}, {<<"urn:example">>, <<"Entry">>}], Root
    ),
    ?assertEqual({ok, "urn:app"}, xmlan:attr_value(<<"xmlns">>, Attrs)),
    ?assertEqual({ok, "urn:inner"}, xmlan:attr_value(<<"xmlns:q">>, Attrs)),
    ?assertEqual({ok, "urn:example"}, xmlan:attr_value(<<"xmlns:s">>, Attrs)),
    ?assertEqual(
        <<"<s:Entry xmlns=\"urn:app\" xmlns:q=\"urn:inner\" xmlns:s=\"", "urn:example",
            "\"><q:child/></s:Entry>\n">>,
        xmlan:export([], Child)
    ),
    %% Existing binary selectors remain lexical and return the original tuple.
    {ok, {<<"s:Envelope">>, _, [Original]}} = xmlan:find_path([<<"s:Envelope">>], Root),
    ?assertEqual(
        {ok, Original}, xmlan:find_path([<<"s:Envelope">>, <<"s:Entry">>], Root)
    ).

expanded_names_preserve_content_and_scope_test() ->
    Attrs = [{<<"xmlns:p">>, "urn:outer"}],
    InnerAttrs = [{<<"xmlns:p">>, <<"urn:inner">>}],
    Root =
        {<<"p:root">>, Attrs, [
            "before",
            {<<"p:child">>, InnerAttrs, [<<"text">>]},
            {<<"p:child">>, [], []},
            {<<"unbound:child">>, [], []},
            "after"
        ]},
    ?assertEqual(
        {{<<"urn:outer">>, <<"root">>}, Attrs, [
            "before",
            {{<<"urn:inner">>, <<"child">>}, InnerAttrs, [<<"text">>]},
            {{<<"urn:outer">>, <<"child">>}, [], []},
            {{undefined, <<"child">>}, [], []},
            "after"
        ]},
        xmlan:expanded_names(Root)
    ).

parse_rejects_namespace_constraint_violations_test_() ->
    [
        {Label, ?_assertEqual({error, invalid_xml}, xmlan:parse_binary(Xml))}
     || {Label, Xml} <- [
            {"undeclared element prefix", <<"<p:root/>">>},
            {"undeclared attribute prefix", <<"<root p:a='1'/>">>},
            {"reserved xml rebinding", <<"<xml:Envelope xmlns:xml='urn:example'/>">>},
            {"reserved xmlns prefix", <<"<root xmlns:xmlns='urn:wrong'/>">>},
            {"reserved xmlns URI", <<"<root xmlns:p='http://www.w3.org/2000/xmlns/'/>">>},
            {"XML URI on another prefix",
                <<"<root xmlns:p='http://www.w3.org/XML/1998/namespace'/>">>},
            {"XML URI as default", <<"<root xmlns='http://www.w3.org/XML/1998/namespace'/>">>},
            {"empty prefixed declaration", <<"<root xmlns:p=''><p:child/></root>">>},
            {"duplicate declaration", <<"<root xmlns:p='urn:one' xmlns:p='urn:two'/>">>},
            {"duplicate expanded attributes",
                <<"<root xmlns:a='urn:u' xmlns:b='urn:u' a:id='1' b:id='2'/>">>},
            {"multiple QName colons", <<"<a:b:c xmlns:a='urn:a'/>">>},
            {"empty QName local name", <<"<a: xmlns:a='urn:a'/>">>},
            {"empty QName prefix", <<"<:root/>">>},
            {"numeric QName local name", <<"<a:1 xmlns:a='urn:a'/>">>},
            {"attribute QName colons", <<"<root xmlns:a='urn:a' a:b:c='1'/>">>},
            {"numeric attribute local name", <<"<root xmlns:a='urn:a' a:1='1'/>">>},
            {"xmlns element prefix", <<"<xmlns:root/>">>},
            {"empty namespace declaration prefix", <<"<root xmlns:='urn:x'/>">>},
            {"spaced empty namespace prefix", <<"<root label='ok' xmlns: = 'urn:x'/>">>},
            {"nested empty namespace prefix",
                <<"<root xmlns:p='urn:x'><child xmlns:='urn:y'/></root>">>},
            {"relative prefixed URI", <<"<root xmlns:p='relative'/>">>},
            {"relative default URI", <<"<root xmlns='../relative'/>">>},
            {"fragment namespace URI", <<"<root xmlns:p='#local'/>">>},
            {"reserved xmlns default URI", <<"<root xmlns='http://www.w3.org/2000/xmlns/'/>">>}
        ]
    ].

parse_accepts_reserved_xml_and_rebound_namespaces_test() ->
    Xml = <<
        "<root xmlns:xml='http://www.w3.org/XML/1998/namespace' xml:lang='en' "
        "xmlns:p='urn:outer'><p:child xmlns:p='urn:inner' p:id='1'/><p:child/></root>"
    >>,
    ?assertMatch(
        {ok, {<<"root">>, _, [{<<"p:child">>, _, []}, {<<"p:child">>, _, []}]}},
        xmlan:parse_binary(Xml)
    ).

parse_accepts_distinct_attribute_namespaces_test() ->
    Xml = <<
        "<root xmlns='urn:root' xmlns:p='urn:root' id='1' p:id='2' xml:lang='en'>"
        "<child xmlns=''/></root>"
    >>,
    {ok, {<<"root">>, Attrs, [{<<"child">>, [{<<"xmlns">>, []}], []}]}} =
        xmlan:parse_binary(Xml),
    ?assertEqual({ok, "1"}, xmlan:attr_value(<<"id">>, Attrs)),
    ?assertEqual({ok, "2"}, xmlan:attr_value(<<"p:id">>, Attrs)).

parse_accepts_unicode_namespace_names_test() ->
    Xml = unicode:characters_to_binary("<é:根 xmlns:é='urn:unicode' é:値='ok'/>"),
    ?assertMatch({ok, {_, _, []}}, xmlan:parse_binary(Xml)).

lexical_path_missing_ancestor_test() ->
    Xml = {<<"root">>, [], [{<<"child">>, [], []}]},
    ?assertEqual({error, not_found}, xmlan:find_path([<<"missing">>, <<"child">>], Xml)).

namespace_like_literals_are_preserved_test_() ->
    [
        ?_assertMatch({ok, _}, xmlan:parse_binary(Xml))
     || Xml <- [
            <<"<root><!-- <child xmlns:='urn:x'/> --></root>">>,
            <<"<root><![CDATA[<child xmlns:='urn:x'/>]]></root>">>,
            <<"<root label=\"xmlns:='urn:x'\"/>">>,
            <<"<root>xmlns: = 'urn:x'</root>">>
        ]
    ].

parse_utf8_bom_test() ->
    ?assertEqual(
        {ok, {<<"root">>, [], ["ő"]}},
        xmlan:parse_binary(
            <<239, 187, 191, "<?xml version='1.0' encoding='UTF-8'?><root>ő</root>"/utf8>>
        )
    ).

incomplete_or_malformed_document_test_() ->
    [
        ?_assertEqual({error, invalid_xml}, xmlan:parse_binary(Xml))
     || Xml <- [
            <<>>,
            <<"<!-- only a comment -->">>,
            <<"<root>">>,
            <<"<root><a/></other>">>,
            <<"<root value='unfinished/>">>,
            <<"<?xml version='1.0'?><root>&#0;</root>">>
        ]
    ].

prolog_spelling_and_order_test_() ->
    [
        ?_assertEqual({error, invalid_prolog}, xmlan:parse_prolog(Xml))
     || Xml <- [
            <<" <?xml version='1.0'?><root/>">>,
            <<"<?xml encoding='UTF-8' version='1.0'?><root/>">>,
            <<"<?xml version='1.0' standalone='maybe'?><root/>">>,
            <<"<?xml version='1.0' encoding='UTF-8' encoding='UTF-8'?><root/>">>
        ]
    ].

prolog_retains_original_spelling_test() ->
    Prolog = "<?xml  version = '1.1' encoding = 'uTf-8' standalone = 'no' ?>",
    ?assertEqual({ok, [Prolog]}, xmlan:parse_prolog(list_to_binary(Prolog ++ "<root/>"))).

find_children_preserves_order_and_context_test() ->
    {ok, Root} = xmlan:parse_binary(<<
        "<root xmlns='urn:root' xmlns:p='urn:item'>text"
        "<p:item id='first'/><other/><p:item id='second'/><p:item xmlns:p='urn:decoy'/></root>"
    >>),
    [First, Second] = xmlan:find_children({<<"urn:item">>, <<"item">>}, Root),
    ?assertEqual({ok, "first"}, xmlan:attr_value(<<"id">>, element(2, First))),
    ?assertEqual({ok, "second"}, xmlan:attr_value(<<"id">>, element(2, Second))),
    lists:foreach(
        fun(Child) ->
            ?assertEqual({<<"urn:item">>, <<"item">>}, xmlan:expanded_name(Child, #{})),
            ?assertEqual({ok, "urn:root"}, xmlan:attr_value(<<"xmlns">>, element(2, Child)))
        end,
        [First, Second]
    ),
    ?assertEqual([], xmlan:find_children({<<"urn:missing">>, <<"item">>}, Root)).

namespace_context_preserves_local_undeclaration_test() ->
    ParentNs = xmlan:namespace_context(
        [{<<"xmlns">>, "urn:parent"}, {<<"xmlns:p">>, "urn:p"}], #{}
    ),
    Child = {<<"child">>, [{<<"xmlns">>, []}], ["text"]},
    Detached = xmlan:with_namespace_context(Child, ParentNs),
    ?assertEqual({<<>>, <<"child">>}, xmlan:expanded_name(Detached, #{})),
    ?assertEqual([{<<"xmlns">>, []}, {<<"xmlns:p">>, "urn:p"}], element(2, Detached)),
    ?assertEqual(
        {{<<>>, <<"child">>}, element(2, Detached), ["text"]}, xmlan:expanded_names(Detached)
    ).

parse_and_project_deep_tree_test() ->
    Depth = 10000,
    Xml = iolist_to_binary([
        binary:copy(<<"<p:branch xmlns:p='urn:deep'>">>, Depth),
        <<"<leaf>text</leaf>">>,
        binary:copy(<<"</p:branch>">>, Depth)
    ]),
    {ok, Tree} = xmlan:parse_binary(Xml),
    ?assertEqual({<<"leaf">>, [], ["text"]}, deepest_child(Depth, Tree)),
    ?assertEqual(
        {{<<>>, <<"leaf">>}, [], ["text"]}, deepest_child(Depth, xmlan:expanded_names(Tree))
    ),
    ?assertEqual({ok, Tree}, xmlan:parse_binary(xmlan:export([], Tree))).

deepest_child(0, Tree) ->
    Tree;
deepest_child(Depth, {_, _, [Child]}) ->
    deepest_child(Depth - 1, Child).
