;;; oc-citum.el --- Org-cite export processor for Citum  -*- lexical-binding: t -*-

;; Copyright (C) 2026 Bruce D'Arcus and Citum contributors
;; SPDX-License-Identifier: MIT OR Apache-2.0

;; Author: Bruce D'Arcus
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org "9.6"))
;; Keywords: bib, tex, org
;; URL: https://github.com/citum/citum-labs

;;; Commentary:

;; An org-cite export processor that drives `citum-server' over a
;; newline-delimited JSON-RPC pipe — no FFI, no persistent daemon.
;;
;; Each export runs a SINGLE `format_document' RPC call that covers all
;; citations and the bibliography at once, matching the disambiguation
;; model of the underlying Citum engine.  Results are memoised in the
;; Org export communication channel `info' so subsequent `:export-citation'
;; calls are pure table lookups.
;;
;; Requirements:
;;   - Emacs 29.1+ (uses `json-parse-string' / `json-serialize')
;;   - `citum-server' on PATH, or set `oc-citum-server-path'
;;   - A `.bib' bibliography file (also works with citar)
;;
;; Quickstart:
;;
;;   (add-to-list 'load-path "/path/to/citum-labs/bindings/emacs")
;;   (require 'oc-citum)
;;   (setq org-cite-export-processors '((t . (citum))))
;;   (setq org-cite-global-bibliography '("/path/to/refs.bib"))
;;
;; In a document:
;;   #+cite_export: citum
;;   #+bibliography: refs.bib
;;
;; See README.md in this directory for citar integration and full
;; configuration reference.

;;; Code:

(require 'oc)
(require 'org-element)

;;;; Customization

(defgroup citum nil
  "Citum citation export processor for Org mode."
  :group 'org-cite
  :prefix "oc-citum-")

(defcustom oc-citum-server-path
  (or (getenv "CITUM_SERVER_PATH") "citum-server")
  "Path to the `citum-server' executable.
Defaults to the CITUM_SERVER_PATH environment variable, then plain
`citum-server' (looked up on PATH at call time)."
  :type 'string
  :group 'citum)

(defcustom oc-citum-style nil
  "Default Citum style, as a `StyleInput' alist or nil.
When nil, APA 7th edition is used via the server's built-in resolver.
Can be overridden per-document with the `#+cite_export:' keyword's
third field.  Examples (Elisp plists passed to `json-serialize'):

  \\='(:kind \"id\" :value \"apa\")         ; built-in by id
  \\='(:kind \"path\" :value \"/abs/s.yaml\") ; local YAML file"
  :type '(choice (const nil)
                 (plist :value-type string))
  :group 'citum)

(defcustom oc-citum-locale nil
  "BCP 47 locale string for Citum rendering, or nil for en-US.
Example: \"de-DE\"."
  :type '(choice (const nil) string)
  :group 'citum)

;;;; Internal constants

(defconst oc-citum--plist-key :oc-citum-results
  "Key used to cache batch RPC results in the Org export info plist.")

;;;; Locator label regexp (mirrors oc-csl approach)

(defconst oc-citum--locator-regexp
  (concat "\\(?:^\\|[,; ]\\)"
          "\\(bk\\.?\\|book\\|ch\\.?\\|chap\\.?\\|chapter\\|"
          "col\\.?\\|column\\|fig\\.?\\|figure\\|fol\\.?\\|folio\\|"
          "l\\.?\\|line\\|n\\.?\\|note\\|no\\.?\\|number\\|"
          "op\\.?\\|opus\\|p\\.?p?\\.?\\|page\\|para\\.?\\|paragraph\\|"
          "part\\|pt\\.?\\|sec\\.?\\|section\\|sub\\.?\\|subsection\\|"
          "v\\.?\\|verse\\|vol\\.?\\|volume\\)"
          "[ .]*\\([0-9][0-9a-z ,–-]*\\)")
  "Regexp matching a locator label and value in a suffix string.")

(defconst oc-citum--locator-labels
  '(("bk" . "book") ("book" . "book")
    ("ch" . "chapter") ("chap" . "chapter") ("chapter" . "chapter")
    ("col" . "column") ("column" . "column")
    ("fig" . "figure") ("figure" . "figure")
    ("fol" . "folio") ("folio" . "folio")
    ("l" . "line") ("line" . "line")
    ("n" . "note") ("note" . "note")
    ("no" . "number") ("number" . "number")
    ("op" . "opus") ("opus" . "opus")
    ("p" . "page") ("pp" . "page") ("page" . "page")
    ("para" . "paragraph") ("paragraph" . "paragraph")
    ("part" . "part")
    ("pt" . "part")
    ("sec" . "section") ("section" . "section")
    ("sub" . "subsection") ("subsection" . "subsection")
    ("v" . "verse") ("verse" . "verse")
    ("vol" . "volume") ("volume" . "volume"))
  "Alist mapping locator abbreviations to canonical Citum locator labels.")

;;;; RPC helpers

