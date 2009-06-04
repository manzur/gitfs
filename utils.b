implement Utils;

include "utils.m";

include "sys.m";
	sys: Sys;

include "draw.m";


include "keyring.m";
	keyring: Keyring;
		
include "filter.m";
	inflate: Filter;
	deflate: Filter;



hex := array[16] of {"0","1","2", "3", "4", "5", "6", "7", "8", "9",
			"a","b","c", "d", "e", "f"};


init()
{
	sys = load Sys Sys->PATH;
	keyring = load Keyring Keyring->PATH;
	inflate = load Filter Filter->INFLATEPATH;
	deflate = load Filter Filter->DEFLATEPATH;
	inflate->init();
	deflate->init();
}

writeblobfile(path: string): array of byte
{

	fd := sys->open(path, Sys->OREAD);
	if(fd == nil)
	{
		return nil;
	}

	(ret, dirstat) := sys->stat(path);
	if(ret != 0)
	{
		sys->print("error in getting stat information: %r\n");
		return nil;
	}

	filesize := dirstat.length;

	rqchan := deflate->start("z");
	old := array[0] of byte;

	meta := 1;

mainloop:
	while(1)
	{
		pick rq := <-rqchan
		{
			Finished => if(len rq.buf > 0) 
					sys->print("Data remained\n");
				    break mainloop;

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;

			Fill => 
				cnt := len rq.buf;
				buf := array[cnt] of byte;
				if(meta)
				{
					buf1 := array of byte sys->sprint("blob %bd", filesize);
					buf = array[len buf1 + 1] of byte;
					buf[:] = buf1;
					buf[len buf1] = byte 0;
					cnt = len buf;
					meta = 0;
				}
				else
				{
					cnt = sys->read(fd, buf, cnt);
				}
				rq.buf[:] = buf[:];
				rq.reply <-= cnt;

			Error =>
				sys->print("error ocurred: %s\n", rq.e);
				return nil;
		}
	}
		
	sha := bufsha1(old);		    
	save2file(string2path(sha2string(sha)), old);

	return sha;
	
}

readsha1file(shafilename: string): (string, int, array of byte)
{
	fd := sys->open("objects/"+ shafilename[:2] + "/" + shafilename[2:], Sys->OREAD);
	if(fd == nil)
	{
		sys->print("file note found\n");
		return ("", 0, nil);
	}

	rqchan := inflate->start("z");
	old := array[0] of byte;

mainloop:
	while(1)
	{
		pick rq := <-rqchan
		{
			Finished => if(len rq.buf > 0) 
					sys->print("Data remained\n");
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
				sys->print("error ocurred: %s\n", rq.e);
				return ("", 0, nil);
		}
	}
	
		
	for(i:= 0; i < len old; i++)
	{
		if(old[i] == byte 0)
			break;
	}

	sys->print("o is located at: %d of %d\n", i, len old);
	if(i < 0 || i >= len old)
	{
		sys->print("wrong file format\n");
		return ("",0,nil);
	}

	pos := strchr(string old[:i], ' ');

	sys->print("pos is %d\n", pos);
	sys->print("bytes2int result: %d\n",bytes2int(old, pos + 1));

	return (string old[:pos], bytes2int(old, pos + 1), old[i+1:]);

}

strchr(s: string, ch: int): int
{
	for(i := 0; i < len s; i++)
	{
		if(s[i] == ch)
			return i;
	}
	return -1;
}

string2path(filename: string): string
{
	return "objects/" + filename[:2] + "/" + filename[2:];
}

sha2string(sha: array of byte): string
{
	ret : string = "";
	for(i := 0; i < SHALEN; i++)
	{
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

exists(shaname: string): int
{
	return sys->open(string2path(shaname), Sys->OREAD) != nil;
}


filesha1(filename: string): array of byte
{
	fd := sys->open(filename, Sys->OREAD);
	if(fd == nil)
	{
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

save2file(path: string, buf: array of byte): int
{
	fd := sys->create(path, Sys->OWRITE, 8r644);
	if(fd == nil || sys->write(fd, buf, len buf) != len buf)
		return 1;
	return 0;
}


int2string(num: int): string
{
	sys = load Sys Sys->PATH;
	ret := "";
	do
	{
		ret = hex[num % 10] + ret;
		num /= 10;
	}while(num > 0);
	return ret;
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

copyarray(dst : array of byte, doffset : int, src : array of byte, soffset, count : int)
{
	for(i := 0; i < count; i++)
		dst[i + doffset] = src[i + soffset];
}


