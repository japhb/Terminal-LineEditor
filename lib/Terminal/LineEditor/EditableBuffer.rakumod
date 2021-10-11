# ABSTRACT: Core roles for abstract editable buffers


#| General exceptions for Terminal::LineEditor
class X::Terminal::LineEditor is Exception { }

#| Invalid buffer position (for
class X::Terminal::LineEditor::InvalidPosition is X::Terminal::LineEditor {
    has $.pos    is required;
    has $.reason is required;

    method message() { "Invalid editable buffer position: $!reason" }
}


#| Simple wrapper for undo/redo record pairs
class Terminal::LineEditor::UndoRedo {
    has $.undo;
    has $.redo;
}


#| Core methods for any editable buffer
role Terminal::LineEditor::EditableBuffer {
    method contents()             { ... }
    method ensure-pos-valid($pos) { ... }
    method insert($pos, $content) { ... }
    method delete($start, $after) { ... }
    # XXXX: Support out-of-order undo/redo
    method undo()                 { ... }
    method redo()                 { ... }
}


#| Core functionality for a single line text buffer
role Terminal::LineEditor::SingleLineTextBuffer
does Terminal::LineEditor::EditableBuffer {
    has Str:D $.contents = '';
    has @.undo-records;
    has @.redo-records;


    ### INVARIANT HELPERS

    #| Throw an exception if a position is out of bounds or the wrong type
    method ensure-pos-valid($pos, Bool:D :$allow-end = False) {
        X::Terminal::LineEditor::InvalidPosition.new($pos, :reason('position is not a defined nonnegative integer')).throw
            unless $pos ~~ Int:D && $pos >= 0;

        X::Terminal::LineEditor::InvalidPosition.new($pos, :reason('position is beyond the buffer end')).throw
            unless $pos < $!contents.chars + $allow-end;
    }


    ### LOW-LEVEL OPERATION APPLIERS

    #| Apply a (previously validated) insert operation against current contents
    multi method apply-operation('insert', $pos, $content) {
        substr-rw($!contents, $pos, 0) = $content;
    }

    #| Apply a (previously validated) delete operation against current contents
    multi method apply-operation('delete', $start, $after) {
        substr-rw($!contents, $start, $after - $start) = '';
    }

    #| Apply a (previously validated) replace operation against current contents
    multi method apply-operation('replace', $start, $after, $replacement) {
        substr-rw($!contents, $start, $after - $start) = $replacement;
    }


    ### INTERNAL UNDO/REDO CORE

    #| Create an undo/redo record pair for an insert operation
    multi method create-undo-redo-record('insert', $pos, $content) {
        # The complexity below is because the inserted string might start with
        # combining characters, and thus due to NFG renormalization insert-pos
        # should move less than the full length of the inserted string.

        # XXXX: This is slow (doing a string copy), but until there is a fast
        # solution for calculating the combined section and replacement length,
        # it will have to do.
        my $temp      = $.contents;
        my $before    = $temp.chars;
        substr-rw($temp, $pos, 0) = $content;
        my $after-pos = $pos + $temp.chars - $before;

        # XXXX: This is likely incorrect for modern Unicode
        my $combined-section = $pos ?? substr($pos - 1, 1) !! '';
        my $combined-start   = $pos - $combined-section.chars;

        $combined-section
        ?? Terminal::LineEditor::UndoRedo.new(
            :redo('replace', $combined-start, $pos, $combined-section ~ $content),
            :undo('replace', $combined-start, $after-pos, $combined-section))
        !! Terminal::LineEditor::UndoRedo.new(
            :redo('insert',  $pos, $content),
            :undo('delete',  $pos, $after-pos))
    }

    #| Create an undo/redo record pair for a delete operation
    multi method create-undo-redo-record('delete', $start, $after) {
        # Complexity from insert case not needed because start and end refer to
        # whole grapheme cluster positions, so we don't end up with split
        # grapheme clusters.

        my $to-delete = substr($.contents, $start, $after - $start);
        Terminal::LineEditor::UndoRedo.new(
            :redo('delete', $start, $after),
            :undo('insert', $start, $to-delete))
    }

    #| Execute an undo record against current contents
    method do-undo-record($record) {
        self.apply-operation(|$record.undo);
        @.redo-records.push($record);
    }

    #| Execute a do/redo record against current contents
    method do-redo-record($record) {
        self.apply-operation(|$record.redo);
        @.undo-records.push($record);
    }

    #| Start a new branch of the undo/redo tree (insert or delete after undo)
    method new-redo-branch() {
        # Simply drop the old redo list, keeping a single linear undo/redo list
        @!redo-records = ();
    }


    ### EXTERNAL EDIT COMMANDS

    #| Insert a substring at a given position
    method insert($pos, Str:D $content) {
        self.ensure-pos-valid($pos);

        self.new-redo-branch;
        my $record = self.create-undo-redo-record('insert', $pos, $content);
        self.do-redo-record($record);
    }

    #| Delete a substring at a given position range
    method delete($start, $end) {
        self.ensure-pos-valid($_) for $start, $end;

        self.new-redo-branch;
        my $record = self.create-undo-redo-record('delete', $start, $end);
        self.do-redo-record($record);
    }

    #| Undo the previous edit (or silently do nothing if no edits left)
    method undo() {
        self.do-undo-record(@.undo-records.pop) if @.undo-records;
    }

    #| Redo a previously undone edit (or silently do nothing if no undos left)
    method redo() {
        self.do-redo-record(@.redo-records.pop) if @.redo-records;
    }
}
