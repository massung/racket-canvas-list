#lang scribble/manual

@require[@for-label[canvas-list racket/gui]]

@title{Canvas List}
@author[@author+email["Jeffrey Massung" "massung@gmail.com"]]

@defmodule[canvas-list]

A canvas-list is a fast-rendering, single-selection, list control, which allows for complete custom drawing of each item.


@;; ----------------------------------------------------
@section{Example}


@racketblock[
 (require racket/gui canvas-list)
 
 (define frame
   (new frame%
        [label "List Canvas"]
        [width 260]
        [height 400]))

 (define canvas
   (new canvas-list%
        [parent frame]
        [items (range 1000)]
        [action-callback (λ (canvas item event)
                           (displayln item))]))
 
 (send frame show #t)
]


@;; ----------------------------------------------------
@section{Class}

@defclass[canvas-list% canvas% ()]{
 A @racket[canvas-list%] is similar in nature to a @racket[list-box%], but instead derives from @racket[canvas%]. This allows for extremely fast, custom rendering of very large lists. It supports single selection, keyboard and mouse navigation, context menus, mouse hovering, alternate row colors, primary key indexing, sorting, filtering, and more.

 @defconstructor[([items sequence? #()]
                  [item-height exact-nonnegative-integer? 20]
                  [item-color (or/c (is-a?/c color%) #f) #f]
                  [alt-color (or/c (is-a?/c color%) #f) #f]
                  [selection-color (or/c (is-a?/c color%) #f) #f]
                  [hover-color (or/c (is-a?/c color%) #f) #f]
                  [force-selection boolean? #f]
                  [paint-item-callback (or/c ((is-a?/c canvas-list%)
                                              any/c
                                              (or/c 'selected 'hover 'alt #f)
                                              (is-a?/c dc<%>)
                                              exact-nonnegative-integer?
                                              exact-nonnegative-integer?
                                              ->
                                              any/c)
                                             #f)
                                       #f]
                  [selection-callback (or/c ((is-a?/c canvas-list%)
                                             any/c
                                             (or/c (is-a?/c mouse-event%) #f)
                                             ->
                                             any/c)
                                            #f)
                                      #f]
                  [action-callback (or/c ((is-a?/c canvas-list%)
                                          any/c
                                          (or/c (is-a?/c mouse-event%) #f)
                                          ->
                                          any/c)
                                         #f)
                                   #f]
                  [context-action-callback (or/c ((is-a?/c canvas-list%)
                                                  any/c
                                                  (or/c (is-a?/c mouse-event%) #f)
                                                  ->
                                                  any/c)
                                                 #f)
                                           #f])]{
  Creates a new @racket[canvas-list%] with an initial set of items.

  The @racket[items] are the initial sequence of items that should be displayed.

  The @racket[item-height] is the height - in pixels - afforded for each item to be drawn. This must be the same for every item and (currently) items can not have different heights.

  There are 4 different, basic, background colors that are used to draw items by default. @racket[item-color] is the basic background color used to draw each item and defaults to white. The @racket[alt-color] - if provided - is the background color used for every-other item and defaults to a very light gray. The @racket[selection-color] and @racket[hover-color] are both used to highlight the currently selected item and the item the mouse is currently hovering over.

  The @racket[force-selection] parameter - when @racket[#t] - makes it so that once an item in the list has been selected it cannot be unselected (typically by pressing ESC).

  The @racket[paint-item-callback] is called to render each item in the list. Before being called, the @racket[dc<%>] clipping rect is set and translated to the correct location on screen; drawing at <0,0> will be the upper-left corner of the item's cell. The arguments passed are the @racket[canvas-list%] control, then item to render, the state of the item (whether it's selected, being hovered, or an alternate index), the @racket[dc<%>], and the width and height of the cell.

  The @racket[selection-callback] is called every time the currently selected item changes to a different item in the list. It is passed the @racket[canvas-list%], the item selected, and - if selected with the mouse - the @racket[mouse-event%]. If selection happens using the keyboard (e.g. arrow keys), then @racket[#f] is passed for the event.

  The @racket[action-callback] is called whenever the user double-clicks an item or presses RETURN/ENTER while an item is selected. It is passed the same arguments as the @racket[selection-callback].

  The @racket[context-action-callback] is called when the user right-clicks an item. Typically this is used to bring up a @racket[popup-menu%]. It is passed the same arguments as the @racket[selection-callback].
 }
                                                                                                                                 
 @defmethod[(count-items) exact-nonnegative-integer?]{
 Returns the number of items in the primary key. This may be less than the number of items in the list if there is a filter applied.
 }

 @defmethod[(sort-items [less-than? (any/c any/c -> boolean?)]
                        [#:key key (or/c (any/c -> any/c) #f) #f]) void?]{
 Sorts the items in the list.
 }

 @defmethod[(filter-items [pred (any/c -> boolean?)]
                          [#:key key (or/c (any/c -> any/c) #f) #f]) void?]{
 Applies a filter to the items in the list, hiding any that do not match the predicate.
 }

 @defmethod[(reset-primary-key) void?]{
 Removes any applied sorting or filters to the list.
 }

 @defmethod[(get-item [index exact-nonnegative-integer?]) any/c]{
 Returns the item at the given index or @racket[#f] if the index is out of range.
 }

 @defmethod[(set-items [items sequence?]) void?]{
 Clears the current set of items being displayed and replaces it with a new set.
 }

 @defmethod[(insert-items [items sequence?] [index (or/c exact-nonnegative-integer? #f) #f]) void?]{
 Inserts items into the list at the given index. If no index is provided it is inserted before the currently selected index. If there is no selection it is inserted at the beginning.
 }

 @defmethod[(append-items [items sequence?] [index (or/c exact-nonnegative-integer? #f) #f]) void?]{
 Appends items onto the list at the given index. If no index is provided it is added after the currently selected index. If there is no selection it is inserted at the beginning.
 }

 @defmethod[(get-selected-index) (or/c exact-nonnegative-integer? #f)]{
 Returns the index of the currently selected item or @racket[#f] if there is no selection.
 }

 @defmethod[(get-selected-item) any/c]{
 Returns the currently selected item or @racket[#f] if there is no selection.
 }

 @defmethod[(get-hover-index) (or/c exact-nonnegative-integer? #f)]{
 Returns the index of the currently hovered item or @racket[#f] if there is no item being hovered over.
 }

 @defmethod[(get-hover-item) any/c]{
 Returns the currently hovered item or @racket[#f] if there is no item being hovered over.
 }

 @defmethod[(scroll-to-selection) void?]{
 Ensures that the currently selected item is visible.
 }

 @defmethod[(open-selected-item) void?]{
 If an @racket[action-callback] was set and there is a selected item, apply the callback.
 }

 @defmethod[(select-index [index (or/c exact-nonnegative-integer? #f) hover-index]) void?]{
 Changes the current selection to the index. If not provided, the index of the currently hovered over item is used. If @racket[#f], then the current selection is cleared.
 }

 @defmethod[(clear-selection) void?]{
 Clears the current selection.
 }

 @defmethod[(select-first) void?]{
 Selects the first item in the list.
 }

 @defmethod[(select-last) void?]{
 Selects the last item in the list.
 }

 @defmethod[(select-next [#:advance n exact-nonnegative-integer? 1]) void?]{
 Moves to the next item in the list after the current selection. The @racket[advance] parameter is useful when wanting to skip items (e.g. when using page-up/page-down).
 }

 @defmethod[(select-previous [#:advance n exact-nonnegative-integer? 1]) void?]{
 Moves to the previous item in the list before the current selection. The @racket[advance] parameter is useful when wanting to skip items (e.g. when using page-up/page-down).
 }

 @defmethod[(call-with-selected-item [proc (any/c -> any/c)]) void?]{
 If there is a selected item, call @racket[proc] with the selected item.
 }
}
