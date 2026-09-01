(in-package #:cl-stack-snappy)

(define-foreign-library libsnappy
  (:darwin (:or "libsnappy.1.dylib" "libsnappy.dylib"))
  (:unix (:or "libsnappy.so.1" "libsnappy.so"))
  (:windows (:or "snappy.dll" "libsnappy.dll"))
  (t (:default "libsnappy")))

(defcenum snappy-status
  (:ok 0)
  (:invalid-input 1)
  (:buffer-too-small 2))

(defcfun ("snappy_compress" %snappy-compress) snappy-status
  (input :pointer)
  (input-length :size)
  (compressed :pointer)
  (compressed-length (:pointer :size)))

(defcfun ("snappy_uncompress" %snappy-uncompress) snappy-status
  (compressed :pointer)
  (compressed-length :size)
  (uncompressed :pointer)
  (uncompressed-length (:pointer :size)))

(defcfun ("snappy_max_compressed_length" %snappy-max-compressed-length) :size
  (source-length :size))

(defcfun ("snappy_uncompressed_length" %snappy-uncompressed-length) snappy-status
  (compressed :pointer)
  (compressed-length :size)
  (result (:pointer :size)))

(defcfun ("snappy_validate_compressed_buffer" %snappy-validate) snappy-status
  (compressed :pointer)
  (compressed-length :size))
