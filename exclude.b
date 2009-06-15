implement Exclude;

include "exclude.m";

include "sys.m";
	sys: Sys;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "filepat.m";
	filepat: Filepat;

stderr: ref Sys->FD;

#int is flag for pattern negation: 0 for normal pattern; 1 is for negated
#where string is pattern
patterns: list of (int, string) = nil;

init()
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	filepat = load Filepat Filepat->PATH;
	stderr = sys->fildes(2);
	ibuf := bufio->open(EXCLUDEPATH, Bufio->OREAD);
	if(ibuf == nil)
	{
		sys->fprint(stderr, "excude file couldn't be found\n");
		return;
	}
	while((s := ibuf.gets('\n')) != "")
	{
		negated := 0;
		if(s[0] == '#' || s[0] == '\n') continue;
		if(s[0] == '!') 
		{
			negated = 1;
			s = s[1:];
		}
		s = s[:len s - 1];
		if(s[len s - 1] == '/')
			s[len s] = '*';
		patterns = (negated, s) :: patterns; 
	}
}

excluded(path: string): int
{
	ret := 0;
	for(l := patterns; l != nil; l = tl l)
	{
		elem := hd l;
		if(!elem.t0 && filepat->match(elem.t1, path))
			ret = 1;
		else if(elem.t0 && filepat->match(elem.t1, path))
			ret = 0;
	}
	return ret;
}

