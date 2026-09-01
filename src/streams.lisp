(in-package #:cl-stack-snappy)

;;; Gray binary input streams. Snappy's C API is one-shot (no DStream/CStream),
;;; so these slurp SOURCE then wrap COMPRESS / DECOMPRESS — same DX as zstd.

(defclass snappy-octet-stream (trivial-gray-streams:fundamental-binary-input-stream)
  ((data :initarg :data :reader %sos-data)
   (pos :initform 0 :accessor %sos-pos)))

(defclass snappy-decompressing-stream (snappy-octet-stream) ())
(defclass snappy-compressing-stream (snappy-octet-stream) ())

(defun %slurp-octets (stream)
  (let ((out (make-array 0 :element-type '(unsigned-byte 8)
                         :adjustable t :fill-pointer 0))
        (buf (make-array 4096 :element-type '(unsigned-byte 8))))
    (loop for n = (read-sequence buf stream)
          while (plusp n)
          do (loop for i below n do (vector-push-extend (aref buf i) out)))
    (coerce out '(simple-array (unsigned-byte 8) (*)))))

(defun make-decompressing-stream (source)
  "Return a binary input stream that decompresses octets read from SOURCE."
  (check-type source stream)
  (make-instance 'snappy-decompressing-stream
                 :data (decompress (%slurp-octets source))))

(defun make-compressing-stream (source &key level)
  "Return a binary input stream that compresses octets read from SOURCE."
  (check-type source stream)
  (make-instance 'snappy-compressing-stream
                 :data (compress (%slurp-octets source) :level level)))

(defmethod trivial-gray-streams:stream-read-byte ((stream snappy-octet-stream))
  (let ((pos (%sos-pos stream))
        (data (%sos-data stream)))
    (if (>= pos (length data))
        :eof
        (prog1 (aref data pos)
          (incf (%sos-pos stream))))))

(defmethod trivial-gray-streams:stream-read-sequence
    ((stream snappy-octet-stream) seq start end &key)
  (let* ((data (%sos-data stream))
         (pos (%sos-pos stream))
         (n (min (- end start) (- (length data) pos))))
    (replace seq data :start1 start :end1 (+ start n) :start2 pos)
    (incf (%sos-pos stream) n)
    (+ start n)))

(defmethod close ((stream snappy-octet-stream) &key abort)
  (declare (ignore abort))
  t)
