VERSION=`cat VERSION`

all: unpkg.app

VERSION:
	@echo "Please create a VERSION file with the desired version number."
	@echo "e.g., echo \"4.5\" >VERSION"
	@echo
	@exit 1

unpkg.app: unpkg.py VERSION
	/usr/local/bin/platypus \
		-a unpkg \
		-I org.timdoug.unpkg \
		-u timdoug \
		-p /usr/bin/python3 \
		-c unpkg.py \
		-V ${VERSION} \
		-i appIcon.icns \
		-D \
		-Z \
		-T 'com.apple.installer-package-archive' \
		-o 'Progress Bar' \
		-y \
		unpkg.app

zip: unpkg.app
	mkdir unpkg\ ${VERSION}
	cp -R unpkg.app COPYING unpkg\ ${VERSION}
	cp End-user\ Read\ Me.rtf unpkg\ ${VERSION}/Read\ Me.rtf
	zip -r unpkg-${VERSION}.zip unpkg\ ${VERSION}
	rm -rf unpkg\ ${VERSION}

clean:
	rm -rf unpkg.app unpkg-*.zip
