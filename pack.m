Packmod: module
{
	PATH: con "/dis/git/pack.dis";

	init: fn(mods: Mods);
	stat: fn(name: string): (int, Sys->Dir);
	readpackedobject: fn(sha1: string): (string, int, array of byte);
};

