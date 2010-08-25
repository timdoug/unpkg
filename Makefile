VERSION=`cat VERSION`

all: unpkg.app

unpkg.app:
	/usr/local/bin/platypus -DR -a unpkg -o Droplet -p /usr/bin/python \
-V ${VERSION} -s upkg -I org.timdoug.unpkg -X '*' -T '****|fold' \
-i appIcon.icns -f xar -f cpio -c unpkg.py 'unpkg.app'

zip: unpkg.app
	mkdir unpkg\ ${VERSION}
	cp -R unpkg.app COPYING Read\ Me.rtf unpkg\ ${VERSION}
	zip -r unpkg-${VERSION}.zip unpkg\ ${VERSION}
	rm -rf unpkg\ ${VERSION}

clean:
	rm -rf unpkg.app unpkg-*.zip
