implement Utils;

include "gitfs.m";
include "mods.m";
include "modules.m";

Index, Entry: import gitindex;
sprint: import sys;
cleandir, dirname, makeabsentdirs, makepathabsolute, string2path: import pathmod;	

hex := array[16] of {"0","1","2", "3", "4", "5", "6", "7", "8", "9",
			"a","b","c", "d", "e", "f"};

stderr: ref Sys->FD;

mods: Mods;

init(m: Mods)
{
	mods = m;
	inflatefilter->init();
	deflatefilter->init();
	stderr = sys->fildes(2);
}

writesha1file(ch: chan of (int, array of byte))
{
#FIXME: make deflate level more configurable
	rqchan := deflatefilter->start("z1");
	old := array[0] of byte;
	buf: array of byte; sz := 0;
	state: ref Keyring->DigestState;
mainloop:
	while(1)
	{
		pick rq := <-rqchan
		{
			Finished => 
				if(len rq.buf > 0) 
					debugmsg("Data remained\n");
				break mainloop;

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;

			Fill => 
				(sz, buf) = <-ch;
				state = keyring->sha1(buf, sz, nil, state);
				rq.buf[:] = buf[:];
				rq.reply <-= sz;

			Error =>
				error(sprint("error ocurred: %s\n", rq.e));
				return;
		}
	}
		
	sha1 := array[SHALEN] of byte;
	keyring->sha1(nil, 0, sha1, state);

#FIXME: check the return of save2file
	save2file(string2path(sha2string(sha1)), old);
	ch <-= (SHALEN, sha1);	
}

readsha1file(shafilename: string): (string, int, array of byte)
{
	debugmsg("in readshafile\n");
	fd := sys->open(string2path(shafilename), Sys->OREAD);
	if(fd == nil){
		(filetype, filesize, filebuf) := packmod->readpackedobject(shafilename);
		if(filebuf == nil){
			error(sprint("file(%s) not found\n", string2path(shafilename)));
			return ("", 0, nil);
		}
		return (filetype, filesize, filebuf);
	}
	rqchan := inflatefilter->start("z");
	old := array[0] of byte;

mainloop:
	while(1){
		pick rq := <-rqchan
		{
			Finished => 
				if(len rq.buf > 0) 
					debugmsg("Data remained\n");
				break mainloop;

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;

			Fill => 
				buf := array[len rq.buf] of byte;
				cnt := sys->read(fd, buf, len buf);
				rq.buf[:] = buf[:];
				rq.reply <-= cnt;

			Error =>
				error(sprint("error ocurred: %s\n", rq.e));
				return ("", 0, nil);
		}
	}
	
	for(i := 0; i < len old; i++){
		if(old[i] == byte 0)
			break;
	}

	if(i < 0 || i >= len old){
		error("wrong file format\n");
		return ("",0,nil);
	}

	pos := strchr(string old[:i], ' ');
	return (string old[:pos], asbytes2int(old, pos + 1, i), old[i+1:]);
}

replacechar(s: string, c1, c2: int): string
{
	for(i := 0; i < len s; i++){
		if(s[i] == c1) s[i] = c2;
	}
	return s;
}

strchr(s: string, ch: int): int
{
	for(i := 0; i < len s; i++){
		if(s[i] == ch)
			return i;
	}
	return -1;
}

objectstat(name: string): (int, Sys->Dir)
{
	(ret, dirstat) := sys->stat(string2path(name));
	if(ret == -1){
		return packmod->stat(name);
	}

	return (ret, dirstat);
}


sha2string(sha: array of byte): string
{
	ret := "";
	for(i := 0; i < SHALEN; i++){
		i1 : int = int sha[i] & 16rf;
		i2 : int = (int sha[i] & 16rf0) >> 4;
		ret += hex[i2] + hex[i1];
	}

	return ret;
}

bufsha1(buf: array of byte): array of byte
{
	sha := array[SHALEN] of byte;
	keyring->sha1(buf, len buf, sha, nil);

	return sha;
}


trim(s: string): string
{
	for(i := 0; i < len s && (s[i] == ' ' || s[i] == '\t'); i++);
	for(j := len s; j > 0 && (s[j-1] == ' ' || s[j-1] == '\t'); j--);
	if(j < i)
		j = i;
	return s[i:j];
}

onlyspace(s: string): int
{
	if(s == nil) return 0;
	for(i := 0; i < len s; i++){
		if(s[i] != ' ' || s[i] != '\t')
			return 0; 
	}
	return 0;
}

mergesort(l: list of ref Entry): list of ref Entry
{
	if(len l > 1)
	{
		middle := len l / 2;
		(l1, l2) := partitionbypos(l, middle);
		l1 = mergesort(l1);
		l2 = mergesort(l2);
		return merge(l1, l2);
	}
	return l;
}

