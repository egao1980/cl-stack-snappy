(in-package #:cl-stack-snappy)

;; defparameter: SBCL DEFCONSTANT on strings trips DEFCONSTANT-UNEQL on reload.
(defparameter +snappy-version+
  (let ((parts (uiop:split-string (asdf:component-version (asdf:find-system "cl-stack-snappy"))
                                  :separator ".")))
    (format nil "~{~A~^.~}" (subseq parts 0 (min 3 (length parts)))))
  "Snappy release this package tracks: the first three parts of the ASDF :version and OCI tag (the fourth is the package revision).")

(define-condition snappy-error (error)
  ((message :initarg :message :reader snappy-error-message))
  (:report (lambda (c s)
             (format s "Snappy error: ~A" (snappy-error-message c)))))

(defun %check-snappy (status)
  (case status
    (:ok status)
    (:invalid-input (error 'snappy-error :message "invalid input"))
    (:buffer-too-small (error 'snappy-error :message "buffer too small"))
    (otherwise (error 'snappy-error
                      :message (format nil "unknown status ~S" status)))))

(defun %octet-vector (octets)
  (etypecase octets
    ((simple-array (unsigned-byte 8) (*)) octets)
    ((vector (unsigned-byte 8))
     (make-array (length octets) :element-type '(unsigned-byte 8) :initial-contents octets))))

(defun %copy-foreign-octets (ptr n)
  (let ((result (make-array n :element-type '(unsigned-byte 8))))
    (dotimes (i n)
      (setf (aref result i) (mem-aref ptr :uint8 i)))
    result))

(defun %with-in-ptr (octets fn)
  "Call FN with a pointer to OCTETS (null if empty)."
  (let* ((in (%octet-vector octets))
         (in-len (length in)))
    (if (plusp in-len)
        (with-pointer-to-vector-data (in-ptr in)
          (funcall fn in-ptr in-len))
        (funcall fn (null-pointer) 0))))

(defun compress (octets &key level)
  "Compress OCTETS with raw Snappy. Returns an (unsigned-byte 8) vector.
   LEVEL is accepted for zstd/brotli API parity and ignored — the C API has no level."
  (declare (ignore level))
  (%with-in-ptr octets
    (lambda (in-ptr in-len)
      (let ((bound (max 1 (%snappy-max-compressed-length in-len))))
        (with-foreign-objects ((out :uint8 bound)
                               (out-len :size))
          (setf (mem-ref out-len :size) bound)
          (%check-snappy (%snappy-compress in-ptr in-len out out-len))
          (%copy-foreign-octets out (mem-ref out-len :size)))))))

(defun decompress (octets)
  "Decompress raw Snappy OCTETS. Returns an (unsigned-byte 8) vector."
  (%with-in-ptr octets
    (lambda (in-ptr in-len)
      (with-foreign-object (plain-len :size)
        (%check-snappy (%snappy-uncompressed-length in-ptr in-len plain-len))
        (let ((cap (mem-ref plain-len :size)))
          (if (zerop cap)
              (make-array 0 :element-type '(unsigned-byte 8))
              (with-foreign-objects ((out :uint8 cap)
                                     (out-len :size))
                (setf (mem-ref out-len :size) cap)
                (%check-snappy (%snappy-uncompress in-ptr in-len out out-len))
                (%copy-foreign-octets out (mem-ref out-len :size)))))))))

(defun valid-compressed-p (octets)
  "True if OCTETS is a well-formed raw Snappy buffer."
  (%with-in-ptr octets
    (lambda (in-ptr in-len)
      (eq :ok (%snappy-validate in-ptr in-len)))))
