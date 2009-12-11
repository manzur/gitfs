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

include "names.m";
names: Names;

print : import sys;

global: int;
MAXINT: con (1 << 31) - 1;

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
	names = load Names Names->PATH;
	stringmod = load String String->PATH;
	daytime = load Daytime Daytime->PATH;

	s := "/root/mydir/myfile";
	(s1, s2) := basename(s);
	while( s1 != nil){
		sys->print("==%s\n", s1);
		s = s2;
		(s1, s2) = basename(s);
	}

	mp := "/root/mydir/myfile";
	sys->print("==>%s\n", names->basename(mp, nil));

	sys->print("==>%d\n", int (big 1 << 31) - 1);
	sys->print("==>%d\n", MAXINT);
	a := "abc";
	sys->print("->%s", a[0:0]);
}

kk(ch: chan of array of byte)
{
	ch <-= array of byte "heyфa";
}

pop():string{return "POP";}

text(tm: ref Tm): string
{
	return daytime->text(tm) + " " + string (tm.tzoff / 3600) + string ((tm.tzoff % 3600 ) /60);
}

cutprefix(prefix, s: string): string
{
	if(len prefix > len s)
		return nil;

	if(prefix == s[:len prefix]){
		return s[len prefix:];
	}

	return nil;
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

basename(path: string): (string, string)
{
	if(path[0] == '/')
		path = path[1:];

	for(i := 0; i < len path; i++){
		if(path[i] == '/')
			return (path[:i], path[i+1:]);
	}

	return (nil, path);
}

usage()
{
	sys->fprint(sys->fildes(2),"sadasd");
	exit;
}
