#!/usr/bin/env python
import os, sys, time, optparse, sqlite3

#-Settings-----------------------------------
#DB_dir = "/home/usr7/ishida-t-af/Julian"
DB_dir = "./"
DB_files = ("prdos.0.rdb",
	    "prdos.1.rdb",
	    "prdos.2.rdb",
	    "prdos.3.rdb",
	    "prdos.4.rdb",
	    "prdos.5.rdb",
	    "prdos.6.rdb",
	    "prdos.7.rdb"
	    )

#-Functions----------------------------------
def chk_db(_db, id):
	_id = id[2:]
	sql = "select sid from prdos "
	sql += "where sid = %s"%(_id)
	for sid in _db.execute(sql):
		return True
	return False

#=== Main =========================================================
usage = "%prog [option] prediction_id"
parser = optparse.OptionParser(usage)
parser.add_option("-A", "--All", action="store_true", dest="All", default=False)
parser.add_option("-o", "--output_dir", action="store", dest="output_dir", default=".")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=False)
(options, args) = parser.parse_args()

if options.All: #get all prediction results.
	nFiles = 0
	for db_file in DB_files:
		db_file = "%s/%s"%(DB_dir, db_file)
		if options.verbose: print "Open DB:", db_file
		db = sqlite3.connect(db_file)
		sql = "SELECT sid, casp9 FROM prdos"
		for sid, casp9 in db.execute(sql):
			output_file = "%s/%s.prdos2.casp9"%(options.output_dir, sid)
			if options.verbose: print " Making file:", output_file
			sys.stdout.flush()
			open(output_file, "w").write(casp9)
			nFiles += 1
	print "# %d files are generated."%(nFiles)
	sys.exit()

#get a prediction whose id = args[0]
try:
	sid = int(args[0])
except:
        print usage.replace("%prog", sys.argv[0])
        sys.exit()


for db_file in DB_files:
	db_file = "%s/%s"%(DB_dir, db_file)
	if options.verbose: print "Open DB:", db_file
	db = sqlite3.connect(db_file)
	sql = """SELECT sid, casp9 FROM prdos where sid=%d"""%(sid)
	for _sid, casp9 in db.execute(sql):
		#print casp9
		output_file = "%s/%s.prdos2.casp9"%(options.output_dir, sid)
		if options.verbose: print " Making file:", output_file
		sys.stdout.flush()
		open(output_file, "w").write(casp9)
		sys.exit()

print "No prediction (%d) in DBs."%(sid)
sys.exit()

