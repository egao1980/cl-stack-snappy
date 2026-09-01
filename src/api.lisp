(in-package #:cl-stack-snappy)

;; defparameter: SBCL DEFCONSTANT on strings trips DEFCONSTANT-UNEQL on reload.
(defparameter +snappy-version+ "1.2.2"
  "Snappy release this package version tracks (must match ASDF :version / OCI tag).")

(define-condition snappy-error (error)
  ((message :initarg :message :reader snappy-error-message))
  (:report (lambda (c s)
             (format s "Snappy error: ~A" (snappy-error-message c)))))

(defvar *snappy-loaded* nil)

(defun %host-os ()
  #+windows "windows"
  #+darwin "darwin"
  #+linux "linux"
  #-(or windows darwin linux) "unknown")

(defun %host-arch ()
  #+(or x86-64 x64) "amd64"
  #+(or arm64 aarch64) "arm64"
  #-(or x86-64 x64 arm64 aarch64) "unknown")

(defun %native-search-dirs ()
  "Overlay native/ (OCI) and lib/<os>-<arch>/ (local build). No LD_LIBRARY_PATH."
  (let ((dirs '()))
    (let ((v (uiop:getenv "CL_STACK_SNAPPY_NATIVE")))
      (when (and v (plusp (length v)))
        (push v dirs)))
    (ignore-errors
      (let* ((sys (asdf:find-system :cl-stack-snappy nil))
             (root (when sys (asdf:system-source-directory sys))))
        (when root
          (push (namestring (merge-pathnames "native/" root)) dirs)
          (push (namestring
                 (merge-pathnames (format nil "lib/~A-~A/" (%host-os) (%host-arch)) root))
                dirs))))
    (nreverse dirs)))

(defun %lib-candidates ()
  #+windows '("snappy.dll" "libsnappy.dll")
  #+darwin '("libsnappy.dylib" "libsnappy.1.dylib")
  #+(and unix (not darwin)) '("libsnappy.so" "libsnappy.so.1")
  #-(or windows darwin unix) '("libsnappy.so"))

(defun %find-libsnappy (dir)
  (dolist (name (%lib-candidates))
    (let ((p (merge-pathnames name (uiop:ensure-directory-pathname dir))))
      (when (probe-file p)
        (return (namestring (truename p)))))))

(defun %absolute-preload (dir)
  "Load libsnappy by absolute path (cl-repository post-install policy)."
  (let ((p (%find-libsnappy dir)))
    (when p
      (load-foreign-library p)
      t)))

(defun %load-native ()
  "Load libsnappy via CFFI search path / absolute preload (not LD_LIBRARY_PATH).
   Invoked at ASDF load — consumers just call COMPRESS / DECOMPRESS."
  (unless *snappy-loaded*
    (let ((preloaded nil))
      (dolist (dir (%native-search-dirs))
        (when (and dir (uiop:directory-exists-p dir))
          (pushnew dir cffi:*foreign-library-directories* :test #'equal)
          (unless preloaded
            (setf preloaded (%absolute-preload dir)))))
      (unless preloaded
        (load-foreign-library 'libsnappy)))
    (setf *snappy-loaded* t))
  (values t +snappy-version+))

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
  (%load-native)
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
  (%load-native)
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
  (%load-native)
  (%with-in-ptr octets
    (lambda (in-ptr in-len)
      (eq :ok (%snappy-validate in-ptr in-len)))))

;;; Auto-load on ASDF load — consumers must not call %LOAD-NATIVE.
(eval-when (:load-toplevel :execute)
  (%load-native))
