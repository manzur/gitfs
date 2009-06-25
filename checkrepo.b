implement Checkrepo;

include "checkrepo.m";

include "sys.m";
	sys: Sys;

include "tables.m";
Strhash: import Tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "utils.m";
	utils: Utils;
SHALEN, readsha1file, isdir, sha2string, OBJECTSTOREPATH: import utils;

include "readdir.m";
	readdir: Readdir;

include "string.m";
	stringmodule: String;

Object: adt
{
	name: string;

#flag = -1, if object is needed
#flag = 0, if object is needed and found
#flag = 1, if objects is found, but not needed yet
	flag: int;
};

HASHSZ: con 256;

objects := array[HASHSZ] of list of ref Object;

checkvalidness: int;
stderr: ref Sys->FD;
REPOPATH: string;

init(args: list of string)
{
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;
	bufio = load Bufio Bufio->PATH;
	readdir = load Readdir Readdir->PATH;
	stringmodule = load String String->PATH;

	REPOPATH = hd args;
	utils->init(REPOPATH);
	stderr = sys->fildes(2);
	check();
}

check()
{
	readrepo(REPOPATH + OBJECTSTOREPATH);

	cnt := 0;
	for(i := 0; i < HASHSZ; i++){
		cnt += len objects[i];
		for(l := objects[i]; l != nil; l = tl l){
			object := hd l;
			if(object.flag == -1){
				printlist("is needed", objects[i]);
			}
			else if(object.flag == 1){
				printlist("is found but not referenced", objects[i]);
			}
		}
	}
	sys->print("Object count is %d\n", cnt);
}

readrepo(path: string)
{
	(ret, dirstat) := sys->stat(path);
	#!isdir(mode)
	if(ret == -1 )
	{
		sys->fprint(stderr, "Object store(%s) is not found\n", OBJECTSTOREPATH);
		exit;
	}
	for(i := 0; i < 256; i++){
		subdir := sys->sprint("%s/%02x", path, i);
		(dirs, cnt) := readdir->init(subdir, Readdir->NAME);
		j := 0;
		while(j < cnt){
			dirs[j].name = sys->sprint("%02x%s", i, dirs[j].name);
			checkfile(dirs[j].name, 1);
			j++;
		}
	}
}

checkfile(path: string, flag: int)
{
	(filetype, filesize, filebuf) := readsha1file(path);
	if(filesize == 0){
		return;
	}
	if(filetype == "blob")
		checkblob(path, flag);
	else if(filetype == "tree")
		checktree(path, filebuf, flag);
	else if(filetype == "commit")
		checkcommit(path, filebuf, flag);
	else
		sys->fprint(stderr, "Error in file format: %s\n",filetype);
}

#flag 1 is for found
#flag -1 is for needed
markobject(path: string, flag: int)
{
	index := stringmodule->toint(path[:2], 16).t0;
	for(l := objects[index]; l != nil; l = tl l){
		object := hd l;
		if(object.name == path){
			if(flag == object.flag * -1)
				(hd l).flag = 0;
			return;
		}
	}
	objects[index] = ref Object(path, flag) :: objects[index];
}

checkblob(path: string, flag: int){
	markobject(path, flag);
}

checktree(path: string, treebuf: array of byte, flag: int)
{
	markobject(path, flag);
	ibuf := bufio->aopen(treebuf);
	while((s := ibuf.gets('\0')) != "")
	{
		sha1 := array[SHALEN] of byte;
		ibuf.read(sha1, SHALEN);
		markobject(sha2string(sha1), -1);
		checkfile(sha2string(sha1), -1);
	}
}

checkcommit(path: string, commitbuf: array of byte, flag: int)
{
	ibuf := bufio->aopen(commitbuf);
	#reading tree 
	s := ibuf.gets('\n');
	s = s[:len s - 1];
	sha := stringmodule->splitl(s," ").t1;
	sha = sha[1:];
	checkfile(sha, -1);

	tag: string;
	#reading parents
	while((s = ibuf.gets('\n')) != ""){
		s = s[:len s - 1];
		(tag, sha) = stringmodule->splitl(s, " ");
		if(tag == "author") break;
		sha = sha[1:];
		checkfile(sha, -1);
	}
}

printlist(msg: string, l: list of ref Object)
{
	while(l != nil){
		sys->print("%s %s\n", (hd l).name, msg);
		l = tl l;
	}
}
