;;; rustc-inline-view.el --- View what function calls got inlined by `rustc' -*- lexical-binding: t -*-

;; Copyright (C) 2026 Aditya Singh <antichrome1@proton.me>
;; SPDX-License-Identifier: ISC

;; Author: Aditya Singh <antichrome1@proton.me>
;; Maintainer: Aditya Singh <antichrome1@proton.me>
;; URL: https://github.com/antichrome1/rustc-inline-view.el
;; Package-Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords:

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;;
;;
;;
;;


;;; Code:

(defface rust-inline-success-face '((t :background "#00422a")) "") ;; subtle green
(defface rust-inline-missed-face '((t :background "#620f2a")) "") ;; subtle red

;; TODO parse all package names in workspace root and the run mark-allbuffers for all of them

(defmacro mark-all-buffers (type)
  `(progn
     (let ((original-shell shell-file-name)
           (original-shell2 explicit-shell-file-name)
           (pre-processing-command (concat "
DIR=$(basename $(pwd)); SS=\"/$DIR/\";                      \
cargo rustc --release -- -Cdebuginfo=1 -Cremark=inline 2>&1 \
| grep \"" ,type "\"                                        \
| grep $SS                                                  \
| awk '{print $2}'")))
       (setq shell-file-name "/bin/sh")
       (setq explicit-shell-file-name "/bin/sh")

       (with-temp-buffer
         (call-process-shell-command
          pre-processing-command nil t)
         (message (concat "---------------------------------------" pre-processing-command))
         (dolist (entry (split-string (buffer-string) "\n" t))
           (message entry)
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
                       (overlay-put ov 'face (if (eq ,type "success") 'rust-inline-success-face 'rust-inline-missed-face)))))
                 (display-buffer buf))))))

       (setq explicit-shell-file-name original-shell2)
       (setq shell-file-name original-shell))))

;;;###autoload
(defun rustc-inline-view ()
  (interactive)
  (rustc-inline-view-clear-overlays)
  ;; TODO parse all package dirs in virtual workspace
  (cl-loop for package-folder in workspace
           do
           (chdir package-folder)
           (mark-all-buffers "success")
           (mark-all-buffers "missed")
           (message "OK")))

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
