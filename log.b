implement Log;

include "sys.m";
	sys: Sys;
sprint: import sys;

include "draw.m";	

include "tables.m";
Strhash: import Tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "utils.m";
	utils: Utils;
debugmsg, error, exists, chomp, readsha1file: import utils;	

include "lists.m";
	lists: Lists;

include "string.m";
	stringmod: String;
splitl, splitr: import stringmod;	

include "daytime.m";
	daytime: Daytime;
gmt, Tm: import daytime;

include "log.m";

include "commit.m";
Commit: import Commitmod;

stderr: ref Sys->FD;	
msgchan: chan of array of byte;	
REPOPATH: string;
commits: list of ref Commit;	
	
init(ch: chan of array of byte, args: list of string, debug: int)
{
	sys = load Sys Sys->PATH;
	stringmod = load String String->PATH;
	utils = load Utils Utils->PATH;
	lists = load Lists Lists->PATH;
	daytime = load Daytime Daytime->PATH;

	REPOPATH = hd args; 
	utils->init(REPOPATH, debug);
	bufio = load Bufio Bufio->PATH;

	msgchan = ch;
	commit := ref readcommit(hd tl args);
	showlog(commit);
}

insertbydate(commits: list of ref Commit, commit: ref Commit): list of ref Commit
{
	l: list of ref Commit;
	while(commits != nil){
		if(daytime->tm2epoch((hd commits).date) >= daytime->tm2epoch((commit.date)))
			break;
		l = hd commits :: l;
		commits = tl commits;
	}
	if(commits == nil || commit.sha1 != (hd commits).sha1)
		l = commit :: l;

	l = lists->concat(lists->reverse(l), commits);

	return l;
}

printlist(l: list of ref Commit)
{
	sys->print("\n");
	while(l != nil){
		sys->print("=> %s\n", (hd l).sha1);
		l = tl l;
	}
	sys->print("\n");
}

readcommit(sha: string): Commit
{
	commit: Commit;

	(nil, nil, filebuf) := readsha1file(sha);

	ibuf := bufio->aopen(filebuf);
	commit.sha1 = sha;
	commit.treesha = chomp(ibuf.gets('\n'));
 	while((s := ibuf.gets('\n')) != nil){
        	(t, parentsha1) := splitr(s, " ");
		if(t != "parent ")
			break;
                parentsha1 = chomp(parentsha1);
                commit.parents = parentsha1 :: commit.parents;
	}
	(user, date) := splitr(chomp(s), ">");
	commit.author = chomp(user);
 
	(user, date) = splitr(chomp(ibuf.gets('\n')), ">");
	commit.committer = chomp(user);
	commit.date = parsedate(date);
 
 	ibuf.gets('\n');
	#reading comments of the commit
	commit.comment = chomp(ibuf.gets('\0'));
 
	return commit;		
}

getcommits(parents: list of ref Commit)
{
	if(parents == nil)
		return;

	commit := hd parents;
	parents = tl parents;
	while(commit.parents != nil){
		parent := ref readcommit(hd commit.parents);
		commits = insertbydate(commits, parent);
		commit.parents = tl commit.parents;
		parents = parent :: parents;
	}
	printlist(parents);

	getcommits(parents);
}
 
showlog(commit: ref Commit)
{
	getcommits(commit :: nil);

	commits = lists->reverse(commits);
	commits = commit :: commits;
 	printlist(commits);

	while(commits != nil){
		commit = hd commits;
		msgchan <-= sys->aprint("Commit: %s\n", commit.sha1);

		msgchan <-= sys->aprint("%s\n", commit.author);
	        msgchan <-= sys->aprint("%s\n", commit.committer);
	        msgchan <-= sys->aprint("%s\n\n", commit.comment);
		
		commits = tl commits;
 
	}
	msgchan <-= nil;
}

parsedate(date: string): ref Tm
{
	while(date != nil && date[0] == ' ')
		date = date[1:];
	(tim, zone) := stringmod->toint(date, 10);
	tm := gmt(tim);
	
	zone = ltrim(zone);
	sign := 1;

	if(zone[0] == '-')
		sign = -1;

	sign = zone[0];
	zone = zone[1:];
	
	offset := stringmod->toint(zone[:2], 10).t0 * 60 + stringmod->toint(zone[2:4], 10).t0;
	
	tm.tzoff = sign * offset;

	return tm;
}

ltrim(s: string): string
{
	while(s != nil && s[0] == ' ')
		s = s[1:];
		
	return s;
}

usage()
{
	sys->fprint(stderr, "log <commit-sha1>\n");
	return;
}
