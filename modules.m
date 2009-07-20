
Modules: module
{
	arg: Arg;
	bufio: Bufio;
	daytime: Daytime;
	deflatefilter: Filter;
	env: Env;
	filepat: Filepat;
	inflatefilter: Filter;
	keyring: Keyring;
	lists: Lists;
	readdir: Readdir;
	stringmod: String;
	styx: Styx;
	styxservers: Styxservers;
	sys: Sys;
	tables: Tables;
	workdir: Workdir;

	gitindex: Gitindex;
	repo: Repo;
	utils: Utils;

	debug: int;
	mntpt, repopath: string;

	init: fn(repopath, mntpt: string, debug: int);
};

