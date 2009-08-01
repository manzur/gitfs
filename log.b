implement Log;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
gmt, Tm: import daytime;
splitl, splitr: import stringmod;	
readsha1file: import utils;	
readcommit, Commit: import commitmod;

stderr: ref Sys->FD;	
msgchan: chan of array of byte;	
commits: list of ref Commit;	
mods: Mods;	
	
init(m: Mods)
{
	mods = m;
}

readlog(sha1: string, ch: chan of array of byte)
{
	msgchan = ch;
	commit := readcommit(sha1);
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

toint(b: int): int
{
	return b - '0';
}

dateformatconv(s: string): string
{
	(s1, s2) := stringmod->splitl(s, ">");
	s2 = s2[1:];
	(time, off) := stringmod->toint(s2, 10);
	off = off[1:];
	date := daytime->text(daytime->local(time));

	return s1 + "> " + date + " " + off;
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
		msgchan <-= sys->aprint("%s\n", dateformatconv(commit.author));
	        msgchan <-= sys->aprint("%s\n", dateformatconv(commit.committer));
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
