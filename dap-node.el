;;; dap-node.el --- Debug Adapter Protocol mode for Node      -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Kien Nguyen

;; Author: Kien Nguyen <kien.n.quang@gmail.com>
;; Keywords: languages

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; URL: https://github.com/yyoncho/dap-mode
;; Package-Requires: ((emacs "25.1") (dash "2.14.1") (lsp-mode "4.0"))
;; Version: 0.2

;;; Code:

(require 'dap-mode)
(require 'dap-utils)

(defcustom dap-node-debug-path (expand-file-name "vscode/ms-vscode.node-debug2"
                                                   dap-utils-extension-path)
  "The path to node vscode extension."
  :group 'dap-node
  :type 'string)

(defcustom dap-node-debug-program `("node"
                                      ,(f-join dap-node-debug-path "extension/out/src/nodeDebug.js"))
  "The path to the node debugger."
  :group 'dap-node
  :type '(repeat string))

(dap-utils-openvsx-setup-function "dap-node" "ms-vscode" "node-debug2"
                                  dap-node-debug-path)

(defun dap-node-variable-tooltip(button result variables-reference)
  (setq dap--tooltip-overlay
        (-doto (make-overlay (button-start button) (button-end button))
          (overlay-put 'mouse-face 'dap-mouse-eval-thing-face)))
  ;; Show a dead buffer so that the `posframe' size is consistent.
  (when (get-buffer dap-mouse-buffer)
    (kill-buffer dap-mouse-buffer))
  (unless (and (zerop variables-reference) (string-empty-p result))
    (apply #'posframe-show dap-mouse-buffer
           :position (button-start button)
           :accept-focus t
           dap-mouse-posframe-properties)
    (with-current-buffer (get-buffer-create dap-mouse-buffer)
      (dap-ui-render-value (dap--cur-session) result
                           result variables-reference))
    (run-with-timer .1 nil (lambda()
                         (add-hook 'post-command-hook 'dap-tooltip-post-tooltip)))))

(defun dap-node-body-filter-function (body)
  "Process terminal output from BODY."
  (-when-let* (((&hash "output" "variablesReference") body)
               (response (and
                          (string= output "output")
                          (dap-request
                           (dap--cur-session)
                           "variables"
                           :variablesReference  variablesReference)))
               (variables (gethash "variables" response))
               (output (mapconcat
                            (lambda(x)
                              (-let (((&hash "value" "variablesReference") x))
                                (if (> variablesReference 0)
                                    (buttonize value (lambda (button)
                                                       (dap-node-variable-tooltip button value variablesReference)))
                                  value)))
                            variables
                            " ")))
    (puthash "output" (concat output "\n") body))
  body)

(defun dap-node--populate-start-file-args (conf)
  "Populate CONF with the required arguments."
  (if (plist-get conf :dap-server-path)
      (plist-put conf :dap-server-path (cl-map 'list (lambda(x) x) (plist-get conf :dap-server-path))))
  (let ((conf (-> conf
                  (dap--put-if-absent :dap-server-path dap-node-debug-program)
                  (dap--put-if-absent :body-filter-function #'dap-node-body-filter-function)
                  (dap--put-if-absent :type "node")
                  (dap--put-if-absent :cwd default-directory)
                  (dap--put-if-absent :name "Node Debug"))))
    (if (plist-get conf :args)
        conf
      (dap--put-if-absent
       conf :program (read-file-name "Select the file to run:" nil (buffer-file-name) t)))))

(dap-register-debug-provider "node" #'dap-node--populate-start-file-args)

(dap-register-debug-template "Node Run Configuration"
                             (list :type "node"
                                   :cwd nil
                                   :request "launch"
                                   :program nil
                                   :name "Node::Run"))

(provide 'dap-node)
;;; dap-node.el ends here
