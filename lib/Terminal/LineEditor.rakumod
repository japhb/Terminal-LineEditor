unit class Terminal::LineEditor:auth<zef:japhb>:api<0>:ver<0.0.16>;


=begin pod

=head1 NAME

Terminal::LineEditor - Generalized terminal line editing


=head1 SYNOPSIS

=begin code :lang<raku>

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


=end code

=head1 DESCRIPTION

C<Terminal::LineEditor> is a terminal line editing package similar to
C<Linenoise> or C<Readline>, but B<not> a drop-in replacement for either of
them.  C<Terminal::LineEditor> has a few key design differences:

=item Implemented in pure Raku; C<Linenoise> and C<Readline> are NativeCall
      wrappers.

=item Features strong separation of concerns; all components are exposed and
      replaceable.

=item Useable both directly for simple CLI apps and embedded in TUI interfaces.


=head2 Use with Rakudo REPL

A L<PR for Rakudo|https://github.com/rakudo/rakudo/pull/4623> has been created
to allow C<Terminal::LineEditor> to be used as the REPL line editor when Rakudo
is used in interactive mode.  If your Rakudo build includes this PR, you can
set the following in your environment to use C<Terminal::LineEditor> by default:

=begin code :lang<raku>
export RAKUDO_LINE_EDITOR=LineEditor
=end code

If the environment variable is I<not> specified, but C<Terminal::LineEditor> is
the only line editing module installed, Rakudo will auto-detect and enable it.


=head2 Default Keymap

The latest version of the default keymap is specified in
C<Terminal::LineEditor::KeyMappable.default-keymap()>,
but the below represents the currently implemented, commonly used keys:

=begin table :caption<Commonly Used Keys>
    KEY         | FUNCTION            | NOTES
    ============|=====================|=======================================
    Ctrl-A      | move-to-start       |
    Ctrl-B      | move-char-back      |
    Ctrl-C      | abort-input         |
    Ctrl-D      | abort-or-delete     | Abort if empty, or delete-char-forward
    Ctrl-E      | move-to-end         |
    Ctrl-F      | move-char-forward   |
    Ctrl-H      | delete-char-back    |
    Ctrl-J      | finish              | LF (Line Feed)
    Ctrl-K      | delete-to-end       |
    Ctrl-L      | refresh-all         |
    Ctrl-M      | finish              | CR (Carriage Return)
    Ctrl-N      | history-next        |
    Ctrl-P      | history-prev        |
    Ctrl-T      | swap-chars          |
    Ctrl-U      | delete-to-start     |
    Ctrl-V      | literal-next        |
    Ctrl-W      | delete-word-back    |
    Ctrl-Y      | yank                |
    Ctrl-Z      | suspend             |
    Ctrl-_      | undo                | Ctrl-Shift-<hyphen> on some keyboards
    Backspace   | delete-char-back    |
    CursorLeft  | move-char-back      |
    CursorRight | move-char-forward   |
    CursorHome  | move-to-start       |
    CursorEnd   | move-to-end         |
    CursorUp    | history-prev        |
    CursorDown  | history-next        |
    Alt-b       | move-word-back      |
    Alt-c       | tclc-word           | Readline treats this as Capitalize
    Alt-d       | delete-word-forward |
    Alt-f       | move-word-forward   |
    Alt-l       | lowercase-word      |
    Alt-t       | swap-words          |
    Alt-u       | uppercase-word      |
    Alt-<       | history-start       | Alt-Shift-<comma> on some keyboards
    Alt->       | history-end         | Alt-Shift-<period> on some keyboards
=end table

All bindable edit functions are defined in the
C<Terminal::LineEditor::SingleLineTextInput> role
(in each corresponding method beginning with C<edit->) or is one of the
following special actions:

=begin table :caption<Special Actions>
    ACTION          | MEANING
    ================|=========================================================
    abort-input     | Throw away input so far and return an undefined Str
    abort-or-delete | abort-input if empty, otherwise delete-char-forward
    finish          | Accept and return current input line
    literal-next    | Insert a literal control character into the buffer
    suspend         | Suspend the program with SIGTSTP, wait for SIGCONT
    history-start   | Switch input to first line in history
    history-prev    | Switch input to previous line in history
    history-next    | Switch input to next line in history
    history-end     | Switch input to last line in history (the partial input)
=end table


=head2 Architecture

C<Terminal::LineEditor> is built up in layers, starting from the most abstract:

=item C<EditableBuffer> -- Basic interface role for editable buffers of all sorts

=item C<SingleLineTextBuffer> -- An C<EditableBuffer> that knows how to apply
      simple insert/delete/replace operations at arbitrary positions/ranges,
      tracks a yank item (the most recently deleted text), and creates and
      manages undo/redo information to allow infinite undo

=item C<SingleLineTextBuffer::Cursor> -- A cursor class that knows how to
      move around within a C<SingleLineTextBuffer> without moving outside the
      content area, and knows whether edit operations should automatically
      adjust its position

=item C<SingleLineTextBuffer::WithCursors> -- A wrapper of C<SingleLineTextBuffer>
      that supports multiple simultaneous cursors, and handles automatically
      updating them appropriately whenever applying a basic edit operation

=item C<SingleLineTextInput> -- An input field role that tracks its own insert
      position as an auto-updating cursor, and provides a range of edit methods
      that operate relative to the current insert position

=item C<ScrollingSingleLineInput> -- A C<SingleLineTextInput> that knows how
      to scroll within a limited horizontal display width to ensure that the
      insert position is always visible, no longer how long the input

=item C<ScrollingSingleLineInput::ANSI> -- A further extension of
      C<ScrollingSingleLineInput> that is aware of cursor position and movement
      using ANSI/VT escape codes

=item C<CLIInput> -- A driver for C<ScrollingSingleLineInput::ANSI> that deals
      with raw terminal I/O, detects terminal size and cursor position,
      supports a control key map for common edit operations, and handles
      suspend/resume without corrupting terminal state


=head2 Edge Cases

There are a few edge cases for which C<Terminal::LineEditor> chose one of
several possible behaviors.  Here's the reasoning for each of these otherwise
arbitrary decisions:

=item Attempting to apply an edit operation or create a new cursor outside the
      buffer contents throws an exception, because these indicate a logic error
      elsewhere.

=item Attempting to move a previously correct cursor outside the buffer
      contents silently clips the new cursor position to the buffer endpoints,
      because users frequently hold down cursor movement keys (and thus
      repeatedly try to move past an endpoint).

=item Undo'ing a delete operation, where one or more cursors were within the
      deleted region, results in all such cursors moving to the end of the
      undo; this is consistent with the behavior of an insert operation at the
      same position as the delete undo.

=item For the same reason as for delete operations, replace operations that
      overlap cursor locations will move them to the end of the replaced text.


=head2 Unmapped Functionality

Some of the functionality supported by lower layers of C<Terminal::LineEditor>
is not exposed in the default keymap of C<Terminal::LineEditor::KeyMappable>.
This is generally because no commonly-agreed shell keys map to this
functionality.

For example, C<Terminal::LineEditor::SingleLineTextBuffer> can treat replace as
an atomic operation, but basic POSIX shells generally don't; they instead
expect the user to delete and insert as separate operations.

That said, if I've missed a commonly-supported key sequence for any of the
unmapped functionality, please open an issue for this repository with a link to
the relevant docs so I can expand the default keymap.


=head1 AUTHOR

Geoffrey Broadwell <gjb@sonic.net>


=head1 COPYRIGHT AND LICENSE

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=end pod
