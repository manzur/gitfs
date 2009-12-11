MODDIR=/module
DISBIN=/dis/git

TARG=\
	cat-file.dis\
	checkout.dis\
	commit.dis\
	commit-tree.dis\
	config.dis\
	gitfs.dis\
	gitindex.dis\
	log.dis\
	mods.dis\
	pack.dis\
	path.dis\
	repo.dis\
	tables.dis\
	tree.dis\
	utils.dis

MODULES=\
	cat-file.m\
	checkout.m\
	commit.m\
	commit-tree.m\
	config.m\
	gitindex.m\
	gittables.m\
	log.m\
	mods.m\
	modules.m\
	pack.m\
	path.m\
	repo.m\
	tree.m\
	utils.m

SYSMODULES=\
	sys.m

mall:V: all modinstall

</mkfiles/mkdis

LIMBOFLAGS=-g

modinstall:V: $MODULES
	cp *.m /module/


