%% Remote Deskcite tools for the agent framework. Run in a separate BEAM from
%% the Deskcite server, which already has its own deskcite_agent module.
-module(deskcite_agent).
-export([ install/1, install/2, tools/2, chat/2 ]).

install(Client) ->
	install(Client, #{}).

install(Client, Options) ->
	%% Remove prior registrations so reinstalling without write permission
	%% actually withdraws the optional product tools.
	lists:foreach(fun(#{ name := Name }) ->
		ok = agent_tools:unregister(Name)
	end, tools(Client, #{ allow_writes => true })),
	lists:foreach(fun(#{ name := Name, description := Description,
		schema := Schema, invoke := Invoke }) ->
		ok = agent:register_tool(Name, Description, Schema, Invoke)
	end, tools(Client, Options)),
	ok.

%% A provider allows the host to rotate credentials without reinstalling tools.
tools(ClientOrProvider, Options) ->
	Read = [
		{ status, <<"Read Deskcite knowledge counts.">>, #{} },
		{ similar, <<"Find stored answers with source citations. Distance is a ranking signal.">>,
			#{ <<"text">> => <<"string; required">>, <<"n">> => <<"integer 1..100; optional">> } },
		{ ask, <<"Retrieve the nearest stored answer; does not generate an answer.">>,
			#{ <<"text">> => <<"string; required">> } },
		{ question, <<"Retrieve a stored question and its source citation.">>,
			#{ <<"id">> => <<"UUID; required">> } },
		{ search, <<"Search source documents in the erag index.">>,
			#{ <<"q">> => <<"string; required">>, <<"types">> => <<"string; optional">>,
				<<"document">> => <<"string; optional">> } },
		{ search_graph, <<"Search the document graph.">>,
			#{ <<"q">> => <<"string; required">>, <<"mode">> => <<"string; optional">>,
				<<"hop">> => <<"integer; optional">> } } ],
	Write = case maps:get(allow_writes, Options, false) of
		false ->
			[];
		true ->
			[
				{ import_source, <<"Queue a source import. Accepted does not mean indexed. Do not retry blindly.">>,
					#{ <<"url">> => <<"URL; or use name and content">>, <<"name">> => <<"filename">>,
						<<"content">> => <<"file content">>, <<"encoding">> => <<"utf8 or base64">> } },
				{ embed, <<"Queue embedding of stored questions missing vectors.">>, #{} },
				{ rate, <<"Set shared search feedback for one query and answer.">>,
					#{ <<"id">> => <<"UUID; required">>, <<"text">> => <<"original query; required">>,
						<<"vote">> => <<"up, down, or clear; required">> } } ]
	end,
	[ tool(ClientOrProvider, Spec) || Spec <- Read ++ Write ].

tool(Provider, { Operation, Description, Schema }) ->
	#{ name => <<"deskcite_remote_", (atom_to_binary(Operation))/binary>>,
		description => Description, schema => Schema,
		invoke => fun(Args) ->
			Client = case is_function(Provider, 0) of
				true ->
					Provider();
				false ->
					Provider
			end,
			case deskcite:call(Client, Operation, Args) of
				{ ok, #{ body := Body } } ->
					{ ok, Body };
				{ error, _ } = Error ->
					Error
			end
		end }.

chat(Client, Prompt) ->
	ok = install(Client),
	agent:chat(iolist_to_binary([
		<<"Use Deskcite tools for stored knowledge. Cite returned paths and headings. "
			"Do not invent citations or treat distance as confidence. "
			"Report missing evidence. Follow the application's disclosure policy.\n\n">>, Prompt ])).
