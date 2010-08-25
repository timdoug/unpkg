all: unpkg.app

unpkg.app:
	/usr/local/bin/platypus -DR -a unpkg -o Droplet -p /usr/bin/python \
-V `cat VERSION` -s upkg -I org.timdoug.unpkg -X '*' -T '****|fold' \
-i appIcon.icns -f xar -f cpio -c unpkg.py 'unpkg.app'

clean:
	rm -rf unpkg.app
