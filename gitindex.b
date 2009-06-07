implement Gitindex;

include "sys.m";
	sys : Sys;

include "tables.m";
	tables: Tables;

Strhash : import tables;


include "gitindex.m";
	gitindex : Gitindex;

include "utils.m";
	utils: Utils;
QIDSZ, BIGSZ, INTSZ, SHALEN: import utils;
bytes2int, bytes2big, big2bytes, int2bytes, filesha1, allocnr,sha2string, copyarray: import utils;

stderr : ref Sys->FD;
filebuf: array of byte;

Index.new(): ref Index
{
	tables = load Tables Tables->PATH;
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;

	utils->init();
	stderr = sys->fildes(2);

	index: Index;
	index.header = Header.new();
	index.entries = nil;
	index.hashcap = 0;

	return ref index;
}

Index.addfile(index: self ref Index, path : string) : int
{

	if(!verifypath(path))
	{
		sys->fprint(stderr, "wrong path: %r\n");
		return -1;
	}

	index.header.entriescnt++;
	if(index.header.entriescnt * CLSBND >= index.hashcap)
	{
		oldentries := index.entries.all();
		index.hashcap = allocnr(index.hashcap);
		index.entries = Strhash[ref Entry].new(index.hashcap, nil);

		while(oldentries != nil)
		{
			entry := hd oldentries;
			index.entries.add(entry.name, entry);
			oldentries = tl oldentries;
		}
	}

	sha := writeblobfile(path);
	entry := initentry(path);
	entry.sha1 = sha;
	if((elem := index.entries.find(entry.name)) != nil)
	{
		copyentry(elem, entry);
		index.header.entriescnt--;
	}
	else
		index.entries.add(entry.name, entry);

	sys->print("File added: %s\n", sha2string(entry.sha1));

	return 0;
}

writeblobfile(path: string): array of byte
{
	fd := sys->open(path, Sys->OREAD);
	(ret, dirstat) := sys->stat(path);
	buf := array[Sys->ATOMICIO] of byte;
	ch := chan of (int, array of byte);
	sha: array of byte;
	sz: int;
	
	temp := array of byte sys->sprint("blob %bd", dirstat.length);
	spawn utils->writesha1file(ch);
	buf[:] = temp;
	buf[len temp] = byte 0;
	cnt := len temp + 1;
	while(1)
	{
		ch <-= (cnt, buf);
		if(cnt == 0)
		{
			(sz, sha) = <-ch;
			break;
		}
		cnt = sys->read(fd, buf, len buf);
	}
	return sha;
}

Index.rmfile(index: self ref Index, path : string) 
{
	if(index.entries.find(path) != nil)
	{
		sys->fprint(stderr, "there's no such file in the index\n");
		return;
	}
	index.header.entriescnt--;
	index.entries.del(path);
}

Header.new(): ref Header
{
	header: Header;
	header.signature = CACHESIGNATURE;
	header.version   = 1;
	header.entriescnt = 0;
	header.sha1 = array[SHALEN] of byte;
	return ref header;
}

#return: number of elements read from index file
Index.readindex(index: self ref Index, path : string) : int
{

	indexfd := sys->open(path, Sys->OREAD);

	if(indexfd == nil)
	{
		sys->fprint(stderr,"file access error: %r\n");
		return 0;
	}

	header := array[HEADERSZ] of byte;

	if((ret := sys->read(indexfd, header, HEADERSZ)) != HEADERSZ)
	{
		sys->fprint(stderr, "Index format error: %r\n");
		return 0;
	}

	index.header = Header.pack(header);
	if(!verifyheader(index.header))
	{
		sys->fprint(stderr, "header is not correct\n");
		return 0;
	}

	index.hashcap = index.header.entriescnt * CLSBND * 2;

	index.entries = Strhash[ref Entry].new(index.hashcap, nil);

	for(i := 0; i < index.header.entriescnt; i++)
	{

		entrybuf := array[ENTRYSZ] of byte;

		ret := sys->read(indexfd, entrybuf, ENTRYSZ);
		if(ret != ENTRYSZ)
		{
			sys->fprint(stderr,"index file error: %r\n");
			return 0;
		}

		entry := Entry.pack(entrybuf); 
		namebuf := array[entry.namelen] of byte;
		sys->read(indexfd, namebuf, entry.namelen);
		entry.name = string namebuf;	
		index.entries.add(entry.name, entry);
	
		#each entry is aligned by 8  
		remainder : int;
		remainder = (ENTRYSZ + entry.namelen + 8) & ~7; 
		remainder -= ENTRYSZ + entry.namelen;
		sys->read(indexfd, entrybuf, remainder);
	}
	return index.header.entriescnt;
}

