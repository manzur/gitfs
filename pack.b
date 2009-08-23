implement Packmod;

include "gitfs.m";
include "mods.m";
include "modules.m";

mods: Mods;

hex := array[16] of {"0","1","2", "3", "4", "5", "6", "7", "8", "9",
			"a","b","c", "d", "e", "f"};

Packfile: adt{
	count: int;
	path: string;
};

Indexentry: adt{
	offset: big;
	crc32: int;
	sha1: array of byte;
	packfile: string;
};

entries: ref Table[list of ref Indexentry];

#Magic key for index version 2 and pack
imagic := array[4] of {byte 16rff, byte 16r74, byte 16r4f, byte 16r63};
pmagic := array[4] of {byte 16r50, byte 16r41, byte 16r43, byte 16r4b};

indexcount := 0;
init(m: Mods)
{
	mods = m;
	entries = Table[list of ref Indexentry].new(37, nil);
	readindexfiles(repopath + ".git/objects/pack");
	sys->print("%d pack files were read\n", indexcount);
	printallentries();
}

exists(sha1file: string): int
{
	sys->print("UUUUU\n");
	sha1 := utils->string2sha(sha1file);
	h := hash(sha1);
	l := entries.find(h);
	sys->print("entries cnt: %d/%d\n", len l, len entries.all());
	pp := entries.all();
	while(pp != nil){
		list1 := hd pp;
		while(list1 != nil){
			sys->print("sha1: %s\n", sha2string((hd list1).sha1));
			list1 = tl list1;
		}
		pp = tl pp;
	}
	while(l != nil){
		if(eqarray((hd l).sha1, sha1))
			return 1;
		l = tl l;
	}
	return 0;
}

readpackedobject(sha1: string): (string, int, array of byte)
{
	sys->print("Yeah, I'm here!\n");
	(ret, elem) := search(str2sha1(sha1));
	if(ret == -1){ 
		sys->fprint(sys->fildes(2), "there's no such sha1: %s\n", sha1);
		return (nil, 0, nil);
	}
	
	sys->print("offset=>%bd\n", elem.offset);
	return readbyoffset(elem.packfile, elem.offset);
}

readindexfiles(path: string)
{
	(dirs, cnt) := readdir->init(path, Readdir->NAME);
	for(i := 0; i < cnt; i++){
		fullpath := sys->sprint("%s/%s", path, dirs[i].name);
		if(!(dirs[i].mode & Sys->DMDIR) & isindexfile(fullpath)){
			process(fullpath);
			indexcount++;
		}
	}
}

printallentries()
{
	l := entries.all();
	while(l != nil){
		list1 := hd l;
		while(list1 != nil){
			elem := hd list1;
			sys->print("Sha1: %s; offset: %bd\n", sha2string(elem.sha1), elem.offset);
			list1 = tl list1;
		}
		l = tl l;
	}
}

process(path: string)
{
	sys->print("pack/process: %s\n", path);
	version := 1;
	buf := array[Sys->ATOMICIO] of byte;
	fd := sys->open(path, Sys->OREAD);
	state: ref Keyring->DigestState = nil;
	
	#checking packfile for the current index file
	packpath := sys->sprint("%s.pack", path[:len path - 4]);
	(ret, dir) := sys->stat(packpath);
	if(ret == -1){
		sys->fprint(sys->fildes(2), "no pack file for the index %s\n", path);
		return;
	}

	#checking index file for the minimal size
	#index should be bigger than 
	#<fan-out table size> + <at least one index entry> + <sha1 of the file>
	#256 * 4 + 24 + 20
	(ret, dir) = sys->fstat(fd);
	if(dir.length < big (256 * 4 + 24 + 20)){
		return;
	}

	#checking version of the index file
	state = read(fd, buf, 4, state);

	if(eqarray(buf[:4], imagic)){
		state = read(fd, buf, 4, state);
		if((version = bytes2int(buf, 0, 4)) != 2){
			sys->fprint(sys->fildes(2), "index version error for %s", path);
			exit;
		}
	}

	#skipping fan-out table
	for(i := 0; i < 255; i++){
		state = read(fd, buf, 4, state);
	}

	#reading total count of the entries
	state = read(fd, buf, 4, state);
	total := bytes2int(buf, 0, 4);
	
	sys->print("Version: %d; total %d\n", version, total);
	if(version == 1){
		for(i := 1; i <= total; i++){
			state = read(fd, buf, 4, state);
			offset := bytes2int(buf, 0, 4);
			state = read(fd, buf, 20, state);
			entry := ref Indexentry(big offset, 0, buf[:20], packpath);
			addentry(entry);
		}
	}
	else {
		#absolute offsets for sha1, crc32, offset tables
		#sha1off := sys->seek(fd, big 0, Sys->SEEKRELA); 
		#crcoff := sys->seek(fd, big (total * 20), Sys->SEEKRELA);
		#offoff := sys->seek(fd, big (total * 4), Sys->SEEKRELA);
		
		l: list of ref Indexentry = nil;
		for(i := 0; i < total; i++){
			state = read(fd, buf, 20, state);
			sha1 := array[20] of byte;
			sha1[:] = buf[:20];
			#sys->print("===>sha1: %s\n", sha2string(sha1));
			l = ref Indexentry(big 0, 0, sha1, packpath) :: l;
		}

		l1 := l;
		l = nil;
		for(i = 0; i < total; i++){
			state = read(fd, buf, 4, state);
			crc32 := bytes2int(buf, 0, 4);
			entry := hd l1;
			entry.crc32 = crc32;
			l = entry :: l;
			l1 = tl l1;
		}
		l1 = l;
		l = nil;
		for(i = 0; i < total; i++){	
			state = read(fd, buf, 4, state);
			offset := bytes2int(buf, 0, 4);
			entry := hd l1;
			entry.offset = big offset;
			l = entry :: l;
			l1 = tl l1;
		}	
		
		while(l != nil){
			entry := hd l;
			addentry(entry);
			l = tl l;
		}
	}

	state = read(fd, buf, 20, state);
	sys->print("packs sha1:%s\n", sha2string(buf[:20]));

	#reading sha1 
	sys->read(fd, buf, 20);
	sha1 := array[20] of byte;
	sha1finish(fd, sha1, state);

	sys->print("sha1: %s\n", sha2string(buf[:20]));
	sys->print("real sha1: %s\n", sha2string(sha1));

	#FIXME: add code for checking sha1 correctness
}

