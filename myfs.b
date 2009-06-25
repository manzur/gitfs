implement Myfs;

include "sys.m";
	sys: Sys;

include "draw.m";	

include "styx.m";	
	styx: Styx;
Tmsg, Rmsg: import styx;

include "styxservers.m";
	styxservers: Styxservers;
Navop, Navigator, Fid, Styxserver: import styxservers;

include "daytime.m";
	daytime: Daytime;

include "string.m";
	stringmod: String;

include "log.m";
	log: Log;

include "cat-file.m";
	catfile: Catfile;

include "readdir.m";
	readdir: Readdir;

include "lists.m";
	lists: Lists;

include "tables.m";
	tables: Tables;
Strhash: import tables;	
			 
include "init.m";
	initmod: Initgit;

include "update-index.m";
	indexmod: Updateindex;

include "write-tree.m";

include "read-tree.m";

include "show-diff.m";

include "diff-tree.m";

include "commit-tree.m";

include "checkrepo.m";

include "checkout-index.m";

include "workdir.m";

repopath: string;
 
srv: ref Styxserver;
nav: ref Navigator;

QRoot, QRootCtl, QRootData, QRootLog, QRootConfig, QRootExclude, QRootObjects, QRootFiles, QStaticMax: con iota;
INITSIZE: con 17;

QMax := big QStaticMax;
QObjectLBound, QObjectUBound: big;

Item: adt{
	parentqid: big;
	path: string;
	dirstat: ref Sys->Dir;
};

table: ref Strhash[ref Item];
REPOPATH: string;

Myfs: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

 
init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	daytime = load Daytime Daytime->PATH;
	lists = load Lists Lists->PATH;
	tables = load Tables Tables->PATH;
	stringmod = load String String->PATH;
	log = load Log Log->PATH;
	catfile = load Catfile Catfile->PATH;
	readdir = load Readdir Readdir->PATH;
	initmod = load Initgit Initgit->PATH;
	indexmod = load Updateindex Updateindex->PATH;
	
	if(len args != 2)
		usage();
	

	REPOPATH = makeabsolute(hd (tl args));
	repopath = REPOPATH;
	if(REPOPATH[len REPOPATH - 1] != '/'){
		REPOPATH += "/";
	}
	sys->print("repopath: %s\n", REPOPATH);

	sys->pctl(Sys->NEWPGRP, nil);

	inittable();

	styx = load Styx Styx->PATH;
	styx->init();
	styxservers = load Styxservers Styxservers->PATH;
	styxservers->init(styx);
	#styxservers->traceset(1);
	navch := chan of ref Navop;
	nav = Navigator.new(navch);
	spawn navigate(navch);
	tmsgchan: chan of ref Tmsg;
	(tmsgchan, srv) = Styxserver.new(sys->fildes(0), nav, big QRoot);
	spawn process(srv, tmsgchan);
}

