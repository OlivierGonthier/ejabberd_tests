%%==============================================================================
%% Copyright 2012 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================

-module(muc_SUITE).
-compile(export_all).

-include_lib("escalus/include/escalus.hrl").
-include_lib("escalus/include/escalus_xmlns.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("exml/include/exml.hrl").

-define(MUC_HOST, <<"muc.localhost">>).

%%--------------------------------------------------------------------
%% Suite configuration
%%--------------------------------------------------------------------

all() ->
    [{group, disco}
    %% {group, admin}
     %% {group, room_management}].
    ].

groups() ->
    [{disco, [sequence], [disco_service,
                          disco_features,
                          disco_rooms,
                          disco_info,
                          disco_items,
                          disco_support,
                          disco_contact_rooms
                          ]},
      %% {moderator, [sequence], []},
      %% {admin, [sequence], []},
      {room_management, [sequence], [create_and_destroy_room]}].

suite() ->
    escalus:suite().

%%--------------------------------------------------------------------
%% Init & teardown
%%--------------------------------------------------------------------

init_per_suite(Config) ->
    escalus:init_per_suite(Config).

end_per_suite(Config) ->
    escalus:end_per_suite(Config).

%% Make Alice an admin
init_per_group(admin, Config) ->
  Config1 = escalus:create_users(Config),
  Config2 = start_persistent_room(
      escalus:init_per_testcase(admin, Config1), <<"alicesroom">>, <<"alicesnick">>),
  escalus:end_per_testcase(admin, Config2),
  Config2;

init_per_group(disco, Config) ->
    Config1 = escalus:create_users(Config),
    Config2 = start_persistent_room(escalus:init_per_testcase(disco, Config1), <<"alicesroom">>, <<"aliceonchat">>),
    escalus:end_per_testcase(disco, Config2),
    Config2;

init_per_group(_GroupName, Config) ->
    escalus:create_users(Config).

end_per_group(admin, Config) ->
    Config1 = escalus:init_per_testcase(admin, Config),
    destroy_room(Config1, <<"alicesroom">>),
    escalus:end_per_testcase(admin, Config1),
    escalus:delete_users(Config1);

end_per_group(disco, Config) ->
    Config1 = escalus:init_per_testcase(disco, Config),
    destroy_room(Config1, <<"alicesroom">>),
    escalus:end_per_testcase(disco, Config1),
    escalus:delete_users(Config1);

end_per_group(_GroupName, Config) ->
    escalus:delete_users(Config).

init_per_testcase(CaseName, Config) ->
    escalus:init_per_testcase(CaseName, Config).

end_per_testcase(CaseName, Config) ->
    escalus:end_per_testcase(CaseName, Config).


%%--------------------------------------------------------------------
%%  Occupant use case tests
%%
%%  Tests the usecases described here :
%%  http://xmpp.org/extensions/xep-0045.html/#user
%%--------------------------------------------------------------------

%Example 18
groupchat_user_enter(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->
                Room = <<"room1">>,
                Nick = <<"nick1">>,
                Create_room_stanza = stanza_create_room(Nick, Room),
                escalus:send(Alice, Create_room_stanza),
                Enter_room_stanza = stanza_groupchat_enter_room(<<"room1">>, <<"bob">>),
                error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
                escalus:send(Bob, Enter_room_stanza),
                Presence = escalus:wait_for_stanza(Bob),
                escalus_assert:is_presence_stanza(Presence),
                error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence]),
                From = << Room/binary ,"@", ?MUC_HOST/binary, "/", "bob" >>,
                From = exml_query:attr(Presence, <<"from">>)
        end).

%Example 19
%No error message sent from the server
groupchat_user_enter_no_nickname(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->
                Create_room_stanza = stanza_create_room(<<"room1">>, <<"nick1">>),
                escalus:send(Alice, Create_room_stanza),
                Enter_room_stanza = stanza_groupchat_enter_room_no_nick(<<"room1">>),
                error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
                escalus:send(Bob, Enter_room_stanza),
                Presence3 = escalus:wait_for_stanza(Alice),
                error_logger:info_msg("Alice's new user presence notification: ~n~p~n",[Presence3]),
                escalus_assert:is_presence_stanza(Presence3),
                escalus_assert:has_no_stanzas(Alice),   %!!
                escalus_assert:has_no_stanzas(Bob)
        end).

