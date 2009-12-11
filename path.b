implement Pathmod;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;

mods: Mods;

init(m: Mods)
{
	mods = m;
}

makepathabsolute(path: string): string
{
	if(path == "" || path[0] == '/') return path;
	
	name := "";
	curpath := gwd->init();
	for(i := 0; i < len path; i++){
		if(path[i] == '/'){
			curpath = resolvepath(curpath, name);
			name = "";
			continue;
		}
		name[len name] = path[i];
	}

	curpath = resolvepath(curpath, name);

	if(curpath != nil && curpath[len curpath - 1] != '/'){
		curpath += "/";
	}

	return curpath;
}

resolvepath(curpath: string, path: string): string
{
	if(curpath == "/") return curpath + path;

	if(path == ".")
		return curpath;

	if(path == "..")
	{
		oldpath := gwd->init();
		sys->chdir(curpath);
		sys->chdir("..");
		ret := gwd->init();
		sys->chdir(oldpath);
		return ret;
	}

	return curpath + "/" + path;
}

dirname(path: string): string
{
	for(i := len path - 1; i >= 0; i--){
		if(path[i] == '/')
			return path[0:i];
	}
	return ".";
}

exists(path: string): int
{
	return sys->stat(path).t0 != -1;
}

makeabsentdirs(path: string)
{
	if(!exists(names->dirname(path)))
		makeabsentdirs(names->dirname(path));
	sys->create(path, Sys->OREAD,  Sys->DMDIR|8r755);
}

cleandir(path: string)
{
	entries := readdir->init(path, Readdir->NAME).t0;
	for(i := 0; i < len entries; i++){
		if(entries[i].name == ".git") continue;
		fullpath := sprint("%s/%s", path, entries[i].name);
		if(entries[i].mode & Sys->DMDIR){
			cleandir(fullpath);
		}
		if(sys->remove(fullpath) == -1){
			sys->fprint(sys->fildes(2), "%s couldn't be removed\n", fullpath);
		}
	}
}

shaexists(shaname: string): int
{
	return sys->open(string2path(shaname), Sys->OREAD) != nil;
}

string2path(filename: string): string
{
	return repopath + OBJECTSTOREPATH + "/" + filename[:2] + "/" + filename[2:];
}

basename(path: string): (string, string)
{
	if(path != "" && path[0] == '/')
		path = path[1:];

	for(i := 0; i < len path; i++){
		if(path[i] == '/')
			return (path[:i], path[i+1:]);
	}

	return (nil, path);
}
