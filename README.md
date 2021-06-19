# Racket List Canvas

This is a fast-rendering, single-selection, canvas control allowing custom drawing for a list of items. It can handle extremely large lists as it only renders what's visible on the screen. Additionally, it supports:

* Single selection
* Keyboard and mouse navigation
* Context menus
* Mouse hovering
* Alternate row colors
* Primary key indexing with sorting and filtering

## Example Usage

```racket
(define frame
  (new frame%
       [label "List Canvas"]
       [width 260]
       [height 400]))

(define canvas
  (new canvas-list%
       [parent frame]
       [items (range 1000)]
       [action-callback (λ (canvas item)
                          (displayln item))]))

(send frame show #t)
```

## Documentation

Check out the [scribble documentation][doc].

## Screenshot

This is a screenshot of my own, personal, Hacker News reader made with this control.

![](images/hn.png)

[doc]: https://docs.racket-lang.org/canvas-list/index.html
