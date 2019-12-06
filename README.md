# Racket List Canvas

This is a fast-rendering, single-selection, canvas control allowing
custom drawing of a filtered, sorted list of items.

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
       [items (range 1000)]))

(send frame show #t)
```

## Initialization Fields

A `canvas-list%` can be customized quite a bit.

The `items` field initializes the control with the list of items that should be displayed. This list can be updated at any time with the `set-items` method.

The `item-height` is the size - in pixels - of each item. The origin of the device context will be translated by this amount for every item drawn. _In the future I'd like to make this item-dependent, but for now it's a fixed height for each item._

These fields are available for filtering and sorting the items being rendered to the canvas:

The `filter-function` is used to filter the list (e.g. `odd?`; default `#f`) and can be updated at any time with the `set-filter-function` method.

The `sort-order` function is used to compare items for sorting (e.g. `<`; default `#f`). If the `sort-order` is `#f` then no sorting occurs and the items are displayed in the order they were added to the list. This can be updated at any time with the `set-sort-order` method.

The `sort-key` what is passed to the `sort-order` function (e.g. `second`; default `#f`). If the `sort-key` is `#f` then the items are sorted as if the `sort-key` was the `identity` function. This can be updated at any time with the `set-sort-key` method.

The following background colors are available for setting. They are set to some nice defaults, but can also be set to `#f` if you don't want item backgrounds automatically drawn for you (_note: the `background` color of the canvas is always used to clear the device context before each render_):

* `item-color`
* `alt-color` a `color%` used for every other item
* `selection-color` a `color%` used for the selected item
* `hover-color` a `color%` used for the item under the mouse

The following callbacks are available for when the user interacts with items in the list:

* `selection-callback` function called whenever the selected item changes (default `#f`)
* `action-callback` function called whenever the selected item is clicked (default `#f`)
* `context-action-callback` function called whenever the selected item is right-clicked (default `#f`)

Each of the above callbacks take both the `canvas-list%` and the item itself as parameters. For example:

```racket
(define (my-selection-callback canvas-list item)
  (displayln (format "~a was selected" item)))
```

_Note: Racket currently cannot distinguish between single-click and double-click on a canvas control. For this reason, the first "click" of an item will select it and the second click (whenever that happens) will perform the action. If/when Racket can distinguish between single- and double-clicks, this will be updated._

Finally, the `paint-item-callback` function called whenever an item needs to be draw. By default, this is `#f` and indicates that the default draw function will be used, which simply draws the item as text.

The `paint-item-callback` is passed the `canvas-list%`, the device context (`dc<%>`), the item to be drawn, and finally a state, which is either `'selected`, `'hover`, `alt` or `#f`.
