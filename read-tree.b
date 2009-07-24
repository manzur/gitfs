implement Readtree;

include "gitfs.m";
include "mods.m";
include "modules.m";

error, readsha1file, sha2string, SHALEN: import utils;
Index, Entry: import gitindex;	
splitl: import stringmod;	

mods: Mods;

init(m: Mods)
{
	mods = m;
}

readtree(path: string)
{
#	index = Index.new(REPOPATH, "",debug);
	readtreefile(path, "");
#	index.writeindex(INDEXPATH);
}

readtreefile(path: string, basename: string)
{
	(filetype, filesize, buf) := readsha1file(path);

	ibuf := bufio->aopen(buf);
	while((s := ibuf.gets('\0')) != ""){
		(modestr, filepath) := splitl(s, " ");
		sys->print("==>filepath %s\n", filepath);
		mode := stringmod->toint(modestr,10).t0;
		if(isdir(mode)){
			sha1 := array[SHALEN] of byte;
			ibuf.read(sha1, SHALEN);
			readtreefile(sha2string(sha1), basename + filepath + "/");	
			continue;
		}
		entry := Entry.new();
		entry.name = basename + filepath;
		ibuf.read(entry.sha1, SHALEN);

		sys->print("=>entry=>%o %s==>%s\n",mode, entry.name, sha2string(entry.sha1));
#		index.addentry(entry);
	}
}



usage()
{
	error("usage: read-tree <tree-sha>\n");
	exit;
}

isdir(mode: int): int
{
	return mode & 16384;
}
