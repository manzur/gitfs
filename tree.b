implement Treemod;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
splitl, toint: import stringmod;	
error, readsha1file, sha2string, SHALEN: import utils;

mods: Mods;

init(m: Mods)
{
	mods = m;
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
