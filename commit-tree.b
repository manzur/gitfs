implement Committree;

include "sys.m";
	sys: Sys;

include "draw.m";

include "arg.m";
	arg: Arg;

include "filter.m";
	deflate: Filter;
		
include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "tables.m";
	tables: Tables;

Strhash: import tables;

include "utils.m";
	utils: Utils;
Config: import utils;
chomp, readline, int2string, sha2string: import utils;


include "daytime.m";
	daytime: Daytime;

stderr: ref Sys->FD;

Committree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};



init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	utils = load Utils Utils->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	bufio = load Bufio Bufio->PATH;
	tables = load Tables Tables->PATH;
	daytime = load Daytime Daytime->PATH;

	stderr = sys->fildes(2);

	if(len args < 2)
	{
		usage();
		return;
	}
	
	arg->init(args);
	utils->init();
	deflate->init();

	parents: list of string = nil;
	sha := arg->arg();

	while((c := arg->opt()) != 0)
	{
		case c
		{

			'p' => parents = arg->arg() :: parents;
			 *  => usage(); return; 
		}
	}

	commit(sha, parents);
}

commit(treesha: string, parents: list of string): string
{
	if(!utils->exists(treesha))
	{
		sys->fprint(stderr, "no such tree file\n");
		return "";
	}

	for(l := parents; l != nil; l = tl l)
	{
		if(!utils->exists(hd l)){
			sys->fprint(stderr, "no such sha file: %s\n", hd l);
			return "";
		}

	}
	commitmsg := "";
	commitmsg += "tree " + treesha + "\n";
	while(parents != nil)
	{
		commitmsg += "parent " + (hd parents) + "\n";
		parents = tl parents;
	}
	config: ref Strhash[ref Config];
	config = utils->getuserinfo();
	name := (config.find("user")).val;
	email := (config.find("email")).val; 

	(comname, comemail) := getcommitterinfo();
	date := daytime->time();

	commitmsg += "author " + name + " " + email + " " + date + "\n";
	commitmsg += "committer " + comname + " " + comemail + " " + date + "\n\n";
	
	commitmsg += getcomment();

	buf := array of byte ("commit " + int2string(len commitmsg) + string (byte 0) + commitmsg);

	sys->print("Commitmsg: %s\n", commitmsg);

	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte;
	sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, buf);
	(sz, sha) = <-ch;

	return sha2string(sha);

}


getcommitterinfo(): (string, string)
{

	ibuf := bufio->fopen(sys->fildes(0), bufio->OREAD);
	
	sys->print("Enter commiter's name: ");
	name := readline(ibuf);	

	sys->print("Enter committer's email: ");
	email := readline(ibuf);

	return (name, email);
}



getcomment(): string
{
	ibuf := bufio->fopen(sys->fildes(0), bufio->OREAD);	
	sys->print("Comments: ");
	return ibuf.gets('\0');
}

usage()
{
	sys->fprint(sys->fildes(1), "commit-tree sha1 [-p sha1]");
	return;
}
