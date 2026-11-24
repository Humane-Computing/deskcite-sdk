-module(deskcite_tests).
-include_lib("eunit/include/eunit.hrl").

client(Response) ->
	Self = self(),
	deskcite:new("https://example.test", <<"test-bearer">>,
		#{ transport => fun(M, P, B, T) ->
			Self ! { request, M, P, B, T },
			Response
		end }).

manifest_test() ->
	{ ok, Bytes } = file:read_file("api/operations.json"),
	Manifest = json:decode(Bytes),
	Expected = maps:from_list([ { atom_to_binary(Name), #{ <<"method">> => string:uppercase(atom_to_binary(Method)),
		<<"path">> => list_to_binary(Path), <<"kind">> => atom_to_binary(Kind) } } ||
		{ Name, { Method, Path, Kind } } <- maps:to_list(deskcite:operations()) ]),
	?assertEqual(Expected, Manifest).

request() ->
	receive
		{ request, M, P, B, T } ->
			{ M, P, B, T }
	after 1000 ->
			error(no_request)
	end.

product_routes_test() ->
	%% Independently specified paths catch drift between the published API and
	%% the wrapper's dispatch table, including GET-vs-POST and empty bodies.
	Routes = [
		{ status, get, "/deskcite", #{} },
		{ similar, post, "/deskcite/similar", #{ <<"text">> => <<"café"/utf8>> } },
		{ ask, post, "/deskcite/ask", #{ <<"text">> => <<"query">> } },
		{ rate, post, "/deskcite/rate", #{ <<"id">> => <<"id">>, <<"vote">> => <<"up">> } },
		{ create_question, post, "/deskcite/question", #{ <<"question">> => <<"Q?">> } },
		{ search, post, "/deskcite/search", #{ <<"q">> => <<"a & b">>, <<"types">> => <<"section">> } },
		{ search_graph, post, "/deskcite/search/graph", #{ <<"hop">> => 2 } },
		{ import_source, post, "/deskcite/import", #{ <<"url">> => <<"https://source.test">> } },
		{ embed, post, "/deskcite/embed", #{} },
		{ agents, get, "/deskcite/agents", #{} },
		{ schedules, get, "/deskcite/agents/schedules", #{} },
		{ tasks, post, "/deskcite/agents/tasks", #{ <<"action">> => <<"cancel_queued">> } },
		{ schedule, post, "/deskcite/agents/schedule", #{ <<"action">> => <<"calendar">> } },
		{ logout, post, "/auth/logout", #{} } ],
	C = client({ ok, 202, [], <<"{\"ok\":true,\"status\":\"queued\"}">> }),
	lists:foreach(fun({ Op, Method, Path, Args }) ->
		{ ok, #{ status := 202, body := #{ <<"status">> := <<"queued">> } } } = deskcite:call(C, Op, Args),
		{ Method, Path, Body, <<"test-bearer">> } = request(),
		Expected = case lists:member(Op, [ status, embed, agents, schedules, logout ]) of
			true ->
				undefined;
			false ->
				Args
		end,
		?assertEqual(Expected, Body)
	end, Routes).

identifiers_test() ->
	C = client({ ok, 200, [], <<"{}">> }),
	{ ok, _ } = deskcite:question(C, <<"id/with ?#">>),
	?assertEqual({ get, "/deskcite/question/id%2Fwith%20%3F%23", undefined, <<"test-bearer">> }, request()).

document_test() ->
	C = client({ ok, 200, [ { "content-type", "application/pdf" } ], <<0, 255, 10>> }),
	{ ok, #{ body := <<0, 255, 10>>, headers := [ { "content-type", "application/pdf" } ] } } =
	deskcite:document(C, <<"/deskcite/documents/folder/a%20b.pdf">>),
	?assertEqual({ get, "/deskcite/documents/folder/a%20b.pdf", undefined, <<"test-bearer">> }, request()).

document_restrictions_test() ->
	C = client({ ok, 200, [], <<>> }),
	lists:foreach(fun(Path) ->
		?assertError({ badmatch, false }, deskcite:document(C, Path))
	end, [ <<"https://other.test/private">>, <<"//other.test/private">>,
		<<"/deskcite/documents/%2e%2e/private">>, <<"/deskcite/documents/a%0d%0ab">>,
		<<"/deskcite/documents/a%5cb">> ]),
	?assertError({ badmatch, _ }, deskcite:document(C, <<"/deskcite/documents/a?token=x">>)).

errors_test() ->
	lists:foreach(fun(Status) ->
		C = client({ ok, Status, [ { "retry-after", "3" } ], <<"<html>unavailable</html>">> }),
		?assertEqual({ error, #{ status => Status, headers => [ { "retry-after", "3" } ],
			body => <<"<html>unavailable</html>">> } }, deskcite:status(C)),
		request()
	end, [ 301, 400, 401, 403, 404, 409, 429, 503 ]),
	C = client({ error, timeout }),
	?assertEqual({ error, { transport, timeout } }, deskcite:embed(C)),
	request(),
	receive
		{ request, _, _, _, _ } ->
			error(retried_mutation)
	after 10 ->
			ok
	end.

rotation_test() ->
	C = client({ ok, 200, [], <<"{\"access_token\":\"replacement\"}">> }),
	{ ok, New, _ } = deskcite:refresh(C),
	?assertEqual({ post, "/auth/refresh", undefined, <<"test-bearer">> }, request()),
	deskcite:status(New),
	?assertEqual({ get, "/deskcite", undefined, <<"replacement">> }, request()),
	?assertEqual(<<"test-bearer">>, maps:get(token, C)).

origin_test() ->
	?assertEqual("https://example.test:443", deskcite_http:origin("https://example.test:443/")),
	lists:foreach(fun(Url) ->
		?assertError({ badmatch, _ }, deskcite:new(Url, <<"token">>))
	end, [ "http://example.test", "https://user@example.test", "https://example.test/path",
		"https://example.test/?secret=x", "https://example.test/#fragment" ]),
	?assertError({ badmatch, false }, deskcite:new("https://example.test", <<"token\r\nheader">>)).

agent_tools_test() ->
	C = client({ ok, 200, [], <<"{\"ok\":true,\"rows\":[]}">> }),
	Tools = deskcite_agent:tools(fun() ->
		deskcite:with_token(C, <<"rotated">>)
	end, #{}),
	?assertEqual(6, length(Tools)),
	[ Search ] = [ T || T = #{ name := <<"deskcite_remote_similar">> } <- Tools ],
	?assertEqual({ ok, #{ <<"ok">> => true, <<"rows">> => [] } },
		(maps:get(invoke, Search))(#{ <<"text">> => <<"query">> })),
	?assertEqual({ post, "/deskcite/similar", #{ <<"text">> => <<"query">> }, <<"rotated">> }, request()),
	?assertEqual(9, length(deskcite_agent:tools(C, #{ allow_writes => true }))).
