;;; biblio-crossref.el --- Lookup and import bibliographic entries from CrossRef -*- lexical-binding: t -*-

;; Copyright (C) 2016  Clément Pit-Claudel

;; Author: Clément Pit-Claudel
;; Version: 0.1
;; Package-Requires: ((biblio-core "0.0") (biblio-doi "0.0"))
;; Keywords: bib, tex, convenience, hypermedia
;; URL: http://github.com/cpitclaudel/biblio.el

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Lookup and download bibliographic records from CrossRef (a very nicely
;; curated metadata engine) using `crossref-lookup'.
;;
;; This package uses `biblio-selection-mode', and is part of the more general
;; `biblio' package (which see for more documentation).

;;; Code:

(require 'biblio-core)
(require 'biblio-doi)

(defun biblio-crossref--forward-bibtex (metadata forward-to)
  "Forward BibTeX for CrossRef entry METADATA to FORWARD-TO."
  (biblio-doi-forward-bibtex (biblio-alist-get 'doi metadata) forward-to))

(defun biblio-crossref--format-affiliation (affiliation)
  "Format AFFILIATION for CrossRef search results."
  (biblio-string-join (seq-map (apply-partially #'biblio-alist-get 'name) affiliation) ", "))

(defun biblio-crossref--format-author (author)
  "Format AUTHOR for CrossRef search results."
  (let-alist author
    (biblio-join
     " " ""
     .given .family (biblio-parenthesize (biblio-crossref--format-affiliation .affiliation)))))

(defun biblio-crossref--extract-interesting-fields (item)
  "Prepare a CrossRef search result ITEM for display."
  (let-alist item
    (list (cons 'doi .DOI)
          (cons 'title (biblio-join
                        " " "(no title)"
                        (biblio-string-join .title ", ")
                        (biblio-parenthesize (biblio-string-join .subtitle ", "))))
          (cons 'authors (apply #'biblio-join ", " "(no authors)"
                                (biblio-remove-empty (seq-map #'biblio-crossref--format-author .author))))
          (cons 'publisher .publisher)
          (cons 'container .container-title)
          (cons 'references (seq-concatenate 'list (list .DOI) .isbn))
          (cons 'type .type)
          (cons 'url .URL))))

(defun biblio-crossref--parse-search-results ()
  "Extract search results from CrossRef response."
  (let-alist (json-read)
    (unless (string= .status "ok")
      (error "Query failed with status %S" .status))
    (seq-map #'biblio-crossref--extract-interesting-fields .message.items)))

(defun biblio-crossref--url (query)
  "Create a CrossRef url to look up QUERY."
  (format "http://api.crossref.org/works?query=%s" (url-encode-url query)))

(defun biblio-crossref-backend (command &optional arg &rest more)
  "A CrossRef backend for biblio.el.
COMMAND, ARG, MORE: See `biblio-backends'."
  (pcase command
    (`name "CrossRef")
    (`prompt "CrossRef query: ")
    (`url (biblio-crossref--url arg))
    (`parse-buffer (biblio-crossref--parse-search-results))
    (`forward-bibtex (biblio-crossref--forward-bibtex arg (car more)))
    (`register (add-to-list 'biblio-backends #'biblio-crossref-backend))))

;;;###autoload
(add-hook 'biblio-init-hook #'biblio-crossref-backend)

;;;###autoload
(defun crossref-lookup ()
  "Start a CrossRef search."
  (interactive)
  (biblio-lookup #'biblio-crossref-backend))

(provide 'biblio-crossref)
;;; biblio-crossref.el ends here
