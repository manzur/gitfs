implement Checkoutmod;

include "sys.m";
	sys: Sys;
sprint: import sys;	

include "bufio.m";
Iobuf: import Bufio;

include "daytime.m";

include "draw.m";

include "string.m";
	stringmod: String;

include "tables.m";
	tables: Tables;
Table, Strhash: import tables;

include "commit.m";
	commitmod: Commitmod;
readcommit: import commitmod;	

include "fs.m";
Shaobject: import Fs;

include "gitindex.m";
	gitindex: Gitindex;
Entry, Index: import gitindex;

include "tree.m";
	treemod: Treemod;
readtree: import treemod;	

include "path.m";
	pathmod: Pathmod;
dirname, makeabsentdirs, string2path: import pathmod;	

include "utils.m";
	utils: Utils;
cutprefix, error, isunixdir, readsha1file, sha2string, string2sha: import utils;	

include "checkout.m";

shatable: ref Strhash[ref Shaobject];
commit, mntpt, repopath: string;
index: ref Index;	

init(arglist: list of string, debug: int, ind: ref Index, shat: ref Strhash[ref Shaobject])
{
	sys = load Sys Sys->PATH;
	stringmod = load String String->PATH;
	tables = load Tables Tables->PATH;

	commitmod = load Commitmod Commitmod->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	pathmod = load Pathmod Pathmod->PATH;
	treemod = load Treemod Treemod->PATH;
	utils = load Utils Utils->PATH;

	commitmod->init(arglist, debug);
	index = Index.new(arglist, debug);
	index.header = ind.header;
	index.header.entriescnt = 0;
	pathmod->init(repopath);
	treemod->init(arglist, debug);
	utils->init(arglist, debug);

	repopath = hd arglist;
	arglist = tl arglist;
	mntpt = hd arglist; 
	shatable = shat;
}

checkout(sha1: string): ref Index
{
	commit := readcommit(sha1);
	pt := index;
	index = index.removeentries();
	checkouttree(repopath[:len repopath-1], commit.treesha1);
	
	return index;
}

checkouttree(path, treesha1: string)
{
	tree := readtree(treesha1);
	while(tree.children != nil){
		(mode, filepath, sha1) := hd tree.children;
		tree.children = tl tree.children;
		fullpath := sprint("%s/%s", path, filepath);
		if(isunixdir(mode)){
			sys->create(fullpath, Sys->OREAD, 8r755|Sys->DMDIR);
			checkouttree(fullpath, sha1);
			continue;
		}
		checkoutblob(fullpath, sha1);
	}
}

checkoutblob(path, sha1: string)
{
	fd := sys->create(path, Sys->OWRITE, 8r644);
	if(fd == nil){
		makeabsentdirs(dirname(path));
		if((fd = sys->create(path, Sys->OWRITE, 8r644)) == nil){
			error(sprint("couldn't create file(%s): %r\n", path));
			return;
		}
	}

	name := cutprefix(repopath, path);
	flags := len name & 16r0fff;
	shaobject := shatable.find(sha1);
	if(shaobject == nil){
		dirstat := sys->stat(string2path(sha1)).t1;
		shaobject = ref Shaobject(ref dirstat, nil, sha1, "blob", nil);
		shatable.add(string sha1, shaobject);
	}
	e := ref Entry(shaobject.dirstat.qid, string2sha(sha1), flags, name);
	index.addentry(e);
	index.header.entriescnt++;
	(nil, nil, buf) := readsha1file(sha1);
	cnt := sys->write(fd, buf, len buf);
	if(cnt != len buf){
		error(sprint("error occured while checkout blob file(%s): %r\n", sha1));
	}
	(ret, dirstat) := sys->stat(path);
	dirstat.qid = shaobject.dirstat.qid;
	shaobject.dirstat = ref dirstat;
}




