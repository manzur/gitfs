implement Log;

include "sys.m";
	sys: Sys;
sprint: import sys;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "daytime.m";
	daytime: Daytime;
gmt, Tm: import daytime;

include "draw.m";	

include "lists.m";
	lists: Lists;

include "string.m";
	stringmod: String;
splitl, splitr: import stringmod;	

include "tables.m";
Strhash: import Tables;

include "utils.m";
	utils: Utils;
debugmsg, error, readsha1file: import utils;	

include "commit.m";
	commitmod: Commitmod;
readcommit, Commit: import commitmod;

include "log.m";

stderr: ref Sys->FD;	
msgchan: chan of array of byte;	
repopath: string;
commits: list of ref Commit;	
	
init(arglist: list of string, ch: chan of array of byte, debug: int)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	daytime = load Daytime Daytime->PATH;
	lists = load Lists Lists->PATH;
	stringmod = load String String->PATH;

	commitmod = load Commitmod Commitmod->PATH;
	utils = load Utils Utils->PATH;
	commitmod->init(arglist, debug);
	utils->init(arglist, debug);

	repopath = hd arglist; 
	arglist = tl arglist;

	msgchan = ch;
	commit := readcommit(hd tl arglist);

	showlog(commit);
}

insertbydate(commits: list of ref Commit, commit: ref Commit): list of ref Commit
{
	l: list of ref Commit;
	while(commits != nil){
		if(daytime->tm2epoch((hd commits).date) >= daytime->tm2epoch(commit.date))
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

getcommits(parents: list of ref Commit)
{
	if(parents == nil)
		return;

	commit := hd parents;
	parents = tl parents;
	while(commit.parents != nil){
		parent := readcommit(hd commit.parents);
		commits = insertbydate(commits, parent);
		commit.parents = tl commit.parents;
		parents = parent :: parents;
	}

	getcommits(parents);
}
 
showlog(commit: ref Commit)
{
	getcommits(commit :: nil);

	commits = lists->reverse(commits);
	commits = commit :: commits;

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





usage()
{
	sys->fprint(stderr, "log <commit-sha1>\n");
	return;
}