inittable()
{
	table = Strhash[ref Item].new(INITSIZE, nil);
	dirstat: Sys->Dir;
	ret: int;

	dirstat = sys->stat(REPOPATH).t1;
	uid := dirstat.uid;
	gid := dirstat.gid;
	atime := dirstat.atime;
	mtime := dirstat.mtime;
	time := daytime->now();

	qid := Sys->Qid(big QRoot, 0, Sys->QTDIR);
	d := ref Sys->Dir(".", uid, gid, "", qid, 8r755|Sys->DMDIR, atime, mtime, big 0, 0, 0);
	droot := ref Item(big QRoot, nil, d); 
	table.add(string QRoot, droot);

	qid = Sys->Qid(big QRootCtl,0,0);
	d = ref Sys->Dir("ctl", uid, gid, "", qid, 8r222, time, time, big 0, 0, 0);
	ditem := ref Item(big QRoot, nil, d);
	table.add(string QRootCtl, ditem);
	
	qid = Sys->Qid(big QRootData,0,0);
	d = ref Sys->Dir("data", uid, gid, "", qid, 8r644, time, time, big 0, 0, 0);
	ditem = ref Item(big QRoot, nil, d);
	table.add(string QRootData, ditem);

	qid = Sys->Qid(big QRootLog,0,0); 
	d = ref Sys->Dir("log", uid, gid, "", qid, 8r644, time, time, big 0, 0, 0);
	ditem = ref Item(big QRoot, nil, d);
	table.add(string QRootLog, ditem);
	
	(ret, dirstat) = sys->stat(repopath + "/config");
	qid = Sys->Qid(big QRootConfig,0,0); 
	d = ref Sys->Dir("config", uid, gid,  "", qid, 8r644, dirstat.atime, dirstat.mtime, dirstat.length, 0, 0);
	ditem = ref Item(big QRoot, nil, d);
	table.add(string QRootConfig, ditem);

	(ret, dirstat) = sys->stat(repopath + "/exclude");
	qid = Sys->Qid(big QRootExclude,0,0); 
	d = ref Sys->Dir("exclude", uid, gid,  "", qid, 8r644, dirstat.atime, dirstat.mtime, dirstat.length, 0, 0);
	ditem = ref Item(big QRoot, nil, d);
	table.add(string QRootExclude, ditem);

	(ret, dirstat) = sys->stat(repopath + "/objects");

	qid = Sys->Qid(big QRootObjects,0,Sys->QTDIR);
	d = ref Sys->Dir("objects", uid, gid, "", qid, 8r755|Sys->DMDIR, dirstat.atime, dirstat.mtime, dirstat.length, 0, 0);
	ditem = ref Item(big QRoot, REPOPATH + "objects", d);
	table.add(string QRootObjects, ditem);

	QObjectLBound = QMax;
	readdirectory(REPOPATH + "objects", big QRootObjects, ditem);
	QObjectUBound = QMax;

	(ret, dirstat) = sys->stat(repopath);
	qid = Sys->Qid(big QRootFiles,0,Sys->QTDIR);
	d = ref Sys->Dir("files", uid, gid, "", qid, 8r755|Sys->DMDIR, dirstat.atime, dirstat.mtime, dirstat.length, 0, 0);
	ditem = ref Item(big QRoot, REPOPATH, d);
	table.add(string QRootFiles, ditem);

	readdirectory(REPOPATH + "files", big QRootFiles, ditem);

#	qid = Sys->Qid(big QRoot,0,Sys->QTDIR); 
#	d = ref Sys->Dir("..", uid, gid, "", qid, 8r755|Sys->DMDIR, dirstat.atime, dirstat.mtime, dirstat.length, 0, 0);
#	ditem = ref Item(big QRootObjects, REPOPATH, d);
#	table.add(string QRoot, ditem);

}

