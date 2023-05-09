#lang racket/base

(require racket/function racket/pretty c-defs)
(provide pre-installer)

(define inotify-header (c-defs "sys/inotify.h"))

(define inotify-symbols
  '(
    IN_ACCESS
    IN_ATTRIB
    IN_CLOSE_WRITE
    IN_CLOSE_NOWRITE
    IN_CREATE
    IN_DELETE
    IN_DELETE_SELF
    IN_MODIFY
    IN_MOVE_SELF
    IN_MOVED_FROM
    IN_MOVED_TO
    IN_OPEN
    IN_MOVE
    IN_CLOSE
    IN_DONT_FOLLOW
    IN_EXCL_UNLINK
    IN_MASK_ADD
    IN_ONESHOT
    IN_ONLYDIR
    IN_IGNORED
    IN_ISDIR
    IN_Q_OVERFLOW
    IN_UNMOUNT
    IN_ALL_EVENTS))

(define (pre-installer collects-path local-path)
  (displayln "Creating private/flags.rkt")
  (with-output-to-file (build-path local-path "private" "flags.rkt")
    #:exists 'truncate/replace
    (thunk
     (displayln "#lang racket/base")
     (displayln "(provide inotify-flags)")
     (pretty-write
      `(define inotify-flags
         ,(for/hasheq ([sym (in-list inotify-symbols)]
                       [val (in-list
                             (call-with-values
                              (thunk
                               (apply inotify-header
                                      "%u"
                                      (map symbol->string inotify-symbols)))
                              list))])
            (values sym val)))))))
