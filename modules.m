
#System modules 
include "sys.m";
include "bufio.m";
include "daytime.m";
include "draw.m";
include "env.m";
include "filter.m";
include "keyring.m";
include "lists.m";
include "readdir.m";
include "tables.m";
include "string.m";
include "styx.m";
include "styxservers.m";
include "workdir.m";

sys, bufio, daytime, draw, deflatefilter, env, gwd, inflatefilter, keyring, lists, readdir, tables, stringmod, styx, styxservers: import mods; 

Iobuf: import bufio;
Table, Strhash: import tables;

#Gitfs modules
include "cat-file.m";
include "checkout.m";
include "commit.m";
include "commit-tree.m";
include "config.m";
include "gitindex.m";
include "log.m";
include "path.m";
include "repo.m";
include "tree.m";
include "read-tree.m";
include "utils.m";
include "write-tree.m";

catfilemod, checkoutmod, commitmod, committree, configmod, gitindex, log, pathmod, repo, treemod, readtreemod, utils, writetreemod: import mods;

index, repopath, shatable: import  mods;
