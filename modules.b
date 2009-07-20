implement Modules;

include "sys.m";

include "arg.m";

include "bufio.m";
Iobuf: import bufio;

include "daytime.m";
include "env.m";
include "filepat.m";
include "filter.m";
include "keyring.m";
include "lists.m";
include "readdir.m";
include "string.m";
include "styx.m";
include "styxservers.m";

include "tables.m";
Strhash: import tables;

include "workdir.m";

include "gitindex.m";
include "repo.m";
include "utils.m";

include "modules.m";

init(rpath, mpt: string, deb: int)
{
	repopath = rpath;
	mntpt = mpt;
	debug = deb;

	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	daytime = load Daytime Daytime->PATH;
	deflatefilter = load Filter Filter->DEFLATEPATH;
	env = load Env Env->PATH;
	filepat = load Filepat Filepat->PATH;
	inflatefilter = load Filter Filter->INFLATEPATH;
	keyring = load Keyring Keyring->PATH;
	lists = load Lists Lists->PATH;
	readdir = load Readdir Readdir->PATH;
	stringmod = load String String->PATH;
	styx = load Styx Styx->PATH;
	styxservers = load Styxservers Styxservers->PATH;
	sys = load Sys Sys->PATH;
	tables = load Tables Tables->PATH;
	workdir = load Workdir Workdir->PATH;

	gitindex = load Gitindex Gitindex->PATH;
	repo = load Repo Repo->PATH;
	utils = load Utils Utils->PATH;
}
