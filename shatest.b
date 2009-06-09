implement Shatest;

include "sys.m";
	sys: Sys;

include "draw.m";

include "keyring.m";
	keyring: Keyring;

Shatest: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

SHALEN: con 20;

hex := array[16] of {"0","1","2", "3", "4", "5", "6", "7", "8", "9",
                        "a","b","c", "d", "e", "f"};


init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	keyring = load Keyring Keyring->PATH;
	fd := sys->open("text1", Sys->OREAD);
	buf := array[Sys->ATOMICIO] of byte;
	state: ref Keyring->DigestState = nil;
#	while((cnt := sys->read(fd, buf, len buf)) > 0)
#	{
#		sys->print("\naa\n");
#		state = keyring->sha1(buf, cnt, nil, state);
#		
#	}
	sha := array[20] of byte;
	cnt := sys->read(fd, buf, len buf);
	sys->write(sys->fildes(1), buf, cnt);
#	sys->print("---%s---", string buf);
#	st := keyring->sha1(buf, cnt, sha, nil);
	st := keyring->sha1(buf, cnt, nil, nil);
	keyring->sha1(buf,0,sha,st);
	sys->print("%s\n",string sha );
	sys->print("%s", sha2string(sha));
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