#return: number of elements written to the index file
Index.writeindex(index: self ref Index, path : string) : int
{
	fd := sys->create(path, Sys->OWRITE, 8r644);
	if(fd == nil)
	{
		sys->fprint(stderr, "write index error: %r\n");
		return 0;
	}

	header := index.header.unpack();
	sys->write(fd, header, len header);

	entrybuf : array of byte;
	cnt := 0;
	for(l := index.entries.all(); l != nil; l = tl l)
	{
		entrybuf = (hd l).unpack();

		cnt := sys->write(fd, entrybuf, len entrybuf);
		if(cnt != len entrybuf)
		{
			sys->print("couldn't write entry to the file: %r\n");
			return cnt;
		}
		#each entry is aligned by 8  
		remainder : int;
		remainder = (ENTRYSZ + (hd l).namelen + 8) & ~7; 
		remainder -= ENTRYSZ + (hd l).namelen;
		sys->write(fd, array[remainder] of byte, remainder);
	}

	return index.header.entriescnt;
}

Header.pack(buf : array of byte) : ref Header
{
	ret : Header;
	offset := 0;

	ret.signature = bytes2int(buf,offset);
	offset += INTSZ;
	
	ret.version = bytes2int(buf,offset);
	offset += INTSZ;
	
	ret.entriescnt = bytes2int(buf,offset);
	offset += INTSZ;
	
	ret.sha1 = buf[offset: offset + SHALEN];
	
	return ref ret;
}

Header.unpack(header : self ref Header) : array of byte
{
	ret := array[HEADERSZ] of byte;

	offset := 0;
	
	temp := int2bytes(header.signature);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	temp = int2bytes(header.version);
	copyarray(ret, offset,  temp, 0, len temp);
	offset += len temp;

	temp = int2bytes(header.entriescnt);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;
	

	copyarray(ret, offset, header.sha1, 0, SHALEN);

	return ret;
}

Entry.unpack(entry : self ref Entry) : array of byte
{
	ret := array[ENTRYSZ + entry.namelen] of byte;

	offset := 0;

	temp := unpackqid(entry.qid);
	copyarray(ret, offset, temp, 0, len temp);
	offset += QIDSZ;
	
	temp = int2bytes(entry.dtype);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	temp = int2bytes(entry.dev);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;
	
	temp = int2bytes(entry.mtime);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	temp = int2bytes(entry.mode);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	temp =  big2bytes(entry.length);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	copyarray(ret, offset, entry.sha1, 0, SHALEN);
	offset += SHALEN;

	temp = int2bytes(entry.namelen);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	temp = array of byte entry.name;
	copyarray(ret, offset, temp, 0, len temp);

	return ret;
}

Entry.pack(buf : array of byte) : ref Entry
{
	entry: Entry;

	offset := 0;

	entry.qid = packqid(buf, offset);
	offset += QIDSZ;

	entry.dtype = bytes2int(buf, offset);
	offset += INTSZ;
	
	entry.dev = bytes2int(buf, offset);
	offset += INTSZ;
	
	entry.mtime = bytes2int(buf, offset);
	offset += INTSZ;

	entry.mode = bytes2int(buf, offset);
	offset += INTSZ;

	entry.length = bytes2big(buf, offset);
	offset += BIGSZ;

	entry.sha1 = buf[offset : offset + SHALEN];
	offset += SHALEN;

	entry.namelen = bytes2int(buf, offset);
	offset += INTSZ;

	return ref entry;
}

packqid(buf: array of byte, offset: int): Sys->Qid
{
 	qid: Sys->Qid;

	qid.path = bytes2big(buf, offset); 
	offset += BIGSZ;

	qid.vers = bytes2int(buf, offset);
	offset += INTSZ;

	qid.qtype = bytes2int(buf, offset);
	
	return qid;
}

initentry(filename: string): ref Entry
{
	entry: Entry;

	(retval, dirstat) := sys->stat(filename);
	if(retval != 0)
	{
		sys->fprint(stderr,"stat error: %r\n");
		return nil;
	}
	
	entry.qid = dirstat.qid;
	entry.dtype = dirstat.dtype;
	entry.dev = dirstat.dev;
	entry.mtime = dirstat.mtime;
	entry.mode = dirstat.mode;
	entry.length = dirstat.length;
	entry.sha1 = filesha1(filename); 
	entry.namelen = len filename;
	entry.name = filename;

	return ref entry;
}



verifypath(path : string) : int
{
	return sys->open(path, Sys->OREAD) != nil;
}

verifyheader(header: ref Header): int
{
#FIXME: Code should be add for verifying sha of the whole file
	return 	header.signature == CACHESIGNATURE &&
		header.version == 1 &&
		header.entriescnt >= 0;
}

unpackqid(qid : Sys->Qid) : array of byte
{
	ret := array[QIDSZ] of byte;
	
	offset := 0;

	temp := big2bytes(qid.path);
	copyarray(ret, 0, temp, 0, len temp);
	offset += len temp;

	temp = int2bytes(qid.vers);
	copyarray(ret, offset, temp, 0, len temp);
	offset += len temp;

	temp = int2bytes(qid.qtype);
	copyarray(ret, offset, temp, 0, len temp);

	return ret;
}

copyentry(dst, src: ref Entry)
{
	dst.qid = src.qid;
	dst.dtype = src.dtype;
	dst.dev = src.dev;
	dst.mtime = src.mtime;
	dst.mode = src.mode;
	dst.length = src.length;
	dst.sha1 = src.sha1;
	dst.namelen = src.namelen;
	dst.name = src.name;
}	
