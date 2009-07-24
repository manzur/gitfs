implement Repo;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
comparebytes, debugmsg, error, int2bytes, packqid, readint, readshort, INTSZ, QIDSZ, SHALEN: import utils;	

mods: Mods;
indexpath, gitfsindexpath: string;

init(m: Mods)
{
	mods = m;
	sys->print("repopath is %s\n", repopath);
	indexpath = repopath + ".git/index";
	gitfsindexpath = repopath + ".git/gitfsindex";
}

readrepo(): int
{
	return checkrepo() && convertindex();
}

checkindex(): int
{
	(ret, dirstat) := sys->stat(indexpath);
	#36 = cache_signature + version + entriescount + sha1
	if(ret == -1 || dirstat.length < big 36){
		error(sprint("index file at %s is not found\n", indexpath));
		return 0;
	}

	return 1;
}

checkrefs(): int
{
#FIXME: code for checking that refs aren't dangling
	return 1;
}

checkrepo(): int
{
	return checkstructure() && checkindex() && checkrefs();
}

checkstructure(): int
{
#Checking for existense of objects/, refs/ and head
	path1 := repopath + ".git/objects";
	path2 := repopath + ".git/refs";
	path3 := repopath + ".git/HEAD";
	ret := isdir(path1) && isdir(path2) 
		&& !sys->stat(path3).t0;  

	return ret;
}

convertindex(): int
{
	sha1 := array[SHALEN] of byte;
	if(indicesmatch(sha1)){
		sys->print("indices match\n");
		return 1;
	}

	sys->print("indices don't match\n");
	fd := sys->create(gitfsindexpath, Sys->OWRITE, 8r644);
	indexfd := sys->open(indexpath, Sys->OREAD);
	
	signature := readint(indexfd);
	version := readint(indexfd);
	entriescnt := readint(indexfd);

	sys->write(fd, sha1, len sha1);
	sys->write(fd, int2bytes(signature), INTSZ);
	sys->write(fd, int2bytes(version), INTSZ);
	sys->write(fd, int2bytes(entriescnt), INTSZ);
	for(i := 0; i < entriescnt; i++){
		#skiping all information until sha1
		sys->seek(indexfd, big 40, Sys->SEEKRELA);

		cnt := sys->read(indexfd, sha1, len sha1);
		flags := readshort(indexfd);
		if(extendedflags(flags))
		{
			debugmsg("extended record\n");
			flags = (flags << 16) | readshort(fd);
		}

		namelen := entrynamelen(flags);
		namebuf := array[namelen] of byte;
		sys->read(indexfd, namebuf, len namebuf);

		readgarbage(indexfd, namelen, flags);
		(ret, dirstat) := sys->stat(repopath + string namebuf);
		if(ret == -1){
			error("index doesn't match working dir\n");
			return 0;
		}
		#writing all that to gitfs index
		sys->write(fd, packqid(ref dirstat.qid), QIDSZ);
		sys->write(fd, sha1, SHALEN);
		sys->write(fd, int2bytes(flags), INTSZ);
		sys->write(fd, namebuf, len namebuf);

	}	
	#code for reading tree extension

	return 1;
}

entrynamelen(flags: int): int
{
	return flags & 16r0fff;
}

entrysize(namelen: int, flags: int): int
{
#FIXME: Code should be added for namelen recalculation for namelen >= 4096
#if cache entry is extended
	if(extendedflags(flags))
		return (NAMEOFFSETEX + namelen + 8) & ~7;

	return (NAMEOFFSET + namelen + 8) & ~7;
}

extendedflags(flags: int): int
{
	return flags & EXTENDEDENTRY;
}

indicesmatch(realsha1: array of byte): int
{
	fd := sys->open(gitfsindexpath, Sys->OREAD);
	if(fd == nil){
		return 0;
	}

	sha1 := array[SHALEN] of byte;
	cnt := sys->read(fd, sha1, SHALEN);
	if(cnt < SHALEN)
		return 0;
	
	indexfd := sys->open(indexpath, Sys->OREAD);
	sys->seek(fd, big -SHALEN, Sys->SEEKEND);
	sys->read(indexfd, realsha1, SHALEN);
	
	return !comparebytes(sha1, realsha1);	
}

isdir(path: string): int
{
	(ret, dirstat) := sys->stat(path);
	return !ret && dirstat.mode & Sys->DMDIR;
}

ntohl(num: int): int
{
	return (ntohs(num) << 16) | (ntohs(num >> 16));
}


ntohs(num: int): int
{
	ret := num & 16rff;
	num >>= 8;
	ret = (ret << 8) | (num & 16rff);

	return ret;
}

readgarbage(fd: ref Sys->FD, namelen, flags: int)
{	
	#reading alignment 
	esize := entrysize(namelen, flags) - ENTRYSZ - namelen;
	
	garbage := array[esize] of byte;
	cnt := sys->read(fd, garbage, len garbage);
	if(len garbage != cnt){
		error(sprint("index format error(alignment) %d\n", cnt));
	}
	
}

sizeofrest(fd: ref Sys->FD): big  
{
	curpos := sys->seek(fd, big 0, Sys->SEEKRELA);
	rest := sys->seek(fd, big 0, Sys->SEEKEND) - curpos;
	sys->seek(fd, curpos, Sys->SEEKSTART);

	return rest;
}




