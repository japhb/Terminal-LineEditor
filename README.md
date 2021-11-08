[![Actions Status](https://github.com/japhb/Terminal-LineEditor/workflows/test/badge.svg)](https://github.com/japhb/Terminal-LineEditor/actions)

NAME
====

Terminal::LineEditor - Generalized terminal line editing

SYNOPSIS
========

```raku
### PREP

use Terminal::LineEditor;
use Terminal::LineEditor::RawTerminalInput;

# Create a basic CLI text input object
my $cli = Terminal::LineEditor::CLIInput.new;


### BASICS

# Preload some input history
$cli.load-history($history-file);
$cli.add-history('synthetic input', 'more synthetic input');

# Prompt for input, supporting common edit commands,
# scrolling the field to stay on one line
my $input = $cli.prompt('Please enter your thoughts: ');

# Prompt for a password, masking with asterisks (suppresses history)
my $pass  = $cli.prompt('Password: ', mask => '*');

# Prompt defaults to empty
my $stuff = $cli.prompt;

# Review and save history
.say for $cli.history;
$cli.save-history($history-file);


### TYPICAL USE

loop {
    # Get user's input
    my $in = $cli.prompt("My prompt >");

    # Exit loop if user indicated finished
    last without $in;

    # Add line to history if it is non-empty
    $cli.add-history($in) if $in.trim;

    # Do something with the input line; here we just echo it
    say $in;
}
```

DESCRIPTION
===========

`Terminal::LineEditor` is a terminal line editing package similar to `Linenoise` or `Readline`, but **not** a drop-in replacement for either of them. `Terminal::LineEditor` has a few key design differences:

  * Implemented in pure Raku; `Linenoise` and `Readline` are NativeCall wrappers.

  * Features strong separation of concerns; all components are exposed and replaceable.

  * Useable both directly for simple CLI apps and embedded in TUI interfaces.

Use with Rakudo REPL
--------------------

A [PR for Rakudo](https://github.com/rakudo/rakudo/pull/4623) has been created to allow `Terminal::LineEditor` to be used as the REPL line editor when Rakudo is used in interactive mode. If your Rakudo build includes this PR, you can set the following in your environment to use `Terminal::LineEditor` by default:

```raku
export RAKUDO_LINE_EDITOR=LineEditor
```

If the environment variable is *not* specified, but `Terminal::LineEditor` is the only line editing module installed, Rakudo will auto-detect and enable it.

Default Keymap
--------------

The latest version of the default keymap is specified in `Terminal::LineEditor::KeyMappable.default-keymap()`, but the below represents the currently implemented, commonly used keys:

<table class="pod-table">
<caption>Commonly Used Keys</caption>
<thead><tr>
<th>KEY</th> <th>FUNCTION</th> <th>NOTES</th>
</tr></thead>
<tbody>
<tr> <td>Ctrl-A</td> <td>move-to-start</td> <td></td> </tr> <tr> <td>Ctrl-B</td> <td>move-char-back</td> <td></td> </tr> <tr> <td>Ctrl-C</td> <td>abort-input</td> <td></td> </tr> <tr> <td>Ctrl-D</td> <td>abort-or-delete</td> <td>Abort if empty, or delete-char-forward</td> </tr> <tr> <td>Ctrl-E</td> <td>move-to-end</td> <td></td> </tr> <tr> <td>Ctrl-F</td> <td>move-char-forward</td> <td></td> </tr> <tr> <td>Ctrl-H</td> <td>delete-char-back</td> <td></td> </tr> <tr> <td>Ctrl-J</td> <td>finish</td> <td>LF (Line Feed)</td> </tr> <tr> <td>Ctrl-K</td> <td>delete-to-end</td> <td></td> </tr> <tr> <td>Ctrl-L</td> <td>refresh-all</td> <td></td> </tr> <tr> <td>Ctrl-M</td> <td>finish</td> <td>CR (Carriage Return)</td> </tr> <tr> <td>Ctrl-N</td> <td>history-next</td> <td></td> </tr> <tr> <td>Ctrl-P</td> <td>history-prev</td> <td></td> </tr> <tr> <td>Ctrl-T</td> <td>swap-chars</td> <td></td> </tr> <tr> <td>Ctrl-U</td> <td>delete-to-start</td> <td></td> </tr> <tr> <td>Ctrl-V</td> <td>literal-next</td> <td></td> </tr> <tr> <td>Ctrl-W</td> <td>delete-word-back</td> <td></td> </tr> <tr> <td>Ctrl-Y</td> <td>yank</td> <td></td> </tr> <tr> <td>Ctrl-Z</td> <td>suspend</td> <td></td> </tr> <tr> <td>Ctrl-_</td> <td>undo</td> <td>Ctrl-Shift-&lt;hyphen&gt; on some keyboards</td> </tr> <tr> <td>Backspace</td> <td>delete-char-back</td> <td></td> </tr> <tr> <td>CursorLeft</td> <td>move-char-back</td> <td></td> </tr> <tr> <td>CursorRight</td> <td>move-char-forward</td> <td></td> </tr> <tr> <td>CursorHome</td> <td>move-to-start</td> <td></td> </tr> <tr> <td>CursorEnd</td> <td>move-to-end</td> <td></td> </tr> <tr> <td>CursorUp</td> <td>history-prev</td> <td></td> </tr> <tr> <td>CursorDown</td> <td>history-next</td> <td></td> </tr> <tr> <td>Alt-b</td> <td>move-word-back</td> <td></td> </tr> <tr> <td>Alt-c</td> <td>tclc-word</td> <td>Readline treats this as Capitalize</td> </tr> <tr> <td>Alt-d</td> <td>delete-word-forward</td> <td></td> </tr> <tr> <td>Alt-f</td> <td>move-word-forward</td> <td></td> </tr> <tr> <td>Alt-l</td> <td>lowercase-word</td> <td></td> </tr> <tr> <td>Alt-t</td> <td>swap-words</td> <td></td> </tr> <tr> <td>Alt-u</td> <td>uppercase-word</td> <td></td> </tr> <tr> <td>Alt-&lt;</td> <td>history-start</td> <td>Alt-Shift-&lt;comma&gt; on some keyboards</td> </tr> <tr> <td>Alt-&gt;</td> <td>history-end</td> <td>Alt-Shift-&lt;period&gt; on some keyboards</td> </tr>
</tbody>
</table>

All bindable edit functions are defined in the `Terminal::LineEditor::SingleLineTextInput` role (in each corresponding method beginning with `edit-`) or is one of the following special actions:

<table class="pod-table">
<caption>Special Actions</caption>
<thead><tr>
<th>ACTION</th> <th>MEANING</th>
</tr></thead>
<tbody>
<tr> <td>abort-input</td> <td>Throw away input so far and return an undefined Str</td> </tr> <tr> <td>abort-or-delete</td> <td>abort-input if empty, otherwise delete-char-forward</td> </tr> <tr> <td>finish</td> <td>Accept and return current input line</td> </tr> <tr> <td>literal-next</td> <td>Insert a literal control character into the buffer</td> </tr> <tr> <td>suspend</td> <td>Suspend the program with SIGTSTP, wait for SIGCONT</td> </tr> <tr> <td>history-start</td> <td>Switch input to first line in history</td> </tr> <tr> <td>history-prev</td> <td>Switch input to previous line in history</td> </tr> <tr> <td>history-next</td> <td>Switch input to next line in history</td> </tr> <tr> <td>history-end</td> <td>Switch input to last line in history (the partial input)</td> </tr>
</tbody>
</table>

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

Some of the functionality supported by lower layers of `Terminal::LineEditor` is not exposed in the default keymap of `Terminal::LineEditor::KeyMappable`. This is generally because no commonly-agreed shell keys map to this functionality.

For example, `Terminal::LineEditor::SingleLineTextBuffer` can treat replace as an atomic operation, but basic POSIX shells generally don't; they instead expect the user to delete and insert as separate operations.

That said, if I've missed a commonly-supported key sequence for any of the unmapped functionality, please open an issue for this repository with a link to the relevant docs so I can expand the default keymap.

AUTHOR
======

Geoffrey Broadwell <gjb@sonic.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