addentry(entry: ref Indexentry)
{
	h := hash(entry.sha1);
	if((l := entries.find(h)) != nil){
		entries.del(h);
		l = entry :: l;
		entries.add(h, l);
	}
	else{
		entries.add(h, entry :: nil);
	}
}

hash(sha1: array of byte): int
{
	return (int sha1[1] << 16) 
		| (int sha1[18] << 8) | (int sha1[19]);
}

sha1finish(fd: ref Sys->FD, sha1: array of byte, state: ref Keyring->DigestState)
{
	keyring->sha1(nil, 0, sha1, state);
}

read(fd: ref Sys->FD, buf: array of byte, size: int, state: ref Keyring->DigestState): ref Keyring->DigestState
{
	cnt := sys->read(fd, buf, size);
	state = keyring->sha1(buf, cnt, nil, state);
	return state;
}

isindexfile(path: string): int
{
	if(len path > 3 && path[len path - 4:] == ".idx")
		return 1;
	
	return 0;
}

readbyoffset(packpath: string, off: big): (string, int, array of byte)
{
	packfd := sys->open(packpath, Sys->OREAD);

	#moving to the beginning of the offset entry 
	sys->seek(packfd, off, Sys->SEEKSTART);
	b := array[1] of byte;
	sys->read(packfd, b, len b);
	b0 := int b[0];

	#extracting type of the sha1
	t := (b0 & 16r70) >> 4;
	size := b0 & 16r0f;
	sys->print("b is %x; size is %d\n", int b0, size);

	sys->fprint(sys->fildes(2), "==>%d ", int b0);
	if(b0 & 16r80){
		shift := 4;
		do{
			if(sys->read(packfd, b, len b) != len b)
				break;
			b0 = int b[0];
			sys->fprint(sys->fildes(2), "==>%d ", int b0);
			size += (b0 & 16r7f ) << shift;
			shift += 7;
		}while(b0 & 16r80);
	}

	unpacked: array of byte;
	sys->print("TYPE: %s\n", typefromint(t));
	sys->print("size is %d\n", size);
	if(t == 6){
		#OFS_DELTA
		sys->read(packfd, b, 1);
		offset := big (int b[0] & 127);
		while(int b[0] & 16r80){
			sys->read(packfd, b, 1);
			offset += big 1;
			offset = (offset << 7) + big (int b[0] & 16r7f);
		}
		offset = off - offset;
		delta := unpack(packfd, size);
		basebuf := readbyoffset(packpath, big offset).t2;
		unpacked = patch(basebuf, delta);
	}
	else if(t == 7){
		#OFS_REF_DELTA
		sh := array[20] of byte;
		sys->read(packfd, sh, len sh);
		sys->print("base sha1: %s\n", sha2string(sh));
		delta := unpack(packfd, size);
		basebuf := readpackedobject(sha2string(sh)).t2;
		unpacked = patch(basebuf, delta);	
	}
	else{
		unpacked = unpack(packfd, size);
	}

	return (typefromint(t), size, unpacked);
}


