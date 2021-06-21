#lang racket/gui


#|

Racket Canvas List

Copyright (c) 2019 by Jeffrey Massung
All rights reserved.

--

This is a fast-rendering, single-selection, canvas control allowing
custom drawing for a list of items.

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

                ;; do not allow no selection
                [force-selection #f]

                ;; item colors
                [item-color (make-color #xff #xff #xff)]
                [alt-color (make-color #xf8 #xf8 #xf8)]
                [selection-color (make-color #x99 #xcc #xff)]
                [hover-color (make-color #xbb #xdd #xff)]

                ;; callbacks
                [paint-item-callback #f]
                [selection-callback #f]
                [action-callback #f]
                [context-action-callback #f])

    ;; index mapping
    (define primary-key #())

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

    ;; reset the primary key index
    (define/public (reset-primary-key)
      (set! primary-key (build-vector (vector-length items) identity)))

    ;; return the number of items in the list
    (define/public (count-items)
      (vector-length primary-key))

    ;; return the item at the given index
    (define/public (get-item index)
      (let ([n (- (vector-length primary-key) 1)])
        (and index (<= 0 index n) (vector-ref items (vector-ref primary-key index)))))

    ;; set the list of items
    (define/public (set-items xs)
      (set! items (for/vector ([x xs]) x))
      (reset-primary-key)

      ; update scrolling and redraw
      (send this set-scroll-pos 'vertical 0)
      (update-scrollbar)
      (if (and force-selection selected-index)
          (select-first)
          (clear-selection))
      (send this refresh))

    ;; sort the items
    (define/public (sort-items less-than? #:key [key #f])
      (let ([sel (and selected-index (vector-ref primary-key selected-index))])
        (vector-sort! primary-key
                      less-than?
                      #:cache-keys? #t
                      #:key (λ (i)
                              (let ([item (vector-ref items i)])
                                (if key (key item) item))))
        (select-index (vector-member sel primary-key))))

    ;; filter items
    (define/public (filter-items pred #:key [key #f])
      (let ([sel (and selected-index (vector-ref primary-key selected-index))])
        (when key
          (set! pred (λ (item) (pred (key item)))))
        (set! primary-key (vector-filter (λ (i) (pred (vector-ref items i))) primary-key))
        (select-index (vector-member sel primary-key))
        (update-scrollbar)))

    ;; clear the list of items
    (define/public (clear)
      (set! hover-index #f)
      (set! selected-index #f)
      (set! v-offset 0)
      (set-items #()))

    ;; replace an item at the provided - or selected - index
    (define/public (set-item x [index selected-index])
      (when index
        (vector-set! items (vector-ref primary-key index) x)
        (send this refresh)))

    ;; insert an item before the provided - or selected - index
    (define/public (insert-items xs [index #f])
      (set-items (if index
                     (let-values ([(left right) (vector-split-at items index)])
                       (vector-append left (for/vector ([x xs]) x) right))
                     (vector-append (for/vector ([x xs]) x) items))))

    ;; append new items to the list
    (define/public (append-items xs [index #f])
      (if index
          (insert-items xs (+ index 1))
          (set-items (vector-append items (for/vector ([x xs]) x)))))

    ;; return the currently hovered and selected item indices
    (define/public (get-hover-index) hover-index)
    (define/public (get-selected-index) selected-index)

    ;; return the currently hovered over item
    (define/public (get-hover-item)
      (get-item hover-index))

    ;; return the currently selected item
    (define/public (get-selected-item)
      (get-item selected-index))

    ;; execute a callback with the selected item
    (define/public (call-with-selected-item f)
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
        ('left-down (click event))
        ('right-down (r-click event))
        ('motion (update-hover-index event))
        ('leave (update-hover-index #f))))

    ;; handle key events
    (define/override (on-char event)
      (let ([ds (exact-truncate item-height)])
        (case (send event get-key-code)
          ('down (select-next))
          ('up (select-previous))
          ('next (select-next #:advance (visible-items)))
          ('prior (select-previous #:advance (visible-items)))
          ('home (select-first))
          ('end (select-last))
          ('escape (clear-selection))
          ('clear (clear-selection))
          ('wheel-up (scroll-relative (- ds)))
          ('wheel-down (scroll-relative (+ ds)))
          ((#\space) (scroll-to-selection))
          ((#\return) (open-selected-item)))))

    ;; update the scroll position so the selection is visible
    (define/public (scroll-to-selection)
      (when selected-index
        (let* ([pos (* selected-index item-height)]
               [cur-pos (send this get-scroll-pos 'vertical)]
               [h (send this get-height)]
               [m (- (+ h cur-pos) item-height)]
               [new-pos (cond
                          [(<= cur-pos pos m) cur-pos]
                          [(< pos cur-pos) pos]
                          [else (+ (- pos h) item-height)])])
          (send this set-scroll-pos 'vertical new-pos)
          (send this on-scroll (new scroll-event% [position new-pos])))))

    ;; the selected index should be acted on
    (define/public (open-selected-item)
      (when (and selected-index action-callback)
        (action-callback this (get-selected-item) #f)))

    ;; change the selected item
    (define/public (select-index [index hover-index])
      (unless (and force-selection (not index))
        (set! selected-index index)
        (when selected-index
          (when selection-callback
            (selection-callback this (get-selected-item) #f))
          (scroll-to-selection))
        (send this refresh)))

    ;; clear the current selection
    (define/public (clear-selection)
      (unless (and force-selection (positive? (count-items)))
        (select-index #f)))

    ;; select the first item
    (define/public (select-first)
      (when (positive? (count-items))
        (select-index 0)))

    ;; select the last item
    (define/public (select-last)
      (let ([n (count-items)])
        (when (positive? n)
          (select-index (- n 1)))))

    ;; select the next item
    (define/public (select-next #:advance [n 1])
      (if (not selected-index)
          (select-first)
          (let ([m (- (count-items) 1)])
            (select-index (max (min (+ selected-index n) m) 0)))))

    ;; select the previous item
    (define/public (select-previous #:advance [n 1])
      (select-next #:advance (- n)))

    ;; return the number of visible items
    (define/private (visible-items)
      (exact-truncate (/ (send this get-height) item-height)))

    ;; return the first visible index
    (define/private (first-visible)
      (let-values ([(q r) (quotient/remainder v-offset item-height)])
        (+ q (if (positive? r) 1 0))))

    ;; return the last visible index
    (define/private (last-visible)
      (min (+ (first-visible) (visible-items)) (- (count-items) 1)))

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
    (define/private (scroll-to pos)
      (let ([h (send this get-scroll-range 'vertical)])
        (set! v-offset (min (max pos 0) h))
        (send this set-scroll-pos 'vertical v-offset)
        (send this refresh-now)))

    ;; move the scrollbar relative to its current position
    (define scroll-positions null)
    (define scroll-flush-delay-ms 8) ;; 120FPS
    (define scroll-flush-scheduled? #f)
    (define/private (flush-scroll-position positions)
      (collect-garbage 'incremental)
      (define pos (send this get-scroll-pos 'vertical))
      (define dpos (apply + positions))
      (scroll-to (+ pos dpos)))

    ;; Scrolling is a relatively expensive operation and on platforms
    ;; that generate a lot of scroll wheel events (like when using a
    ;; trackpad on macOS), we need some form of "frame skipping" in
    ;; order to correctly handle situtations where the user starts
    ;; scrolling in one direction then changes direction mid scroll.
    (define/private (scroll-relative dpos)
      (define deadline-evt (alarm-evt (+ (current-inexact-milliseconds) scroll-flush-delay-ms)))
      (set! scroll-positions (cons dpos scroll-positions))
      (unless scroll-flush-scheduled?
        (set! scroll-flush-scheduled? #t)
        (thread
         (lambda ()
           (sync deadline-evt)
           (queue-callback (lambda ()
                             (set! scroll-flush-scheduled? #f)
                             (flush-scroll-position
                              (begin0 (reverse scroll-positions)
                                (set! scroll-positions null)))))))))

    ;; the left mouse button was clicked
    (define/private (click event)
      (let ([now (current-inexact-milliseconds)])
        (if (and (equal? hover-index selected-index)
                 (< (- now click-time) 200))
            (when action-callback
              (action-callback this (get-selected-item) event))
            (select-index))
        (set! click-time now)))

    ;; the right mouse button was clicked
    (define/private (r-click event)
      (unless (eq? hover-index selected-index)
        (select-index)
        (send this refresh-now))
      (when context-action-callback
        (context-action-callback this (get-selected-item) event)))

    ;; update which story is being hovered over
    (define/private (update-hover-index event)
      (if event
          (let* ([y (send event get-y)]
                 [i (exact-truncate (/ (+ y v-offset) item-height))])
            (when (< i (count-items))
              (set! hover-index i)))
          (set! hover-index #f))
      (send this refresh))

    ;; draw a single item in the list
    (define/private (paint-item dc item state w h)
      (if paint-item-callback
          (paint-item-callback this item state dc w h)
          (send dc draw-text (~a item) 1 1)))

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
                (paint-item dc item state w item-height)))))

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
                      [context-action-callback (λ (canvas item event) (println item))]
                      [action-callback (λ (canvas item event)
                                         (send canvas sort-items >))])])
    (send frame show #t)))
