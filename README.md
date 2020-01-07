# Racket List Canvas

This is a fast-rendering, single-selection, canvas control allowing
custom drawing for a list of items.

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

## Initialization Fields

A `canvas-list%` can be customized quite a bit.

The `items` field initializes the control with the list of items that should be displayed. This list can be updated at any time with the `set-items` method.

The `item-height` is the size - in pixels - of each item. The origin of the device context will be translated by this amount for every item drawn. _In the future I'd like to make this item-dependent, but for now it's a fixed height for each item._

The following background colors are available for setting. They are set to some nice defaults, but can also be set to `#f` if you don't want item backgrounds automatically drawn for you (_note: the `background` color of the canvas is always used to clear the device context before each render_):

* `item-color` a `color%` used as the color for each item
* `alt-color` a `color%` used as the color for every other item
* `selection-color` a `color%` used for the selected item
* `hover-color` a `color%` used for the item under the mouse

The following callbacks are available for when the user interacts with items in the list:

* `selection-callback` function called whenever the selected item changes (default `#f`)
* `action-callback` function called whenever the selected item is double-clicked (default `#f`)
* `context-action-callback` function called whenever the selected item is right-clicked (default `#f`)

Each of the above callbacks take both the `canvas-list%` and the item itself as parameters. For example:

```racket
(define (my-selection-callback canvas-list item)
  (displayln (format "~a was selected" item)))
```

## Subclassing

The default implementation of `canvas-list%` uses a vector to store all the items and renders a string representation of each item (using `~s`).

If you'd like to provide your own, custom method of storing what should be rendered, you will need to override the following methods:

```racket
(define/override (set-items items)) -> ()
(define/override (append-items items)) -> ()
(define/override (count-items)) -> exact-nonnegative-integer?
(define/override (get-item index)) -> any?
```

If you'd like to provide your own, custom rendering of items, you only need to override the `paint-item` method:

```racket
(define/override (paint-item dc index state width height) ...) -> ()
```

* `item` is the item to paint
* `state` is one of `'selected`, `'hover`, `alt` or `#f`
* `width` and `height` are the bounds of the item itself

The canvas is already transformed and clips to the bounds of the item. You can assume the correct background has been drawn and that `(0,0)` is the upper-left corner of the item and `(w,h)` is the lower-right extent.
