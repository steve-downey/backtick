;;; slide-footer.el --- Org-re-reveal per-deck footer injection  -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Injects a footer bar into every reveal.js slide via
;; `org-re-reveal-postamble'.  Three variables control the content and are
;; set per deck in the org file's Local Variables block:
;;
;;   # Local Variables:
;;   # org-slide-footer-text:       "Steve Downey — Infix Backticks — C++Now 2026"
;;   # org-slide-footer-left-logo:  "etc/assets/left.png"
;;   # org-slide-footer-right-logo: "etc/assets/right.png"
;;   # End:
;;
;; Left side (bottom-left): optional logo image stacked above the text.
;; Right side (bottom-right): optional logo image.  An empty string omits
;; the image, which is the default: this repository ships the mechanism and
;; no branding.  Logo paths are relative to the exported HTML file.
;;
;; The `org-' prefix on all three names is load-bearing, not decoration.  The
;; export runs in a copy of the deck's buffer, and `org-element-copy-buffer'
;; carries a buffer-local variable across only if its name matches
;; `^\\(org-\\|orgtbl-\\)'.  Under any other prefix the file-local values are
;; set in the original buffer and invisible from the hook, which sees the
;; empty defaults and silently emits no footer.
;;
;; Carried over from steve-downey/cppnow26 `etc/bbg-footer.el', whose
;; `bbg-footer-*' names hit exactly that; there the content is hardcoded
;; globally in `etc/set-footer.el' instead of coming from the deck.

;;; Code:

(defvar org-slide-footer-text ""
  "Footer text shown bottom-left beneath the left logo.
Set in the org file's Local Variables block.")

(defvar org-slide-footer-left-logo ""
  "Path to the image shown bottom-left above `org-slide-footer-text'.
Relative to the exported HTML file.  Empty string omits the image.")

(defvar org-slide-footer-right-logo ""
  "Path to the image shown bottom-right.
Relative to the exported HTML file.  Empty string omits the image.")

(defun org-slide-footer--img (src alt height)
  "Return an <img> tag for SRC at HEIGHT px, or empty string if SRC is blank."
  (if (string-blank-p src)
      ""
    (format "<img src='%s' alt='%s' style='height:%dpx;width:auto;display:block;'>"
            src alt height)))

(defun org-slide-footer--build-postamble ()
  "Return the postamble HTML string from the current footer variables."
  (let ((left-logo  (org-slide-footer--img org-slide-footer-left-logo  "" 35))
        (right-logo (org-slide-footer--img org-slide-footer-right-logo "" 45)))
    ;; Four percent signs, not two.  `format' here collapses %%%% to %%, and
    ;; org-re-reveal then runs the postamble through `format-spec', which
    ;; collapses that %% to the single % the CSS needs.  Writing %% here
    ;; leaves a bare % for format-spec to choke on.
    (format
     "<style type=\"text/css\">
    #header-left  { position: absolute; top: 0%%%%; left: 0%%%%; }
    #header-right { position: absolute; top: 0%%%%; right: 0%%%%; }
    #footer-left {
        position: absolute;
        bottom: 0%%%%;
        left: 0%%%%;
        padding: 4px;
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 3px;
    }
    #footer-left-text {
        font-size: 0.3em;
        line-height: 1;
        white-space: nowrap;
    }
    #footer-right {
        position: absolute;
        bottom: 0%%%%;
        right: 0%%%%;
        padding: 4px;
        display: flex;
        align-items: flex-end;
    }
</style>

<div id=\"hidden\" style=\"display:none;\">
<div id=\"header\">
<div id=\"footer-left\">%s<div id=\"footer-left-text\">%s</div></div>
<div id=\"footer-right\">%s</div>
</div>
</div>

<script src=\"https://code.jquery.com/jquery-2.2.4.min.js\"></script>
<script type=\"text/javascript\">
var header = $('#header').html();
if ( window.location.search.match( /print-pdf/gi ) ) {
    Reveal.addEventListener( 'ready', function( event ) {
        $('.slide-background').append(header);
    });
} else {
    $('div.reveal').append(header);
}
</script>"
     left-logo
     org-slide-footer-text
     right-logo)))

(defun org-slide-footer-apply (&rest _)
  "Set `org-re-reveal-postamble' from the current footer variables.
Runs from `org-export-before-processing-functions', which fires before
`org-export-get-environment' reads the defcustom into the export plist,
and after the deck's file-local values have been copied into the export
buffer.

A deck that sets none of the three variables gets no postamble at all
rather than an empty one: the postamble pulls jQuery off a CDN, and a
deck exported with `reveal_single_file:t' otherwise has no external
reference left in it."
  (setq org-re-reveal-postamble
        (unless (and (string-blank-p org-slide-footer-text)
                     (string-blank-p org-slide-footer-left-logo)
                     (string-blank-p org-slide-footer-right-logo))
          (org-slide-footer--build-postamble))))

(add-hook 'org-export-before-processing-functions #'org-slide-footer-apply)

(provide 'slide-footer)

;;; slide-footer.el ends here
