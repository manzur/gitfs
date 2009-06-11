implement Updateindex;


include "sys.m";
	sys: Sys;

include "draw.m";

include "tables.m";
	tables: Tables;

Strhash: import tables;

include "gitindex.m";
	gitindex : Gitindex;

include "arg.m";
	arg: Arg;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;
	
include "utils.m";	

include "readdir.m";
	readdir: Readdir;

Index: import gitindex;
INDEXPATH: import Utils;


index: ref Index;

stderr: ref Sys->FD;

Updateindex: module
{
	init : fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	tables = load Tables Tables->PATH;
	readdir = load Readdir Readdir->PATH;

	stderr = sys->fildes(2);
	sys->create("index.lock", Sys->OWRITE | Sys->OEXCL, Sys->DMEXCL | 8r644);
	index = Index.new();
	cnt := index.readindex(INDEXPATH);
	if(cnt < 0)
		return;

	arg = load Arg Arg->PATH;
	arg->init(args);
	while((c := arg->opt()) != 0)
	{
		case c
		{
			'a' =>
				path := arg->arg();
				sys->print("Adding %s\n", path);
				addfile(path);
			'r' =>
				path := arg->arg();
				sys->print("Removing %s\n", path);
				index.rmfile(path);
		}
			
	}
	
	printindex(index);
	sys->print("Writing to index\n");
	index.writeindex("index.lock");

	#renaming index.lock to index
	dirstat := sys->nulldir;
	dirstat.name = INDEXPATH;
	if(sys->wstat("index.lock", dirstat) < 0)
	{
		sys->fprint(sys->fildes(2), "file index.lock can't be renamed to index\n");
		return;
	}
}

printindex(index: ref Index)
{
	table := index.entries;
	if(table == nil) sys->print("its nill\n");
	for( l := table.all(); l != nil; l = tl l)
	{
		sys->print("Name: %s\n", (hd l).name);
		sys->print("Length: %bd\n", (hd l).length);
	}
}

addfile(path: string)
{
	(ret, dirstat) := sys->stat(path);
	if(ret == -1)
		sys->fprint(stderr, "%s does not exist\n", path);
	if(dirstat.mode & Sys->DMDIR)
	{
		(dirs,cnt)  := readdir->init(path,Readdir->NAME);
		if(path[len path - 1] != '/')
			path += "/";

		for(i := 0; i < cnt; i++)
		{
			index.addfile(path + dirs[i].name);
		}
	}
	else
	{
		index.addfile(path);
	}
}
