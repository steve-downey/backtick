# Makefile                                                       -*-makefile-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Build the WG21 papers from their org-mode sources with wg21org, vendored as
# a git subtree under wg21org/.  The papers stay here, next to this Makefile;
# the exporter looks for its stylesheets, LaTeX prolog and preamble next to
# the paper first and next to itself second, so the subtree needs no edits.
#
#   make -C papers                      # every paper, HTML
#   make -C papers <name>.html <name>.pdf
#   make -C papers check                # export all, fail on external loads
#
# Refresh the exporter from GitHub (a local clone's main can lag it):
#   git subtree pull --prefix=papers/wg21org --squash \
#       git@github.com:steve-downey/wg21org.git main
#
# The exporter needs its pinned org-transclusion submodule, registered in
# the top-level .gitmodules; after cloning this repository run
#   git submodule update --init papers/wg21org/packages/org-transclusion
#
# Always --squash: wg21org's own history carries an address that must not
# enter this repository's history.
#
# The R0 markdown papers are still built by mpark/wg21: see mpark.mk.

MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

WG21ORG := wg21org
DEPS_DIR := .deps
EMACS := $(shell command -v emacs 2> /dev/null)

# Evaluate org-babel code blocks when exporting: yes or no.
BABEL ?= yes

PAPERS := $(wildcard *.org)
HTML := $(PAPERS:.org=.html)

EXPORTER := $(addprefix $(WG21ORG)/,wg21-links.el wg21-git.el wg21-cmptbl.el \
	wg21-cite.el wg21-wording.el wg21-front.el wg21-code.el emacs.d/export-init.el \
	packages/org-transclusion/org-transclusion.el \
	packages/org-transclusion/org-transclusion-src-lines.el \
	packages/org-transclusion/text-clone.el)

EXPORT = WG21_BABEL=$(BABEL) $(EMACS) --batch --init-directory=$(WG21ORG)/emacs.d \
	--load $(WG21ORG)/emacs.d/export-init.el \
	--eval '(setq enable-local-variables :all)' \
	--eval '(setq org-export-allow-bind-keywords t)'

.DELETE_ON_ERROR:

# Keep the .tex a .pdf is made from; make would delete it as intermediate.
.SECONDARY: $(PAPERS:.org=.tex)

.PHONY: all html pdf
all: html
html: $(HTML)
pdf: $(PAPERS:.org=.pdf)

%.html: %.org references.bib $(EXPORTER) $(WG21ORG)/ox-wg21html.el $(WG21ORG)/wg21org.css
	$(EXPORT) --load $(WG21ORG)/ox-wg21html.el \
	--visit $< -f my-wg21-export-to-html -f wg21org-exit

%.tex: %.org references.bib $(EXPORTER) $(WG21ORG)/ox-wg21latex.el $(WG21ORG)/wg21org-preamble.tex
	$(EXPORT) --load $(WG21ORG)/ox-wg21latex.el \
	--visit $< -f my-wg21-export-to-latex -f wg21org-exit

# The engine is the one the paper names in #+LATEX_COMPILER, which Org
# records in the .tex.
LATEXMK_ENGINE = $$(sed -n 's/^% Intended LaTeX compiler: \(pdf\)\{0,1\}\(.*\)latex$$/-\2\1latex/p' $< | sed 's/^-pdflatex$$/-pdf/')

%.pdf: %.tex | $(DEPS_DIR)
	latexmk -interaction=nonstopmode -halt-on-error -shell-escape \
	  $(LATEXMK_ENGINE) -use-make -deps -deps-out=$(DEPS_DIR)/$@.d -MP $<

# A paper must be one self-contained file: anything it would load from
# elsewhere breaks once it is uploaded, or once the other server changes.
EXTERNAL := <link[^>]*stylesheet|src=.?(https?:)?//|@import|url\(|<img[^>]*src="([^d"]|d[^a]|da[^t]|dat[^a]|data[^:])

# Export every paper, keep going past failures, and report them all.
.PHONY: check
check: | $(DEPS_DIR)
	@failed=; \
	for org in $(PAPERS); do \
	  html=$${org%.org}.html; \
	  if ! $(MAKE) --no-print-directory -B $$html > $(DEPS_DIR)/$$html.log 2>&1; \
	  then echo "FAILED  $$html  (see $(DEPS_DIR)/$$html.log)"; failed="$$failed $$html"; \
	  elif grep -Eqi '$(EXTERNAL)' $$html; \
	  then echo "FAILED  $$html  loads external resources:"; \
	       grep -Eoi '$(EXTERNAL)[^>]{0,80}' $$html | sed 's/^/          /'; \
	       failed="$$failed $$html"; \
	  else echo "ok      $$html"; fi; \
	done; \
	test -z "$$failed"

$(DEPS_DIR):
	mkdir -p $@

.PHONY: clean
clean:
	-latexmk -C $(PAPERS:.org=.tex)
	rm -f $(HTML) $(PAPERS:.org=.tex)

-include $(wildcard $(DEPS_DIR)/*.pdf.d)
