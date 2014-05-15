-module(sm_helpers).
-compile([export_all]).

-import(escalus_stanza, [setattr/3]).
-import(vcard_update, [discard_vcard_update/1,
                       server_string/1]).


mk_resume_stream(SMID, PrevH) ->
    fun (Conn, Props, Features) ->
            escalus_connection:send(Conn, escalus_stanza:resume(SMID, PrevH)),
            Resumed = escalus_connection:get_stanza(Conn, get_resumed),
            true = escalus_pred:is_resumed(SMID, Resumed),
            {Conn, [{smid, SMID} | Props], Features}
    end.

buffer_unacked_messages_and_die(AliceSpec, Bob, Messages) ->
    Steps = [start_stream,
             maybe_use_ssl,
             authenticate,
             bind,
             session,
             stream_resumption],
    {ok, Alice, Props, _} = escalus_connection:start(AliceSpec, Steps),
    InitialPresence = setattr(escalus_stanza:presence(<<"available">>),
                              <<"id">>, <<"presence1">>),
    escalus_connection:send(Alice, InitialPresence),
    Presence = escalus_connection:get_stanza(Alice, presence1),
    escalus:assert(is_presence, Presence),
    Res = server_string("escalus-default-resource"),
    {ok, C2SPid} = get_session_pid(AliceSpec, Res),
    escalus_connection:send(Alice, escalus_stanza:presence(<<"available">>)),
    _Presence = escalus_connection:get_stanza(Alice, presence2),
    discard_vcard_update(Alice),
    %% Bobs sends some messages to Alice.
    [escalus:send(Bob, escalus_stanza:chat_to(alice, Msg))
     || Msg <- Messages],
    %% Alice receives them, but doesn't ack.
    Stanzas = [escalus_connection:get_stanza(Alice, {msg, I})
               || I <- lists:seq(1, 3)],
    [escalus:assert(is_chat_message, [Msg], Stanza)
     || {Msg, Stanza} <- lists:zip(Messages, Stanzas)],
    %% Alice's connection is violently terminated.
    escalus_connection:kill(Alice),
    {C2SPid, proplists:get_value(smid, Props)}.


get_session_pid(UserSpec, Resource) ->
    ConfigUS = [proplists:get_value(username, UserSpec),
                proplists:get_value(server, UserSpec)],
    [U, S] = [server_string(V) || V <- ConfigUS],
    MatchSpec = match_session_pid({U, S, Resource}),
    case escalus_ejabberd:rpc(ets, select, [session, MatchSpec]) of
        [] ->
            {error, not_found};
        [{_, C2SPid}] ->
            {ok, C2SPid};
        [C2SPid] ->
            {ok, C2SPid};
        [_|_] = Sessions ->
            {error, {multiple_sessions, Sessions}}
    end.

%% Copy'n'paste from github.com/lavrin/ejabberd-trace

match_session_pid({_User, _Domain, _Resource} = UDR) ->
    [{%% match pattern
      set(session(), [{2, {'_', '$1'}},
                      {3, UDR}]),
      %% guards
      [],
      %% return
      ['$1']}];

match_session_pid({User, Domain}) ->
    [{%% match pattern
      set(session(), [{2, {'_', '$1'}},
                      {3, '$2'},
                      {4, {User, Domain}}]),
      %% guards
      [],
      %% return
      [{{'$2', '$1'}}]}].

set(Record, FieldValues) ->
    F = fun({Field, Value}, Rec) ->
                setelement(Field, Rec, Value)
        end,
    lists:foldl(F, Record, FieldValues).

session() ->
    set(erlang:make_tuple(6, '_'), [{1, session}]).

%% End of copy'n'paste from github.com/lavrin/ejabberd-trace
