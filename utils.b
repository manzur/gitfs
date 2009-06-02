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

writeblobfile(path: string): int
{

	fd := sys->open(path, Sys->OREAD);
	if(fd == nil)
	{
		return -1;
	}

	(ret, dirstat) := sys->stat(path);
	if(ret != 0)
	{
		sys->print("error in getting stat information: %r\n");
		return -1;
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
					buf = array of byte sys->sprint("blob %bd", filesize);
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
				return 1;
		}
	}
		
	sha := bufsha1(old);		    
	save2file(string2path(sha2string(sha)), old);

	return 0;
	
}

string2path(filename: string): string
{
	return "objects/" + filename[:2] + "/" + filename[2:];
}

sha2string(sha: array of byte): string
{
	ret : string = "";
	for(i := 0; i < SHALEN; ++i)
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
	fd := sys->create(path, Sys->OWRITE, 644);
	if(fd == nil || sys->write(fd, buf, len buf) != len buf)
		return 1;
	return 0;
}

readsha1file(path: string): array of byte
{
	return array[0] of byte;
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
