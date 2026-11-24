%% Deskcite product API over mesgd HTTPS, with mesgd event subscriptions.
-module(deskcite).
-export([ new/2, new/3, with_token/2, call/3, operations/0,
	status/1, similar/2, ask/2, rate/2, question/2, create_question/2,
	search/2, search_graph/2, document/2, import_source/2, embed/1,
	agents/1, schedules/1, tasks/2, schedule/2, refresh/1, logout/1,
	events/3, close_events/1 ]).

%% A transport is fun(Method, Path, Body, Token) ->
%% {ok, Status, Headers, Bytes} | {error, Reason}.
new(Origin, Token) ->
	new(Origin, Token, #{}).

new(Origin, Token, Options) ->
	Base = deskcite_http:origin(Origin),
	Transport = maps:get(transport, Options, deskcite_http:transport(Base, Options)),
	#{ origin => Base, token => token(Token), transport => Transport }.

with_token(Client, Token) ->
	Client#{ token := token(Token) }.

token(Token) when is_binary(Token), byte_size(Token) > 0 ->
	true = lists:all(fun(C) ->
		C > 32 andalso C < 127
	end, binary_to_list(Token)),
	Token.

%% Stable operation names for the language wrappers. Query routes use their
%% documented POST form so Unicode and filters remain JSON fields.
operations() ->
	#{ status => { get, "/deskcite", none },
		similar => { post, "/deskcite/similar", json },
		ask => { post, "/deskcite/ask", json },
		rate => { post, "/deskcite/rate", json },
		question => { get, "/deskcite/question/", id },
		create_question => { post, "/deskcite/question", json },
		search => { post, "/deskcite/search", json },
		search_graph => { post, "/deskcite/search/graph", json },
		document => { get, "/deskcite/documents/", document },
		import_source => { post, "/deskcite/import", json },
		embed => { post, "/deskcite/embed", none },
		agents => { get, "/deskcite/agents", none },
		schedules => { get, "/deskcite/agents/schedules", none },
		tasks => { post, "/deskcite/agents/tasks", json },
		schedule => { post, "/deskcite/agents/schedule", json },
		refresh => { post, "/auth/refresh", none },
		logout => { post, "/auth/logout", none } }.

status(C) ->
	call(C, status, #{}).
similar(C, A) ->
	call(C, similar, A).
ask(C, A) ->
	call(C, ask, A).
rate(C, A) ->
	call(C, rate, A).
question(C, Id) ->
	call(C, question, #{ <<"id">> => Id }).
create_question(C, A) ->
	call(C, create_question, A).
search(C, A) ->
	call(C, search, A).
search_graph(C, A) ->
	call(C, search_graph, A).
document(C, Path) ->
	call(C, document, #{ <<"path">> => Path }).
import_source(C, A) ->
	call(C, import_source, A).
embed(C) ->
	call(C, embed, #{}).
agents(C) ->
	call(C, agents, #{}).
schedules(C) ->
	call(C, schedules, #{}).
tasks(C, A) ->
	call(C, tasks, A).
schedule(C, A) ->
	call(C, schedule, A).
logout(C) ->
	call(C, logout, #{}).

%% The caller owns credential storage and event lifetimes. No automatic replay.
refresh(C) ->
	case call(C, refresh, #{}) of
		{ ok, #{ body := #{ <<"access_token">> := Token } } = Response } ->
			{ ok, with_token(C, Token), Response };
		{ error, _ } = Error ->
			Error
	end.

call(#{ transport := Transport, token := Token }, Operation, Args) when is_map(Args) ->
	{ Method, Prefix, Kind } = maps:get(Operation, operations()),
	{ Path, Body } = route(Prefix, Kind, Args),
	case Transport(Method, Path, Body, Token) of
		{ ok, Status, Headers, Bytes } when Status >= 200, Status < 300 ->
			Decoded = case Kind of
				document ->
					Bytes;
				_ ->
					json:decode(Bytes)
			end,
			{ ok, #{ status => Status, headers => Headers, body => Decoded } };
		{ ok, Status, Headers, Bytes } ->
			{ error, #{ status => Status, headers => Headers, body => Bytes } };
		{ error, Reason } ->
			{ error, { transport, Reason } }
	end.

route(Path, none, Args) when map_size(Args) =:= 0 ->
	{ Path, undefined };
route(Path, json, Args) ->
	{ Path, Args };
route(Prefix, id, #{ <<"id">> := Id }) ->
	true = is_binary(Id) andalso byte_size(Id) > 0,
	{ Prefix ++ uri_string:quote(binary_to_list(Id)), undefined };
route(Prefix, document, #{ <<"path">> := Path }) ->
	%% Accept the service's already-encoded source URL path verbatim. Never
	%% accept an origin, query, fragment, traversal, or an unrelated route.
	Prefix = "/deskcite/documents/",
	P = unicode:characters_to_list(Path),
	true = lists:prefix(Prefix, P),
	#{ path := P } = uri_string:parse(P),
	Decoded = uri_string:unquote(P),
	true = lists:all(fun(S) ->
		S =/= "." andalso S =/= ".."
	end,
		string:split(Decoded, "/", all)),
	true = lists:all(fun(C) ->
		C > 32
	end, P),
	true = lists:all(fun(C) ->
		C >= 32 andalso C =/= 127 andalso C =/= $\\
	end, Decoded),
	{ P, undefined }.

%% Open one mesgd connection for this credential. The process is linked to
%% its caller, so put it under an application supervisor for recovery.
events(#{ origin := Origin, token := Token }, Handler, Options) when is_function(Handler, 1) ->
	Url = "wss://" ++ lists:nthtail(length("https://"), Origin) ++ "/deskcite/events",
	Connection = mesgd:connect(Url, Options#{ token => Token }),
	ok = mesgd:on(Connection, <<"*">>, Handler),
	Connection.

close_events(Connection) ->
	mesgd:close(Connection).