process(srv: ref Styxserver, tmsgchan: chan of ref Tmsg)
{

mainloop:
	while((gm := <-tmsgchan) != nil){
		pick m := gm{
			Read =>
				fid := srv.getfid(m.fid); 
				buf := array[m.count] of byte;
				if(fid.path == big QRootConfig || fid.path == big QRootExclude){
					fd := sys->open(repopath + table.find(string fid.path).dirstat.name, Sys->OREAD);
					sys->seek(fd, m.offset, Sys->SEEKSTART);
					cnt := sys->read(fd, buf, len buf);
					buf = buf[:cnt];
					srv.reply(ref Rmsg.Read(m.tag, buf));
				}
				else if(fid.path == big QRootLog){
					logch := chan of array of byte;
					fd := sys->open(REPOPATH + "head", Sys->OREAD);
					if(fd == nil){
						sys->print("head is not found\n");
						srv.reply(ref Rmsg.Read(m.tag, nil));
						continue mainloop;		
					}
					headbuf := array[40] of byte; 
					sys->read(fd, headbuf, len headbuf);
					head := string headbuf;
					sys->print("REPOPATH = %s; head is %s\n", REPOPATH, head);
					spawn log->init(logch, REPOPATH :: head :: nil);

					offset := m.offset;
					temp: array of byte;
					while(offset > big 0){
						temp = <-logch;
						offset -= big len temp;
					}
					if(m.offset != big 0 && temp == nil){
						srv.reply(ref Rmsg.Read(m.tag, nil));
						continue mainloop;
					}
					buf = array[0] of byte;
					if(offset < big 0){
						buf = array[int -offset] of byte;
						buf[:] = temp[len temp + int offset:];
					}
					while(m.count > 0){
						temp = <-logch;
						if(temp == nil){
							break;
						}
						oldbuf := buf[:];
						buf = array[len oldbuf + len temp] of byte;
						buf[:] = oldbuf;
						buf[len oldbuf:] = temp;
						m.count -= len temp;
					}
					srv.reply(ref Rmsg.Read(m.tag, buf));
				}
			else{
					item1 := table.find(string fid.path);
					item2 := table.find(string item1.parentqid);

					sys->print("myfs: reading file under objects\n");
					#if objects is git object;FIXME: should be added code for checking zlib header
					if(item2 != nil && item2.parentqid == big QRootObjects){
						path := item2.dirstat.name + item1.dirstat.name;
						catch := chan of array of byte;
						spawn catfile->init(REPOPATH, 0, path, catch);
						filetype := <-catch;
						msg := <-catch;
						buf = array[len filetype + len msg] of byte;
						buf[:] = filetype;
						buf[len filetype:] = msg;
						srv.reply(styxservers->readbytes(m, buf));
					}
					else{
						srv.read(m);
					}
				}
			Write =>
				fid := srv.getfid(m.fid);
				cnt := len m.data;
				if(fid.path == big QRootCtl){
					ctl(m);
				}
				else if(fid.path == big QRootConfig || fid.path == big QRootExclude){
					fd := sys->open(REPOPATH + table.find(string fid.path).dirstat.name, Sys->OWRITE);
					sys->seek(fd, m.offset, Sys->SEEKSTART);
					cnt = sys->write(fd, m.data, len m.data);
				}
				srv.reply(ref Rmsg.Write(m.tag, cnt));
			
			* => srv.default(gm);
		}
	}
}


ctl(m: ref Tmsg.Write)
{
	s := string m.data;
	if(s != nil && s[len s - 1] == '\n')
		s = s[:len s - 1];
	
	command: string;
	(command, s) = stringmod->splitl(s, " ");		
	if(s != nil)
		s = s[1:];

	 args: list of string = nil;
	 elem: string;
	 while(s != ""){
		 (elem, s) = stringmod->splitl(s, " ");
		 sys->print("==>%s\n", elem);
		 args = elem :: args;
		 if(s != nil)
			 s = s[1:];
	 }
	args = lists->reverse(args);
	case command{
		"init" => sys->print("init\n");
			 spawn initmod->init(REPOPATH :: nil);

		"add" => sys->print("add\n");		
			 spawn indexmod->init(REPOPATH :: "-a" ::args);

		"print" => sys->print("print\n");
			spawn indexmod->init(REPOPATH :: nil);

		"remove" => sys->print("remove\n");
			spawn indexmod->init(REPOPATH :: "-r" :: args);
		
		"show-diff" => sys->print("show-diff\n");
			showdiff := load Showdiff Showdiff->PATH;
			spawn showdiff->init(REPOPATH :: nil);
		
		"write-tree" => sys->print("write-tree\n");
			writetree := load Writetree Writetree->PATH;
			spawn writetree->init(REPOPATH :: nil); 

		"read-tree" => sys->print("read-tree\n");
			readtree := load Readtree Readtree->PATH;
			readtree->init(REPOPATH :: args);

		"checkrepo" => sys->print("checkrepo\n");
			checkrepo := load Checkrepo Checkrepo->PATH;
			checkrepo->init(REPOPATH :: args);

		"checkoutindex" => sys->print("checkoutindex\n");
			checkoutindex := load Checkoutindex Checkoutindex->PATH;
			checkoutindex->init(REPOPATH :: args);

		"diff-tree" => sys->print("diff-tree\n");
			difftree := load Difftree Difftree->PATH;
			difftree->init(REPOPATH :: args);

		"commit" => sys->print("commit\n");
			committree := load Committree Committree->PATH;
			committree->init(REPOPATH :: args);
		* => sys->print("default\n");
	}
}

