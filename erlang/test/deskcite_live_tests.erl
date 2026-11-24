-module(deskcite_live_tests).
-export([ run/0 ]).
run() ->
	Root = filename:absname("."),
	true = code:add_patha(filename:join(os:getenv("HOME"), ".beamer")),
	true = code:add_patha(filename:join([ Root, "erlang", "ebin" ])),
	CA = os:getenv("DS_TEST_CA"),
	{ ok, PEM } = file:read_file(CA),
	Certs = [ DER || { 'Certificate', DER, not_encrypted } <- public_key:pem_decode(PEM) ],
	ok = public_key:cacerts_load(CA),
	C = deskcite:new(os:getenv("DS_TEST_URL"), <<"test-bearer">>, #{ cacerts => Certs }),
	maps:foreach(fun(Op, { _, _, Kind }) ->
		case lists:member(Op, [ refresh, question, document ]) of
			true ->
				ok;
			false ->
				Args = case Kind of
					json ->
						#{ <<"text">> => <<"café & ?"/utf8>>, <<"q">> => <<"test">>, <<"action">> => <<"calendar">> };
					_ ->
						#{}
				end,
				{ ok, #{ body := #{ <<"ok">> := true } } } = deskcite:call(C, Op, Args)
		end
	end, deskcite:operations()),
	{ ok, #{ body := #{ <<"path">> := Path } } } = deskcite:question(C, <<"id/ ?#">>),
	true = lists:suffix("id%2F%20%3F%23", binary_to_list(Path)),
	{ ok, #{ body := <<0, 255, 10>> } } = deskcite:document(C, <<"/deskcite/documents/a%20b.pdf">>),
	{ error, #{ status := 503, body := <<"unavailable">> } } = deskcite:similar(C, #{ <<"text">> => <<"__error__">> }),
	{ error, #{ status := 302 } } = deskcite:similar(C, #{ <<"text">> => <<"__redirect__">> }),
	{ ok, Next, _ } = deskcite:refresh(C),
	{ ok, #{ body := #{ <<"credential">> := <<"rotated">> } } } = deskcite:status(Next),
	Parent = self(),
	Connection = deskcite:events(Next, fun(M) ->
		Parent ! { event, M }
	end,
		#{ key_file => os:getenv("DS_TEST_KEY_FILE") }),
	receive
		{ event, #{ <<"type">> := <<"import.done">> } } ->
			ok
	after 5000 ->
			error(event_missing)
	end,
	ok = deskcite:close_events(Connection),
	%% Register and invoke through the actual agent framework registry.
	{ ok, Registry } = agent_tools:start_link(),
	ok = deskcite_agent:install(Next, #{ allow_writes => true }),
	ok = deskcite_agent:install(Next),
	undefined = agent_tools:get(<<"deskcite_remote_import_source">>),
	{ ok, #{ <<"ok">> := true } } = agent_tools:invoke(<<"deskcite_remote_status">>, #{}),
	ok = gen_server:stop(Registry),
	io:format("Erlang: HTTPS routes, bytes, errors, rotation, WSS, agent registration passed~n").
