implement Readtree;

include "read-tree.m";

include "sys.m";
	sys: Sys;

include "draw.m";

include "tables.m";
	tables: Tables;
Strhash: import Tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "utils.m";
	utils: Utils;
error, readsha1file, sha2string, SHALEN: import utils;


include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;	

include "string.m";
	stringmodule: String;
splitl: import stringmodule;	

index: ref Index;

repopath: string;

debug: int;

init(arglist: list of string, deb: int)
{
	sys = load Sys Sys->PATH;	
	utils = load Utils Utils->PATH;
	bufio = load Bufio Bufio->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	tables = load Tables Tables->PATH;
	stringmodule = load String String->PATH;

	repopath = hd arglist;
	debug = deb;
	utils->init(arglist, debug);

}

readtree(path: string)
{
#	index = Index.new(REPOPATH, "",debug);
	readtreefile(path, "");
#	index.writeindex(INDEXPATH);
}

readtreefile(path: string, basename: string)
{
	(filetype, filesize, buf) := readsha1file(path);

	ibuf := bufio->aopen(buf);
	while((s := ibuf.gets('\0')) != ""){
		(modestr, filepath) := splitl(s, " ");
		sys->print("==>filepath %s\n", filepath);
		mode := stringmodule->toint(modestr,10).t0;
		if(isdir(mode)){
			sha1 := array[SHALEN] of byte;
			ibuf.read(sha1, SHALEN);
			readtreefile(sha2string(sha1), basename + filepath + "/");	
			continue;
		}
		entry := Entry.new();
		entry.name = basename + filepath;
		ibuf.read(entry.sha1, SHALEN);

		sys->print("=>entry=>%o %s==>%s\n",mode, entry.name, sha2string(entry.sha1));
#		index.addentry(entry);
	}
}



usage()
{
	error("usage: read-tree <tree-sha>\n");
	exit;
}

isdir(mode: int): int
{
	return mode & 16384;
}
