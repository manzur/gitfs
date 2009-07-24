implement Gitindex;

include "gitfs.m";
include "modules.m";
include "mods.m";

sprint: import sys;

dirname, makeabsentdirs: import pathmod;	

QIDSZ, BIGSZ, INTSZ, SHALEN: import utils;
debugmsg, error, bytes2int, bytes2big, big2bytes, comparebytes,int2bytes, filesha1, allocnr, packqid, sha2string, unpackqid, equalshas: import utils;

filebuf: array of byte;

indexpath: string;

mods: Mods;

Index.new(arglist: list of string, debug: int): ref Index
{
	return ref initindex();
}

init(m: Mods)
{
	mods = m;
	indexpath = repopath + ".git/gitfsindex";
}

initindex(): Index
{
	index: Index;
	index.header = Header.new();
	index.hashcap = 37;
	index.entries = Strhash[ref Entry].new(index.hashcap, nil);

	return index;
}

#FIXME: Use addentry
Index.addfile(index: self ref Index, path : string): string 
{
	debugmsg("in index addfile\n");
#no need for verification
#	if(!verifypath(mntpt + path)){
#		error(sprint("wrong path: %r\n"));
#		return -1;
#	}
	#FIXME: Exclude code should be modified to be specific for each branch
#	if(exclude->excluded(path)) return -1;

	debugmsg("gitindex/addfile before if statement\n");
	index.header.entriescnt++;
	if(index.header.entriescnt * CLSBND >= index.hashcap){
		oldentries := index.entries.all();
		index.hashcap = allocnr(index.hashcap);
		index.entries = Strhash[ref Entry].new(index.hashcap, nil);

		while(oldentries != nil){
			entry := hd oldentries;
			index.entries.add(entry.name, entry);
			oldentries = tl oldentries;
		}
	}

	debugmsg("gitindex/addfile before writeblobfile\n");
	fullpath := repopath + getentrypath(path);
	makeabsentdirs(dirname(fullpath));
	sha1 := writeblobfile(fullpath);
	debugmsg("gitindex/addfile after writeblobfile\n");

	#only path from master/tree is needed
	entry := initentry(getentrypath(path));
	sys->print("adding entry(%s) with name %s to %s\n", fullpath, entry.name, sha2string(sha1));
	entry.sha1 = sha1;
	if((elem := index.entries.find(entry.name)) != nil){
		copyentry(elem, entry);
		index.header.entriescnt--;
	}
	else
		index.entries.add(entry.name, entry);

	debugmsg(sprint("File added: %s\n", sha2string(entry.sha1)));

	return sha2string(entry.sha1);
}

writeblobfile(path: string): array of byte
{
	fd := sys->open(path, Sys->OREAD);
	(ret, dirstat) := sys->stat(path);
	if(ret == -1){
		error(sprint("file %s for adding for index isn't found\n", path));
		return nil;
	}

	buf := array[Sys->ATOMICIO] of byte;
	ch := chan of (int, array of byte);
	sha1: array of byte;
	sz: int;
	
	spawn utils->writesha1file(ch);
	temp := sys->aprint("blob %bd", dirstat.length);
	buf[:] = temp;
	buf[len temp] = byte 0;
	cnt := len temp + 1;
	while(1){
		ch <-= (cnt, buf);
		if(cnt == 0){
			(sz, sha1) = <-ch;
			break;
		}
		cnt = sys->read(fd, buf, len buf);
	}

	return sha1;
}

Index.removeentries(index: self ref Index): ref Index
{
	return ref initindex();
}

getentrypath(path: string): string
{
	#FIXME: code should take into account commit tags, and dirs named tree

	sep := "/tree/";
	(s1, s2) := stringmod->splitstrr(path, sep); 

	return s2;
}

Index.addentry(index: self ref Index, entry: ref Entry)
{
	index.header.entriescnt++;
	if(index.header.entriescnt * CLSBND >= index.hashcap){
		oldentries := index.entries.all();
		index.hashcap = allocnr(index.hashcap);
		index.entries = Strhash[ref Entry].new(index.hashcap, nil);

		while(oldentries != nil){
			entry := hd oldentries;
			index.entries.add(entry.name, entry);
			oldentries = tl oldentries;
		}
	}
	index.entries.add(entry.name, entry);
}



