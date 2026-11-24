%% Raw HTTPS adapter. Keeps HTTP status, headers, and non-JSON failures intact.
-module(deskcite_http).
-export([ origin/1, transport/2 ]).

origin(Value) ->
	Origin = unicode:characters_to_list(Value),
	Parsed = uri_string:parse(Origin),
	#{ scheme := "https", host := Host } = Parsed,
	true = Host =/= "",
	true = lists:all(fun(K) ->
		not maps:is_key(K, Parsed)
	end, [ userinfo, query, fragment ]),
	true = lists:member(maps:get(path, Parsed, ""), [ "", "/" ]),
	string:trim(Origin, trailing, "/").

transport(Origin, Options) ->
	#{ host := Host } = uri_string:parse(Origin),
	Timeout = maps:get(timeout, Options, 30000),
	true = is_integer(Timeout) andalso Timeout > 0,
	fun(Method, Path, Body, Token) ->
		{ ok, _ } = application:ensure_all_started(inets),
		{ ok, _ } = application:ensure_all_started(ssl),
		CACerts = maps:get(cacerts, Options, public_key:cacerts_get()),
		Headers = [ { "accept", "application/json" },
			{ "authorization", "Bearer " ++ binary_to_list(Token) } ],
		Request = case { Method, Body } of
			{ get, undefined } ->
				{ Origin ++ Path, Headers };
			{ post, undefined } ->
				{ Origin ++ Path, Headers, "application/json", <<>> };
			{ post, _ } ->
				{ Origin ++ Path, Headers, "application/json", json:encode(Body) }
		end,
		HTTPOptions = [ { autoredirect, false }, { timeout, Timeout }, { connect_timeout, Timeout },
			{ ssl, [ { verify, verify_peer }, { server_name_indication, Host }, { cacerts, CACerts },
				{ customize_hostname_check,
					[ { match_fun, public_key:pkix_verify_hostname_match_fun(https) } ] } ] } ],
		case httpc:request(Method, Request, HTTPOptions, [ { body_format, binary } ]) of
			{ ok, { { _, Status, _ }, ResponseHeaders, Bytes } } ->
				{ ok, Status, ResponseHeaders, Bytes };
			{ error, Reason } ->
				{ error, Reason }
		end
	end.
