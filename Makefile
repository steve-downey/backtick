#! /usr/bin/make -f
# Makefile                                                       -*-makefile-*-
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# This repository holds design documents, plans and papers, and no code. The
# CMake, ctest, coverage and install machinery of the sibling projects'
# Makefile (steve-downey/expected) is therefore not here. What is here:
#
#   - the wg21 markdown papers under papers/, built by pandoc through the
#     vendored papers/wg21 submodule (`make papers`);
#   - org-mode export of docs/*.org and papers/*.org, driven by the Emacs
#     configuration in .emacs.d/ (`make <file>.html`, `make blog-md`).
#     `make` with no target is `org-html`;
#   - reveal.js decks from talks/*.org and docs/*-talk.org (`make slides`),
#     themed out of etc/.

NO_COLOR=1

export

default: org-html
.PHONY: default

.PHONY: papers
papers: ## Build the wg21 markdown papers, HTML and PDF
	$(MAKE) -C papers html pdf

.PHONY: clean-papers
clean-papers: ## Delete the generated papers
	$(MAKE) -C papers clean

.PHONY: env
env:
	$(foreach v, $(.VARIABLES), $(info $(v) = $($(v))))

.PHONY: clean
clean: clean-papers

.PHONY: realclean
realclean: clean

# ------------------------------------------------------------------------------
# Org-mode: org -> HTML, reveal.js slides, and GFM markdown, with UUID-anchored
# source transclusion.
#
# The elisp in .emacs.d/ resolves org-transclusion links. orgit-file: links are
# pinned to a committed git rev, so a published post keeps showing the code its
# prose was written about. Emacs installs its packages from MELPA into
# .emacs.d/elpa-<version>/ on first use; that directory is ignored by git.
#
# Output paths are made absolute because `--visit` changes Emacs's working
# directory to the org file's own directory.
# ------------------------------------------------------------------------------
EMACS := $(shell command -v emacs 2> /dev/null)

EMACS_BATCH := $(EMACS) --init-directory=$(CURDIR)/.emacs.d/ \
	--batch --load $(CURDIR)/.emacs.d/init.el \
	-f package-initialize \
	--eval "(setq enable-local-variables :all)"

