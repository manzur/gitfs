MODDIR=/module
DISBIN=/dis/git

TARG=\
	cat-file.dis\
#	checkout-index.dis\
#	checkrepo.dis\
	checkout.dis\
	commit-tree.dis\
#	diff-tree.dis\
#	exclude.dis\
	gitindex.dis\
#	init.dis\
	log.dis\
	gitfs.dis\
	mods.dis\
	read-tree.dis\
	checkout.dis\
#	show-diff.dis\
#	indexparser.dis\
#	update-index.dis\
	utils.dis\
	path.dis\
	repo.dis\
	tree.dis\
	read-tree.dis\
	commit.dis\
	write-tree.dis

MODULES=\
	cat-file.m\
#	exclude.m\
	checkout.m\
	modules.m\
	mods.m\
	commit.m\
	read-tree.m\
	gitindex.m\
	repo.m\
	tree.m\
	checkout.m\
	log.m\
	commit-tree.m\
	path.m\
#	update-index.m\
	init.m\
#	indexparser.m\
	write-tree.m\
	utils.m

SYSMODULES=\
	tables.m

mall:V: all modinstall

</mkfiles/mkdis

LIMBOFLAGS=-g

modinstall:V: $MODULES
	cp *.m /module/