(defun oc-citum--rpc (request)
  "Send REQUEST plist to citum-server and return parsed JSON response.
REQUEST is serialized with `json-serialize'.  The server is invoked via
`call-process-region' reading one line of output.  Signals an error if
the server reports an error field."
  (let* ((payload (concat (json-serialize request) "\n"))
         (server  (oc-citum--locate-server))
         (buf     (generate-new-buffer " *citum-rpc*"))
         exit-code response)
    (unwind-protect
        (with-temp-buffer
          (insert payload)
          (setq exit-code
                (call-process-region (point-min) (point-max)
                                     server nil buf nil))
          (with-current-buffer buf
            (goto-char (point-min))
            (let ((line (buffer-substring-no-properties
                         (point-min) (line-end-position))))
              (when (string-empty-p line)
                (error "citum-server returned no output (exit %s)" exit-code))
              (setq response
                    (json-parse-string line :object-type 'plist
                                            :array-type 'array
                                            :null-object nil
                                            :false-object nil)))))
      (kill-buffer buf))
    (when-let ((err (plist-get response :error)))
      (error "citum-server error: %s" err))
    response))

(defun oc-citum--locate-server ()
  "Return the citum-server executable path, signalling if not found."
  (let ((path oc-citum-server-path))
    (unless (or (file-executable-p path)
                (executable-find path))
      (error "citum-server not found: %S.  \
Install it or set `oc-citum-server-path'" path))
    path))

;;;; Bibliography helpers

(defun oc-citum--read-bib-files (info)
  "Return concatenated content of all bibliography files in export INFO.
Reads the `:bibliography' key from the export communication channel INFO,
which is populated from `#+bibliography:' keywords and
`org-cite-global-bibliography' before any processor callback fires.
Signals if no bibliography files are configured."
  (let ((files (plist-get info :bibliography)))
    (unless files
      (error "No bibliography files found.  \
Set `org-cite-global-bibliography' or use #+bibliography:"))
    (mapconcat (lambda (f)
                 (with-temp-buffer
                   (insert-file-contents f)
                   (buffer-string)))
               files
               "\n")))

;;;; Style helpers

(defun oc-citum--resolve-style (info)
  "Return a Citum StyleInput plist for the current export in INFO.
Checks the `#+cite_export:' citation-style argument first, then
`oc-citum-style', then falls back to `(:kind \"id\" :value \"apa\")'."
  (let ((cite-style (cadr (plist-get info :cite-export))))
    (cond
     ((and cite-style (not (string-empty-p cite-style)))
      (if (file-name-absolute-p cite-style)
          (list :kind "path" :value cite-style)
        (list :kind "id" :value cite-style)))
     (oc-citum-style oc-citum-style)
     (t (list :kind "id" :value "apa")))))

