MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CWD := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER_IMG := pytm
SHELL := /bin/bash

ifeq ($(USE_DOCKER),true)
	SHELL=docker
	.SHELLFLAGS=run -u $$(id -u) -v $(CWD):/usr/src/app --rm $(DOCKER_IMG):latest -c
endif
ifndef PLANTUML_PATH
	export PLANTUML_PATH = ./plantuml.jar
endif

models := tm.py
libs := $(wildcard pytm/*.py) $(wildcard pytm/threatlib/*.json) $(wildcard pytm/images/*)

build: docs/pytm/index.html reports
all: clean build

docs/pytm/index.html: $(wildcard pytm/*.py)
	PYTHONPATH=. pdoc --html --force --output-dir docs pytm

docs/threats.md: $(wildcard pytm/threatlib/*.json)
	printf "# Threat database\n" > $@
	jq -r ".[] | \"$$(cat docs/threats.jq)\"" $< >> $@

clean:
	rm -rf dist/* build/* $(models:.py=/)

$(models:.py=):
	[ -d "$@" ] || mkdir -p $@
	ln -s ../docs $@

%/dfd.png: %.py $(libs) | %
	./$< --dfd | dot -Tpng -o $@

%/seq.png: %.py $(libs) | %
	./$< --seq | java -Djava.awt.headless=true -jar $$PLANTUML_PATH -tpng -pipe 2> >(grep -v 'CoreText note:') > $@

%/report.html: %.py $(libs) docs/template.md %/dfd.png %/seq.png docs/Stylesheet.css | %
	./$< --report docs/template.md | pandoc -f markdown -t html > $@

%/report.pdf: %/report.html
	echo '<meta http-equiv="Content-type" content="text/html; charset=utf-8" /><meta charset="UTF-8" />' > $<.tmp.html
	sed \
	  -e 's/\<details\>/<details open>/' \
	  -e 's/<\([Ii][Mm][Gg] [Ss][Rr][Cc]=javascript[^>]*\)>/<pre>\1<\/pre>/' \
	  $< >> $<.tmp.html
	wkhtmltopdf --quiet --enable-local-file-access -n $<.tmp.html $@ && rm -f $<.tmp.html


dfd: $(models:.py=/dfd.png)

seq: $(models:.py=/seq.png)

html: $(models:.py=/report.html)

pdf: $(models:.py=/report.pdf)

reports: dfd seq html pdf


.PHONY: test
test:
	@python3 -m unittest

.PHONY: describe
describe:
	./$(word 1,$(models)) --describe "TM Element Boundary ExternalEntity Actor Lambda Server Process SetOfProcesses Datastore Dataflow"

.PHONY: image
image:
	docker build -t $(DOCKER_IMG) .

.PHONY: docs
docs: docs/pytm/index.html docs/threats.md

.PHONY: fmt
fmt:
	black  $(wildcard pytm/*.py) $(wildcard tests/*.py) $(wildcard *.py)
