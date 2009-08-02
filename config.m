
Configmod: module
{
	PATH: con "/dis/git/config.dis";

	getall: fn(): list of (string, string);
	getbool: fn(key: string): int;
	getint: fn(key: string): (int, int);
	getstring: fn(key: string): string;
	init: fn(mods: Mods);
	printall: fn();
	readconfig: fn(path: string): int;
	setbool: fn(key: string, val: int): int;
	setint: fn(key: string, val: int): int;
	setstring: fn(key, val: string): int;
};

