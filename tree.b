implement Treemod;

include "sys.m";
	sys: Sys;
sprint: import sys;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;		

include "lists.m";
	lists: Lists;

include "string.m";
	stringmod: String;
splitl, toint: import stringmod;	

include "tables.m";
Strhash: import Tables;

include "utils.m";
	utils: Utils;
error, readsha1file, sha2string, SHALEN: import utils;

include "tree.m";

mntpt, repopath: string;

init(arglist: list of string, debug: int)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	lists = load Lists Lists->PATH;	
	stringmod = load String String->PATH;

	utils = load Utils Utils->PATH;
	utils->init(arglist, debug);

	repopath = hd arglist;
	arglist = tl arglist;
	mntpt = hd arglist;
}

readtree(sha1: string): ref Tree
{
	sys->print("reading tree %s\n", sha1);
	(filetype, filesize, filebuf) := readsha1file(sha1);
	if(filetype != "tree"){
		error(sprint("%s is not tree\n", sha1));
		return nil;
	}

	return readtreebuf(sha1, filebuf);
}

readtreebuf(sha1: string, filebuf: array of byte): ref Tree
{	
	children: list of (int, string, string);
	ibuf := bufio->aopen(filebuf);
	while((s := ibuf.gets('\0')) != ""){
		(mode, path) := splitl(s, " ");
		sha1 := array[SHALEN] of byte;
		cnt := ibuf.read(sha1, len sha1);
		path = path[1:len path-1];
		shastr := sha2string(sha1);
		children = (toint(mode, 8).t0, path, shastr) :: children;
	}
	
	return ref Tree(sha1, reverse(children));
}

#FIXME: should use lists->reverse which need ref T, and doesn't work with tuples
reverse(l: list of (int, string, string)): list of (int, string, string)
{
	ret: list of (int, string, string);
	while(l != nil){
		ret = hd l :: ret;
		l = tl l;
	}

	return ret;
}