navigate(navch: chan of ref Navop)
{
mainloop:
	while(1){
	pick navop := <-navch
	{
		Stat =>
				sys->print("in stat:\n");
				item := table.find(string navop.path);
				if(item.dirstat == nil)
					item.dirstat = ref sys->stat(item.path).t1;
				navop.reply <-= (item.dirstat, "");	

		Walk =>
			sys->print("in walk\n");
			for(l := table.all(); l != nil; l = tl l){
				dirstat := (hd l).dirstat;
				if(dirstat == nil)
					dirstat = ref sys->stat((hd l).path).t1;
				if(dirstat.name == navop.name ){
					navop.reply <-= (dirstat, nil);
					continue mainloop;
				}
			}
			navop.reply <-= (nil, "not found");

		Readdir =>
			sys->print("in readdir\n");
			if(navop.path == big QRoot){
				l1 := table.all();

				l: list of ref Item = nil;
				while(l1 != nil){
					if((hd l1).dirstat != nil)
						l = hd l1 :: l;
					l1 = tl l1;
				}

				offset := navop.offset;
				while(l != nil && offset > 0){
					if((hd l).parentqid == big QRoot)
						offset--;
					l = tl l;
				}
				count := navop.count;
				while(l != nil && count-- > 0){
					#if(table[i + navop.offset].t0 != navop.path || i == QRoot) continue;
					navop.reply <-= ((hd l).dirstat, nil);
					l = tl l;

				}
				navop.reply <-= (nil, nil);
			}
#			else if (navop.path == big QRootObjects){
#				(dirs, ret) := readdir->init(REPOPATH + "objects", readdir->NAME);	
#				sys->print("cnt is: %d; %d\n", len dirs, navop.count);
#				for(i := 0; i + navop.offset < len dirs && i < navop.count; i++){
#					navop.reply <-= (dirs[i], nil);
#				}
#
#				navop.reply <-= (nil, nil);
#			}
			else{
				item := table.find(string navop.path);
				if(item != nil){
					(dirs, ret) := readdir->init(item.path, Readdir->NAME);			
					for(i := navop.offset; i < len dirs && i < navop.count + navop.offset; i++){
						navop.reply <-= (dirs[i], nil);
					}
				}
				navop.reply <-= (nil, nil);
			}
	}
	}
}

readdirectory(path: string, parentqid: big, parent: ref Item)
{
	(dirs, ret) := readdir->init(path, Readdir->NAME);
	for(i := 0; i < len dirs; i++){
		item := ref Item(parentqid, path + "/" + dirs[i].name, nil);
		table.add(string dirs[i].qid.path, item);
		readdirectory(path + "/" + dirs[i].name, dirs[i].qid.path, item);
	}
}

min(a, b: int): int
{
	if(a < b) return a;
	return b;
}

usage()
{
	sys->fprint(sys->fildes(2), "mount {myfs dir} mntpt");
	exit;
}

makeabsolute(path: string): string
{
	if(path == "" || path[0] == '/') return path;
	
	gwd := load Workdir Workdir->PATH;
	pwd := gwd->init();

	if(path[0] == '.'){
		if(len path <= 2)
			return pwd;
		return pwd + path[2:];
	}

	return pwd + "/" + path;
}
