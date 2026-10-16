-module(xmlan_consumer).

-include_lib("stdlib/include/assert.hrl").

-export([run/0, run/1, tree/0]).

-spec tree() -> xmlan:simplified_xml().
tree() ->
    {<<"root">>, [{<<"value">>, <<"café"/utf8>>}], [<<"東京"/utf8>>]}.

-spec metadata() -> {xmlan:attribute_value(), xmlan:expanded_name()}.
metadata() ->
    {<<"café"/utf8>>, {<<"urn:example">>, <<"root">>}}.

-spec run() -> {xmlan:simplified_xml(), xmlan:expanded_xml(), xmlan:namespace_context()}.
run() ->
    {Name, Attrs, _} = Tree = tree(),
    ?assertEqual(<<"root">>, Name),
    ?assertEqual({ok, <<"café"/utf8>>}, xmlan:attr_value(<<"value">>, Attrs)),
    ?assertEqual(<<"café"/utf8>>, xmlan:attr_value_or_undefined(<<"value">>, Attrs)),
    ?assertEqual({ok, <<"東京"/utf8>>}, xmlan:single_text(Tree)),
    Child = {<<"child">>, [], ["árvíz"]},
    Added = xmlan:add_new_element(Child, Tree),
    ?assertEqual([<<"東京"/utf8>>, Child], element(3, Added)),
    ?assertEqual({ok, <<"árvíz"/utf8>>}, xmlan:single_text(Child)),
    {Value, ExpandedName} = metadata(),
    {Added, {ExpandedName, [{<<"value">>, Value}], []}, #{<<"p">> => <<"urn:example">>}}.

-spec run(string()) -> ok.
run(Dir) ->
    _ = run(),
    check_xml(Dir),
    ok.

check_xml(Dir) ->
    Input = read(Dir, "input.xml"),
    {ok, [ExpectedTree]} = file:consult(filename:join(Dir, "parsed.term")),
    ?assertEqual({ok, ExpectedTree}, xmlan:parse_binary(Input)),
    ?assertEqual(ExpectedTree, xmlan:parse_file(filename:join(Dir, "input.xml"))),
    Prolog = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"],
    ?assertEqual({ok, Prolog}, xmlan:parse_prolog(Input)),
    ?assertEqual(read(Dir, "export.xml"), xmlan:export(Prolog, ExpectedTree)),
    ?assertEqual(read(Dir, "fragment.xml"), xmlan:export_fragment(ExpectedTree)),
    Missing = filename:join([Dir, "absent-consumer-directory", "output.xml"]),
    ?assertEqual({error, enoent}, xmlan:to_file(Missing, <<"<root/>">>)),
    [Item] = xmlan:find_children({<<"urn:items">>, <<"item">>}, ExpectedTree),
    ?assertEqual({ok, Item}, xmlan:find_path([{<<"urn:items">>, <<"item">>}], ExpectedTree)),
    ?assertEqual({<<"urn:items">>, <<"item">>}, xmlan:expanded_name(Item, #{})),
    Context = xmlan:namespace_context(element(2, ExpectedTree), #{}),
    ?assertEqual(<<"urn:invoice">>, maps:get(<<>>, Context)),
    ?assertEqual(Item, xmlan:with_namespace_context(Item, Context)),
    ?assertMatch(
        {{<<"urn:invoice">>, <<"invoice">>}, _, _}, xmlan:expanded_names(ExpectedTree)
    ).

read(Dir, Name) ->
    {ok, Bytes} = file:read_file(filename:join(Dir, Name)),
    Bytes.
