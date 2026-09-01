(in-package #:cl-stack-snappy/tests)

(deftest decompressing-stream-round-trip
  (let* ((raw (%bytes "stream decompress via gray"))
         (enc (compress raw)))
    (with-open-stream (src (make-octet-input-stream enc))
      (with-open-stream (in (make-decompressing-stream src))
        (ok (typep in 'snappy-decompressing-stream))
        (ok (equalp raw (%read-all in)))))))

(deftest compressing-stream-then-buffer-decode
  (let ((raw (%bytes "compressing stream output")))
    (with-open-stream (src (make-octet-input-stream raw))
      (with-open-stream (cin (make-compressing-stream src))
        (ok (typep cin 'snappy-compressing-stream))
        (let ((enc (%read-all cin)))
          (ok (plusp (length enc)))
          (ok (equalp raw (decompress enc))))))))

(deftest stream-to-stream-round-trip
  (let ((raw (%bytes "pull compress then pull decompress")))
    (with-open-stream (plain (make-octet-input-stream raw))
      (with-open-stream (cin (make-compressing-stream plain))
        (with-open-stream (din (make-decompressing-stream cin))
          (ok (equalp raw (%read-all din))))))))

(deftest decompressing-stream-large
  (let* ((raw (make-array 20000 :element-type '(unsigned-byte 8)
                          :initial-element 42))
         (enc (compress raw)))
    (with-open-stream (src (make-octet-input-stream enc))
      (with-open-stream (in (make-decompressing-stream src))
        (ok (equalp raw (%read-all in 1024)))))))