merge(l1, l2: list of ref Entry): list of ref Entry
{
	if(l1 == nil)
		return l2;
	if(l2 == nil)
		return l1;
	
	l: list of ref Entry = nil;
	while(l1 != nil && l2 != nil)
	{
		if((hd l1).compare(hd l2) == 1)
		{
			l = hd l1 :: l;
			l1 = tl l1;
			continue;
		}
		l = hd l2 :: l;
		l2 = tl l2;
	}

	while(l1 != nil)
	{
		l = hd l1 :: l;
		l1 = tl l1;
	}

	while(l2 != nil)
	{
		l = hd l2 :: l;
		l2 = tl l2;
	}

	l = reverse(l);
	return l;
}

partitionbypos(l: list of ref Entry, pos: int): (list of ref Entry, list of ref Entry)
{
	if(len l < pos)
		return (l, nil);
	l1 : list of ref Entry = nil;
	for(i := 0; i < pos; i++)
	{
		l1 = hd l :: l1;
		l = tl l;
	}
	return (reverse(l1), l);
}

reverse(l: list of ref Entry): list of ref Entry
{
	l1: list of ref Entry = nil;
	while(l != nil)
	{
		l1 = hd l :: l1;
		l = tl l;
	}

	return l1;
}

filesha1(filename: string): array of byte
{
	fd := sys->open(filename, Sys->OREAD);
	if(fd == nil){
		return nil;
	}

	buf := array[Sys->ATOMICIO] of byte;
	cnt : int; state : ref Keyring->DigestState = nil;
	while((cnt = sys->read(fd, buf, Sys->ATOMICIO)) > 0){
		state = keyring->sha1(buf,cnt, nil, state);		
	}
	sha := array[SHALEN] of byte;
	keyring->sha1(buf,0, sha, state);
	
	return sha;
}

ltrim(s: string): string
{
	i := 0;
	while(s != nil && s[i] == ' ')
		i++;
		
	return s[i:];
}

save2file(path: string, buf: array of byte): int
{
	makeabsentdirs(dirname(path));
	fd := sys->create(path, Sys->OWRITE, 8r644);
	if(fd == nil || sys->write(fd, buf, len buf) != len buf)
	{
		return 1;
	}
	return 0;
}


int2string(num: int): string
{
	sys = load Sys Sys->PATH;
	ret := "";
	do{
		ret = hex[num % 10] + ret;
		num /= 10;
	}while(num > 0);
	return ret;
}

bytes2int(buf: array of byte, offset: int): int
{
	ret := 0;
	for(i := 0; i < INTSZ; i++)
		ret = (ret << 8) | int(buf[offset + i]); 

	return ret;
}

asbytes2int(buf: array of byte, offset, end: int): int
{
	ret := 0;
	for(i := 0; i + offset < end; i++)
		ret = (ret << 8) | int(buf[offset + i] - byte '0'); 
	return ret;
}

bytes2big(buf: array of byte, offset: int): big
{
	return (big bytes2int(buf, offset) << (INTSZ * 8)) |
		(big bytes2int(buf,offset + INTSZ));
}

big2bytes(n: big): array of byte
{
	ret := array[BIGSZ] of byte;

	part1 := int (n >> 32);
	part2 := int n;

	ret[:] = int2bytes(part1);
	ret[INTSZ:] = int2bytes(part2);
	
	return ret;
}

int2bytes(number: int): array of byte
{
	ret := array[INTSZ] of byte;

	ret[3] = byte (number & 16rff);
	number >>= 8;

	ret[2] = byte (number & 16rff);
	number >>= 8;
	
	ret[1] = byte (number & 16rff);
	number >>= 8;
	
	ret[0] = byte (number & 16rff);
	
	return ret;
}

htons(n: int): int
{
	part1 := (n & 16rff00);
	part2 := (n & 16r00ff);

	return part2 | part1;
}

ntohs(n: int): int
{
	return htons(n);
}

htonl(n: int): int
{
	part2 := (n & 16rffff);
	n >>= 16;
	part1 := (n & 16rffff);

	return (htons(part1) << 16) | htons(part2);
}

ntohl(n: int): int
{
	return htonl(n);
}

htonb(b: big): big
{
	part2 := (int b & ~0);
	b >>= 32;
	part1 := (int b & ~0);

	return big ((part1 << 32) | part2);
}

ntohb(b: big): big
{
	return htonb(b);
}

allocnr(num: int): int
{
	return (num + 16) * 3 / 2;
}

copyarray(dst : array of byte, doffset : int, src : array of byte, soffset, count : int)
{
	for(i := 0; i < count; i++)
		dst[i + doffset] = src[i + soffset];
}

equalqids(q1, q2: Sys->Qid): int
{
	return q1.path  == q2.path &&
	       q1.vers  == q2.vers &&
	       q1.qtype == q2.qtype;    	
}

extractfile(shafilename: string): string
{
	tempfile := "/tmp/gitfile";
	buf := (readsha1file(shafilename)).t2;	
	fd := sys->create(tempfile, Sys->OWRITE, 8r644);
	
	offset := 0;
	while(offset < len buf)
		offset += sys->write(fd, buf[offset:len buf], len buf - offset);

	return tempfile;
}

