PATH          := ./node_modules/.bin:$(PATH)

# Add local versions of ttf2eot nd ttfautohint to the PATH
PATH := $(PATH):./support/font-builder/support/ttf2eot
PATH := $(PATH):./support/font-builder/support/ttfautohint/frontend
PATH := $(PATH):./support/font-builder/bin

PROJECT       :=  $(notdir ${PWD})
TMP_PATH      := /tmp/${PROJECT}-$(shell date +%s)

REMOTE_NAME   ?= origin
REMOTE_REPO   ?= $(shell git config --get remote.${REMOTE_NAME}.url)

FONTS         += entypo
FONTS         += awesome-uni.font
FONTS         += iconic-uni.font
FONTS         += typicons.font
FONTS         += modernpics.font
FONTS         += websymbols-uni.font
FONTS         += brandico.font
FONT_CONFIGS   = $(foreach f,$(FONTS),src/${f}/config.yml)


help:
	echo "make help           - Print this help"
	echo "make app-start      - Run Fontomas server"
	echo "make rebuild-fonts  - Rebuild embedded fonts"
	echo "make dev-setup      - Install deps for development"
	echo "make lint           - Lint sources with JSHint"
	echo "make gh-pages       - Build and push the project into gh-pages branch"


rebuild-fonts:
	mkdir -p assets/embedded_fonts
	for config in $(FONT_CONFIGS); do \
		bin/font_copy_to_assets.py -c "$$config" -o assets/embedded_fonts; \
		done
	bin/build_embedded_fonts_js.py -i assets/embedded_fonts -o shared/embedded_fonts.js $(FONT_CONFIGS)
	bin/build_embedded_fonts_css.py -o assets/embedded_fonts/fontface-embedded.css.ejs $(FONT_CONFIGS)
	# build single font
	mkdir ${TMP_PATH}
	bin/build_common_font.py -i $(foreach f,$(FONTS), ./src/${f}) -o ${TMP_PATH}/fontello.ttf -c shared/glyphs_map.js
	ttfautohint --latin-fallback --hinting-limit=200 --hinting-range-max=50 \
  --symbol "${TMP_PATH}/fontello.ttf" "${TMP_PATH}/fontello-hinted.ttf"
	mv "${TMP_PATH}/fontello-hinted.ttf" "assets/embedded_fonts/fontello.ttf"
	fontconvert.py --src_font "assets/embedded_fonts/fontello.ttf" --fonts_dir "assets/embedded_fonts"
	ttf2eot < "assets/embedded_fonts/fontello.ttf" > "assets/embedded_fonts/fontello.eot"
	rm -rf ${TMP_PATH}


dev-setup:
	rm -rf node_modules
	npm install
	npm install -g jshint


dev-server:
	if test ! `which inotifywait` ; then \
		echo "You need 'inotifywait' installed in order to run dev-server." >&2 ; \
		echo "   sudo apt-get install inotify-tools" >&2 ; \
		exit 128 ; \
		fi
	./support/forever.sh


repl:
	if test ! `which socat` ; then \
		echo "You need `socat` installed in order to run repl." >&2 ; \
		echo "   sudo apt-get install socat" >&2 ; \
		exit 128 ; \
		fi
	if test ! -e ./tmp/fontello-repl.sock ; then \
		echo "You need to start fontello server with --repl." >&2 ; \
		echo "   ./fontello server --repl" >&2 ; \
		exit 128 ; \
		fi
	socat - UNIX:./tmp/fontello-repl.sock


lint:
	if test ! `which jshint` ; then \
		echo "You need 'jshint' installed in order to run lint." >&2 ; \
		exit 128 ; \
		fi
	jshint . --show-non-errors


test: lint


gh-pages:
	@if test -z ${REMOTE_REPO} ; then \
		echo 'Remote repo URL not found' >&2 ; \
		exit 128 ; \
		fi
	cp -r ./ ${TMP_PATH} && \
		touch ${TMP_PATH}/.nojekyll
	cd ${TMP_PATH} && \
		git init && \
		git add . && \
		git commit -q -m 'refreshed at gh-pages'
	cd ${TMP_PATH} && \
		git remote add remote ${REMOTE_REPO} && \
		git push --force remote +master:gh-pages 
	rm -rf ${TMP_PATH}

todo:
	grep 'TODO' -n -r ./lib 2>/dev/null || test true


.PHONY: help rebuild-fonts dev-setup lint gh-pages todo dev-server repl
.SILENT: help rebuild-fonts dev-setup lint todo