% Examples 20, 21, 22
% TO DO: check the messages content details
muc_user_enter(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->
                Room = <<"room1">>, Nick= <<"nick1">>, 
                Create_room_stanza = stanza_create_room(Room, Nick),

                %Alice creates a room
                escalus:send(Alice, Create_room_stanza),

                %Bob enters the room
                Enter_room_stanza = stanza_muc_enter_room(<<"room1">>, <<"bob">>),
                error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
                escalus:send(Bob, Enter_room_stanza),
                Presence = escalus:wait_for_stanza(Bob),
                error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence]),
                escalus_assert:is_presence_stanza(Presence),
                From = << Room/binary ,"@", ?MUC_HOST/binary, "/", Nick/binary >>,
                From = exml_query:attr(Presence, <<"from">>),

                Presence2 = escalus:wait_for_stanza(Bob),
                error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence2]),
                escalus_assert:is_presence_stanza(Presence2),
                From2 = << Room/binary ,"@", ?MUC_HOST/binary, "/", "bob" >>,
                From2 = exml_query:attr(Presence2, <<"from">>),

                Topic = escalus:wait_for_stanza(Bob),
                error_logger:info_msg("Bobs topic notification: ~n~p~n",[Topic]),

                Presence3 = escalus:wait_for_stanza(Alice),
                error_logger:info_msg("Alice's new user presence notification: ~n~p~n",[Presence3]),
                escalus_assert:is_presence_stanza(Presence3),

                Topic2 = escalus:wait_for_stanza(Alice),
                error_logger:info_msg("Alice's topic notification: ~n~p~n",[Topic2]),

                Presence4 = escalus:wait_for_stanza(Alice),
                error_logger:info_msg("Alice's new user presence notification: ~n~p~n",[Presence4]),
                escalus_assert:is_presence_stanza(Presence4),
                escalus_assert:has_no_stanzas(Alice),
                escalus_assert:has_no_stanzas(Bob)
        end).

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------


disco_service(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        Server = escalus_client:server(Alice),
        escalus:send(Alice, escalus_stanza:service_discovery(Server)),
        Stanza = escalus:wait_for_stanza(Alice),
        escalus:assert(has_service, [?MUC_HOST], Stanza),
        escalus:assert(is_stanza_from, [escalus_config:get_config(ejabberd_domain, Config)], Stanza)
    end).

disco_features(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
          Server = escalus_client:server(Alice),
          escalus:send(Alice, stanza_get_features(Server)),
          Stanza = escalus:wait_for_stanza(Alice),
          has_features(Stanza),
          escalus:assert(is_stanza_from, [?MUC_HOST], Stanza)
    end).

disco_rooms(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
          Server = escalus_client:server(Alice),
          escalus:send(Alice, stanza_get_rooms(Server)),
          %% we should have 1 room, created in init
          Stanza = escalus:wait_for_stanza(Alice),
          count_rooms(Stanza, 1),
          has_room(room_address(<<"alicesroom">>), Stanza),
          escalus:assert(is_stanza_from, [?MUC_HOST], Stanza)
    end).

disco_info(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        Server = escalus_client:server(Alice),
        escalus:send(Alice, stanza_to_room(escalus_stanza:iq_get(?NS_DISCO_INFO,[]), <<"alicesroom">>)),
        Stanza = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, Stanza),
        #xmlelement{body = [Body]} = Stanza,
        has_feature(Body#xmlelement.body, <<"muc_persistent">>)
    end).

