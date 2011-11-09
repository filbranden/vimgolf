;;; vimgolf.el --- VimGolf interface for the One True Editor

;; Copyright (C) never, by no one

;; Author: Tim Visher <tim.visher@gmail.com>
;; Maintainer: Tim Visher <tim.visher@gmail.com>
;; Created: 2011-11-02
;; Version: 0.1
;; Package-Version: 6a616502
;; Keywords: games vimgolf vim

;; This file is not part of GNU Emacs

;;; Commentary:

;; This is a simple package that allows Emacs users to compete on [VimGolf][1]
;; using the One True Editor. Competition can be commenced utilizing `M-x
;; vimgolf`. When finished with a challenge, `C-c C-v C-c` should finish your
;; editing, ensure correctness, and submit your score and keystrokes to
;; [VimGolf][1].
;;
;; On second thought, let's not go to Camelot. It's a silly place.

;;; Installation:

;; Use package.el. You'll need to add Marmalade to your archives:

;; (require 'package)
;; (add-to-list 'package-archives
;;              '("marmalade" . "http://marmalade-repo.org/packages/"))

;; If you use a version of Emacs prior to 24 that doesn't include
;; package.el, you can get it from http://bit.ly/pkg-el23. If you have
;; an older package.el installed from tromey.com, you should upgrade
;; in order to support installation from multiple sources.

;;; License:

;; [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/)

;;; Code:

(defgroup vimgolf nil
  "Compete on VimGolf with the One True Editor."
  :prefix "vimgolf-"
  :group 'applications)

(defcustom vimgolf-key nil
  "Your VimGolf API Key. Must be set in order to submit your solution."
  :type 'string
  :group 'vimgolf)

(defcustom vimgolf-mode-hook '((lambda () (whitespace-mode t)))
  "A list of functions to call upon the initialization of vimgolf-mode."
  :type 'hook
  :group 'vimgolf)

(defvar vimgolf-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-v C-c") 'vimgolf-submit)
    (define-key map (kbd "C-c C-v r") 'vimgolf-revert)
    (define-key map (kbd "C-c C-v d") 'vimgolf-diff)
    (define-key map (kbd "C-c C-v c") 'vimgolf-continue)
    (define-key map (kbd "C-c C-v p") 'vimgolf-pause)
    (define-key map (kbd "C-c C-v q") 'vimgolf-quit)
    map))

(define-minor-mode vimgolf-mode
  "Toggle VimGolf mode.

With no argument, this command toggles the mode. Non-null prefix
argument turns on the mode. Null prefix argument turns off the
mode.

When VimGolf mode is enabled, several key bindings are defined
with `C-c C-v` prefixes to help in playing VimGolf.

\\{vimgolf-mode-map}"
  ;; The initial value.
  nil
  ;; The indicator for the mode line.
  " VimGolf"
  ;; The minor mode bindings.
  :keymap vimgolf-mode-map
  :group 'vimgolf)

(defvar vimgolf-challenge nil)

(defvar vimgolf-prior-window-configuration nil)

(defvar vimgolf-working-window-configuration nil)

(defvar vimgolf-dribble-file-path (expand-file-name "vimgolf-dribble" temporary-file-directory))

(defvar vimgolf-keystrokes-file-path (expand-file-name "vimgolf-keystrokes" temporary-file-directory))

(defvar vimgolf-work-buffer-name "*vimgolf-work*")
(defvar vimgolf-start-buffer-name "*vimgolf-start*")
(defvar vimgolf-end-buffer-name "*vimgolf-end*")

(defun point-min-in-buffer (buffer)
  (with-current-buffer buffer
    (point-min)))

(defun point-max-in-buffer (buffer)
  (with-current-buffer buffer
    (point-max)))

(defun vimgolf-solution-correct-p ()
  (let ((case-fold-search nil))
    (eq 0 (compare-buffer-substrings
           (get-buffer vimgolf-work-buffer-name) (point-min-in-buffer vimgolf-work-buffer-name) (point-max-in-buffer vimgolf-work-buffer-name)
           (get-buffer vimgolf-end-buffer-name) (point-min-in-buffer vimgolf-end-buffer-name) (point-max-in-buffer vimgolf-end-buffer-name)))))

(defun vimgolf-close-and-capture-dribble ()
  (with-current-buffer (find-file-noselect vimgolf-dribble-file-path)
    (append-to-file (point-min) (point-max) vimgolf-keystrokes-file-path)
    (kill-buffer))
  (open-dribble-file nil))

(defun vimgolf-open-dribble-file (file)
  (if file (open-dribble-file file) (vimgolf-close-and-capture-dribble)))

(defun vimgolf-wrong-solution ()
  (message "Wrong!")
  (vimgolf-diff))

(defun vimgolf-parse-keychord (keychord-string)
  (message keychord-string)
  (single-key-description (string-to-number (substring keychord-string 2) 16)))

(defun vimgolf-parse-dribble-file (file)
  (with-current-buffer (find-file-noselect file)
    (beginning-of-buffer)
    (while (re-search-forward "0x[1-9]0000[a-z0-9]\\{2\\}" nil t)
      (replace-match (vimgolf-parse-keychord (match-string 0))))
    (save-buffer)
    (kill-buffer)))

(defun vimgolf-right-solution ()
  (message "Hurray!")
  (let ((parsed-keystrokes (vimgolf-parse-dribble-file vimgolf-keystrokes-file-path)))
    (message "You should really write that parser at some point.")))

(defun vimgolf-submit ()
  "Stop the challenge and attempt to submit the solution to VimGolf."
  (interactive)
  (vimgolf-open-dribble-file nil)
  (if (vimgolf-solution-correct-p) (vimgolf-right-solution) (vimgolf-wrong-solution)))

(defun clear-dribble-file ()
  (vimgolf-open-dribble-file nil)
  (with-temp-file vimgolf-keystrokes-file-path
    (erase-buffer))
  (vimgolf-open-dribble-file vimgolf-dribble-file-path))

(defun vimgolf-revert ()
  "Revert the work buffer to it's original state and reset keystrokes."
  (interactive)
  (with-current-buffer (get-buffer-create vimgolf-work-buffer-name)
    (delete-region (point-min) (point-max))
    (insert-buffer (get-buffer-create vimgolf-start-buffer-name))
    (clear-dribble-file)
    (set-window-configuration vimgolf-working-window-configuration)
    (message "If at first you don't succeed, try, try again.")))

(defun vimgolf-diff ()
  "Pause the competition and view differences between the buffers."
  (interactive)
  (vimgolf-open-dribble-file nil)
  (ediff-buffers (get-buffer-create vimgolf-work-buffer-name) (get-buffer-create vimgolf-end-buffer-name))
  (message "Remember to `C-c C-v c` when you're done."))

(defun vimgolf-continue ()
  "Restore work and end buffers and begin recording keystrokes again."
  (interactive)
  (vimgolf-open-dribble-file vimgolf-dribble-file-path)
  (set-window-configuration vimgolf-working-window-configuration)
  (message "Golf away!"))

(defun vimgolf-pause ()
  "Stop recording keystrokes."
  (interactive)
  (vimgolf-open-dribble-file nil)
  (message "Come `C-c C-v c` soon."))

(defun vimgolf-quit ()
  "Cancel the competition."
  (interactive)
  (if (get-buffer vimgolf-start-buffer-name) (kill-buffer vimgolf-start-buffer-name))
  (if (get-buffer vimgolf-work-buffer-name) (kill-buffer vimgolf-work-buffer-name))
  (if (get-buffer vimgolf-end-buffer-name) (kill-buffer vimgolf-end-buffer-name))
  (vimgolf-open-dribble-file nil)
  (set-window-configuration vimgolf-prior-window-configuration)
  (message "I declare you, n00b!"))

(defvar vimgolf-host "http://vimgolf.com/")

;; (setq vimgolf-host "http://vimgolf.local:8888/")
;; (setq vimgolf-host "http://vimgolf.com/")
;; Overall VimGolf Rank ID: 4d2fb20e63b08b08b0000075
;; Sort entries based on date ID: 4ea9bc988b36f70001000008

(defvar vimgolf-challenge-extension ".yaml")

(defun vimgolf-challenge-path (challenge-id)
  (concat "challenges/" challenge-id))

(defun vimgolf-challenge-url (challenge-id)
  (concat vimgolf-host (vimgolf-challenge-path challenge-id) vimgolf-challenge-extension))

(defun vimgolf-scrub-buffer (buffer)
  (with-current-buffer buffer
    (beginning-of-buffer)
    (re-search-forward data-end-regexp nil t)
    (delete-region (match-beginning 0) (point-max))
    (decrease-left-margin (point-min) (point-max) 4)
    (beginning-of-buffer)
    (vimgolf-mode t)))

(defun vimgolf-kill-existing-session ()
  (if (get-buffer vimgolf-start-buffer-name) (kill-buffer vimgolf-start-buffer-name))
  (if (get-buffer vimgolf-work-buffer-name) (kill-buffer vimgolf-work-buffer-name))
  (if (get-buffer vimgolf-end-buffer-name) (kill-buffer vimgolf-end-buffer-name)))

;;;###autoload
(defun vimgolf (challenge-id)
  "Open a VimGolf Challenge"
  (interactive "sChallenge ID: ")
  (clear-dribble-file)
  (setq vimgolf-prior-window-configuration (current-window-configuration)
        vimgolf-challenge challenge-id)
  (let ((vimgolf-yaml-buffer (url-retrieve-synchronously (vimgolf-challenge-url challenge-id)))
        (data-end-regexp "\\([ 	]\\{4\\}\\|[ 	]\\{0\\}\\)
  type: [a-z]+")
        (data-start-regexp "  data: |\\+\\{0,1\\}
"))
    (set-buffer vimgolf-yaml-buffer)
    (beginning-of-buffer)
    (re-search-forward data-start-regexp nil t)
    (vimgolf-kill-existing-session)
    (let ((vimgolf-start-buffer (get-buffer-create vimgolf-start-buffer-name))
          (vimgolf-work-buffer (get-buffer-create vimgolf-work-buffer-name))
          (vimgolf-end-buffer (get-buffer-create vimgolf-end-buffer-name)))
      (append-to-buffer vimgolf-start-buffer (point) (point-max))
      (append-to-buffer vimgolf-work-buffer (point) (point-max))
      (vimgolf-scrub-buffer vimgolf-start-buffer)
      (vimgolf-scrub-buffer vimgolf-work-buffer)
      (re-search-forward data-start-regexp nil t)
      (append-to-buffer vimgolf-end-buffer (point) (point-max))
      (vimgolf-scrub-buffer vimgolf-end-buffer)
      (delete-other-windows)
      (display-buffer vimgolf-end-buffer 'display-buffer-pop-up-window)
      (set-window-buffer (selected-window) vimgolf-work-buffer)
      (switch-to-buffer vimgolf-work-buffer)
      (vimgolf-open-dribble-file vimgolf-dribble-file-path)
      (setq vimgolf-working-window-configuration (current-window-configuration)))))

;;; vimgolf.el ends here
