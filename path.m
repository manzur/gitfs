
Pathmod: module
{
	PATH: con "/dis/git/path.dis";

	CONFIGFILEPATH: con "config";
	HEADSPATH: con ".git/refs/heads";
	INDEXPATH: con ".git/index";
	INDEXLOCKPATH: con ".git/index.lock";
	OBJECTSTOREPATH: con ".git/objects";
	
	init: fn(path: string);
	basename: fn(path: string): (string, string);
	cleandir: fn(path: string);
	dirname: fn(path: string): string;
	makeabsentdirs: fn(path: string);
	makepathabsolute: fn(path: string): string;
	resolvepath: fn(curpath: string, path: string): string;
	shaexists: fn(shaname: string): int;
	string2path:   fn(filename: string): string;
};
