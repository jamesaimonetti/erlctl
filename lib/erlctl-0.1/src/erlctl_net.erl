-module (erlctl_net).
-export([start_networking/1]).

-include_lib("erlctl/include/internal.hrl").

start_networking(Opts) ->
  case proplists:get_value(names,Opts,?DEF_NAMES) of
    long -> Names = longnames;
    short -> Names = shortnames
  end,
  CN = cli_nodename(Opts),
  case net_kernel:start([CN,Names]) of
    {ok,_} ->
      ok;
    {error,_} ->
      erlctl_err:networking_failure()
  end,
  SvrNode = svr_nodename(Opts),
  {ok,[{target,SvrNode} | Opts]}.

is_longname(Name) -> lists:member($.,Name).

make_hostname(short,auto) ->
  {ok,HN} = inet:gethostname(),
  HN;
make_hostname(short,Manual) ->
  Manual;
make_hostname(long,auto) ->
  {ok,HN} = inet:gethostname(),
  DN = inet_db:res_option(domain), % Networking Must Be Running Here!
  HN ++ "." ++ DN;
make_hostname(long,Manual) ->
  case is_longname(Manual) of
    true ->
      Manual;
    false ->
      DN = inet_db:res_option(domain),
      Manual ++ "." ++ DN % Networking Must Be Running Here!
  end.

get_hostname(Opts) ->
  NmOpt = proplists:get_value(names,Opts,?DEF_NAMES),
  HnOpt = proplists:get_value(host,Opts,auto),
  HostName = make_hostname(NmOpt,HnOpt),
  case {NmOpt,is_longname(HostName)} of
    {short,true} ->
      io:format(standard_error,
        "Warning: using name with dot as a shortname (~p)~n",[HostName]),
        erlctl_err:networking_failure();
    {long,false} ->
      io:format(standard_error,
        "Warning: using name without a dot as a longname (~p)~n",[HostName]),
        erlctl_err:networking_failure();
    _ ->
      ok
  end,
  HostName.

cli_nodename(Opts) ->
  AppName = proplists:get_value(app,Opts),
  list_to_atom(AppName ++ "ctl_" ++ os:getpid()).

svr_nodename(Opts) ->
  case proplists:get_value(fullnode,Opts) of
    undefined ->
      HostName = get_hostname(Opts),
      case proplists:get_value(node,Opts) of
        undefined ->
          NodeName = proplists:get_value(app,Opts);
        NName ->
          NodeName = NName
      end,
      NodeName ++ "@" ++ HostName;
    NodeName ->
      NodeName % FIXME: Verify fully specified node names?
  end.