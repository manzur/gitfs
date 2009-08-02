implement Configmod;

include "gitfs.m";
include "mods.m";
mods: Mods;
include "modules.m";

sprint: import sys;

Config: adt
{
	key, value: string;
};

configs: ref Strhash[ref Config];

addenventry(key: string, name: string)
{
	val := readenventry(key);
	if(val != nil)
		configs.add(name, ref Config(name, val));
}

getall(): list of (string, string)
{
	l := configs.all();	
	retlist: list of (string, string);
	while(l != nil){
		retlist = ((hd l).key, (hd l).value) :: retlist;
		l = tl l;
	}

	return retlist;
}

#return -1 - is when value is not a boolean type
getbool(key: string): int
{
	item := configs.find(key);
	if(item == nil)
		return -1;
	val := stringmod->tolower(item.value);
	if(val == "true" || val == "yes" || val == nil)
		return 1;
	else if(val == "false" || val == "no")
		return 0;

	return -1;
}

getint(key: string): (int, int)
{
	item := configs.find(key); 
	if(item == nil)
		return (-1, -1);
	val := item.value;
	(ival, rest) := stringmod->toint(val, 10);
	return (rest != "" , ival);
}

getparam(fd: ref Sys->FD): (int, string, string)
{
	s := "";
	key, val: string;
	while(1){
		s = utils->getline(fd);
		if(s == "\n") continue;
		if(s == nil || !utils->onlyspace(s))
			break;
	}
	ret := 0;
	if(s == nil) ret = -1;
	else if(s[0] != '['){	
		s = s[:len s-1];
		(key, val) = stringmod->splitl(s, "=");
		val = val[1:];
		key = utils->trim(key);
		val = utils->trim(val);
	}
	else{
		sys->seek(fd, big -len s, Bufio->SEEKRELA);
		ret = -1;
	}
	return (ret, key, val);
}

getsectionname(fd: ref Sys->FD): (int, string)
{
	buf := array[1] of byte;
	sys->read(fd, buf, len buf);
	if(buf[0] != byte '[')
		return (-1, nil);

	sname := "";
	while(1){
		cnt := sys->read(fd, buf, len buf);
		if(cnt <= 0 || buf[0] == byte ']'){
			break;
		}
		sname += string buf;
	}
	return (0, sname);
}

getstring(key: string): string
{
	item := configs.find(key);
	if(item == nil) 
		return nil;
	
	return item.value;
}

init(m: Mods)
{
	mods = m;
	configs = Strhash[ref Config].new(17, nil);
}

readconfig(path: string): int
{
	#read user-wide config
	if(path != nil){
		abspath := pathmod->makepathabsolute(path);
		parseconfigfile(abspath);
	}

	#read repository-specific config
	parseconfigfile(repopath + ".git/config");	

	readenv();

	return 0;
}

printall()
{
	l := getall();
	while(l != nil){
		sys->print("key=%s; value=%s\n", (hd l).t0, (hd l).t1);
		l = tl l;
	}
}

readenv()
{
	sysname := readparamfile("/dev/sysname");
	uname := readparamfile("/dev/user");
	configs.add("authorname", ref Config("authorname", uname));
	configs.add("authormail", ref Config("authormail", uname + "@" + sysname + ".NONE"));
	configs.add("committername", ref Config("committername", uname));
	configs.add("committermail", ref Config("committermail", uname + "@" + sysname));
	addenventry("GIT_AUTHOR_NAME", "authorname");
	addenventry("GIT_AUTHOR_EMAIL", "authormail");
	addenventry("GIT_COMMITTER_NAME", "committername");
	addenventry("GIT_COMMITTER_MAIL", "committermail");
}

readenventry(key: string): string
{
	return readparamfile("/env/" + key);
}

readparamfile(path: string): string
{
	ret := "";
	ibuf := bufio->open(path, Bufio->OREAD);	
	if(ibuf != nil){
		ret = ibuf.gets('\0');
		if(ret != nil && ret[len ret-1] == '\n')
			ret = ret[:len ret-1];
	}
	
	return ret;
}

#Precondition: fd is located at beginning of the section or at eof
readsection(fd: ref Sys->FD): (string, list of (string, string))
{
	(ret, sname) := getsectionname(fd);
	if(ret == -1){
		return (nil, nil);
	}
	params: list of (string, string);
	while(1){
		(ret, key, val) := getparam(fd); 
		if(ret == -1){
			break;
		}
		params = (key, val) :: params;
	}

	return (sname, params);
}


parseconfigfile(path: string)
{
	fd := sys->open(path, Sys->OREAD);
	if(fd != nil){
		while(1){
			(sname, params) := readsection(fd);
			if(sname == nil)
				break;
			while(params != nil){
				(key, val) := hd params;
				key = sname + "." + key;
				configs.add(key, ref Config(key, val));
				params = tl params;
			}
		}
	}
}

setbool(key: string, val: int): int
{
	return 0;
}

setint(key: string, val: int): int
{
	return 0;
}

setstring(key, val: string): int
{
	return 0;
}