(defun oc-citum--output-format (backend)
  "Return the Citum output_format string for Org export BACKEND symbol."
  (pcase backend
    ('latex    "latex")
    ('beamer   "latex")
    ('html     "html")
    ('md       "markdown")
    ('markdown "markdown")
    (_         "plain")))

;;;; Locator parsing

(defun oc-citum--parse-locator (suffix-str)
  "Parse SUFFIX-STR for a locator; return (LABEL . VALUE) or nil."
  (when (and suffix-str
             (string-match oc-citum--locator-regexp suffix-str))
    (let* ((abbrev (downcase (string-trim (match-string 1 suffix-str) "\\." "")))
           (abbrev (replace-regexp-in-string "\\.$" "" abbrev))
           (value  (string-trim (match-string 2 suffix-str)))
           (label  (or (cdr (assoc abbrev oc-citum--locator-labels)) "page")))
      (cons label value))))

;;;; Citation occurrence builder

(defun oc-citum--build-occurrence (citation style index)
  "Return a CitationOccurrence plist for CITATION with org STYLE at INDEX.
STYLE is the `(name . variant)' pair from `org-cite-citation-style'.
INDEX is used as a stable id suffix."
  (let* ((name    (car style))
         (variant (cdr style))
         (refs    (org-cite-get-references citation))
         (items   (mapcar (lambda (ref)
                            (oc-citum--build-item ref variant))
                          refs))
         (occ (list :id (format "cite-%d" index)
                    :items (vconcat items))))
    ;; Map org-cite style to Citum mode / suppress_author.
    ;; org-cite-citation-style returns the raw style string from the document
    ;; (e.g. "t", not the expanded "text"), so match both canonical names and
    ;; their registered shortcuts.  plist-put must be captured for new keys.
    (pcase name
      ((or "text" "t")
       (setq occ (plist-put occ :mode "integral")))
      ((or "author" "a")
       (setq occ (plist-put occ :mode "integral")))
      ((or "noauthor" "na")
       (setq occ (plist-put occ :suppress_author t)))
      ((or "year" "y")
       (setq occ (plist-put occ :suppress_author t))))
    occ))

(defun oc-citum--build-item (ref variant)
  "Build a CitationOccurrenceItem plist from citation-reference element REF.
VARIANT is the style variant string or nil."
  (let* ((key    (org-element-property :key ref))
         (pre    (org-element-property :prefix ref))
         (suf    (org-element-property :suffix ref))
         (pre-s  (when pre (string-trim (org-element-interpret-data pre))))
         (suf-s  (when suf (string-trim (org-element-interpret-data suf))))
         (loc    (oc-citum--parse-locator suf-s))
         (item   (list :id key)))
    (when (and pre-s (not (string-empty-p pre-s)))
      (setq item (plist-put item :prefix pre-s)))
    (when (and suf-s (not (string-empty-p suf-s)) (not loc))
      (setq item (plist-put item :suffix suf-s)))
    (when loc
      (setq item (plist-put item :locator
                             (list :label (car loc) :value (cdr loc)))))
    ;; bare/caps variants are post-processed on the rendered text
    (ignore variant)
    item))

;;;; Batch RPC and memoization

(defun oc-citum--batch-results (info)
  "Run (or return cached) format_document RPC results for export INFO.
Returns a plist with :citations-alist (id . text) and :bibliography."
  (or (plist-get info oc-citum--plist-key)
      (let* ((bib-content (oc-citum--read-bib-files info))
             (style       (oc-citum--resolve-style info))
             (backend     (plist-get info :back-end))
             (backend-sym (when backend (org-export-backend-name backend)))
             (fmt         (oc-citum--output-format backend-sym))
             (all-cites   (org-cite-list-citations info))
             (occurrences (cl-loop for cit in all-cites
                                   for i from 1
                                   collect
                                   (let ((sty (org-cite-citation-style cit info)))
                                     (oc-citum--build-occurrence cit sty i))))
             (params      (list :style style
                                :refs  (list :kind "biblatex"
                                             :value bib-content)
                                :output_format fmt
                                :citations (vconcat occurrences)))
             (_ (when oc-citum-locale
                  (setq params (plist-put params :locale oc-citum-locale))))
             (request  (list :id 1
                             :method "format_document"
                             :params params))
             (response (oc-citum--rpc request))
             (result   (plist-get response :result))
             (fc-vec   (plist-get result :formatted_citations))
             (bib-obj  (plist-get result :bibliography))
             (bib-text (when bib-obj (plist-get bib-obj :content)))
             ;; Build alist: occurrence id -> rendered text
             (cit-alist
              (cl-loop for fc across (or fc-vec [])
                       collect (cons (plist-get fc :id)
                                     (plist-get fc :text)))))
        ;; Build parallel list: (citation-element . occurrence-id) for lookup
        (let ((id-map
               (cl-loop for cit in all-cites
                        for i from 1
                        collect (cons cit (format "cite-%d" i))))
              (cache (list :citations-alist cit-alist
                           :id-map nil
                           :bibliography bib-text)))
          (setq cache (plist-put cache :id-map id-map))
          (plist-put info oc-citum--plist-key cache)
          cache))))

;;;; Variant post-processing

(defun oc-citum--apply-variant (text variant)
  "Apply org-cite style VARIANT to rendered TEXT string.
Handles `caps'/`c' (capitalize first char) and
`bare'/`b' (strip outer brackets/parens)."
  (when (and text variant)
    (when (member variant '("caps" "c" "bare-caps" "bc" "caps-full" "cf" "bare-caps-full" "bcf"))
      (setq text (concat (upcase (substring text 0 1)) (substring text 1))))
    (when (member variant '("bare" "b" "bare-caps" "bc" "bare-caps-full" "bcf"))
      (setq text (replace-regexp-in-string
                  "\\`[[(]\\(.*\\)[])][[:space:]]*\\'" "\\1" text))))
  text)

;;;; Export callbacks

(defun oc-citum-export-citation (citation style _backend info)
  "Return rendered string for CITATION using STYLE in export INFO.
Triggers the batch RPC on first call; subsequent calls use the cache."
  (let* ((results  (oc-citum--batch-results info))
         (id-map   (plist-get results :id-map))
         (cit-alist (plist-get results :citations-alist))
         (occ-id   (cdr (assq citation id-map)))
         (text     (cdr (assoc occ-id cit-alist)))
         (variant  (cdr style)))
    (or (oc-citum--apply-variant text variant) "")))

(defun oc-citum-export-bibliography (_keys _files _style _props _backend info)
  "Return rendered bibliography string from the cached RPC result in INFO."
  (let ((results (oc-citum--batch-results info)))
    (or (plist-get results :bibliography) "")))

;;;; Processor registration

(org-cite-register-processor 'citum
  :export-citation     #'oc-citum-export-citation
  :export-bibliography #'oc-citum-export-bibliography
  :cite-styles
  '((("author"   "a") ("bare" "b") ("caps" "c") ("full" "f")
     ("bare-caps" "bc") ("caps-full" "cf") ("bare-caps-full" "bcf"))
    (("noauthor" "na") ("bare" "b") ("caps" "c") ("bare-caps" "bc"))
    (("year"     "y")  ("bare" "b"))
    (("text"     "t")  ("caps" "c") ("full" "f") ("caps-full" "cf"))
    (("nil")           ("bare" "b") ("caps" "c") ("bare-caps" "bc"))
    (("nocite"   "n"))))

(provide 'oc-citum)
;;; oc-citum.el ends here
