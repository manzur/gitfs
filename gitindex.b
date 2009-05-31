implement Gitindex;

include "sys.m";
	sys : Sys;

include "tables.m";
	tables: Tables;

Strhash : import tables;


include "gitindex.m";
	gitindex : Gitindex;

include "keyring.m";
	keyring: Keyring;


stderr : ref Sys->FD;

Index.new(): ref Index
{
	ret: Index;
	ret.header = nil;
	ret.entries = nil;
	ret.hashcap = 0;
	return ref ret;
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

	entry := initentry(path);
	index.entries.add(entry.name, entry);
	return 0;
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

#return - number of elements read from index file
Index.readindex(index: self ref Index, path : string) : int
{
	tables = load Tables Tables->PATH;
	sys = load Sys Sys->PATH;
	
	stderr = sys->fildes(2);
	
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

#return - number of elements written to the index file
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
	}

	sys->print("wrote to file\n");
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

bytes2int(buf: array of byte, offset: int): int
{
	ret := 0;
	for(i := 0; i < INTSZ; i++)
		ret |= int(buf[offset + i]) << (i * 8); 
	return ret;
}

bytes2big(buf: array of byte, offset: int): big
{
	return (big bytes2int(buf,offset + INTSZ) << INTSZ * 8)| 
	       (big bytes2int(buf, offset));

}

big2bytes(n: big): array of byte
{
	ret := array[BIGSZ] of byte;

	part1 := int (n >> INTSZ * 8);
	part2 := int n;
	copyarray(ret, 0, int2bytes(part2), 0, INTSZ);
	copyarray(ret, INTSZ, int2bytes(part1), 0, INTSZ);
	
	return ret;
}

int2bytes(number: int): array of byte
{
	ret := array[INTSZ] of byte;

	ret[0] = byte (number & 16rff);
	number >>= 8;

	ret[1] = byte (number & 16rff);
	number >>= 8;
	
	ret[2] = byte (number & 16rff);
	number >>= 8;
	
	ret[3] = byte (number & 16rff);
	
	return ret;
}



allocnr(num: int): int
{
	return (num + 16) * 3 / 2;
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
	entry.length = dirstat.length;
	entry.sha1 = filesha1(filename); 
	entry.namelen = len filename;
	entry.name = filename;

	return ref entry;
}

filesha1(filename: string): array of byte
{
	fd := sys->open(filename, Sys->OREAD);
	if(fd == nil)
	{
		sys->fprint(stderr,"open file error: %r\n");
		return nil;
	}

	buf := array[Sys->ATOMICIO] of byte;
	cnt : int;
	state : ref Keyring->DigestState = nil;
	while((cnt = sys->read(fd, buf, Sys->ATOMICIO)) > 0)
	{
		state = keyring->sha1(buf,cnt, nil, state);		
	}
	sha := array[SHALEN] of byte;
	keyring->sha1(buf,0, sha, state);
	
	return sha;
}

verifypath(path : string) : int
{
	return sys->open(path, Sys->OREAD) != nil;
}

verifyheader(header: ref Header): int
{
#Code should be add for verifying sha of the whole file
	keyring = load Keyring Keyring->PATH;
	return 	header.signature == CACHESIGNATURE &&
		header.version == 1 &&
		header.entriescnt >= 0;
}

copyarray(dst : array of byte, doffset : int, src : array of byte, soffset, count : int)
{
	for(i := 0; i < count; i++)
	{
		dst[i + doffset] = src[i + soffset];
	}
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

