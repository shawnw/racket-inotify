#lang racket/base
;;; Racket bindings for Linux inotify API.
;;; Copyright 2022 Shawn Wagner <shawnw.mobile@gmail.com>

(require ffi/unsafe ffi/unsafe/define ffi/unsafe/define/conventions ffi/unsafe/port
         (rename-in racket/contract [-> -->]) racket/require
         (for-syntax racket/base (only-in racket/string string-prefix?))
         srfi/74 srfi/160/u8 stencil-vector-utils)
(require (filtered-in (lambda (name) (and (string-prefix? name "unsafe-fx") (substring name 7))) racket/unsafe/ops))
(module+ test (require racket/file rackunit))

(provide
 (contract-out
  [inotify-instance? predicate/c]
  [inotify-watch? predicate/c]
  [open-inotify-instance (--> inotify-instance?)]
  [close-inotify-instance (--> inotify-instance? void?)]
  [inotify-set-watch (--> inotify-instance? path-string? (listof symbol?) inotify-watch?)]
  [inotify-remove-watch (--> inotify-instance? inotify-watch? void?)]
  (struct inotify-event ([wd inotify-watch?] [flags (listof symbol?)] [cookie exact-nonnegative-integer?] [name (or/c path? #f)]) #:omit-constructor)
  [read-inotify-event (--> inotify-instance? inotify-event?)]
  [read-inotify-event* (--> inotify-instance? (or/c inotify-event? #f))]
  ))

(define-ffi-definer define-inotify-func (ffi-lib #f) #:make-c-id convention:hyphen->underscore)
(define-inotify-func inotify-init (_fun #:save-errno 'posix -> _int))
(define-inotify-func inotify-add-watch (_fun #:save-errno 'posix _int _path _uint32 -> _int))
(define-inotify-func inotify-rm-watch (_fun #:save-errno 'posix _int _int -> _int))

(define inotify-event-struct-fields (list _int _uint32 _uint32 _uint32))
(define inotify-event-struct (make-cstruct-type inotify-event-struct-fields))
(define inotify-event-struct-size (ctype-sizeof inotify-event-struct))
(define inotify-event-struct-offsets (list->vector (compute-offsets inotify-event-struct-fields)))

(struct inotify-instance (fd port buf [start-pos #:mutable] [end-pos #:mutable])
  #:extra-constructor-name make-inotify-instance
  #:property prop:evt
  (lambda (self)
    (if (fx= (inotify-instance-start-pos self) (inotify-instance-end-pos self))
        (handle-evt (unsafe-fd->evt (inotify-instance-fd self) '(read)) (lambda (evt) (read-inotify-event self)))
        (handle-evt always-evt (lambda (evt) (read-inotify-event self))))))

(struct inotify-watch (descriptor) #:transparent #:extra-constructor-name make-inotify-watch)
(struct inotify-event (wd flags cookie name) #:transparent #:extra-constructor-name make-inotify-event)

(define (raise-errno msg)
  (raise (make-exn:fail:filesystem:errno msg (current-continuation-marks) (cons (saved-errno) 'posix))))

(define (open-inotify-instance)
  (let ([fd (inotify-init)])
    (if (< fd 0)
        (raise-errno "open-inotify-instance")
        (let ([port (unsafe-file-descriptor->port fd 'inotify '(read))])
          (file-stream-buffer-mode port 'none)
          (make-inotify-instance fd port (make-bytes 4096) 0 0)))))

(define (close-inotify-instance inot)
  (unsafe-fd->evt (inotify-instance-fd inot) 'remove)
  (close-input-port (inotify-instance-port inot)))

(define flags '#hasheq( (IN_ACCESS . 1) (IN_ATTRIB . 4) (IN_CLOSE_WRITE . 8) (IN_CLOSE_NOWRITE . 16) (IN_CREATE . 256) (IN_DELETE . 512) (IN_DELETE_SELF . 1024) (IN_MODIFY . 2) (IN_MOVE_SELF . 2048) (IN_MOVED_FROM . 64) (IN_MOVED_TO . 128) (IN_OPEN . 32) (IN_MOVE . 192) (IN_CLOSE . 24) (IN_DONT_FOLLOW . 33554432) (IN_EXCL_UNLINK . 67108864) (IN_MASK_ADD . 536870912) (IN_ONESHOT . 2147483648) (IN_ONLYDIR . 16777216) (IN_IGNORED . 32768) (IN_ISDIR . 1073741824) (IN_Q_OVERFLOW . 16384) (IN_UNMOUNT . 8192) (IN_ALL_EVENTS . 4095)))

(define (flags->bitmask name flag-list)
  (for/fold ([bitmask 0])
            ([flag (in-list flag-list)])
    (bitwise-ior bitmask (hash-ref flags flag (lambda () (raise-argument-error name "unknown inotify flag" "flag" flag))))))

(define bitmask->flags
  (if (fx= (stencil-vector-mask-width) 58)
      (let ([flag-names (for/fold ([sv (stencil-vector 0)])
                                  ([(flag val) (in-hash flags)]
                                   #:when (fx= (fxpopcount32 val) 1))
                          (stencil-vector-update sv 0 val flag))])
        (lambda (mask)
          (stencil-vector->list (stencil-vector-update flag-names (fxand (stencil-vector-mask flag-names) (fxnot mask)) 0))))
      (error "Currently unimplemented for 32 bit")))

(define (inotify-set-watch inot path flags)
  (let ([wd (inotify-add-watch (inotify-instance-fd inot) (path->complete-path path) (flags->bitmask 'inotify-set-watch flags))])
    (if (fx< wd 0)
        (raise-errno "inotify-set-watch")
        (make-inotify-watch wd))))

(define (inotify-remove-watch inot wd)
  (when (fx< (inotify-rm-watch (inotify-instance-fd inot) (inotify-watch-descriptor wd)) 0)
    (raise-errno "inotify-remove-watch")))

(define (fxzero? n) (fx= n 0))
(define (extract-path buf)
  (let ([last-non-null (u8vector-skip-right fxzero? buf)])
    (bytes->path (subbytes buf 0 (fx+ last-non-null 1)))))

(define endian (if (system-big-endian?) (endianness big) (endianness little)))

(define (build-inotify-event inot)
  (let* ([buf (inotify-instance-buf inot)]
         [start (inotify-instance-start-pos inot)]
         [wd (blob-s32-ref endian buf (fx+ start (vector-ref inotify-event-struct-offsets 0)))]
         [mask (blob-u32-ref endian buf (fx+ start (vector-ref inotify-event-struct-offsets 1)))]
         [cookie (blob-u32-ref endian buf (fx+ start (vector-ref inotify-event-struct-offsets 2)))]
         [path-len (blob-u32-ref endian buf (fx+ start (vector-ref inotify-event-struct-offsets 3)))]
         [end-pos (fx+ start inotify-event-struct-size path-len)]
         [path (if (fx> path-len 0) (extract-path (subbytes buf (fx+ start inotify-event-struct-size) end-pos)) #f)])
    (set-inotify-instance-start-pos! inot end-pos)
    (make-inotify-event (make-inotify-watch wd) (bitmask->flags mask) cookie path)))

(define (read-inotify-event inot)
  (when (fx= (inotify-instance-start-pos inot) (inotify-instance-end-pos inot))
    (set-inotify-instance-start-pos! inot 0)
    (set-inotify-instance-end-pos! inot (read-bytes-avail! (inotify-instance-buf inot) (inotify-instance-port inot))))
  (build-inotify-event inot))

;; Non-blocking version
(define (read-inotify-event* inot)
  (when (fx= (inotify-instance-start-pos inot) (inotify-instance-end-pos inot))
    (set-inotify-instance-start-pos! inot 0)
    (set-inotify-instance-end-pos! inot (read-bytes-avail!* (inotify-instance-buf inot) (inotify-instance-port inot))))
  (if (fx= (inotify-instance-start-pos inot) (inotify-instance-end-pos inot))
      #f
      (build-inotify-event inot)))

(module+ test
  ;; Any code in this `test` submodule runs when this file is run using DrRacket
  ;; or with `raco test`. The code here does not run when this file is
  ;; required by another module.

  (define tmpdir (make-temporary-directory))
  (define inot (open-inotify-instance))
  (define wd (inotify-set-watch inot tmpdir '(IN_CREATE)))

  (define tid
    (thread
     (lambda ()
       (display-to-file 1 (build-path tmpdir "a.txt"))
       (display-to-file 2 (build-path tmpdir "b.txt"))
       (display-to-file 3 (build-path tmpdir "c.txt"))
       (display-to-file 4 (build-path tmpdir "d.txt"))
       )))

  (check-equal? (path->string (inotify-event-name (read-inotify-event inot))) "a.txt")
  (check-equal? (path->string (inotify-event-name (sync inot))) "b.txt")
  (check-equal? (inotify-event-flags (read-inotify-event inot)) '(IN_CREATE))
  (check-equal? (inotify-event-wd (read-inotify-event inot)) wd)
  (thread-wait tid)
  (delete-directory/files tmpdir)
  (check-equal? (inotify-event-flags (read-inotify-event inot)) '(IN_IGNORED))

  (close-inotify-instance inot))
