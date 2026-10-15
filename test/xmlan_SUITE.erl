-module(xmlan_SUITE).

-include_lib("stdlib/include/assert.hrl").
-compile([export_all, nowarn_export_all]).

all() ->
    [standalone_consumer].

standalone_consumer(_Config) ->
    {ok, Peer, _} = peer:start_link(#{
        connection => standard_io,
        args => [
            "+S",
            "2:2",
            "-pa",
            filename:join(code:lib_dir(xmlan), "ebin"),
            filename:dirname(code:which(xmlan_consumer))
        ]
    }),
    try
        ?assertMatch({ok, _}, peer:call(Peer, application, ensure_all_started, [xmlan])),
        ?assertMatch(
            {{<<"root">>, _, _}, {{<<"urn:example">>, <<"root">>}, _, []}, #{
                <<"p">> := <<"urn:example">>
            }},
            peer:call(Peer, xmlan_consumer, run, [])
        ),
        ?assertEqual(false, peer:call(Peer, code, is_loaded, [signerl]))
    after
        peer:stop(Peer)
    end.
