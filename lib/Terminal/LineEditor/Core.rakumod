# ABSTRACT: Core roles and exceptions for abstract editable buffers


#| General exceptions for Terminal::LineEditor
class X::Terminal::LineEditor is Exception { }

#| Invalid buffer position
class X::Terminal::LineEditor::InvalidPosition is X::Terminal::LineEditor {
    has $.pos    is required;
    has $.reason is required;

    method message() { "Invalid editable buffer position: $!reason" }
}

#| Invalid buffer range
class X::Terminal::LineEditor::InvalidRange is X::Terminal::LineEditor {
    has $.start  is required;
    has $.after  is required;
    has $.reason is required;

    method message() { "Invalid editable buffer position range: $!reason" }
}

#| Invalid or non-existant cursor
class X::Terminal::LineEditor::InvalidCursor is X::Terminal::LineEditor {
    has $.id     is required;
    has $.reason is required;

    method message() { "Invalid cursor: $!reason" }
}


#| Core methods for any editable buffer
role Terminal::LineEditor::EditableBuffer {
    # Return raw buffer contents
    method contents()                                { ... }

    # Throw exception if pos or range not valid
    method ensure-pos-valid($pos, :$allow-end)       { ... }
    method ensure-range-valid($start, $after)        { ... }

    # Perform primitive edit operations
    method insert($pos, $content)                    { ... }
    method yank($pos)                                { ... }
    method delete($start, $after)                    { ... }
    method delete-length($start, $length)            { ... }
    method replace($start, $after, $content)         { ... }
    method replace-length($start, $length, $content) { ... }

    # Undo/redo
    # XXXX: Support out-of-order undo/redo
    method undo()                                    { ... }
    method redo()                                    { ... }
}
