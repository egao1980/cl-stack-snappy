(defsystem "cl-stack-snappy"
  :version "1.2.2"
  :description "Snappy native overlays + thin CFFI for cl-stack compression"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cffi" "trivial-gray-streams")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "ffi")
               (:file "api")
               (:file "streams"))
  :in-order-to ((test-op (test-op "cl-stack-snappy/tests")))
  :properties
  (:cl-repo
   (:cffi-libraries ("libsnappy")
    :provides ("cl-stack-snappy")
    :overlays
    ((:platform (:os "linux" :arch "amd64")
      :layers ((:role "native-library"
                :files (("lib/linux-amd64/libsnappy.so" . "libsnappy.so")))))
     (:platform (:os "linux" :arch "arm64")
      :layers ((:role "native-library"
                :files (("lib/linux-arm64/libsnappy.so" . "libsnappy.so")))))
     (:platform (:os "darwin" :arch "arm64")
      :layers ((:role "native-library"
                :files (("lib/darwin-arm64/libsnappy.dylib" . "libsnappy.dylib")))))
     (:platform (:os "windows" :arch "amd64")
      :layers ((:role "native-library"
                :files (("lib/windows-amd64/snappy.dll" . "snappy.dll")))))))))

(defsystem "cl-stack-snappy/tests"
  :depends-on ("cl-stack-snappy" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "api-test")
               (:file "streams-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