# A deck is any org file under talks/, and any docs/*-talk.org -- a deck that
# transcludes from a design doc is kept next to what it transcludes rather
# than moved away from it. Decks are excluded from ORGFILES and BLOG_ORGFILES
# so `org-html' and `blog-md' stay about prose; `slides' builds the decks.
DECK_ORGFILES := $(wildcard talks/*.org docs/*-talk.org)

ORGFILES := $(filter-out $(DECK_ORGFILES),$(wildcard docs/*.org papers/*.org))

%.html : %.org
	$(EMACS_BATCH) \
	--visit $< \
	--eval "(org-transclusion-mode t)" \
	--eval "(org-export-to-file 'html \"$(abspath $@)\")"
	echo $@ : \\ > $@.deps
	echo "  $<" \\ >> $@.deps
	sed -n "s/^.*\[\[file:\(\S*\)::.*$$/\1/p" < $<  | sort -u | xargs -r printf "  $(dir $<)%s \\\\\\n" >> $@.deps

-include $(wildcard $(ORGFILES:%.org=%.html.deps))

# ------------------------------------------------------------------------------
# Slides: org -> reveal.js, via org-re-reveal.
#
# Machinery carried over from steve-downey/cppnow26's trees/ deck. Three
# pieces beyond the plain HTML export above:
#
#   - reveal.js itself. cppnow26 vendors a 12M copy; this repository holds
#     prose only, so instead the library is cloned on demand into .tools/,
#     which git ignores. etc/deck.setup names that path, and
#     `#+OPTIONS: reveal_single_file:t' then inlines the CSS and JS, so the
#     built .html needs neither .tools/ nor a network at all.
#   - etc/slide-footer.el, which builds a per-slide footer out of variables
#     the deck sets in its own Local Variables block. It ships with every
#     variable empty, so a deck that sets none gets no footer.
#   - etc/my_theme.css and the two Modus themes, named by etc/deck.setup.
#
# A deck exports to its own name -- docs/foo-talk.org gives
# docs/foo-talk.html -- rather than to a -slides suffix. Which rule builds a
# .html is decided by whether the source is in DECK_ORGFILES, not by the
# output's name, so the static pattern rule below has to come before the
# `%.html : %.org' rule can claim these targets. It does: a static pattern
# rule is an explicit rule, and explicit rules beat implicit ones.
# ------------------------------------------------------------------------------
DECK_HTML := $(DECK_ORGFILES:.org=.html)

REVEAL_VERSION_TAG := 6.0.1
REVEAL_DIR := $(CURDIR)/.tools/reveal.js

$(REVEAL_DIR):
	mkdir -p $(dir $@)
	git clone --depth 1 --branch $(REVEAL_VERSION_TAG) \
		https://github.com/hakimel/reveal.js $@

.PHONY: reveal.js
reveal.js: $(REVEAL_DIR) ## Clone reveal.js into .tools/ if it is not there yet

# The footer elisp is loaded before the deck is visited; it puts itself on
# `org-export-before-processing-functions' so the deck's Local Variables are
# in effect by the time the postamble is built.
#
# The two etc/ prerequisites are named here rather than left to the generated
# .deps: a deck pulls them in by `#+SETUPFILE:' and by --load, neither of
# which is a `[[file:...::...]]' link for the sed below to find.
# htmlize emits class names rather than inline styles, so the Modus CSS that
# etc/deck.setup pulls in can colour the source blocks. Set here and not in
# .emacs.d/init.el: `use-package org' there is `:after (flycheck)', flycheck is
# not installed, so the whole form -- and its :custom block -- never runs. Set
# only for decks; an article export links no Modus CSS and would come out with
# class names nothing colours.
$(DECK_HTML) : %.html : %.org etc/deck.setup etc/slide-footer.el | $(REVEAL_DIR)
	$(EMACS_BATCH) \
	--load $(CURDIR)/etc/slide-footer.el \
	--eval "(setq org-html-htmlize-output-type 'css)" \
	--visit $< \
	--eval "(org-transclusion-mode t)" \
	--eval "(org-export-to-file 're-reveal \"$(abspath $@)\")"
	echo $@ : \\ > $@.deps
	echo "  $<" \\ >> $@.deps
	sed -n "s/^.*\[\[file:\(\S*\)::.*$$/\1/p" < $<  | sort -u | xargs -r printf "  $(dir $<)%s \\\\\\n" >> $@.deps

-include $(wildcard $(DECK_ORGFILES:%.org=%.html.deps))

.PHONY: slides
slides: $(DECK_HTML) ## Export every talks/*.org and docs/*-talk.org to a reveal.js deck

# The blog posts live in docs/ next to their Nikola .meta sidecars. The GFM
# rule is confined to docs/ on purpose: papers/*.md are the wg21 markdown
# sources, and a pattern rule over papers/ would offer to overwrite them.
BLOG_ORGFILES := $(filter-out $(DECK_ORGFILES),$(wildcard docs/*.org))

docs/%.md : docs/%.org
	$(EMACS_BATCH) \
	--visit $< \
	--eval "(org-transclusion-mode t)" \
	--eval "(require 'ox-gfm)" \
	--eval "(org-export-to-file 'gfm \"$(abspath $@)\")"
	echo $@ : \\ > $@.deps
	echo "  $<" \\ >> $@.deps
	sed -n \
	  -e "s/^.*\[\[file:\(\S*\)::.*$$/\1/p" \
	  -e "s/^.*\[\[orgit:[^:]*::\([^:]*\)::.*$$/\1/p" \
	  < $< | sort -u | xargs -r printf "  %s \\\\\\n" >> $@.deps

-include $(wildcard $(BLOG_ORGFILES:.org=.md.deps))

.PHONY: org-html
org-html: $(ORGFILES:.org=.html) ## Export every docs/*.org and papers/*.org to HTML

.PHONY: blog-md
blog-md: $(BLOG_ORGFILES:.org=.md) ## Convert docs/*.org to GFM markdown

.PHONY: clean-org
clean-org: ## Delete the org export outputs and their .deps
	-rm -f $(ORGFILES:.org=.html) $(ORGFILES:.org=.html.deps)
	-rm -f $(DECK_HTML) $(DECK_HTML:.html=.html.deps)
	-rm -f $(BLOG_ORGFILES:.org=.md) $(BLOG_ORGFILES:.org=.md.deps)
clean: clean-org

.PHONY: clean-reveal.js
clean-reveal.js: ## Delete the cloned reveal.js checkout
	-rm -rf $(REVEAL_DIR)

.PHONY: clean-emacs.d
clean-emacs.d: ## Delete the Emacs package cache
	-rm -rf .emacs.d/eln-cache
	-rm -rf .emacs.d/elpa*

realclean: clean-emacs.d
realclean: clean-reveal.js

# Help target
.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[.a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'  $(MAKEFILE_LIST) | sort
