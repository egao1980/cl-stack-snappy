(defsystem "cl-stack-snappy"
  :version "1.3.1.2"
  :description "Snappy native overlays + thin CFFI for cl-stack compression"
  :author "egao1980"
  :license "MIT"
  :defsystem-depends-on ("asdf-native")
  :depends-on ("cffi" "trivial-gray-streams" "compression-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               ;; $CL_STACK_SNAPPY_NATIVE, native/ (overlay), lib/<os>-<arch>/ (checkout), else the system library.
               (:native-library "snappy" :versions ("1") :env "CL_STACK_SNAPPY_NATIVE" :system t)
               (:file "ffi")
               (:file "api")
               (:file "streams")
               (:file "compression"))
  :in-order-to ((test-op (test-op "cl-stack-snappy/tests")))
  ;; Overlays: lib/<os>-<arch>/ per platform, from the :native-library components.
  :properties (:cl-repo (:provides ("cl-stack-snappy"))))

(defsystem "cl-stack-snappy/tests"
  :depends-on ("cl-stack-snappy" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "api-test")
               (:file "streams-test")
               (:file "protocol-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
