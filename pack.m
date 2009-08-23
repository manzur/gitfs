Packmod: module
{
	PATH: con "/dis/git/pack.dis";

	init: fn(mods: Mods);
	exists: fn(name: string): int;
	readpackedobject: fn(sha1: string): (string, int, array of byte);
};

