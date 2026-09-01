(defpackage #:cl-stack-snappy
  (:use #:cl #:cffi)
  (:export #:+snappy-version+
           #:snappy-error
           #:snappy-error-message
           #:compress
           #:decompress
           #:valid-compressed-p
           #:make-decompressing-stream
           #:make-compressing-stream
           #:snappy-decompressing-stream
           #:snappy-compressing-stream))
