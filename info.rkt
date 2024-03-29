#lang info
(define collection "inotify")
(define deps '("base" "stencil-vector-utils" "srfi-lib" "extra-srfi-libs" ("racket" #:platform #rx"linux")))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/inotify.scrbl" ())))
(define pkg-desc "Bindings to the Linux inotify API")
(define version "0.9")
(define pkg-authors '(shawnw))
(define license '(Apache-2.0 OR MIT))
