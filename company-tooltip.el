;;; company-tooltip.el --- Use a real tooltip to show company candidates

;;; Commentary:
;;

;;; Code:

(require 'xcb)

(defvar company-tooltip--frame nil)

(defun company-tooltip--frame-params ()
  `((visibility . nil)
    (border-width . 0)
    (internal-border-width . 0)
    (minibuffer . nil)
    (right-fringe . 0)
    (left-fringe . 0)
    (height . 50)
    (width . 50)
    (background-color . ,(face-attribute 'company-tooltip :background))))

(defun company-tooltip--remove-window-border (frame)
  (let ((window (string-to-number (frame-parameter frame 'outer-window-id)))
        (connection (xcb:connect-to-socket)))
    (xcb:+request connection
        (make-instance 'xcb:ChangeWindowAttributes
                       :window window
                       :value-mask xcb:CW:OverrideRedirect
                       :override-redirect 1))
    (xcb:flush connection)
    (xcb:disconnect connection)))

(defun company-tooltip--create-frame ()
  (unless company-tooltip--frame
    (let* ((frame (make-frame (company-tooltip--frame-params))))
      (setq company-tooltip--frame frame)
      (company-tooltip--remove-window-border frame)))
  company-tooltip--frame)

(defun company-tooltip--delete-frame ()
  (when (and company-tooltip--frame (frame-live-p company-tooltip--frame))
    (delete-frame company-tooltip--frame))
  (setq company-tooltip--frame nil))

(defun company-tooltip--get-buffer ()
  (when company-tooltip--frame
    (with-current-buffer (get-buffer-create " *company-tooltip-buffer*")
      (setq-local mode-line-format nil)
      (current-buffer))))

(defun company-tooltip--get-window ()
  (when company-tooltip--frame
    (frame-root-window company-tooltip--frame)))

(defun company-tooltip--set-contents (selection)
  (let* ((height (abs (company--pseudo-tooltip-height)))
         (lines (company--create-lines selection height))
         (contents (mapconcat (lambda (l) (concat l "​")) lines "\n")))
    (with-current-buffer (company-tooltip--get-buffer)
      (erase-buffer)
      (insert contents)
      (setq-local truncate-lines t)
      (set-window-buffer (company-tooltip--get-window) (current-buffer)))))

;; (defvar company-tooltip--lines-cache (make-hash-table))
(defvar company-tooltip--prev-size nil)

(defun company-tooltip--resize-frame ()
  (let ((size (window-text-pixel-size (company-tooltip--get-window) (point-min) (point-max)
                                      500 500)))
    (unless (and (>= (or (car company-tooltip--prev-size) 0) (car size))
                 (>= (or (cdr company-tooltip--prev-size) 0) (cdr size)))
      (setq company-tooltip--prev-size size) ;; FIXME 20
      (set-frame-size company-tooltip--frame (+ (car size) 20) (cdr size) t)
      (redisplay t))))

(defun company-tooltip--move-frame ()
  (let* ((point-x-y (posn-x-y (save-excursion
                                (backward-char (length company-prefix))
                                (posn-at-point))))
         (win-edges (window-edges (selected-window) nil t t))
         (win-x-y (cons (nth 0 win-edges) (nth 1 win-edges)))
         (frame-x-y (cons (frame-parameter (selected-frame) 'top)
                          (frame-parameter (selected-frame) 'left)))
         (x-y (cons (+ (car point-x-y)
                       (car win-x-y))
                    (+ (cdr point-x-y)
                       (cdr win-x-y)
                       (line-pixel-height)))))
    (set-frame-position company-tooltip--frame (car x-y) (cdr x-y))))

(defvar company-tooltip--hide-timer nil)

(defun company-tooltip-show (row column selection)
  ;; (message "show")
  (when company-tooltip--hide-timer
    (cancel-timer company-tooltip--hide-timer)
    (setq company-tooltip--hide-timer nil))
  (company-tooltip--create-frame)
  (company-tooltip--set-contents selection)
  (company-tooltip--resize-frame)
  (company-tooltip--move-frame)
  (make-frame-visible company-tooltip--frame))

(defun company-tooltip--hide ()
  ;; (message "hide")
  (when company-tooltip--frame
    ;; Or delete frame?
    (make-frame-invisible company-tooltip--frame)))

(defun company-tooltip-hide ()
  ;; Use a timer to prevent successions of ‘show’s and ‘hide’s from making the
  ;; tooltip flicker
  (setq company-tooltip--hide-timer (run-with-idle-timer 0 nil 'company-tooltip--hide)))

(defun company-tooltip--add-advice ()
  (interactive)
  (advice-add 'company-pseudo-tooltip-show :after 'company-tooltip-show)
  (advice-add 'company-pseudo-tooltip-hide :after 'company-tooltip-hide))

(defun company-tooltip--remove-advice ()
  (interactive)
  (advice-remove 'company-pseudo-tooltip-show 'company-tooltip-show)
  (advice-remove 'company-pseudo-tooltip-hide 'company-tooltip-hide))

(provide 'company-tooltip)
;;; company-tooltip.el ends here
