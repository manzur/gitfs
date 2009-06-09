implement Catfile;

include "sys.m";
	sys: Sys;

include "draw.m";

include "tables.m";
	tables: Tables;
Strhash: import tables;	

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;		
	
include "utils.m";
	utils: Utils;
	
include "arg.m";
	arg: Arg;

Catfile: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

printtypeonly := 0;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	if(len args < 2)
	{
		usage();
		return;
	}
	utils = load Utils Utils->PATH;
	arg   = load Arg Arg->PATH;
	utils->init();
	arg->init(args);
	while((c := arg->opt()) != 0)
	{
		case c
		{
			't' => printtypeonly = 1;
				sys->print("cattt\n");
			* => usage();return;
		}
	}
	catfile(hd arg->argv());
}


catfile(path: string)
{
	(filetype, filesize, buf) := utils->readsha1file(path);	
	offset := 0;
	sys->print("filetype: %s\n", filetype);
	if(printtypeonly)
		return;
	while(offset < len buf)
	{
		cnt := sys->write(sys->fildes(1), buf[offset:], len buf - offset);
		offset += cnt;
	}
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: cat-file <sha1>");
	return;
}

