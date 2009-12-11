
#System modules 
include "sys.m";
include "bufio.m";
include "crc.m";
include "daytime.m";
include "draw.m";
include "env.m";
include "filter.m";
include "keyring.m";
include "lists.m";
include "names.m";
include "readdir.m";
include "gittables.m";
include "string.m";
include "styx.m";
include "styxservers.m";
include "workdir.m";

sys, bufio, crcmod, daytime, draw, deflatefilter, env, gwd, inflatefilter, keyring, lists, names, readdir, tables, stringmod, styx, styxservers: import mods; 

Iobuf: import bufio;
CRCstate: import crcmod;
Table, Strhash: import tables;

#Gitfs modules
include "cat-file.m";
include "checkout.m";
include "commit.m";
include "commit-tree.m";
include "config.m";
include "gitindex.m";
include "log.m";
include "pack.m";
include "path.m";
include "repo.m";
include "tree.m";
include "utils.m";

catfilemod, checkoutmod, commitmod, committree, configmod, gitindex, log, packmod, pathmod, repo, treemod, utils: import mods;
repopath, shatable: import  mods;

