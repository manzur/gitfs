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
SHALEN, readsha1file, string2path, sha2string, INDEXPATH: import utils;

include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;	

include "string.m";
	stringmodule: String;
splitl: import stringmodule;	

index: ref Index;

REPOPATH: string;


init(args: list of string)
{
	sys = load Sys Sys->PATH;	
	utils = load Utils Utils->PATH;
	bufio = load Bufio Bufio->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	tables = load Tables Tables->PATH;
	stringmodule = load String String->PATH;

	REPOPATH = hd args;
	utils->init(REPOPATH);
	if(len args != 2)
		usage();

	readtree(hd (tl args));
}

readtree(path: string)
{
	index = Index.new(REPOPATH);
	readtreefile(path, "");
	index.writeindex(INDEXPATH);
}

readtreefile(path: string, basename: string)
{
	(filetype, filesize, buf) := readsha1file(path);

	ibuf := bufio->aopen(buf);
	while((s := ibuf.gets('\0')) != ""){
		(modestr, filepath) := splitl(s, " ");
		mode := stringmodule->toint(modestr,10).t0;
		if(isdir(mode)){
			sha1 := array[SHALEN] of byte;
			ibuf.read(sha1, SHALEN);
			readtreefile(sha2string(sha1), basename + filepath + "/");	
			continue;
		}
		entry := Entry.new();
		entry.mode = mode;
		entry.namelen = len basename + len filepath;
		entry.name = basename + filepath;
		ibuf.read(entry.sha1, SHALEN);

#FIXME: find better solution to find length of the file
		(filetype, filesize, buf) = readsha1file(sha2string(entry.sha1));
		entry.length = big len buf;
		index.addentry(entry);
	}
}



usage()
{
	sys->fprint(sys->fildes(2), "usage: read-tree <tree-sha>\n");
	exit;
}

isdir(mode: int): int
{
	return mode & 16384;
}
