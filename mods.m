
Mods: module
{
	PATH: con "/dis/git/mods.dis";

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
	readdir: Readdir;
	tables: Tables;
	stringmod: String;
	styx: Styx;
	styxservers: Styxservers;

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
	readtreemod: Readtree;
	utils: Utils;
	writetreemod: Writetree;

	repopath: string;
	debug: int;
	index: ref Gitindex->Index;
	shatable: ref Tables->Strhash[ref Gitfs->Shaobject];

	init: fn(repopath: string, debug: int);
};

