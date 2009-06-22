
Exclude: module
{
	PATH: con "/dis/git/exclude.dis";
	EXCLUDEPATH: con "exclude";
	init: fn(args: list of string);
	excluded: fn(path: string): int;	

};
