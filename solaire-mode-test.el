;;; solaire-mode-test.el --- unit tests -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'solaire-mode-autoloads nil t)
(require 'solaire-mode)


;;
;;; Helpers

(defmacro deftest (name face-specs &rest body)
  "A wrapper around `ert-deftest'.

Activates a psuedo theme with FACE-SPECS, runs BODY, then cleans up any
side-effects of enabling `solaire-mode'."
  (declare (indent 2))
  (let ((theme (make-symbol "solaire-mode-theme")))
    `(ert-deftest ,name ()
       (with-temp-buffer
         (deftheme ,theme)
         (apply #'custom-theme-set-faces ',theme (list ,@face-specs))
         (unwind-protect
             (progn
               (enable-theme ',theme)
               (solaire-mode--prepare-for-theme-a ',theme)
               ,@body)
           (when solaire-mode
             (solaire-mode -1))
           (when solaire-mode--theme
             ;; Disable and unregister theme
             (disable-theme solaire-mode--theme)
             (put solaire-mode--theme 'theme-feature nil)
             (setq custom-known-themes (delq solaire-mode--theme custom-known-themes)))
           (setq solaire-mode--supported-p nil
                 solaire-mode--swapped-p nil
                 solaire-mode--theme nil
                 solaire-mode--remaps nil))))))


;;
;;; Tests

(deftest activates-on-supported-theme
    ('(default ((t (:background "#000000"))))
     '(solaire-default-face ((t (:background "#222222")))))
  (solaire-mode +1)
  (should solaire-mode))

(deftest activates-on-unsupported-theme ()
  (solaire-mode +1)
  (should-not solaire-mode))

(deftest activates-in-unreal-buffers
    ('(default ((t (:background "#000000"))))
     '(solaire-default-face ((t (:background "#222222")))))
  (let ((solaire-mode-real-buffer-fn (lambda () t)))
    (turn-on-solaire-mode))
  (should-not solaire-mode)
  (let ((solaire-mode-real-buffer-fn (lambda () nil)))
    (turn-on-solaire-mode))
  (should solaire-mode))

(deftest remaps-faces-buffer-locally
    ('(default                         ((t (:background "#000000"))))
     '(solaire-default-face            ((t (:background "#222222"))))
     '(mode-line                       ((t (:background "#111111"))))
     '(solaire-mode-line-face          ((t (:background "#222222"))))
     '(mode-line-inactive              ((t (:background "#333333"))))
     '(solaire-mode-line-inactive-face ((t (:background "#444444")))))
  (let ((solaire-mode-remap-alist
         '((default            . solaire-default-face)
           (mode-line          . solaire-mode-line-face)
           (mode-line-inactive . solaire-mode-line-inactive-face))))
    (with-temp-buffer
      (solaire-mode +1)
      (dolist (remap solaire-mode-remap-alist)
        (should-not (equal (face-background (car remap))
                           (face-background (cdr remap))))
        (should (eq (cdr remap) (cadr (assq (car remap) face-remapping-alist)))))
      ;; and cleans up after itself
      (solaire-mode -1)
      (should (null face-remapping-alist)))))

(deftest swaps-faces-globally
  ('(default                         ((t (:background "#000000"))))
   '(solaire-default-face            ((t (:background "#222222"))))
   '(mode-line                       ((t (:background "#111111"))))
   '(solaire-mode-line-face          ((t (:background "#222222"))))
   '(mode-line-inactive              ((t (:background "#333333"))))
   '(solaire-mode-line-inactive-face ((t (:background "#444444")))))
  (let ((solaire-mode-swap-alist
         '((default            . solaire-default-face)
           (mode-line          . solaire-mode-line-face)))
        (dont-swap-alist
         '((mode-line-inactive . solaire-mode-line-inactive-face)))
        old-colors)
    (dolist (swap (append solaire-mode-swap-alist dont-swap-alist))
      (setf (alist-get (car swap) old-colors) (face-background (car swap))
            (alist-get (cdr swap) old-colors) (face-background (cdr swap))))
    (let ((solaire-mode-themes-to-face-swap ()))
      (should-not (solaire-mode-swap-faces-maybe))
      (dolist (swap solaire-mode-swap-alist)
        (should-not (equal (face-background (car swap))
                           (alist-get (cdr swap) old-colors)))
        (should-not (equal (face-background (cdr swap))
                           (alist-get (car swap) old-colors)))))
    (let ((solaire-mode-themes-to-face-swap '(".")))
      (should (solaire-mode-swap-faces-maybe))
      (dolist (swap solaire-mode-swap-alist)
        (should (equal (face-background (car swap))
                       (alist-get (cdr swap) old-colors)))
        (should (equal (face-background (cdr swap))
                       (alist-get (car swap) old-colors))))
      ;; These shouldn't have changed
      (dolist (swap dont-swap-alist)
        (should (equal (face-background (car swap))
                       (alist-get (car swap) old-colors)))
        (should (equal (face-background (cdr swap))
                       (alist-get (cdr swap) old-colors))))
      ;; But don't swap the same theme more than once
      (should-not (solaire-mode-swap-faces-maybe)))))

(provide 'solaire-mode-test)
;;; solaire-mode-test.el ends here
