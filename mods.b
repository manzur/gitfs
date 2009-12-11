implement Mods;

#System modules 
include "sys.m";

include "bufio.m";
Iobuf: import bufio;

include "crc.m";
CRCstate: import crcmod;

include "daytime.m";
include "draw.m";
include "env.m";
include "filter.m";
include "keyring.m";
include "lists.m";
include "names.m";
include "readdir.m";

include "gittables.m";
Table, Strhash: import tables;

include "string.m";
include "styx.m";
include "styxservers.m";
include "workdir.m";

#Gitfs modules
include "cat-file.m";
include "checkout.m";
include "commit.m";
include "commit-tree.m";
include "config.m";
include "gitfs.m";
include "gitindex.m";
include "log.m";
include "pack.m";
include "path.m";
include "repo.m";
include "tree.m";
include "utils.m";

include "mods.m";

init(path: string, deb: int)
{
	repopath = path;
	debug = deb;

	#sys modules load
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	crcmod = load Crc Crc->PATH;
	daytime = load Daytime Daytime->PATH;
	deflatefilter = load Filter Filter->DEFLATEPATH;
	env = load Env Env->PATH;
	gwd = load Workdir Workdir->PATH;
	inflatefilter = load Filter Filter->INFLATEPATH;
	keyring = load Keyring Keyring->PATH;
	lists = load Lists Lists->PATH;
	names = load Names Names->PATH;
	readdir = load Readdir Readdir->PATH;
	tables = load Tables Tables->PATH;
	stringmod = load String String->PATH;
	styx = load Styx Styx->PATH;
	styxservers = load Styxservers Styxservers->PATH;
	
	#Gitfs modules load
	catfilemod = load Catfile Catfile->PATH;
	checkoutmod = load Checkoutmod Checkoutmod->PATH;
	commitmod = load Commitmod Commitmod->PATH;
	committree = load Committree Committree->PATH;
	configmod = load Configmod Configmod->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	log = load Log Log->PATH;
	packmod = load Packmod Packmod->PATH;
	pathmod = load Pathmod Pathmod->PATH;
	repo = load Repo Repo->PATH;
	treemod = load Treemod Treemod->PATH;
	utils = load Utils Utils->PATH;

	#initializitions
	deflatefilter->init();
	inflatefilter->init();
	styx->init();
	styxservers->init(styx);

	repopath = makepathabsolute(path);
}


makepathabsolute(path: string): string
{
	if(path == "" || path[0] == '/') return path;
	
	name := "";
	curpath := gwd->init();
	for(i := 0; i < len path; i++){
		if(path[i] == '/'){
			curpath = resolvepath(curpath, name);
			name = "";
			continue;
		}
		name[len name] = path[i];
	}

	curpath = resolvepath(curpath, name);

	if(curpath != nil && curpath[len curpath - 1] != '/'){
		curpath += "/";
	}

	return curpath;
}

resolvepath(curpath: string, path: string): string
{

	if(curpath == "/") return curpath + path;

	if(path == ".")
		return curpath;

	if(path == ".."){
		oldpath := gwd->init();
		sys->chdir(curpath);
		sys->chdir("..");
		ret := gwd->init();
		sys->chdir(oldpath);
		return ret;
	}

	return curpath + "/" + path;
}

