(in-package #:cl-stack-snappy)

(defun %protocol-octets (data)
  (compression-protocol::%ensure-octets data))

(defun %as-compression-error (algorithm condition)
  (error 'compression-protocol:compression-error
         :algorithm algorithm
         :message (or (ignore-errors (snappy-error-message condition))
                      (princ-to-string condition))))

(macrolet ((define-snappy-codec (algorithm)
             `(progn
                (defmethod compression-protocol:compress-using-algorithm
                    ((algorithm (eql ,algorithm)) data &key level)
                  (handler-case
                      (compress (%protocol-octets data) :level level)
                    (snappy-error (c)
                      (%as-compression-error ,algorithm c))))
                (defmethod compression-protocol:decompress-using-algorithm
                    ((algorithm (eql ,algorithm)) data &key)
                  (handler-case
                      (decompress (%protocol-octets data))
                    (snappy-error (c)
                      (%as-compression-error ,algorithm c))))
                (defmethod compression-protocol:make-decompressing-stream-using-algorithm
                    ((algorithm (eql ,algorithm)) input &key)
                  (handler-case
                      (make-decompressing-stream input)
                    (snappy-error (c)
                      (%as-compression-error ,algorithm c)))))))
  (define-snappy-codec :snappy)
  (define-snappy-codec :x-snappy))
