implement Committree;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
error, int2string, readline, sha2string: import utils;

MAXUSERLEN: con 128;

stderr: ref Sys->FD;
mods: Mods;

init(m: Mods)
{
	mods = m;
	deflatefilter->init();
}

#returns sha1 of the new commit
commit(treesha: string, parents: list of string, path: string): string
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

	author, committer, comments: string;
	ibuf := bufio->open(path, Bufio->OREAD);
	if(ibuf == nil){
		error(sprint("Error in commit msg(%s) and will commit default\n", path));
		return nil;
	}

	if(iscommitfile(ibuf)){
		s: string;
		#commitfile contains raw commit msg
		while((s = ibuf.gets('\n')) != nil){
			if(stringmod->prefix("author", s)){
				author = s;
			}
			else if(s == "\n")
				break;
		}
	}

	#reading comments field
	comments += ibuf.gets('\0');		

	if(author == nil){
		author = getauthorinfo();
	}
	committer = getcommitterinfo();
	commitmsg += author + committer;

	#Should add code for adding encoding field, if in the encoding of Inferno OS changes
	commitmsg += comments;

	return commitbuf(commitmsg);
}

commitbuf(commitmsg: string): string
{
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

iscommitfile(ibuf: ref Iobuf): int
{
	s := ibuf.gets('\n');
	ibuf.seek(big -len s, Bufio->SEEKRELA);
	return stringmod->prefix("tree ", s);
}


curtime(): string
{
	t := daytime->now();
	off := daytime->local(t).tzoff;
	sign := '+';
	if(off < 0){
		sign = '-';
	}
	date := sys->sprint("%d %c%02d%02d", daytime->now(), sign, off / 3600, (off % 3600) / 60); 

	return date;
}

getcommitterinfo(): string
{
	name := configmod->getstring("user.name");
	mail := configmod->getstring("user.email");
	s: string;
	if((s = env->getenv("GIT_COMMITTER_NAME")) != nil){
		name = utils->strip(s);
	}
	if((s = env->getenv("GIT_COMMITTER_MAIL")) != nil){
		mail = utils->strip(s);
	}

	if(name == nil){
		name = configmod->getstring("committername"); 
	}
	if(mail == nil){
		mail = configmod->getstring("committermail");
	}

	info := "committer " + name + " <" + mail+ "> " + curtime() + "\n\n";

	return info;
}

getauthorinfo(): string
{
	name := configmod->getstring("authorname");
	mail := configmod->getstring("authormail");

	info := "author " + name + " <" + mail+ "> " + curtime() + "\n";

	return info;
}

getcomment(): string
{
	ibuf := bufio->fopen(sys->fildes(0), bufio->OREAD);	
	return ibuf.gets('\0');
}

usage()
{
	error("commit-tree sha1 [-p sha1]");
	exit;
}
