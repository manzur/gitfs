MODDIR=/module
DISBIN=/dis/git

TARG=\
	cat-file.dis\
	checkout-index.dis\
	checkrepo.dis\
	commit-tree.dis\
	diff-tree.dis\
	exclude.dis\
	gitindex.dis\
	init.dis\
	log.dis\
	gitfs.dis\
	read-tree.dis\
	show-diff.dis\
	indexparser.dis\
	update-index.dis\
	utils.dis\
	write-tree.dis

SYSMODULES=\
	cat-file.m\
	exclude.m\
	gitindex.m\
	log.m\
	update-index.m\
	init.m\
	indexparser.m\
	write-tree.m\
	utils.m

mall:V: all modinstall

</mkfiles/mkdis

LIMBOFLAGS=-g

modinstall:V: $SYSMODULES
	cp *.m /module/
