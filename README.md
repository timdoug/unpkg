Build instructions
==================

1.  Download and install Platypus (http://www.sveinbjorn.org/platypus).
2.  From Platypus->Preferences, install the command line tool.
3.  echo "4.5-beta" >VERSION
4.  make

To build xar and cpio
---------------------

1.  Download the most recent xar and libarchive source from opensource.apple.com.
2.  Use the instructions here: http://www.timdoug.com/log/2010/08/25/ to build fat binaries.
3.  For libarchive, make sure to add "--enable-bsdcpio --disable-bsdtar" to the config line.
