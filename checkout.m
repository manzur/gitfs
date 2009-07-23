
Checkoutmod: module
{
	PATH: con "/dis/git/checkout.dis";

	checkout: fn(sha1: string): ref Gitindex->Index;
	init: fn(arglist: list of string, debug: int, index: Gitindex->Index, shatable: ref Tables->Strhash[ref Shaobject]);
};