disco_items(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        escalus:send(Alice, stanza_join_room(<<"alicesroom">>, <<"nicenick">>)),
        _Stanza = escalus:wait_for_stanza(Alice),

        escalus:send(Bob, stanza_to_room(escalus_stanza:iq_get(?NS_DISCO_ITEMS,[]), <<"alicesroom">>)),
        Stanza2 = escalus:wait_for_stanza(Bob),
        escalus:assert(is_iq_result, Stanza2)
    end).

disco_support(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
      S = escalus_stanza:to(escalus_stanza:iq_get(?NS_DISCO_INFO, []), Bob),
      error_logger:info_msg(S),
      escalus:send(Alice, escalus_stanza:to(
        escalus_stanza:iq_get(?NS_DISCO_INFO, []), Bob)),
      escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice))
    end).

disco_contact_rooms(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
    #xmlelement{name = Name, attrs = Attrs, body = [Body]} =
        escalus_stanza:to(escalus_stanza:iq_get(?NS_DISCO_INFO, []), Bob),
    NewBody = #xmlelement{name = Body#xmlelement.name,
                          attrs = [{<<"node">>,<<"http://jabber.org/protocol/muc#rooms">>}|
                                    Body#xmlelement.attrs],
                          body = Body#xmlelement.body},
    escalus:send(Alice, #xmlelement{name = Name, attrs = Attrs, body = NewBody}),
    escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice))
    end).

create_and_destroy_room(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
          Server = escalus_client:server(Alice),
          Room1 = stanza_create_room(<<"room1">>, <<"nick1">>),
          escalus:send(Alice, Room1),
          %Alice gets topic message after creating the room
          [S, _S2] = escalus:wait_for_stanzas(Alice, 2),
          was_room_created(S),

          DestroyRoom1 = stanza_destroy_room(<<"room1">>),
          escalus:send(Alice, DestroyRoom1),
          [Presence, Iq] = escalus:wait_for_stanzas(Alice, 2),
          was_room_destroyed(Iq),
          was_destroy_presented(Presence)
        end).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

