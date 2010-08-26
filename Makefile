VERSION=`cat VERSION`

all: unpkg.app

VERSION:
	@echo "Please create a VERSION file with the desired version number."
	@echo "e.g., echo \"4.5\" >VERSION"
	@echo
	@exit 1

unpkg.app: unpkg.py VERSION
	/usr/local/bin/platypus -DR -a unpkg -o 'Progress Bar' \
-p /usr/bin/python -n 'LucidaGrande 12' \
-V ${VERSION} -s upkg -I org.timdoug.unpkg -u timdoug -X '*' -T '****|fold' \
-i appIcon.icns -f xar -f cpio -y -c unpkg.py unpkg.app

zip: unpkg.app
	mkdir unpkg\ ${VERSION}
	cp -R unpkg.app COPYING unpkg\ ${VERSION}
	cp End-user\ Read\ Me.rtf unpkg\ ${VERSION}/Read\ Me.rtf
	zip -r unpkg-${VERSION}.zip unpkg\ ${VERSION}
	rm -rf unpkg\ ${VERSION}

clean:
	rm -rf unpkg.app unpkg-*.zip
