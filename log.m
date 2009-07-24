
Log: module
{
	PATH: con "/dis/git/log.dis";
	init: fn(mods: Mods);
	readlog: fn(sha1: string, ch: chan of array of byte);
};
