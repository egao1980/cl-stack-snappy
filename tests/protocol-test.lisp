(in-package #:cl-stack-snappy/tests)

(deftest protocol-snappy-roundtrip
  (let* ((raw (%bytes "hello compression-protocol snappy"))
         (enc (compression-protocol:compress raw :algorithm :snappy))
         (dec (compression-protocol:decompress enc :algorithm :snappy)))
    (ok (plusp (length enc)))
    (ok (equalp raw dec))))

;;; Preamble declaring #xFFFFFFFF (~4 GiB) bytes, no body.
(defparameter *4gib-header*
  (make-array 5 :element-type '(unsigned-byte 8)
                :initial-contents '(#xff #xff #xff #xff #x0f)))

(deftest declared-length-over-limit
  (ok (signals (decompress *4gib-header* :max-output 1024)
               'compression-protocol:compression-limit-exceeded))
  (ok (= 1024 (handler-case (decompress *4gib-header* :max-output 1024)
                (compression-protocol:compression-limit-exceeded (c)
                  (compression-protocol:compression-limit-exceeded-limit c)))))
  (ok (signals (compression-protocol:decompress *4gib-header* :algorithm :snappy
                                                              :max-output 1024)
               'compression-protocol:compression-limit-exceeded))
  (ok (eq :x-snappy
          (handler-case (compression-protocol:decompress *4gib-header* :algorithm :x-snappy
                                                                       :max-output 1024)
            (compression-protocol:compression-limit-exceeded (c)
              (compression-protocol:compression-error-algorithm c)))))
  (with-open-stream (src (make-octet-input-stream *4gib-header*))
    (ok (signals (make-decompressing-stream src :max-output 1024)
                 'compression-protocol:compression-limit-exceeded))))

(deftest declared-length-within-limit
  (let* ((raw (make-array 4096 :element-type '(unsigned-byte 8) :initial-element 7))
         (enc (compress raw)))
    (ok (equalp raw (decompress enc :max-output 4096)))
    (ok (equalp raw (compression-protocol:decompress enc :algorithm :snappy :max-output 4096)))
    (ok (signals (compression-protocol:decompress enc :algorithm :snappy :max-output 4095)
                 'compression-protocol:compression-limit-exceeded))))
