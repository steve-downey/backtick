# Makefile                                                       -*-makefile-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Build the WG21 papers from their org-mode sources with wg21org, vendored as
# a git subtree under wg21org/.  The papers stay here, next to this Makefile;
# the exporter looks for its stylesheets, LaTeX prolog and preamble next to
# the paper first and next to itself second, so the subtree needs no edits.
#
#   make -C papers help                 # list the targets
#   make -C papers                      # every paper, HTML
#   make -C papers <name>.html <name>.pdf
#   make -C papers verify               # HTML and PDF of all, then check them
#   make -C papers check                # re-export all, fail on external loads
#
# Refresh the exporter from GitHub (a local clone's main can lag it):
#   git subtree pull --prefix=papers/wg21org --squash \
#       git@github.com:steve-downey/wg21org.git main
#
# The exporter needs its pinned org-transclusion submodule, registered in
# the top-level .gitmodules; a fresh clone has it registered but empty, and
# the rule for its sources below checks it out on first use.
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

# Everything the exporter reads, so that a change to any of it re-exports.
# A file of the same name next to a paper would be read instead; none is.
ORG_TRANSCLUSION := $(WG21ORG)/packages/org-transclusion
ORG_TRANSCLUSION_SOURCES := $(addprefix $(ORG_TRANSCLUSION)/,org-transclusion.el \
	org-transclusion-src-lines.el text-clone.el)

EXPORTER := $(addprefix $(WG21ORG)/,wg21-links.el wg21-git.el wg21-cmptbl.el \
	wg21-cite.el wg21-wording.el wg21-grammar.el wg21-front.el wg21-code.el \
	emacs.d/export-init.el) $(ORG_TRANSCLUSION_SOURCES)

# The HTML inlines its stylesheet and the face sheets that colour code.
HTML_RESOURCES := $(addprefix $(WG21ORG)/,ox-wg21html.el wg21org.css \
	modus-vivendi-tinted.css modus-operandi-tinted.css)

# The .tex has the preamble copied in, and the working draft's prolog with
# every stdtex/ file it \inputs.
LATEX_RESOURCES := $(addprefix $(WG21ORG)/,ox-wg21latex.el wg21org-preamble.tex \
	common.tex) $(wildcard $(WG21ORG)/stdtex/*.tex)

EXPORT = WG21_BABEL=$(BABEL) $(EMACS) --batch --init-directory=$(WG21ORG)/emacs.d \
	--load $(WG21ORG)/emacs.d/export-init.el \
	--eval '(setq enable-local-variables :all)'

.DELETE_ON_ERROR:

# Keep the .tex a .pdf is made from; make would delete it as intermediate.
.SECONDARY: $(PAPERS:.org=.tex)

.PHONY: all html pdf
all: html ## Export every paper to HTML (the default)
html: $(HTML) ## Export every paper to HTML
pdf: $(PAPERS:.org=.pdf) ## Typeset every paper to PDF, through LaTeX

# A fresh clone has the submodule registered but not checked out; the
# exporter refuses to run without it.
$(ORG_TRANSCLUSION_SOURCES) &:
	git -C $(CURDIR)/.. submodule update --init papers/$(ORG_TRANSCLUSION)

.PHONY: submodule
submodule: $(ORG_TRANSCLUSION_SOURCES) ## Check out the pinned org-transclusion submodule

%.html: %.org references.bib $(EXPORTER) $(HTML_RESOURCES)
	$(EXPORT) --load $(WG21ORG)/ox-wg21html.el \
	--visit $< -f my-wg21-export-to-html -f wg21org-exit

%.tex: %.org references.bib $(EXPORTER) $(LATEX_RESOURCES)
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
check: | $(DEPS_DIR) ## Re-export every paper to HTML; fail on any external load
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

# Build both formats only where out of date, then check what was built: a
# paper can come out of either exporter with status 0 and its content wrong.
# The HTML must load nothing from elsewhere, and the PDF must have every
# glyph: lualatex only logs a character no font supplies, and the Unicode
# operators are in none of the prolog's own fonts.
.PHONY: verify
verify: html pdf ## Build every paper as HTML and PDF, then check both
	@failed=; \
	for org in $(PAPERS); do \
	  name=$${org%.org}; \
	  if grep -Eqi '$(EXTERNAL)' $$name.html; \
	  then echo "FAILED  $$name.html  loads external resources:"; \
	       grep -Eoi '$(EXTERNAL)[^>]{0,80}' $$name.html | sed 's/^/          /'; \
	       failed=1; \
	  else echo "ok      $$name.html"; fi; \
	  if grep -q 'Missing character' $$name.log; \
	  then echo "FAILED  $$name.pdf  is missing glyphs:"; \
	       grep 'Missing character' $$name.log | sort -u | sed 's/^/          /'; \
	       failed=1; \
	  else echo "ok      $$name.pdf"; fi; \
	done; \
	test -z "$$failed"

$(DEPS_DIR):
	mkdir -p $@

.PHONY: clean
clean: ## Delete the HTML, the .tex, the PDF and latexmk's by-products
	-latexmk -C $(PAPERS:.org=.tex)
	rm -f $(HTML) $(PAPERS:.org=.tex)

-include $(wildcard $(DEPS_DIR)/*.pdf.d)

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[.a-zA-Z_-]+:.*?## / {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}' $(firstword $(MAKEFILE_LIST)) | sort
	@echo
	@echo "<name>.html, <name>.pdf, <name>.tex  build one paper; <name> is one of:"
	@printf '  %s\n' $(PAPERS:.org=)
	@echo "BABEL=no  export without evaluating code blocks (default: $(BABEL))"