types := array[8] of {"none", "commit", "tree", "blob", "tag", "error", "ofs_delta", "ref_delta"};

typefromint(t: int): string
{
	return types[t & 16r7];
}

headersize(buf: array of byte): (int, array of byte)
{
	shift := i := size := 0;
	do {	
		size |= (int buf[i] & 16r7f) << shift;
		shift += 7;
	} while((++i < len buf) && (int buf[i-1] & 16r80));

	if(i >= len buf) 
		return (size, nil);
	return (size, buf[i:]);
}

patch(basebuf, delta: array of byte): array of byte
{
	i := offset := 0;
	inputsize, outputsize: int;
	(inputsize, delta) = headersize(delta);
	(outputsize, delta) = headersize(delta);

	output := array[outputsize] of byte;
	size := outputsize;
	while(i < len delta){
		b0 := int delta[i++];
		if(b0 & 16r80){
			sys->print("cmd is copy\n");
			off := sz := 0;
			if(b0 & 16r01) off = int delta[i++];
			if(b0 & 16r02) off |= int delta[i++] << 8;
			if(b0 & 16r04) off |= int delta[i++] << 16;
			if(b0 & 16r08) off |= int delta[i++] << 24;
			if(b0 & 16r10) sz |= int delta[i++];
			if(b0 & 16r20) sz |= int delta[i++] << 8;
			if(b0 & 16r40) sz |= int delta[i++] << 16;
			if(sz > size){
				sys->fprint(sys->fildes(2), "size of chunk exceeds overall size\n");
				return nil;
			}
			output[offset:] = basebuf[off:off+sz];
			offset += sz;
			size -= sz;
		}
		else if (b0){
			sys->print("no cmd; size is %d\n", b0);
			if(b0 + i > len delta){
				sys->fprint(sys->fildes(2), "size of chunk exceeds overall size\n");
				break;	
			}
			output[offset:] = delta[i:i + b0];
			offset += b0;
			i += b0;
			size -= b0;
		}
	}

	return output;
}

unpack(fd: ref Sys->FD, size: int): array of byte
{
	rqchan := inflatefilter->start("z");
	unpacked := array[size] of byte;
	buf := array[Sys->ATOMICIO] of byte;
	offset := 0;

mainloop:
	while(1){
		pick rq := <-rqchan
		{
			Finished => if(len rq.buf > 0){ 
					sys->print("Data remained:%r\n");
					sys->seek(fd, big -len rq.buf, Sys->SEEKRELA);
				    }
				    break mainloop;

			Result => 
				unpacked[offset:] = rq.buf;
				offset += len rq.buf;
				rq.reply <-= 0;

			Fill => 
				rq.reply <-= sys->read(fd, rq.buf, len rq.buf);

			Error =>
				sys->print("error ocurred: %s\n", rq.e);
				return  nil;
		}
	}

	return unpacked;
}

str2sha1(sha1: string): array of byte
{
	ret := array[20] of byte;
	for(i := 0; i + 1 < len sha1; i += 2){
		ret[i / 2] = (hex2byte(sha1[i]) << 4) | hex2byte(sha1[i+1]); 	
	}
	return ret;
}

hex2byte(a: int): byte
{
	ret: byte;
	if(a >= 'a' && a <= 'f') 
		ret = byte(a - 'a' + 10);
	else if(a >= 'A' && a <= 'F')
		ret = byte(a - 'A' + 10);
	else 
		ret = byte(a - '0');

	return ret;
}

search(sha1: array of byte): (int, ref Indexentry)
{
	elem: ref Indexentry = nil;
	h := hash(sha1);
	l := entries.find(h);
	while(l != nil){
		if(eqarray((hd l).sha1, sha1)){
			elem = hd l;
			break;
		}

		l = tl l;
	}
	
	if(elem != nil){
		sys->print("mega offseT: %bd\n", elem.offset);
		return (0, elem);
	}

	return (-1, nil);
}

sha2string(sha: array of byte): string
{
	ret : string = "";
	for(i := 0; i < 20; i++){
		i1 : int = int sha[i] & 16rf;
		i2 : int = (int sha[i] & 16rf0) >> 4;
		ret += hex[i2] + hex[i1];
	}
	return ret;
}


eqarray(a, b: array of byte): int
{
	if(len a != len b)
		return 0; 

	for(i := 0; i < len a; i++){
		if(a[i] != b[i]){
			return 0;
		}
	}

	return 1;
}

bytes2int(a: array of byte, start, end: int): int
{
	ret := 0;
	for(i := start; i < end; i++){
		ret = ret << 8 | int a[i];
	}
	return ret;
}