%Basic MUC protocol
stanza_muc_enter_room(Room, Nick) ->
    stanza_to_room(
        escalus_stanza:presence(  <<"available">>,
                                [#xmlelement{ name = <<"x">>, attrs=[{<<"xmlns">>, <<"http://jabber.org/protocol/muc">>}]}]),
        Room, Nick).

%Groupchat 1.0 protocol
stanza_groupchat_enter_room(Room, Nick) ->
    stanza_to_room(escalus_stanza:presence(<<"available">>), Room, Nick).


stanza_groupchat_enter_room_no_nick(Room) ->
    stanza_to_room(escalus_stanza:presence(<<"available">>), Room).

start_persistent_room(Config, Room, Nick) ->
    escalus:story(Config, [1], fun(Alice) ->
          escalus:send(Alice, stanza_create_room(Room, Nick)),
          Stanzas2 = escalus:wait_for_stanzas(Alice, 2),
          FormRequest = stanza_to_room(escalus_stanza:iq_get(?NS_MUC_OWNER, []), Room),
          escalus:send(Alice, FormRequest),
          Form = escalus:wait_for_stanza(Alice),
          Params = [{<<"muc#roomconfig_persistentroom">>,<<"1">>,<<"boolean">>}],
          ConfigForm = stanza_configuration_form(Room, Params),
          escalus:send(Alice, stanza_configuration_form(Room, Params)),
          Response = escalus:wait_for_stanza(Alice)
        end),
    Config.

destroy_room(Config, Room) ->
    escalus:story(Config, [1], fun(Alice) ->
          escalus:send(Alice, stanza_destroy_room(Room)),
          Stanzas2 = escalus:wait_for_stanzas(Alice, 2)
        end).

room_address(Room) ->
    <<Room/binary, "@", ?MUC_HOST/binary>>.

room_address(Room, Nick) ->
    <<Room/binary, "@", ?MUC_HOST/binary, "/", Nick/binary>>.

%%--------------------------------------------------------------------
%% Helpers (stanzas)
%%--------------------------------------------------------------------
stanza_join_room(Room, Nick) ->
  stanza_to_room(#xmlelement{name = <<"presence">>, body =
    #xmlelement{name = <<"x">>, attrs = [{<<"xmlns">>,<<"http://jabber.org/protocol/muc">>}]}},
    Room, Nick).

stanza_configuration_form(Room, Params) ->
  DefaultParams = [{<<"FORM_TYPE">>,<<"http://jabber.org/protocol/muc#roomconfig">>,<<"hidden">>}],
  FinalParams = lists:foldl(fun({Key,Val,Type},Acc) ->
        lists:keydelete(Key,1,Acc) end,
        DefaultParams, Params) ++ Params,
  XPayload = [ #xmlelement{name = <<"field">>,
                attrs = [{<<"type">>, Type},{<<"var">>, Var}],
                body = #xmlelement{name = <<"value">>,
                          body = #xmlcdata{content = Value}}}
              || {Var, Value, Type} <- FinalParams],
  Payload = #xmlelement{name = <<"x">>,
              attrs = [{<<"xmlns">>,<<"jabber:x:data">>}, {<<"type">>,<<"submit">>}],
              body = XPayload},
  stanza_to_room(escalus_stanza:iq_set(?NS_MUC_OWNER, Payload), Room).

stanza_destroy_room(Room) ->
  Payload = [ #xmlelement{name = <<"destroy">>} ],
  stanza_to_room(escalus_stanza:iq_set(?NS_MUC_OWNER, Payload), Room).

stanza_create_room(Room, Nick) ->
  stanza_to_room(#xmlelement{name = <<"presence">>}, Room, Nick).

stanza_to_room(Stanza, Room, Nick) ->
  escalus_stanza:to(Stanza, room_address(Room, Nick)).

stanza_to_room(Stanza, Room) ->
  escalus_stanza:to(Stanza, room_address(Room)).

stanza_get_rooms(Config) ->
  %% <iq from='hag66@shakespeare.lit/pda'
  %%   id='zb8q41f4'
  %%   to='chat.shakespeare.lit'
  %%   type='get'>
  %% <query xmlns='http://jabber.org/protocol/disco#items'/>
  %% </iq>

  escalus_stanza:setattr(escalus_stanza:iq_get(?NS_DISCO_ITEMS, []), <<"to">>,
                          ?MUC_HOST).

stanza_get_features(Config) ->
    %% <iq from='hag66@shakespeare.lit/pda'
    %%     id='lx09df27'
    %%     to='chat.shakespeare.lit'
    %%     type='get'>
    %%  <query xmlns='http://jabber.org/protocol/disco#info'/>
    %% </iq>
    escalus_stanza:setattr(escalus_stanza:iq_get(?NS_DISCO_INFO, []), <<"to">>,
                             ?MUC_HOST).

stanza_get_services(Config) ->
    %% <iq from='hag66@shakespeare.lit/pda'
    %%     id='h7ns81g'
    %%     to='shakespeare.lit'
    %%     type='get'>
    %%   <query xmlns='http://jabber.org/protocol/disco#items'/>
    %% </iq>
    escalus_stanza:setattr(escalus_stanza:iq_get(?NS_DISCO_ITEMS, []), <<"to">>,
                           escalus_config:get_config(ejabberd_domain, Config)).

%%--------------------------------------------------------------------
%% Helpers (assertions)
%%--------------------------------------------------------------------

has_feature(Body, Feature) ->
  Features = lists:foldl(fun(#xmlelement{name = <<"feature">>} = El,Acc) -> [El | Acc];
    (_,Acc) -> Acc end, [], Body),
  true = lists:any(fun(Item) ->
    exml_query:attr(Item, <<"var">>) == Feature end,
    Features).

was_destroy_presented(#xmlelement{body = [Items]} = Presence) ->
  #xmlelement{} = exml_query:subelement(Items, <<"destroy">>),
  <<"unavailable">> = exml_query:attr(Presence, <<"type">>).

was_room_destroyed(Query) ->
  <<"result">> = exml_query:attr(Query, <<"type">>).

was_room_created(#xmlelement{body = [ #xmlelement{body = Items} = Query ]}) ->
  #xmlelement{} = Status = exml_query:subelement(Query, <<"status">>),
  <<"201">> = exml_query:attr(Status, <<"code">>),

  #xmlelement{} = Item = exml_query:subelement(Query, <<"item">>),
  <<"owner">> = exml_query:attr(Item, <<"affiliation">>),
  <<"moderator">> = exml_query:attr(Item, <<"role">>).

has_room(JID, #xmlelement{body = [ #xmlelement{body = Rooms} ] = Query}) ->
  %% <iq from='chat.shakespeare.lit'
  %%   id='zb8q41f4'
  %%   to='hag66@shakespeare.lit/pda'
  %%   type='result'>
  %% <query xmlns='http://jabber.org/protocol/disco#items'>
  %%    <item jid='heath@chat.shakespeare.lit'
  %%         name='A Lonely Heath'/>
  %%    <item jid='coven@chat.shakespeare.lit'
  %%         name='A Dark Cave'/>
  %%    <item jid='forres@chat.shakespeare.lit'
  %%         name='The Palace'/>
  %%     <item jid='inverness@chat.shakespeare.lit'
  %%         name='Macbeth&apos;s Castle'/>
  %%   </query>
  %% </iq>
  
  RoomPred = fun(Item) ->
                exml_query:attr(Item, <<"jid">>) == JID
             end,
  true = lists:any(RoomPred, Rooms).

count_rooms(#xmlelement{body = [ #xmlelement{body = Rooms} ] = Query}, N) ->
  N = length(Rooms).

has_features(#xmlelement{body = [ Query ]}) ->
    %%<iq from='chat.shakespeare.lit'
    %%  id='lx09df27'
    %%  to='hag66@shakespeare.lit/pda'
    %%  type='result'>
    %%  <query xmlns='http://jabber.org/protocol/disco#info'>
    %%    <identity
    %%      category='conference'
    %%      name='Shakespearean Chat Service'
    %%      type='text'/>
    %%      <feature var='http://jabber.org/protocol/muc'/>
    %%  </query>
    %%</iq>

    Identity = exml_query:subelement(Query, <<"identity">>),
    <<"conference">> = exml_query:attr(Identity, <<"category">>),
    #xmlelement{name = _Name, attrs = _Attrs, body = _Body} = exml_query:subelement(Query, <<"feature">>).

has_muc(#xmlelement{body = [ #xmlelement{body = Services} = Query ]}) ->
    %% should be along the lines of (taken straight from the XEP):
    %% <iq from='shakespeare.lit'
    %%     id='h7ns81g'
    %%     to='hag66@shakespeare.lit/pda'
    %%     type='result'>
    %%   <query xmlns='http://jabber.org/protocol/disco#items'>
    %%     <item jid='chat.shakespeare.lit'
    %%           name='Chatroom Service'/>
    %%   </query>
    %% </iq>

    %% is like this:
    %% {xmlelement,<<"iq">>,
    %%     [{<<"from">>,<<"localhost">>},
    %%         {<<"to">>,<<"alice@localhost/res1">>},
    %%         {<<"id">>,<<"a5eb1dc70826598893b15f1936b18a34">>},
    %%         {<<"type">>,<<"result">>}],
    %%     [{xmlelement,<<"query">>,
    %%             [{<<"xmlns">>,
    %%                     <<"http://jabber.org/protocol/disco#items">>}],
    %%             [{xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"vjud.localhost">>}],
    %%                     []},
    %%                 {xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"pubsub.localhost">>}],
    %%                     []},
    %%                 {xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"muc.localhost">>}],
    %%                     []},
    %%                 {xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"irc.localhost">>}],
    %%                     []}]}]}
    %% how to obtaing output like the above? simply put this in the test case:
    %% S = escalus:wait_for_stanza(Alice),
    %% error_logger:info_msg("~p~n", [S]),
    IsMUC = fun(Item) ->
                exml_query:attr(Item, <<"jid">>) == ?MUC_HOST
            end,
    lists:any(IsMUC, Services).