iswhitespace(s: string): int
{
	return s == "\n" || s == "\t" || s == " ";
}

strip(s: string): string
{
	if(s != nil && s[len s-1] == '\n')
		return s[:len s - 1];
	return s;
}

readline(ibuf: ref Iobuf): string
{
	ret := ""; i := 0;
	while(1)
	{
		c := ibuf.getc();
		if(c == '\n' || c < 0)
			break;
		ret[i++] = c;
	}

	return ret;
}

getline(fd: ref Sys->FD): string
{
	s: string; cnt: int;
	buf := array[1] of byte;
	while(1){
		cnt = sys->read(fd, buf, len buf);
		if(cnt <= 0 || buf[0] == byte '\n')
			break;
		s += string buf;
	}
	if(cnt <= 0)
		return nil;
	s[len s] = '\n';

	return s;
}


equalshas(sha1, sha2: array of byte): int
{
	for(i := 0; i < SHALEN; i++){
		if(sha1[i] != sha2[i])
			return 0;
	}
	return 1;
}

isunixdir(mode: int): int
{
	return (mode & 16384) > 0;
}

bytepos(a: array of byte, offset: int, delim: byte): int
{
	for(i := offset; i < len a; i++){
		if(a[i] == delim)
			return i;
	}

	return -1;
}

string2sha(sha1: string): array of byte
{
	ret := array[SHALEN] of byte;
	for(i := 0; i < len ret; i++)
		ret[i] = (hex2byte(sha1[i*2]) << 4) | hex2byte(sha1[i*2+1]);

	return ret;
}

hex2byte(val: int): byte
{
	if(val >= '0' && val <= '9')
		return byte (val - '0');
	
	if(val >= 'A' && val <= 'F')	
		return byte (val - 'A' + 10);

	return byte (val - 'a' + 10);
}

debugmsg(msg: string)
{
	if(debug == 1)
		sys->fprint(stderr, "%s", msg);
}

error(msg: string)
{
	sys->fprint(stderr, "%s", msg);
}

splitl(s: string, sep: string, count: int): (string, string)
{
	if(count == 1)
		return stringmod->splitl(s, sep);

	(s1, s2) := splitl(s, sep, count - 1);	
	if(len s2 <= 1 ) 
		return (s1, s2);
	s2 = s2[1:];
	(s3, s4) := stringmod->splitl(s2, sep);
	s1 += sep + s3;

	return (s1, s4);
}

comparebytes(a, b: array of byte): int
{
	len1 := len a;

	if(len1 < len b)
		return -1;
	
	if(len1 > len b)
		return 1;
	
	for(i := 0; i < len1; i++){
		if(a[i] < b[i])
			return -1;
		else if(a[i] > b[i])
			return 1;
	}

	return 0;
}

cutprefix(prefix, s: string): string
{
	if(len prefix > len s)
		return nil;
	
	if(prefix == s[:len prefix]){
		return s[len prefix:];
	}

	return nil;
}

readint(fd: ref Sys->FD): int
{
	buf := array[4] of byte;
	cnt := sys->read(fd, buf, len buf);

	if(cnt != 4)
		return 0;

	ret := 0;
	for(i := 0; i < len buf; i++){
		ret = ret * 256 + int buf[i];
	}

	return ret;
}


packqid(qid: ref Sys->Qid): array of byte
{
	packedqid := array[QIDSZ] of byte;

	packedqid[:] = big2bytes(qid.path);
	offset := BIGSZ;

	packedqid[offset:] = int2bytes(qid.vers);
	offset += INTSZ;

	packedqid[offset:] = int2bytes(qid.qtype);
	offset += INTSZ;

	return packedqid;
}

readshort(fd: ref Sys->FD): int
{
	buf := array[2] of byte;

	cnt := sys->read(fd, buf, len buf);
	
	if(cnt != 2)
		return 0;

	ret := 0;
	for(i := 0; i < len buf; i++)
		ret = (ret << 8) | int buf[i];
	
	return ret;
}


unpackqid(buf: array of byte, offset: int): Sys->Qid
{
	path := bytes2big(buf, offset);
	offset += BIGSZ;

	vers := bytes2int(buf, offset);
	offset += INTSZ;

	qtype := bytes2int(buf, offset);
	
	return Sys->Qid(path, vers, qtype);
}


mktempfile(filename: string): string
{
	fd := sys->create("/tmp/" + filename, Sys->OWRITE, 8r644);
	if(fd == nil){
		error(sprint("file(%s) coudn't be created\n", filename));
	}
	return "/tmp/" + filename;
}

sizeofrest(fd: ref Sys->FD): big  
{
	curpos := sys->seek(fd, big 0, Sys->SEEKRELA);
	rest := sys->seek(fd, big 0, Sys->SEEKEND) - curpos;
	sys->seek(fd, curpos, Sys->SEEKSTART);

	return rest;
}


