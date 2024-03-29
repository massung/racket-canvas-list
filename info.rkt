#lang info

(define collection "canvas-list")
(define version "1.0.1")
(define pkg-authors '("massung@gmail.com"))
(define pkg-desc "Fast-rendering, single-selection, canvas control allowing custom drawing for a list of items.")
(define deps '("base" "draw-lib" "gui-lib" "draw-doc" "gui-doc" "racket-doc" "scribble-lib"))
(define scribblings '(("scribblings/canvas-list.scrbl" ())))
(define compile-omit-paths '("images"))
