implement Difftree;

include "diff-tree.m";

include "sys.m";
	sys: Sys;
sprint: import sys;

include "arg.m";
	arg: Arg;

include "tables.m";
Strhash: import Tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "utils.m";
	utils: Utils;
debugmsg, error, SHALEN, equalshas, sha2string, exists,readsha1file, isdir: import utils;

include "string.m";
	stringmodule: String;

include "gitindex.m";
	gitindex: Gitindex;
Entry: import gitindex;	

recursive: int;

REPOPATH: string;

init(args: list of string, debug: int)
{
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;
	bufio = load Bufio Bufio->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	stringmodule = load String String->PATH;

	REPOPATH = hd args;
	utils->init(REPOPATH, debug);

	if(len args < 3)
		usage();
	
	tree1, tree2: string;

	args = tl args;

	if(hd args == "-r") 
	{
		recursive = 1;
		args = tl args;
	}
	tree1 = hd args;
	tree2 = hd (tl args);
	recursive = 1;
	
	difftree(tree1, tree2, "");
}


difftree(tree1, tree2: string, basename: string): int
{
	(filetype1, nil, buf1) := readsha1file(tree1);		
	(filetype2, nil, buf2) := readsha1file(tree2);

	if(filetype1 != "tree" || filetype1 != filetype2){
		error("files aren't tree\n");
	}

	
	return difftreefile(buf1, buf2, basename);
}

comparetrees(buf1, buf2: array of byte, basename: string): int
{
	entry1 := extractentry(buf1);
	entry2 := extractentry(buf2);

	name1 := basename + entry1.name;
	name2 := basename + entry2.name;
	
	if(name1 < name2){
		showfile("-", buf1, basename);
		return -1;
	}

	if(name1 > name2){
		showfile("+", buf2, basename);
		return 1;
	}

	if(equalshas(entry1.sha1, entry2.sha1) && entry1.mode == entry2.mode){
		return 0;
	}

	if(isdir(entry1.mode) != isdir(entry2.mode)){
		showfile("-", buf1, basename);
		showfile("+", buf2, basename);
		return 0;
	}
	
	if(recursive && isdir(entry1.mode)){
		return difftree(sha2string(entry1.sha1), sha2string(entry2.sha1),basename + entry1.name + "/");
	}

	# '\n' is '\0' in Linus's diff-tree
	sys->print("*%o->%o %s->%s %s%s\n", entry1.mode, entry2.mode, sha2string(entry1.sha1), sha2string(entry2.sha1), basename, name1);
	return 0;
}

extractentry(buf: array of byte): ref Entry
{
	entry := Entry.new();

	ibuf := bufio->aopen(buf);
	s := ibuf.gets('\0');
	(mode, name) := stringmodule->splitl(s, " ");
#Removeing ' '  and '\0' from the name
	name = name[1:len name -1];
	entry.name = name;
	entry.mode = stringmodule->toint(mode,8).t0;
	ibuf.read(entry.sha1, SHALEN);

	return entry;
}

showfile(prefix: string, treebuf: array of byte, basename: string)
{
	entry := extractentry(treebuf);
	if(recursive && isdir(entry.mode)){
		(filetype, filesize, tree) := readsha1file(sha2string(entry.sha1));
		if(filetype != "tree"){
			error(sprint("corrupt tree sha %s\n", sha2string(entry.sha1)));
			return;
		}
		showtree(prefix, tree, basename + entry.name + "/");
	}
	sys->print("%s%o %s %s%s\n", prefix, entry.mode, sha2string(entry.sha1), basename, entry.name);
}

showtree(prefix: string, treebuf: array of byte, basename: string)
{
	while(len treebuf > 0)	
	{
		showfile(prefix, treebuf, basename);
		treebuf = updatetree(treebuf);
	}
}

difftreefile(buf1, buf2: array of byte, basename: string): int
{
	while(len buf1 > 0 && len buf2 > 0){
		case comparetrees(buf1, buf2, basename){
			-1 => buf1 = updatetree(buf1);
			0  => buf1 = updatetree(buf1); buf2 = updatetree(buf2);
			1  => buf2 = updatetree(buf2);
		}
	}
	while(len buf1 > 0){
		showfile("-", buf1, basename);
		buf1 = updatetree(buf1);
	}

	while(len buf2 > 0){
		showfile("+", buf2, basename);
		buf2 = updatetree(buf2);
	}

	return 0;
}

updatetree(tree: array of byte): array of byte
{
	entry := Entry.new();
	ibuf := bufio->aopen(tree);
	offset := ibuf.offset();
	s := ibuf.gets('\0');
	(name, mode) := stringmodule->splitl(s, " ");
	entry.name = name;
	entry.mode = stringmodule->toint(mode, 10).t0;
	sha1 := array[SHALEN] of byte;
	ibuf.read(entry.sha1, SHALEN);
	offset = ibuf.offset() - offset;

	return tree[int offset:];
}

usage()
{
	error("usage: diff-tree <tree-sha1> <tree-sha2>\n");
	exit;
}

