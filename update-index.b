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

Index: import gitindex;

index: ref Index;

Updateindex: module
{
	init : fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	tables = load Tables Tables->PATH;

	index = gitindex->Index.new();
	cnt := index.readindex("index");


	arg = load Arg Arg->PATH;
	arg->init(args);
	while((c := arg->opt()) != 0)
	{
		case c
		{
			'a' =>
				path := arg->arg();
				sys->print("Adding %s\n", path);
				index.addfile(path); 
			'r' =>
				path := arg->arg();
				sys->print("Removing %s\n", path);
				index.rmfile(path);
		}
			
	}
	
	printindex(index);
	sys->print("writing to index\n");
	index.writeindex("index");
	
}

printindex(index: ref Index)
{
	table := index.entries;
	for( l := table.all(); l != nil; l = tl l)
	{
		sys->print("Name: %s\n", (hd l).name);
		sys->print("Length: %bd\n", (hd l).length);
	}
}
