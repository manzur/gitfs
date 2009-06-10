implement Readtree;

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

Readtree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};


init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;	
	utils = load Utils Utils->PATH;
	bufio = load Bufio Bufio->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	tables = load Tables Tables->PATH;
	stringmodule = load String String->PATH;
	utils->init();
	if(len args != 2)
	{
		usage();
		return;
	}
	readtree(hd (tl args));
}

readtree(path: string)
{
	(filetype, filesize, buf) := readsha1file(path);
	index := Index.new();

	ibuf := bufio->aopen(buf);
	while((s := ibuf.gets('\0')) != "")
	{
		(mode, filepath) := splitl(s, " ");
		entry := Entry.new();
		entry.mode = stringmodule->toint(mode,10).t0;
		entry.namelen = len filepath;
		entry.name = filepath;
		ibuf.read(entry.sha1, SHALEN);
#FIXME: make better solution to find length of the file
		(filetype, filesize, buf) := readsha1file(sha2string(entry.sha1));
		entry.length = big len buf;
		index.addentry(entry);
	}
	index.writeindex(INDEXPATH);
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: read-tree <tree-sha>\n");
}

