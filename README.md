NAME
====

Terminal::LineEditor - Generalized terminal line editing

SYNOPSIS
========

```raku
use Terminal::LineEditor;
```

DESCRIPTION
===========

`Terminal::LineEditor` is a terminal line editing package similar to `Linenoise` or `Readline`, but **not** a drop-in replacement for either of them. `Terminal::LineEditor` has a few key design differences:

  * Implemented in pure Raku; `Linenoise` and `Readline` are NativeCall wrappers.

  * Features strong separation of concerns; all components are exposed and replaceable.

  * Useable both directly for simple CLI apps and embedded in TUI interfaces.

Edge Cases
----------

There are a few edge cases for which `Terminal::LineEditor` chose one of several possible behaviors. Here's the reasoning for each of these otherwise arbitrary decisions:

  * Attempting to apply an edit operation or create a new cursor outside the buffer contents throws an exception, because these indicate a logic error elsewhere.

  * Attempting to move a previously correct cursor outside the buffer contents silently clips the new cursor position to the buffer endpoints, because users frequently hold down cursor movement keys (and thus repeatedly try to move past an endpoint).

  * Undo'ing a delete operation, where one or more cursors were within the deleted region, results in all such cursors moving to the end of the undo; this is consistent with the behavior of an insert operation at the same position as the delete undo.

  * For the same reason as for delete operations, replace operations that overlap cursor locations will move them to the end of the replaced text.

AUTHOR
======

Geoffrey Broadwell <gjb@sonic.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

