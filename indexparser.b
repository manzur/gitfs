implement Indexparser;

include "sys.m";
	sys : Sys;

include "gitindex.m";
	gitindex : Gitindex;

include "draw.m";

include "arg.m";
	arg : Arg;

Index, Header, Cachetime, Entry : import Gitindex;

index : Index;

ENTRYSIZE : con 62;
CACHETIMESIZE : con 8;
PRINT, ADD : con iota;
SHA_LEN : con 20;

hex := array[16] of {"0","1","2", "3", "4", "5", "6", "7", "8", "9",
			"a","b","c", "d", "e", "f"};



Indexparser : module
{
	init : fn(nil : ref Draw->Context, nil : list of string);
};

init(nil : ref Draw->Context, args : list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	sys->print("Index parser\n");
	arg->init(args);
	action : int;
	fname : string;
	while((c := arg->opt()) != 0)
	{
		case c
		{
			'p' => action = PRINT;
				fname = arg->arg();
			'a' => action = ADD;
				fname = arg->arg();
		}
	}

	read_from_index("index");

	if(action == ADD)
	{
		addtocache(fname);
	}
	else
	{
		printcache(fname);
	}
	outputfilename := "index1";

	write_to_cache(outputfilename);

}

bytestoint(buf : array of byte, offset, count : int) : int
{
	ret : int = 0;
	for(i := 0; i < count; ++i)
	{
		ret |= int(buf[offset + i]) << (i * 8); 
	}
	return ret;
}

inttobytes(number : int) : array of byte
{
	ret := array[4] of byte;
	ret[0] = byte (number & 16rff);
	number >>= 8;
	ret[1] = byte (number & 16rff);
	number >>= 8;
	ret[2] = byte (number & 16rff);
	number >>= 8;
	ret[3] = byte (number & 16rff);
	return ret;
}

extracttime(buf : array of byte, offset : int) : Cachetime
{
	ret : Cachetime;
	ret.sec = bytestoint(buf, offset, 4);
	ret.nsec = bytestoint(buf, offset + 4, 4);
	return ret;
}

sha_to_string(sha : array of byte) : string
{

	ret : string = "";
	b : byte;
	for(i := 0; i < SHA_LEN; ++i)
	{
		i1 : int = int sha[i] & 16rf;
		i2 : int = (int sha[i] & 16rf0) >> 4;
		ret += hex[i2] + hex[i1];
	}
	return ret;
}

extractentry(buf : array of byte) : Entry
{
	entry : Entry;
	entry.ctime = extracttime(buf, 0);
	entry.mtime = extracttime(buf, 8);
	entry.st_dev = bytestoint(buf, 16, 4);
	entry.st_ino = bytestoint(buf, 20, 4);
	entry.st_mode = bytestoint(buf, 24, 4);
	entry.st_uid = bytestoint(buf, 28, 4);
	entry.st_gid = bytestoint(buf, 32,4);
	entry.st_size = bytestoint(buf, 36, 4);
	entry.sha1 = buf[40:40 + SHA_LEN];
	sys->print("sha1\n");
	sys->print("%s\n", sha_to_string(entry.sha1));
	sys->print("\n");

	return entry;
}

allocnr(num : int) : int
{
	return (num + 16) * 3 / 2;
}

read_from_index(filename : string)
{
	indexfd := sys->open(filename, Sys->OREAD);
	if(indexfd == nil)
	{
		sys->print("file access error\n");
		return;
	}
	COUNT : con 32;
	buf := array[COUNT] of byte;
	ret := 0;
	stdout := sys->fildes(1);
	if((ret = sys->read(indexfd, buf, COUNT)) == COUNT)
	{
		index.header.signature = bytestoint(buf,0,4);
		index.header.version = bytestoint(buf,4,4);
		index.header.entries = bytestoint(buf,8,4);

		index.header.sha1 = array[SHA_LEN] of byte;

		index.header.sha1 = buf[12: 12 + SHA_LEN];
	}

	index.entries = array[allocnr(index.header.entries)] of Entry;

	for(i := 0; i < index.header.entries; ++i)
	{
		entrybuf := array[ENTRYSIZE] of byte;
		ret := sys->read(indexfd, entrybuf, ENTRYSIZE);
		
		if(ret != ENTRYSIZE)
		{
			sys->print("index file error\n");
			return;
		}

		entry := extractentry(entrybuf); 
		entry.namelen = array[2] of byte;
		entry.namelen[0] = entrybuf[60];
		entry.namelen[1] = entrybuf[61];
		
		namelen := bytestoint(entrybuf, 60, 2);
		sys->print("==>%d\n", namelen);
		namebuf := array[namelen] of byte;
		sys->read(indexfd, namebuf, namelen);

		entry.name = string namebuf;	
		index.entries[i] = entry;
		sys->print("\n%s\n",entry.name);
	
		remainder : int;
		remainder = (ENTRYSIZE + namelen + 8) & ~7; 
		remainder -= ENTRYSIZE + namelen;
		sys->read(indexfd, buf, remainder);
	}
	

}