Index.rmfile(index: self ref Index, path : string) 
{
	if(index.entries.find(path) == nil){
		error(sprint("there's no such file(%s) in the index\n", path));
		return;
	}
	index.header.entriescnt--;
	index.entries.del(path);
}

Header.new(): ref Header
{
	header: Header;
	header.signature = CACHESIGNATURE;
	header.version   = 2;
	header.entriescnt = 0;

	return ref header;
}

readindex(index:ref Index): int
{
	return readindexfrom(index, indexpath);
}


#return: number of elements read from index file
readindexfrom(index:ref Index, path : string) : int
{
	debugmsg(sprint("index path is %s\n", indexpath));
	indexfd := sys->open(indexpath, Sys->OREAD);

	if(indexfd == nil){
		error(sprint("file access error: %r\n"));
		return -1;
	}

	header := array[HEADERSZ] of byte;

	#skiping sha1 of the git index
	sys->seek(indexfd, big SHALEN, Sys->SEEKSTART);

	if((ret := sys->read(indexfd, header, HEADERSZ)) != HEADERSZ){
		error(sprint("Index format error: %r\n"));
		return -1;
	}

	index.header = Header.unpack(header);

	state: ref Keyring->DigestState = nil;
	keyring->sha1(header, len header, nil, state);

	index.hashcap = index.header.entriescnt * CLSBND * 2;
	index.entries = Strhash[ref Entry].new(index.hashcap, nil);

	for(i := 0; i < index.header.entriescnt; i++){
		entrybuf := array[ENTRYSZ] of byte;
		cnt := sys->read(indexfd, entrybuf, ENTRYSZ);
		if(cnt != ENTRYSZ){
			error(sprint("index file error: %r\n"));
			return 0;
		}

		state = keyring->sha1(entrybuf, len entrybuf, nil, state);
		entry := Entry.unpack(entrybuf); 
		namelen := entry.flags & 16r0fff;
		namebuf := array[namelen] of byte;
		sys->read(indexfd, namebuf, namelen);
		entry.name = string namebuf;	
		index.entries.add(entry.name, entry);
		state = keyring->sha1(namebuf, len namebuf, nil, state);

	}

	sha1 := array[SHALEN] of byte;
	realsha1 := array[SHALEN] of byte;
	sys->read(indexfd, realsha1, len realsha1);
	keyring->sha1(nil, 0, sha1, state);
	if(!comparebytes(sha1, realsha1)){
		error("header is not correct\n");
		return -1;
	}

	return index.header.entriescnt;
}

sizeofrest(fd: ref Sys->FD): big  
{
	curpos := sys->seek(fd, big 0, Sys->SEEKRELA);
	rest := sys->seek(fd, big 0, Sys->SEEKEND) - curpos;
	sys->seek(fd, curpos, Sys->SEEKSTART);

	return rest;
}

Index.getentries(index:self ref Index, stage: int): list of ref Entry
{
	ret: list of ref Entry;
	entries := index.entries.all();
	while(entries != nil){
		entry := hd entries;
		if(entrystage(entry) == stage){
			ret = entry :: ret;
		}
		entries = tl entries;
	}
	
	return ret; 
}

entrystage(e: ref Entry): int
{
	return (e.flags & STAGEMASK) >> STAGESHIFT;
}

lock(): int
{
	lockpath := repopath + ".git/index.lock";	
	(ret, nil) := sys->stat(lockpath);
	if(ret != -1){
		sys->sleep(120);
		(ret, nil) := sys->stat(lockpath);
	}
	return ret == -1;
}

unlock()
{
	sys->remove(repopath + ".git/index.lock");
}

writeindex(index:ref Index): int
{
	if(!lock())
		return 0;
	ret := writeindexto(index, indexpath);
	unlock();
	return ret;
}

