;;; rustc-inline-view.el --- View what function calls got inlined by `rustc' -*- lexical-binding: t -*-

;; Copyright (C) 2026 Aditya Singh <antichrome1@proton.me>
;; SPDX-License-Identifier: ISC

;; Author: Aditya Singh <antichrome1@proton.me>
;; Maintainer: Aditya Singh <antichrome1@proton.me>
;; URL: https://github.com/antichrome1/rustc-inline-view.el
;; Package-Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: languages tools

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Get visual feedback of what rust code was successfully inlined (or
;; not) by the rust compiler in your project.

;;; Code:

(require 'cl-lib)

;; TODO Pick color based on user's color theme
(defface rustc-inline-view--success
  '((t :background "#00422a"))
  "") ;; subtle green

(defface rustc-inline-view--missed
  '((t :background "#620f2a"))
  "") ;; subtle red

;; TODO: remove grep and awk as deps
(defmacro rustc-inline-view--mark-all-open-buffers (overlay-type crate-type crate-name)
  `(progn
     (let ((original-shell shell-file-name)
           (original-shell2 explicit-shell-file-name)
           (pre-processing-command (concat
                                    "DIR=$(basename $(pwd));"
                                    "SS=\"/$DIR/\";"
                                    (if (string= ,crate-type "lib")
                                        (concat "cargo rustc --" ,crate-type " --release -- -Cdebuginfo=1 -Cremark=inline 2>&1")
                                      (concat "cargo rustc --" ,crate-type " " ,crate-name " --release -- -Cdebuginfo=1 -Cremark=inline 2>&1"))
                                    "| grep \"" ,overlay-type "\""
                                    "| grep $SS"
                                    "| awk '{print $2}'")))
       (setq shell-file-name "/bin/sh")
       (setq explicit-shell-file-name "/bin/sh")

       (with-temp-buffer
         (start-process-shell-command
          "rustc-inline-view"
          "*rustc-inline-view*"
          pre-processing-command)
         (message (concat "Compiling crate: " ,crate-name "..."))
         (dolist (entry (split-string (buffer-string) "\n" t))
           ;; (message entry)
           (when (string-match "\\`\\(.*\\):\\([0-9]+\\):\\([0-9]+\\)\\'" entry)
             (let ((file (match-string 1 entry))
                   (line (string-to-number (match-string 2 entry)))
                   (col  (string-to-number (match-string 3 entry))))
               (let ((buf (find-file-noselect file)))
                 (with-current-buffer buf
                   (save-excursion
                     (goto-char (point-min))
                     (forward-line (1- line))
                     (move-to-column (1- col))
                     (let ((ov (make-overlay (point) (line-end-position))))
                       (overlay-put ov 'face (if (string= ,overlay-type "success") 'rustc-inline-view--success 'rustc-inline-view--missed)))))
                 (display-buffer buf))))))

       (setq explicit-shell-file-name original-shell2)
       (setq shell-file-name original-shell))))

(defun rustc-inline-view--cargo-metadata ()
  "Return a list of (crate-name crate-type package-path)."
  (let* ((cargo-output (shell-command-to-string
                        "cargo metadata --no-deps --format-version 1"))
         (json (json-parse-string cargo-output
                                  :object-type 'alist
                                  :array-type 'list)))
    (mapcan (lambda (p)
              (mapcar (lambda (tgt)
                        (list (alist-get 'name tgt)
                              (car (alist-get 'kind tgt))
                              (file-name-directory
                               (alist-get 'manifest_path p))))
                      (alist-get 'targets p)))
            (alist-get 'packages json))))

;;;###autoload
(defun rustc-inline-view ()
  (interactive)
  (rustc-inline-view-clear-overlays)
  (message "Compiling all crates...")
  (let* ((all-crate-info (rustc-inline-view--cargo-metadata))
         (crate-names (mapcar #'car all-crate-info)))
    (cl-loop for (crate-name crate-type crate-path) in (rustc-inline-view--cargo-metadata) do
             (rustc-inline-view--mark-all-open-buffers "success" crate-type crate-name)
             (rustc-inline-view--mark-all-open-buffers "missed" crate-type crate-name))
    (message (format "Marked successful and missed inlining attempts by the compiler.\n Compiled %d crates in `release' mode:\n %s" (length crate-names) crate-names))))

;;;###autoload
(defun rustc-inline-view-clear-overlays ()
  (interactive)
  (let ((root (project-root (project-current t))))
    (dolist (b (buffer-list))
      (with-current-buffer b
        (when (and buffer-file-name
                   (file-in-directory-p buffer-file-name root))
          (mapc #'delete-overlay
                (overlays-in (point-min) (point-max))))))))

(provide 'rustc-inline-view)

;;; rustc-inline-view.el ends here
