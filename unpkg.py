#!/usr/bin/python

###############################
# unpkg 4.5                   #
# by timdoug[.com|@gmail.com] #
###############################
# 
# version notes:
#
# 4.5-beta -- 2010-08-24
# - finally: metapackage extraction!
# - use new ``droplet'' Platypus type
# - lots of behind-the-scenes changes
# - compile xar for 10.4/ppc, 10.4/i386, and 10.5/x86_64 from Apple's 10.6.4 version
#   (http://opensource.apple.com/tarballs/xar/xar-36.1.tar.gz)
# - do the same with cpio
# - (http://www.opensource.apple.com/tarballs/libarchive/libarchive-14.tar.gz)
# - be more explicit about BSD licensed software
# 
# 4.0 (final. really, this time!) -- 2009-01-15
# - 10.4 doesn't have "xar" and 10.5 has 1.4, which is really
#   outdated. bundle a CVS snapshot r223 (further unmodified).
# - menial fixes and edits
#
# 4.0-pre (internal only) -- 2009-01-14
# - deals with errors much more gracefully
# - create temp folders properly
# - 10.4 has Python 2.3, which doesn't have subprocess (grr!)
#   use os.system instead
# - other little interface changes here and there
# - new (and prettier!) icon
#
# 4.0-beta (internal-only release) -- 2009-01-13
# - competely re-written in Python
# - now works with multiple packages and new, 10.5-style packages
# - ripped out CocoaDialog, simplifying the interface
# - upgraded to the (much improved) Platypus 4.0, and its Web View
# (what happened to 3.0? it's what I called a few unreleased
#  hack jobs in Cocoa/Python/Objective C...)
# 
# Copyright (C) 2009-10 timdoug
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. (NOT
# any later version!)
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


import os
import sys
import shutil
import tempfile

XAR_PATH = os.path.join(os.path.dirname(sys.argv[0]), 'xar')
CPIO_PATH = os.path.join(os.path.dirname(sys.argv[0]), 'cpio')
DIALOG_BOX_APPLESCRIPT = 'tell app "%s" to display dialog "%s" default button 1 buttons {"OK"}'
DIALOG_BOX = '/usr/bin/osascript -e \'%s\' >/dev/null' % DIALOG_BOX_APPLESCRIPT

def pretty_dialog(error):
	os.system(DIALOG_BOX % ('unpkg' if 'unpkg.app' in sys.argv[0] else 'Finder', error))

def get_extract_dir(pkg_path):
	enclosing_path, pkg_name = os.path.split(os.path.splitext(pkg_path)[0])

	# if the enclosing path is not writable, extract to Desktop
	if not os.access(enclosing_path, os.W_OK):
		enclosing_path = os.path.join(os.environ['HOME'], 'Desktop')
	
	extract_dir = os.path.join(enclosing_path, pkg_name)
	
	if os.path.exists(extract_dir):
		orig_extract_dir = extract_dir
		for i in xrange(1, 1000):
			extract_dir = '%s-%s' % (orig_extract_dir, str(i))
			if not os.path.exists(extract_dir): break
			if i == 999: # I sure hope this never happens...
				pretty_dialog('Cannot establish appropriate extraction directory.')
				sys.exit()
	
	return extract_dir

# we don't need no stinkin' subprocess module
def run_in_path(cmd, path):
	os.chdir(path)
	os.system(cmd)


def extract_package(pkg_path, extract_dir):
	##########################
	### old style packages ###
	##########################	
	if os.path.isdir(pkg_path):
	
		# find the pax file (use the first, stop when found)
		def find_pax():
			for root, dirs, files in os.walk(pkg_path):
				for file in files:
					if file.endswith('.pax') or file.endswith('.pax.gz'):
						return os.path.join(root, file)
			return None
		
		pax_path = find_pax()
		if not pax_path:
			pretty_dialog('Cannot find pax file in \\\"%s\\\". (not a valid package?)' % pkg_path)
			return False
		
		os.mkdir(extract_dir)
		extract_prog = '/usr/bin/gzcat "%s" | /bin/pax -r' if pax_path[-3:] == '.gz' else '/bin/pax -r < "%s"'
		
		run_in_path(extract_prog % pax_path, extract_dir)
		return True
	
	#################################
	### new (10.5) style packages ###
	#################################
	else:
		f = open(pkg_path) # no 'with' for compatibility with python 2.3 (10.4)
		try:
			if f.read(4) != 'xar!':
				pretty_dialog('\\\"%s\\\" is not a valid package.' % pkg_path)
				return False
		finally:
			f.close()
		
		tempdir = tempfile.mkdtemp()
		run_in_path('"%s" -xf "%s"' % (XAR_PATH, pkg_path), tempdir)
		
		payloads = []
		for root, dirs, files in os.walk(tempdir):
			for file in filter(lambda x: x == 'Payload', files):
				payloads.append(os.path.join(root, file))

		os.mkdir(extract_dir)		
		extract_prog = '/usr/bin/gzcat < "%s" | "' + CPIO_PATH + '" -i --quiet'
		
		# simple format -- extract the only contents
		if len(payloads) == 1:
			run_in_path(extract_prog % payloads[0], extract_dir)
		
		# complex format -- extract every payload into its respective folder
		else:
			for payload in payloads:
				subpackname = os.path.splitext(os.path.basename(os.path.dirname(payload)))[0]
				subpackpath = os.path.join(extract_dir, subpackname)
				os.mkdir(subpackpath)
				run_in_path(extract_prog % payload, subpackpath)
		
		shutil.rmtree(tempdir)
		return True


############
### main ###
############
for pkg_path in sys.argv[1:]:
	pretty_name = os.path.splitext(os.path.basename(pkg_path))[0]
	print 'Extracting %s...' % pretty_name
	sys.stdout.flush()
	
	if not os.access(pkg_path, os.R_OK):
		pretty_dialog('Cannot read package %s.' % pretty_name)
		continue
	
	extract_dir = get_extract_dir(pkg_path)
	result = False
	
	if pkg_path.endswith('.mpkg'):
		os.mkdir(extract_dir)
		count = 0
		for root, dirs, files in os.walk(pkg_path):
			for file in files + dirs:
				if file.endswith('.pkg'):
					subpkg_extract_dir = os.path.join(extract_dir, os.path.splitext(file)[0])
					count += 1 if extract_package(os.path.join(root, file), subpkg_extract_dir) else 0
		if count > 0:
			pretty_dialog('Extracted %d internal packages from \\\"%s\\\" to \\\"%s\\\".' % (count, pretty_name, extract_dir))
		else:
			shutil.rmtree(extract_dir)
			pretty_dialog('No packages found within the \\\"%s\\\" metapackage.' % pretty_name)
	else:
		if extract_package(pkg_path, extract_dir):
			pretty_dialog('Extracted \\\"%s\\\" to \\\"%s\\\".' % (pretty_name, extract_dir))