#return: number of elements written to the index file
writeindexto(index:ref Index, path : string) : int
{
	fd := sys->open(path, Sys->OWRITE);
	if(fd == nil){
		error(sprint("write index error: %r\n"));
		return 0;
	}

	#skiping sha1 of the git's index file
	sys->seek(fd, big SHALEN, Sys->SEEKSTART);

	state: ref Keyring->DigestState = nil;
	temp := int2bytes(index.header.signature);
	state = keyring->sha1(temp, len temp, nil, state);

	temp = int2bytes(index.header.version);
	state = keyring->sha1(temp, len temp, nil, state);

	temp = int2bytes(index.header.entriescnt);
	state = keyring->sha1(temp, len temp, nil, state);

	header := index.header.pack();
	sys->write(fd, header, len header);

	cnt := 0;
	entrybuf: array of byte;
	for(l := index.entries.all(); l != nil; l = tl l)
	{
		entrybuf = (hd l).pack();
		cnt := sys->write(fd, entrybuf, len entrybuf);
		if(cnt != len entrybuf){
			error(sprint("couldn't write entry to the file: %r\n"));
			return cnt;
		}
		keyring->sha1(entrybuf, len entrybuf, nil, state);

	}

	sha1 := array[SHALEN] of byte;
	keyring->sha1(nil, 0, sha1, state);
	sys->write(fd, sha1, len sha1);

	return index.header.entriescnt;
}




Header.unpack(buf : array of byte) : ref Header
{
	ret : Header;


	ret.signature = bytes2int(buf, 0);
	offset := INTSZ;

	ret.version = bytes2int(buf,offset);
	offset += INTSZ;
	
	ret.entriescnt = bytes2int(buf,offset);
	offset += INTSZ;
	
	return ref ret;
}

Header.pack(header : self ref Header) : array of byte
{
	ret := array[HEADERSZ] of byte;

	
	ret[:] = int2bytes(header.signature);
	offset := INTSZ;

	ret[offset:] = int2bytes(header.version);
	offset += INTSZ;

	ret[offset:] = int2bytes(header.entriescnt);

	return ret;
}

Entry.pack(entry : self ref Entry) : array of byte
{
	ret := array[ENTRYSZ + len entry.name] of byte;

	offset := 0;

	temp := packqid(ref entry.qid);
	ret[:] = temp;
	offset += QIDSZ;
	
	ret[offset:] = entry.sha1;
	offset += SHALEN;

	ret[offset:] = int2bytes(entry.flags);
	offset += INTSZ;
	
	ret[offset:] = sys->aprint("%s", entry.name); 

	return ret;
}

Entry.unpack(buf : array of byte) : ref Entry
{
	entry: Entry;

	offset := 0;

	entry.qid = unpackqid(buf, offset);
	offset += QIDSZ;

	entry.sha1 = buf[offset : offset + SHALEN];
	offset += SHALEN;

	entry.flags = bytes2int(buf, offset);
	offset += INTSZ;

#FIXME: read also entry.name
	return ref entry;
}


initentry(filename: string): ref Entry
{
	entry: Entry;

	(retval, dirstat) := sys->stat(repopath + filename);
	if(retval != 0)
	{
		error(sprint("stat error: %r\n"));
		return nil;
	}
	
	entry.qid = dirstat.qid;
	entry.name = filename;
	entry.flags = len filename & 16r0fff;

	return ref entry;
}



verifypath(path : string) : int
{
	return !sys->stat(path).t0;
}

verifyheader(header: ref Header, sha1: array of byte): int
{
	return 1;

#	return  equalshas(header.sha1, sha1) &&	
#		header.signature == CACHESIGNATURE &&
#		header.version == 1 &&
#		header.entriescnt >= 0;
}

copyentry(dst, src: ref Entry)
{
	dst.qid = src.qid;
	dst.sha1 = src.sha1;
	dst.flags = src.flags;
	dst.name = src.name;
}	

Entry.compare(e1: self ref Entry, e2: ref Entry): int
{
	namelen := len e1.name;
	if(len e2.name < namelen) namelen = len e2.name;

	for(i := 0; i < namelen; i++)
	{
		if(e1.name[i] < e2.name[i])
			return 1;
		else if(e1.name[i] > e2.name[i])
			return -1;
	}
	if(len e1.name < len e2.name)
		return 1;
	else if(len e1.name > len e2.name)
		return -1;
	return 0;
}

Entry.new(): ref Entry
{
	entry: Entry;
	entry.qid = Sys->Qid(big 0,0,0);
	entry.sha1 = array[SHALEN] of byte;
	entry.flags = 0;
	entry.name = "";

	return ref entry;
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


