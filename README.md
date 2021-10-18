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

Unmapped Functionality
----------------------

Some of the functionality supported by lower layers of `Terminal::LineEditor` is not exposed in the default keymap of `Terminal::LineEditor::KeyMappable`. This is generally because no commonly-agreed shell keys in the basic control code range (codes 0 through 31) map to this functionality.

For example, `Terminal::LineEditor::SingleLineTextBuffer` can treat replace as an atomic operation, but basic POSIX shells generally don't; they instead expect the user to delete and insert as separate operations.

That said, if I've missed a commonly-supported key sequence for any of the unmapped functionality, please open an issue for this repository with a link to the relevant docs so I can expand the default keymap.

AUTHOR
======

Geoffrey Broadwell <gjb@sonic.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

