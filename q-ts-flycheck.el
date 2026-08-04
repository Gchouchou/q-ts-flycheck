;;; q-ts-flycheck.el --- Tree-sitter q mode linter

;; Author: Justin Yu
;; Homepage: https://github.com/Gchouchou/q-ts-flycheck
;; Created 23 Apr 2025
;; Version: 0.1

;;; Commentary:

;;; Adds a flycheck linter for q powered by treesitter

;;; Requirements:
;;; Package-Requires: ((emacs "29.1") (q-ts-mode) (flycheck))

;;; Code:
(require 'treesit)
(require 'q-ts-mode)
(require 'flycheck)

(defvar q-ts-flycheck-linters
  (list #'q-ts-flycheck-errors-and-invalid-atoms)
  "List of q-ts linter functions.")

(defun q-ts-flycheck-run-linters (checker callback)
  "Funcall CALLBACK with results from linter functions in `q-ts-flycheck-linters'.

CHECKER is not used."
  (funcall callback 'finished
           (mapcan #'funcall
                   q-ts-flycheck-linters)))

(defconst q-ts-flycheck--error-invalid-query
  (treesit-query-compile
   'q
   '((ERROR) @error
     (MISSING) @missing
     (invalid_atom) @invalid
     (infix_projection) @infix_projection
     (implicit_composition) @implicit_composition))
  "Compiled treesitter query for getting error and invalid atoms.")

(defun q-ts-flycheck-errors-and-invalid-atoms ()
  "Find all error and invalid atom nodes in parse tree."
  (let* ((capture (treesit-query-capture
                   (treesit-buffer-root-node 'q)
                   q-ts-flycheck--error-invalid-query)))
    (mapcar (lambda (match)
              (let* ((group (car match))
                     (node (cdr match))
                     (start (treesit-node-start node))
                     (end (treesit-node-end node))
                     (level (pcase group
                              ('implicit_composition 'warning)
                              ('infix_projection 'warning)
                              (_ 'error)))
                     (linter-message (pcase group
                                       ('error "Syntax error")
                                       ('missing (format "Missing %s node" (treesit-node-type node)))
                                       ('invalid "Invalid atomic expression")
                                       ('infix_projection "Infix projection is not recommended")
                                       ('implicit_composition "Implicit composition is not recommended"))))
                (flycheck-error-new-at-pos start level linter-message :end-pos end)))
            capture)))


(flycheck-define-generic-checker 'q-ts-checker
  "A flycheck checker for q powered by treesitter"
  :start #'q-ts-flycheck-run-linters
  :modes '(q-ts-mode))

(add-to-list 'flycheck-checkers 'q-ts-checker)

(provide 'q-ts-flycheck)
;;; q-ts-flycheck.el ends here
