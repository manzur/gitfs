
Repo: module
{
	PATH: con "/dis/git/repo.dis";

	EXTENDEDENTRY: con 16r4000; 
	ENTRYSZ: con 62;
	NAMEOFFSET: con 62;
	NAMEOFFSETEX: con 64;

	init: fn(mods: Mods);
	readrepo: fn(): int;
};