printcache(fname : string)
{
	sys->print("in print\n");
	for( i := 0; i < index.header.entries; ++i)
	{
		sys->print("%s\n",index.entries[i].name);
		if(fname != nil && fname != index.entries[i].name) continue;
		sys->print("Name : %s\n", index.entries[i].name);
		sys->print("Size : %d\n", index.entries[i].st_size);
		sys->print("Uid  : %d\n", index.entries[i].st_uid);
		sys->print("Gid  : %d\n", index.entries[i].st_gid);
	}

}

verifypath(fname : string) : int
{
	return 1;
}

copyentries(dst, src : array of Entry, num : int)
{
	for(i := 0; i < num && i < len dst; ++i)
	{
		dst[i] = src[i];
	}
}

calcsha(fname : string) : array of byte
{
	return nil;
}

initentry(fname : string) : Entry
{
	ret : Entry;
	(retval, dirstat) := sys->stat(fname);
	if(retval != 0)
	{
		sys->print("stat error: %r\n");
		return ret;
	}
	ret.ctime.sec = dirstat.mtime; 
	ret.mtime.sec = dirstat.mtime;
	ret.st_dev = dirstat.dev;
	ret.st_ino = int dirstat.qid.path;
	ret.st_mode = dirstat.mode;
	ret.st_uid = 0;
	ret.st_gid = 0; 
	ret.st_size = dirstat.length;
	ret.sha1 = calcsha1(fname); 
	ret.namelen = len fname;
	ret.name = fname;
	return ret;
}

addtocache(fname : string)
{
	if(!verifypath(fname))
	{
		sys->print("wrong path\n");
		return;
	}
	index.header.entries += 1;
	if(index.header.entries >= index.entries_cap)
	{
		temp := index.entries;
		index.entries_cap = allocnr(index.entries_cap);
		index.entries = array[index.entries_cap] of Entry;
		copyentries(index.entries, temp, len temp);
	}
	initentry(fname);
	index.entries[index.header.entries - 1].name = fname;

}

write_to_cache(outputfilename : string)
{
	outfd := sys->create(outputfilename, sys->OWRITE, 8r644);

	if(outfd == nil)
	{
		sys->print("error in opening file for writing %r\n");
		return;
	}

	sys->write(outfd, inttobytes(index.header.signature),4);
	sys->write(outfd, inttobytes(index.header.version), 4);
	sys->write(outfd, inttobytes(index.header.entries), 4);
	
	sys->write(outfd, index.header.sha1, SHA_LEN);
	

	for(i := 0; i < index.header.entries; ++i)
	{
		sys->write(outfd, inttobytes(index.entries[i].ctime.sec),4);
		sys->write(outfd, inttobytes(index.entries[i].ctime.nsec),4);
		sys->write(outfd, inttobytes(index.entries[i].mtime.sec),4);
		sys->write(outfd, inttobytes(index.entries[i].mtime.nsec),4);
		sys->write(outfd, inttobytes(index.entries[i].st_dev),4);
		sys->write(outfd, inttobytes(index.entries[i].st_ino),4);
		sys->write(outfd, inttobytes(index.entries[i].st_mode),4);
		sys->write(outfd, inttobytes(index.entries[i].st_uid),4);
		sys->write(outfd, inttobytes(index.entries[i].st_gid),4);			sys->write(outfd, inttobytes(index.entries[i].st_size),4);
		sys->write(outfd, index.entries[i].sha1, SHA_LEN);
		sys->write(outfd, index.entries[i].namelen,2);
		name_buf := array of byte index.entries[i].name;
		sys->write(outfd, name_buf, len name_buf);

		remainder : int;
		remainder = (ENTRYSIZE + bytestoint(index.entries[i].namelen,0,2) + 8) & ~7; 
		
		remainder -= ENTRYSIZE + bytestoint(index.entries[i].namelen,0,2);
		sys->write(outfd, array[remainder] of byte, remainder);

	}
	outfd = nil;
}
