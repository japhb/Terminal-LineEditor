# TODO


* Tests for new bits of EditableBuffer
* Live hint support
* Tab completion
  * Basic functionality
    * DONE: Tab -> enter mode, show next completion
    * Ctrl-G or Escape -> exit mode, restoring original
    * DONE: Other -> exit mode, accepting current completion, do normal action
  * Different display modes
  * Show hints/extra info for each possible completion
    * Different color/font?
  * WIP: Integration with Raku REPL
  * Bell/flash terminal when to indicate no completion left
* Multi-line mode
* WIP: Terminal-Print compatibility
* Prompt, span, completion, and hint colors
* User-visible multi-cursors (e.g. point and mark)
* MAYBE
  * Clear screen with CTRL-L?
  * Ctrl-x prefixed key combos?
  * Mouse support?
  * Selections
