
Configmod: module
{
	PATH: con "/dis/git/config.dis";

	init: fn(mods: Mods);
	printall: fn();
	readconfig: fn(path: string): int;

	getall: fn(): list of (string, string);
	getbool: fn(key: string): int;
	getint: fn(key: string): (int, int);
	getstring: fn(key: string): string;
	setbool: fn(key: string, val: int): int;
	setint: fn(key: string, val: int): int;
	setstring: fn(key, val: string): int;
};

