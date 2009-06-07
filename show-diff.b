implement Showdiff;

include "sys.m";
	sys: Sys;

include "draw.m";

include "tables.m";
	tables: Tables;

Strhash: import tables;

include "utils.m";
	utils: Utils;

include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;

include "sh.m";	

index: ref Index;	
stderr: ref Sys->FD;
	
Showdiff: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

diff: Command;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	utils = load Utils Utils->PATH;
	tables = load Tables Tables->PATH;

	utils->init();
	index = Index.new();
	index.readindex(utils->INDEXPATH);
	stderr = sys->fildes(2);
	showdiffs();
}

showdiffs()
{
	for(l := index.entries.all(); l != nil; l = tl l)
	{
		if(filechanged(hd l))
			showdiff(hd l);
		else
			sys->print("File %s wasn't changed\n", (hd l).name);
	}
}

filechanged(entry: ref Entry): int
{
	sys->print("name is: %s\n", entry.name);
	(ret, dirstat) := sys->stat(entry.name);
	if(ret == -1)
	{
		sys->fprint(stderr, "File stat failed: %r\n");
		return 0;
	}
	return (!utils->equalqids(entry.qid, dirstat.qid) ||
		 entry.dtype != dirstat.dtype ||
	         entry.dev   != dirstat.dev ||
     	         entry.mtime != dirstat.mtime);
}

showdiff(entry: ref Entry)
{
	#loads acme-sac diff
	diff = load Command "/dis/acdiff.dis";
	diff->init(nil, list of {"diff", "-u",utils->extractfile(utils->sha2string(entry.sha1)), entry.name});

}
