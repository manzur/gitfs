implement Commitmod;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
gmt, Tm: import daytime;	
error, ltrim, readsha1file: import utils;	


mods: Mods;

init(m: Mods)
{
	mods = m;
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

readcommit(sha1: string): ref Commit
{
	(filetype, filesize, filebuf) := readsha1file(sha1);
	if(filetype != "commit"){
		error(sprint("File %s isn't commit type\n", sha1));
		return nil;
	}

	return readcommitbuf(sha1, filebuf);
}

readcommitbuf(sha1: string, filebuf: array of byte): ref Commit
{
	ibuf := bufio->aopen(filebuf);

	s := ibuf.gets('\n');
	(type1, treesha1) := stringmod->splitl(s, " ");
	if(type1 != "tree"){
		error("File %s is corrupted\n");
		return nil;
	}
	treesha1 = treesha1[1:len treesha1 - 1];

	parents: list of string;
	while((s = ibuf.gets('\n')) != ""){
		(tag, parentsha1) := stringmod->splitl(s, " ");
		if(tag == "author") break;
		parentsha1 = parentsha1[1:len parentsha1 - 1];
		parents = parentsha1 :: parents;
	}
	author := s[:len s - 1];
	s = ibuf.gets('\n');
	committer := s[:len s - 1];
	
	(nil, s) = stringmod->splitr(committer, ">");
	date := parsedate(s);

#FIXME: write code for reading encoding
	comment := ibuf.gets('\0');

	return ref Commit(sha1, treesha1, lists->reverse(parents), author, committer, nil, date, comment);
}


