#lang racket/gui


#|

Racket Canvas List

Copyright (c) 2019 by Jeffrey Massung
All rights reserved.

--

This is a fast-rendering, multi-selection, canvas control allowing
custom drawing of a filtered, sorted list of items.

See https://github.com/massung/racket-canvas-list for documentation
and example usage.

|#


(provide canvas-list%)


(require racket/draw)
(require racket/match)


;; create one big canvas to render the stories on
(define canvas-list%
  (class canvas%
    (super-new [style '(vscroll no-autoclear)]
               [paint-callback (λ (canvas dc) (paint dc))])

    ;; public fields
    (init-field [items #()]
                [item-height 20]

                ;; item colors
                [item-color (make-color #xff #xff #xff)]
                [alt-color (make-color #xf8 #xf8 #xf8)]
                [selection-color (make-color #x99 #xcc #xff)]
                [hover-color (make-color #xbb #xdd #xff)]

                ;; callbacks
                [selection-callback #f]
                [action-callback #f]
                [context-action-callback #f])

    ;; the summed height of all display items
    (define display-height 0)

    ;; hovered-over and selected item
    (define hover-index #f)
    (define selected-index #f)

    ;; horizontal and vertical scroll offsets
    (define h-offset 0)
    (define v-offset 0)

    ;; the last time a click event was received
    (define click-time 0)

    ;; return the number of items in the list
    (define/public (count-items)
      (vector-length items))

    ;; return the item at the given index
    (define/public (get-item index)
      (let ([n (- (vector-length items) 1)])
        (and index (<= 0 index n) (vector-ref items index))))

    ;; draw a single item in the list
    (define/public (paint-item dc item state w h)
      (send dc draw-text (~s item) 1 1))

    ;; set the list of items
    (define/public (set-items xs)
      (set! items (for/vector ([x xs]) x))

      ; update scrolling and redraw
      (update-scrollbar)
      (send this refresh))

    ;; clear the list of items
    (define/public (clear)
      (set-items #()))

    ;; append new items to the list
    (define/public (append-items xs)
      (set-items (vector-append items (for/vector ([x xs]) x))))

    ;; return the currently hovered over item
    (define/public (get-hover-item)
      (get-item hover-index))

    ;; return the currently selected item
    (define/public (get-selected-item)
      (get-item selected-index))

    ;; execute a callback with the selected item
    (define/public (apply-to-selected-item f)
      (let ([item (get-selected-item)])
        (when item
          (f item))))

    ;; when the scroll position updates, refresh
    (define/override (on-scroll event)
      (let ([h (send this get-scroll-range 'vertical)]
            [pos (send event get-position)])
        (when (eq? (send event get-direction) 'vertical)
          (set! v-offset (min (max pos 0) h))))
      (super on-scroll event)
      (send this refresh))

    ;; whenever resized, update the scrollbar range
    (define/override (on-size width height)
      (super on-size width height)
      (update-scrollbar))

    ;; handle mouse events
    (define/override (on-event event)
      (case (send event get-event-type)
        ('left-down (click))
        ('right-down (r-click))
        ('motion (update-hover-index event))))

    ;; handle key events
    (define/override (on-char event)
      (let ([ds (exact-truncate item-height)])
        (case (send event get-key-code)
          ('wheel-up (scroll-relative (- ds)))
          ('wheel-down (scroll-relative (+ ds))))))

    ;; change the selected item to the one being hovered
    (define/public (update-selection #:clear [erase #f])
      (set! selected-index (if erase #f hover-index))
      (when selection-callback
        (selection-callback this (get-selected-item)))
      (send this refresh))

    ;; update the vertical scrollbar range
    (define/private (update-scrollbar)
      (let* ([pos (send this get-scroll-pos 'vertical)]

             ; number of items to display and visible height
             [n (count-items)]
             [h (send this get-height)]

             ; scroll height of all items less a single screen
             [y (- (* n item-height) h)]
             [page (max (- h item-height) 1)]

             ; is the scroll bar visible?
             [show (> y 0)])
        (send this show-scrollbars #f show)
        
        (when show
          (send this init-manual-scrollbars #f y 1 page 0 0)

          ; keep the same scroll position if possible
          (let ([new-pos (min pos y)])
            (send this set-scroll-pos 'vertical new-pos)
            (send this on-scroll (new scroll-event% [position new-pos]))))))

    ;; move the scrollbar to an absolute position
    (define/public (scroll-to pos)
      (let ([h (send this get-scroll-range 'vertical)])
        (set! v-offset (min (max pos 0) h))
        (send this set-scroll-pos 'vertical v-offset)
        (send this refresh-now)))

    ;; move the scrollbar relative to its current position
    (define/public (scroll-relative dpos)
      (let ([pos (send this get-scroll-pos 'vertical)])
        (send this scroll-to (+ pos dpos))))
    
    ;; the left mouse button was clicked
    (define/private (click)
      (let ([now (current-inexact-milliseconds)])
        (if (and (equal? hover-index selected-index)
                 (< (- now click-time) 200))
            (when action-callback
              (action-callback this (get-selected-item)))
            (update-selection))
        (set! click-time now)))

    ;; the right mouse button was clicked
    (define/private (r-click)
      (unless (eq? hover-index selected-index)
        (update-selection)
        (send this refresh-now))
      (when context-action-callback
        (context-action-callback this (get-selected-item))))

    ;; update which story is being hovered over
    (define/private (update-hover-index event)
      (let* ([y (send event get-y)]
             [i (exact-truncate (/ (+ y v-offset) item-height))])
        (when (< i (count-items))
          (set! hover-index i)))
      (send this refresh))

    ;; default render of all items
    (define/private (paint dc)
      (let-values ([(w h) (send dc get-size)])
        (when item-color
          (send dc set-background item-color))
        (send dc clear)

        ; calculate the visible items and y offset
        (let-values ([(q r) (quotient/remainder v-offset item-height)])
          (for ([i (range q (count-items))]
                [y (range (- r) h item-height)])
            (let ([item (get-item i)])
              (send dc set-origin 0 y)
              (send dc set-clipping-rect 0 0 w item-height)
              
              ; determine the state of this item
              (let* ([state (cond
                              ((eq? i selected-index) 'selected)
                              ((eq? i hover-index) 'hover)
                              ((odd? i) 'alt)
                              (#t #f))]
                     
                     ; determine the background color
                     [color (match state
                              ('selected selection-color)
                              ('hover hover-color)
                              ('alt alt-color)
                              (_ #f))])
                
                ; draw the background
                (when color
                  (send dc set-pen color 0 'solid)
                  (send dc set-brush color 'solid)
                  (send dc draw-rectangle 0 0 w item-height))
                
                ; draw the item
                (send this paint-item dc item state w item-height)))))

        ; clear clipping
        (send dc set-clipping-region #f)))

    ;; overwrite the items list with a new list of items
    (send this set-items items)))



;; test list
(define (test-canvas-list)
  (let* ([frame (new frame%
                     [label "List Canvas"]
                     [width 260]
                     [height 400])]
         [canvas (new canvas-list%
                      [parent frame]
                      [items (range 1000)]
                      [action-callback (λ (canvas item)
                                         (displayln item))])])
    (send frame show #t)))
