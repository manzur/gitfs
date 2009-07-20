implement Committree;

include "sys.m";
	sys: Sys;
sprint: import sys;

include "filter.m";
	deflate: Filter;
		
include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "path.m";
	pathmod: Pathmod;

include "utils.m";
	utils: Utils;
error, int2string, readline, sha2string: import utils;


include "daytime.m";
	daytime: Daytime;

include "env.m";
	env: Env;

include "commit-tree.m";

MAXUSERLEN: con 128;

stderr: ref Sys->FD;
repopath: string;


init(arglist: list of string, debug: int)
{
	sys = load Sys Sys->PATH;

	bufio = load Bufio Bufio->PATH;
	daytime = load Daytime Daytime->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	env = load Env Env->PATH;

	pathmod = load Pathmod Pathmod->PATH;
	utils = load Utils Utils->PATH;

	stderr = sys->fildes(2);

	deflate->init();

	repopath = hd arglist;
	utils->init(arglist, debug);
	pathmod->init(repopath);

	parents: list of string = nil;

}

#returns sha1 of the new commit
commit(treesha: string, parents: list of string, comments: string): string
{
	if(!pathmod->shaexists(treesha)){
		error(sprint("no such tree(%s) file: %r\n", treesha));
		return "";
	}
	for(l := parents; l != nil; l = tl l){
		if(!pathmod->shaexists(hd l)){
			error(sprint("no such sha file: %s\n", hd l));
			return "";
		}
	}

	commitmsg := "";
	commitmsg += "tree " + treesha + "\n";
	while(parents != nil){
		commitmsg += "parent " + (hd parents) + "\n";
		parents = tl parents;
	}

	
#	authorname := env->getenv("AUTHOR_NAME");
#	authoremail := env->getenv("AUTHOR_EMAIL");
#	authordate := env->getenv("AUTHOR_DATE");
#	
#	if(authorname == "" || authoremail == ""){
#		(authorname, authoremail) = getpersoninfo("author");	
#	}
#
#	(comname, comemail) := (config.find("user"), config.find("email")););
#	if(comname == "" || comemail == ""){
#		(comname, comemail) = getpersoninfo("committer");
#	}

	author := getauthorinfo();
	committer := getcommitterinfo();

#	commitmsg += "author " + authorname + " <" + authoremail + "> " + authordate + "\n";
#	commitmsg += "committer " + comname + " <" + comemail + "> " + date + "\n\n";
	commitmsg += author + committer;

	#Should add code for adding encoding field, if in the encoding of Inferno OS changes
	commitmsg += comments;
	commitlen := int2string(len commitmsg);
	#6 - "commit", 1 - " ", 1 - '\0'
	buf := array[6 + 1 + len commitlen + 1 + len commitmsg] of byte;

	buf[:] = sys->aprint("commit %d", len commitmsg);
	buf[7 + len commitlen] = byte 0;
	buf[7 + len commitlen + 1:] = array of byte commitmsg;


	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte;
	sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, buf);
	(sz, sha) = <-ch;

	fd := sys->create(repopath + "head", Sys->OWRITE, 8r644);
	
	ret := sha2string(sha);

	sys->fprint(fd, "%s", ret);

	return ret;
}


getcommitterinfo(): string
{
	ibuf := bufio->open("/dev/user", Bufio->OREAD);
	user := ibuf.gets('\0');
	ibuf = bufio->open("/dev/sysname", Bufio->OREAD);
	hostname := ibuf.gets('\0');
	mail := user + "@" + hostname;

	date := daytime->time(); 
	info := "committer " + user + " <" + mail+ "> " + date + "\n";

	return info;
}

getauthorinfo(): string
{
#FIXME: Code should be changed to get real author's info
	ibuf := bufio->open("/dev/user", Bufio->OREAD);
	user := ibuf.gets('\0');
	ibuf = bufio->open("/dev/sysname", Bufio->OREAD);
	hostname := ibuf.gets('\0');
	mail := user + "@" + hostname;

	date := daytime->time(); 
	info := "author " + user + " <" + mail+ "> " + date + "\n";

	return info;
}


getpersoninfo(pos: string): (string, string)
{

	ibuf := bufio->fopen(sys->fildes(0), bufio->OREAD);
	
	sys->print("Enter %s's name: ", pos);
	buf := array[128] of byte;
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
	error("commit-tree sha1 [-p sha1]");
	exit;
}
