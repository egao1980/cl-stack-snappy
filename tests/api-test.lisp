(in-package #:cl-stack-snappy/tests)

(deftest version
  (ok (string= +snappy-version+ "1.3.1")))

(deftest buffer-round-trip
  (let* ((raw (%bytes "hello snappy content-encoding"))
         (enc (compress raw))
         (dec (decompress enc)))
    (ok (plusp (length enc)))
    (ok (not (equalp raw enc)))
    (ok (equalp raw dec))
    (ok (valid-compressed-p enc))))

(deftest buffer-empty
  (let* ((raw (make-array 0 :element-type '(unsigned-byte 8)))
         (enc (compress raw))
         (dec (decompress enc)))
    (ok (equalp raw dec))))

(deftest buffer-binary
  (let* ((raw (make-array 4096 :element-type '(unsigned-byte 8)
                          :initial-contents (loop for i below 4096 collect (mod (* i 17) 256))))
         (enc (compress raw))
         (dec (decompress enc)))
    (ok (< (length enc) (length raw)))
    (ok (equalp raw dec))))

(deftest level-ignored
  (let* ((raw (%bytes "level is zstd/brotli parity"))
         (a (compress raw))
         (b (compress raw :level 3)))
    (ok (equalp a b))
    (ok (equalp raw (decompress b)))))

(deftest bad-input
  (ok (signals (decompress (%bytes "not-snappy!!!!")) 'snappy-error))
  (ok (not (valid-compressed-p (%bytes "not-snappy!!!!")))))

(deftest bulk-paths-large-and-edge-sizes
  "#12: uncompress straight into the result, memcpy out of compress, chunked slurp."
  (dolist (n '(0 1 4095 1000003))
    (let ((raw (make-array n :element-type '(unsigned-byte 8))))
      (dotimes (i n) (setf (aref raw i) (mod (* i 31) 256)))
      (ok (equalp raw (cl-stack-snappy:decompress (cl-stack-snappy:compress raw)))
          (format nil "~D bytes" n)))))
