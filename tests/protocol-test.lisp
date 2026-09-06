(in-package #:cl-stack-snappy/tests)

(deftest protocol-snappy-roundtrip
  (let* ((raw (%bytes "hello compression-protocol snappy"))
         (enc (compression-protocol:compress raw :algorithm :snappy))
         (dec (compression-protocol:decompress enc :algorithm :snappy)))
    (ok (plusp (length enc)))
    (ok (equalp raw dec))))
