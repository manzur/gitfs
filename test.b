implement Mymodule;


include "sys.m";
	sys : Sys;

include "tables.m";
	tables : Tables;

Strhash, Table : import tables;


include "draw.m";

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "string.m";
	stringmod: String;
splitr: import stringmod;	

include "utils.m";
	utils: Utils;
sha2string, string2sha: import utils;

include "readdir.m";
	readdir: Readdir;
	
include "filepat.m";
	filepath: Filepat;

include "exclude.m";
	exclude: Exclude;

include "workdir.m";
	gwd: Workdir;

include "lists.m";
	lists: Lists;

include "daytime.m";
	daytime: Daytime;
Tm: import daytime;	

print : import sys;

global: int;

Mymodule : module
{
	init : fn(nil : ref Draw->Context, args : list of string);
};

include "arg.m";
	arg: Arg;

init(nil : ref Draw->Context, args : list of string)
{
	sys = load Sys Sys->PATH;
	tables = load Tables Tables->PATH;
	readdir = load Readdir Readdir->PATH;
	filepat := load Filepat Filepat->PATH;
	exclude  = load Exclude Exclude->PATH;
	stringmod = load String String->PATH;
	daytime = load Daytime Daytime->PATH;

	sys->print("%d\n", (nil :: (nil :: nil)) == nil);
}

text(tm: ref Tm): string
{
	return daytime->text(tm) + " " + string (tm.tzoff / 3600) + string ((tm.tzoff % 3600 ) /60);
}


printlist(l: list of int) 
{
	while(l != nil)
	{
		sys->print("%d ", hd l);
		l = tl l;
	}
	sys->print("\n");
}




usage()
{
	sys->fprint(sys->fildes(2),"sadasd");
	exit;
}
