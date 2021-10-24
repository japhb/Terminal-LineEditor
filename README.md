[![Actions Status](https://github.com/japhb/Terminal-LineEditor/workflows/test/badge.svg)](https://github.com/japhb/Terminal-LineEditor/actions)

NAME
====

Terminal::LineEditor - Generalized terminal line editing

SYNOPSIS
========

```raku
use Terminal::LineEditor;
use Terminal::LineEditor::RawTerminalInput;

# Create a basic CLI text input object
my $cli = Terminal::LineEditor::CLIInput.new;

# Preload some input history
$cli.add-history('a previous input', 'another previous input');

# Prompt for input, supporting common edit commands,
# scrolling the field to stay on one line
my $input = $cli.prompt('Please enter your thoughts: ');

# Prompt for a password, masking with asterisks (suppresses history)
my $pass  = $cli.prompt('Password: ', mask => '*');

# Prompt defaults to empty
my $stuff = $cli.prompt;

# Review history
.say for $cli.history;
```

DESCRIPTION
===========

`Terminal::LineEditor` is a terminal line editing package similar to `Linenoise` or `Readline`, but **not** a drop-in replacement for either of them. `Terminal::LineEditor` has a few key design differences:

  * Implemented in pure Raku; `Linenoise` and `Readline` are NativeCall wrappers.

  * Features strong separation of concerns; all components are exposed and replaceable.

  * Useable both directly for simple CLI apps and embedded in TUI interfaces.

Architecture
------------

`Terminal::LineEditor` is built up in layers, starting from the most abstract:

  * `EditableBuffer` -- Basic interface role for editable buffers of all sorts

  * `SingleLineTextBuffer` -- An `EditableBuffer` that knows how to apply simple insert/delete/replace operations at arbitrary positions/ranges, tracks a yank item (the most recently deleted text), and creates and manages undo/redo information to allow infinite undo

  * `SingleLineTextBuffer::Cursor` -- A cursor class that knows how to move around within a `SingleLineTextBuffer` without moving outside the content area, and knows whether edit operations should automatically adjust its position

  * `SingleLineTextBuffer::WithCursors` -- A wrapper of `SingleLineTextBuffer` that supports multiple simultaneous cursors, and handles automatically updating them appropriately whenever applying a basic edit operation

  * `SingleLineTextInput` -- An input field role that tracks its own insert position as an auto-updating cursor, and provides a range of edit methods that operate relative to the current insert position

  * `ScrollingSingleLineInput` -- A `SingleLineTextInput` that knows how to scroll within a limited horizontal display width to ensure that the insert position is always visible, no longer how long the input

  * `ScrollingSingleLineInput::ANSI` -- A further extension of `ScrollingSingleLineInput` that is aware of cursor position and movement using ANSI/VT escape codes

  * `CLIInput` -- A driver for `ScrollingSingleLineInput::ANSI` that deals with raw terminal I/O, detects terminal size and cursor position, supports a control key map for common edit operations, and handles suspend/resume without corrupting terminal state

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

