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
#     configuration in .emacs.d/ (`make <file>.html`, `make <file>-slides.html`,
#     `make blog-md`). `make` with no target is `org-html`.

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

ORGFILES := $(wildcard docs/*.org papers/*.org)

%.html : %.org
	$(EMACS_BATCH) \
	--visit $< \
	--eval "(org-transclusion-mode t)" \
	--eval "(org-export-to-file 'html \"$(abspath $@)\")"
	echo $@ : \\ > $@.deps
	echo "  $<" \\ >> $@.deps
	sed -n "s/^.*\[\[file:\(\S*\)::.*$$/\1/p" < $<  | sort -u | xargs printf "  $(dir $<)%s \\\\\\n" >> $@.deps

-include $(wildcard $(ORGFILES:%.org=%.html.deps))

%-slides.html : %.org
	$(EMACS_BATCH) \
	--visit $< \
	--eval "(org-transclusion-mode t)" \
	--eval "(org-export-to-file 're-reveal \"$(abspath $@)\")"
	echo $@ : \\ > $@.deps
	echo "  $<" \\ >> $@.deps
	sed -n "s/^.*\[\[file:\(\S*\)::.*$$/\1/p" < $<  | sort -u | xargs printf "  $(dir $<)%s \\\\\\n" >> $@.deps

-include $(wildcard $(ORGFILES:%.org=%-slides.html.deps))

# The blog posts live in docs/ next to their Nikola .meta sidecars. The GFM
# rule is confined to docs/ on purpose: papers/*.md are the wg21 markdown
# sources, and a pattern rule over papers/ would offer to overwrite them.
BLOG_ORGFILES := $(wildcard docs/*.org)

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
	  < $< | sort -u | xargs printf "  %s \\\\\\n" >> $@.deps

-include $(wildcard $(BLOG_ORGFILES:.org=.md.deps))

.PHONY: org-html
org-html: $(ORGFILES:.org=.html) ## Export every docs/*.org and papers/*.org to HTML

.PHONY: blog-md
blog-md: $(BLOG_ORGFILES:.org=.md) ## Convert docs/*.org to GFM markdown

.PHONY: clean-org
clean-org: ## Delete the org export outputs and their .deps
	-rm -f $(ORGFILES:.org=.html) $(ORGFILES:.org=.html.deps)
	-rm -f $(ORGFILES:.org=-slides.html) $(ORGFILES:.org=-slides.html.deps)
	-rm -f $(BLOG_ORGFILES:.org=.md) $(BLOG_ORGFILES:.org=.md.deps)
clean: clean-org

.PHONY: clean-emacs.d
clean-emacs.d: ## Delete the Emacs package cache
	-rm -rf .emacs.d/eln-cache
	-rm -rf .emacs.d/elpa*

realclean: clean-emacs.d

# Help target
.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[.a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'  $(MAKEFILE_LIST) | sort
