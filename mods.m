
Mods: module
{
	PATH: con "/dis/git/mods.dis";

	#System modules
	sys: Sys;
	bufio: Bufio;
	crcmod: Crc;
	daytime: Daytime;
	draw: Draw;
	deflatefilter: Filter;
	env: Env;
	gwd: Workdir;
	inflatefilter: Filter;
	keyring: Keyring;
	lists: Lists;
	names: Names;
	readdir: Readdir;
	tables: Tables;
	stringmod: String;
	styx: Styx;
	styxservers: Styxservers;

	#Gitfs modules
	catfilemod: Catfile;
	checkoutmod: Checkoutmod;
	commitmod: Commitmod;
	committree: Committree;
	configmod: Configmod;
	gitindex: Gitindex;
	log: Log;
	packmod: Packmod;
	pathmod: Pathmod;
	repo: Repo;
	treemod: Treemod;
	utils: Utils;

	debug: int;
	repopath: string;
	shatable: ref Tables->Strhash[ref Gitfs->Shaobject];

	init: fn(repopath: string, debug: int);
};

