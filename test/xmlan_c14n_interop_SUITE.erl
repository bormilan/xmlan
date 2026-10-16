-module(xmlan_c14n_interop_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include("xmlan.hrl").
-compile([export_all, nowarn_export_all]).

all() ->
    [{group, interop_group}].

groups() ->
    [
        {interop_group, [], [
            interop_simple_attrs,
            interop_namespaces,
            interop_nested_ns,
            interop_escaping,
            interop_default_ns,
            interop_mixed_content,
            interop_dsig_like,
            interop_utf8,
            interop_preserved_content,
            interop_namespace_edges,
            interop_detached_fragment
        ]}
    ].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(interop_group, Config) ->
    case os:find_executable("xmllint") of
        false -> ct:fail(xmllint_not_available);
        _Path -> Config
    end;
init_per_group(_Group, Config) ->
    Config.

end_per_group(_Group, _Config) ->
    ok.

interop_simple_attrs(Config) ->
    assert_matches_xmllint("simple_attrs.xml", Config).

interop_namespaces(Config) ->
    assert_matches_xmllint("namespaces.xml", Config).

interop_nested_ns(Config) ->
    assert_matches_xmllint("nested_ns.xml", Config).

interop_escaping(Config) ->
    assert_matches_xmllint("escaping.xml", Config).

interop_default_ns(Config) ->
    assert_matches_xmllint("default_ns.xml", Config).

interop_mixed_content(Config) ->
    assert_matches_xmllint("mixed_content.xml", Config).

interop_dsig_like(Config) ->
    assert_matches_xmllint("dsig_like.xml", Config).

assert_matches_xmllint(FileName, _Config) ->
    FilePath = filename:join([test_examples_dir(), "c14n", FileName]),
    {ok, Raw} = file:read_file(FilePath),
    {ok, Parsed} = xmlan:parse_binary(Raw),
    assert_modes_match(FilePath, Parsed).

test_examples_dir() ->
    SuiteFile = code:which(?MODULE),
    TestDir = filename:dirname(SuiteFile),
    filename:join(TestDir, "examples").

run_xmllint(FilePath, Mode) ->
    Port = open_port(
        {spawn_executable, os:find_executable("xmllint")},
        [{args, [Mode, FilePath]}, binary, exit_status, stderr_to_stdout]
    ),
    collect_port_output(Port, <<>>).

collect_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            canonical_stdout(Acc);
        {Port, {exit_status, Code}} ->
            error({xmllint_failed, Code, Acc})
    after 5000 ->
        error(xmllint_timeout)
    end.

interop_utf8(Config) ->
    assert_matches_xmllint("utf8.xml", Config).

interop_preserved_content(Config) ->
    Path = filename:join([test_examples_dir(), "c14n", "preserved_content.xml"]),
    {ok, Raw} = file:read_file(Path),
    {ok, Parsed} = xmlan:parse_binary(Raw),
    OutputPath = filename:join(?config(priv_dir, Config), "preserved-export.xml"),
    ok = file:write_file(OutputPath, xmlan:export([], Parsed)),
    lists:foreach(
        fun({Mode, Flag}) ->
            Expected = run_xmllint(Path, Flag),
            ?assertEqual(Expected, xmlan_c14n:canonicalize(Parsed, Mode)),
            ?assertEqual(Expected, run_xmllint(OutputPath, Flag))
        end,
        [{c14n11, "--c14n11"}, {exc_c14n, "--exc-c14n"}]
    ).

interop_namespace_edges(Config) ->
    Cases = [
        {"empty-default", <<"<root xmlns=\"\"/>">>},
        {"xml-attributes",
            <<"<root xmlns:xml=\"", ?XML_NAMESPACE_URI/binary, "\" xml:a=\"1\" b=\"2\"/>">>},
        {"default-undeclaration", <<
            "<root xmlns=\"urn:parent\"><child xmlns=\"\">"
            "<leaf/></child></root>"
        >>},
        {"prefix-redeclaration", <<
            "<p:root xmlns:p=\"urn:parent\"><p:child xmlns:p=\"urn:child\"/>"
            "<p:other/></p:root>"
        >>}
    ],
    lists:foreach(
        fun({Name, Raw}) ->
            Path = filename:join(?config(priv_dir, Config), Name ++ ".xml"),
            ok = file:write_file(Path, Raw),
            {ok, Parsed} = xmlan:parse_binary(Raw),
            assert_modes_match(Path, Parsed)
        end,
        Cases
    ).

% xmllint's C14N mode writes stdout even with --output. Windows C stdio
% translates LF to CRLF. Undo that transport conversion only; XML CR values
% remain the literal bytes "&#xD;" and fixture/production bytes are untouched.
canonical_stdout(Output) ->
    case os:type() of
        {win32, _} -> binary:replace(Output, <<"\r\n">>, <<"\n">>, [global]);
        _ -> Output
    end.

interop_detached_fragment(Config) ->
    {ok, Root} = xmlan:parse_binary(<<
        "<root xmlns='urn:app' xmlns:p='urn:item' xmlns:unused='urn:unused'>"
        "<p:outer><p:item id='7'><child xmlns=''/></p:item></p:outer></root>"
    >>),
    {ok, Detached} = xmlan:find_path(
        [{<<"urn:item">>, <<"outer">>}, {<<"urn:item">>, <<"item">>}], Root
    ),
    Path = filename:join(?config(priv_dir, Config), "detached.xml"),
    ok = xmlan:to_file(Path, xmlan:export([], Detached)),
    assert_modes_match(Path, Detached).

assert_modes_match(Path, Tree) ->
    lists:foreach(
        fun({Mode, Flag}) ->
            ?assertEqual(run_xmllint(Path, Flag), xmlan_c14n:canonicalize(Tree, Mode))
        end,
        [{c14n11, "--c14n11"}, {exc_c14n, "--exc-c14n"}]
    ).
