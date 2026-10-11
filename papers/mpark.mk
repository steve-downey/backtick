# Build the R0 markdown papers (*.md) through the mpark/wg21 framework,
# vendored as a git subtree under wg21/.  Outputs land in generated/.
#
#   make -C papers -f mpark.mk html pdf
#
# The org-mode papers are built by wg21org; see Makefile.
include wg21/flat.mk
