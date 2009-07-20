
Repo: module
{
	PATH: con "/dis/git/repo.dis";

	EXTENDEDENTRY: con 16r4000; 
	ENTRYSZ: con 62;
#there's no offsetof in Limbo, so I'll add a constant
	NAMEOFFSET: con 62;
	NAMEOFFSETEX: con 64;

	readrepo: fn(arglist: list of string, debug: int): int;
};

