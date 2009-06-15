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

include "env.m";
	env: Env;

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
	env = load Env Env->PATH;

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
	authorname := env->getenv("AUTHOR_NAME");
	authoremail := env->getenv("AUTHOR_EMAIL");
	authordate := env->getenv("AUTHOR_DATE");
	
	if(authorname == "" || authoremail == ""){
		(authorname, authoremail) = getpersoninfo("author");	
	}

	(comname, comemail) := getpersoninfo("committer");
	date := daytime->time();

	if(authordate == "")
		authordate = date;

	commitmsg += "author " + authorname + " <" + authoremail + "> " + authordate + "\n";
	commitmsg += "committer " + comname + " <" + comemail + "> " + date + "\n\n";

	commitmsg += getcomment();

	commitlen := int2string(len commitmsg);
	#6 - "commit", 1 - " ", 1 - '\0'
	buf := array[6 + 1 + len commitlen + 1 + len commitmsg] of byte;

	buf[:] = array of byte ("commit " + int2string(len commitmsg));
	buf[7 + len commitlen] = byte 0;
	buf[7 + len commitlen + 1:] = array of byte commitmsg;

	sys->print("Commitmsg: %s", commitmsg);

	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte;
	sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, buf);
	(sz, sha) = <-ch;

	return sha2string(sha);

}


getpersoninfo(pos: string): (string, string)
{

	ibuf := bufio->fopen(sys->fildes(0), bufio->OREAD);
	
	sys->print("Enter %s's name: ", pos);
	name := readline(ibuf);	

	sys->print("Enter %s's email: ", pos);
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
