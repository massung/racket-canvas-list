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
    (init-field [items null]
                [item-height 20]
                [item-repr (λ (x) (format "~a" x))]

                ;; item colors
                [item-color (make-color #xff #xff #xff)]
                [alt-color (make-color #xf8 #xf8 #xf8)]
                [selection-color (make-color #x99 #xcc #xff)]
                [hover-color (make-color #xbb #xdd #xff)]

                ;; callbacks
                [action-callback #f]
                [context-action-callback #f]
                [paint-item-callback #f]
                [selection-callback #f]

                ;; sorting and filtering
                [sort-order #f]
                [sort-key #f]
                [filter-function #f])

    ;; all the items to be displayed
    (define display-items null)

    ;; the summed height of all display items
    (define display-height 0)

    ;; hovered-over and selected item
    (define hover-item #f)
    (define selected-item #f)

    ;; the last time a click event was received
    (define click-time 0)

    ;; horizontal and vertical scroll offsets
    (define h-offset 0)
    (define v-offset 0)

    ;; a stream of unique identifiers for items
    (define last-uid 0)

    ;; clear the list of items
    (define/public (clear)
      (send this set-items null))

    ;; set the list of items
    (define/public (set-items xs)
      (set! items (for/list ([x xs]) (make-item x)))
      (update-display-items))

    ;; append new items to the list
    (define/public (append-items xs)
      (set! items (append items (for/list ([x xs]) (make-item x))))
      (update-display-items))

    ;; create a new item, giving it a unique ID
    (define/private (make-item x)
      (let ([uid last-uid])
        (set! last-uid (+ last-uid 1))
        (cons uid x)))

    ;; return the uid of a given item
    (define item-uid car)
    (define item-value cdr)

    ;; update the list of visible items
    (define/private (update-display-items)
      (let* ([ff (or filter-function (const #t))]
             [xs (filter (compose ff item-value) items)])
        (set! display-items
              (if (not sort-order)
                  xs
                  (sort xs sort-order
                        #:key (compose (or sort-key identity) item-value))))

        ; calculate the height of all the items
        (set! display-height (* item-height (length display-items))))

      ; update the scrollbar and refresh
      (update-scrollbar)
      (send this refresh))

    ;; return the current list of items being displayed
    (define/public (get-display-items)
      (map item-value display-items))

    ;; return the value of an item with a given uid
    (define/private (get-item uid)
      (let ([item (findf (λ (i) (eq? (item-uid i) uid)) items)])
        (and item (item-value item))))

    ;; return the currently hovered over item
    (define/public (get-hover-item) (get-item hover-item))

    ;; return the currently selected item
    (define/public (get-selected-item) (get-item selected-item))

    ;; execute a callback with the selected item
    (define/public (apply-to-selected-item f)
      (let ([item (get-item selected-item)])
        (when item
          (f item))))

    ;; change the sort ordering and key
    (define/public (set-sort-order ord #:key [key #f])
      (set! sort-order ord)
      (set! sort-key key)
      (update-display-items))

    ;; change the filter function
    (define/public (set-filter-function filter)
      (set! filter-function (or filter (const #t)))
      (update-display-items))

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
        ('motion (update-hover-item event))))

    ;; handle key events
    (define/override (on-char event)
      (let ([ds (exact-truncate item-height)])
        (case (send event get-key-code)
          ('wheel-up (scroll-relative (- ds)))
          ('wheel-down (scroll-relative (+ ds))))))

    ;; change the selected item to the one being hovered
    (define/public (update-selection #:clear [erase #f])
      (set! selected-item (if erase #f hover-item))
      (when selection-callback
        (selection-callback this (send this get-selected-item)))
      (send this refresh))

    ;; update the vertical scrollbar range
    (define/private (update-scrollbar)
      (let* ([pos (send this get-scroll-pos 'vertical)]

             ; number of items to display and visible height
             [n (length display-items)]
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
        (if (and (< (- now click-time) 200)
                 (equal? hover-item selected-item))
            (when action-callback
              (action-callback this (send this get-selected-item)))
          (send this update-selection))
        (set! click-time now)))

    ;; the right mouse button was clicked
    (define/private (r-click)
      (unless (eq? hover-item selected-item)
        (send this update-selection)
        (send this refresh-now))
      (when context-action-callback
        (context-action-callback this (send this get-selected-item))))

    ;; update which story is being hovered over
    (define/private (update-hover-item event)
      (let* ([y (send event get-y)]
             [i (exact-truncate (/ (+ y v-offset) item-height))])
        (when (< i (length display-items))
          (set! hover-item (item-uid (list-ref display-items i)))))
      (send this refresh))

    ;; default render of all items
    (define/private (paint dc)
      (let-values ([(w h) (send dc get-size)])
        (when item-color
          (send dc set-background item-color))
        (send dc clear)

        ; loop over all the filtered and sorted items
        (for ([i (in-naturals)]
              [item display-items])
          (let ([y (* i item-height)])
            (when (and (> (+ y item-height) v-offset)
                       (> (+ h v-offset) y))
              (send dc set-origin 0 (- y v-offset))
              (send dc set-clipping-rect 0 0 w item-height)
              
              ; determine the state of this item
              (let* ([state (cond
                              ((eq? (item-uid item) selected-item) 'selected)
                              ((eq? (item-uid item) hover-item) 'hover)
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
                (let ([value (item-value item)])
                  (if paint-item-callback
                      (paint-item-callback this dc w item-height value state)
                      (send dc draw-text (item-repr value) 1 1))))

              ; clear clipping
              (send dc set-clipping-region #f))))))

    ;; overwrite the items list with a new list of uid item pairs
    (send this set-items items)))
