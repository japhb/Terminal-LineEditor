# ABSTRACT: Core roles for abstract editable buffers

use Terminal::LineEditor::Core;


# GENERAL INVARIANTS MAINTAINED

# * Content buffers are always in NFG Str form (tested in Raku for edge cases
#   like inserting a combining mark between characters, and it Just Works).
# * Edits are always done by applying an UndoRedo record (choosing the branch
#   based on whether undoing or doing/redoing).
# * Cursor positions are always within the range 0..$cursor.end.


#| Simple wrapper class for undo/redo record pairs
class Terminal::LineEditor::UndoRedo {
    has $.undo is required;
    has $.redo is required;
}


#| Core functionality for a single line text buffer
class Terminal::LineEditor::SingleLineTextBuffer
 does Terminal::LineEditor::EditableBuffer {
    has Str:D $.contents = '';
    has Str   $.yankable;

    has @.undo-records;
    has @.redo-records;


    ### INVARIANT HELPERS

    #| Throw an exception if a position is out of bounds or the wrong type
    method ensure-pos-valid($pos, Bool:D :$allow-end = True) {
        X::Terminal::LineEditor::InvalidPosition.new(:$pos, :reason('position is not a defined nonnegative integer')).throw
            unless $pos ~~ Int && $pos.defined && $pos >= 0;

        X::Terminal::LineEditor::InvalidPosition.new(:$pos, :reason('position is beyond the buffer end')).throw
            unless $pos < $!contents.chars + $allow-end;
    }


    #| Throw an exception if a position range is nonsensical
    method ensure-range-valid($start, $after) {
        self.ensure-pos-valid($start);
        self.ensure-pos-valid($after);

        X::Terminal::LineEditor::InvalidRange.new(:$start, :$after, :reason('range endpoints are reversed')).throw
            if $start > $after;
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
        # could move less than the full length of the inserted string.

        # XXXX: This is slow (doing multiple string copies), but until there is
        # a fast solution for calculating the replacement it will have to do.
        my $temp      = $.contents;
        my $before    = $temp.chars;
        substr-rw($temp, $pos, 0) = $content;
        my $after-pos = $pos + $temp.chars - $before;

        my $combined-section = '';
        if $pos {
            my $prev = substr($.contents, $pos - 1, 1);
            my $cur  = substr($temp,      $pos - 1, 1);
            $combined-section = $prev if $prev ne $cur;
        }
        my $combined-start = $pos - $combined-section.chars;

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
        $!yankable    = $to-delete;

        Terminal::LineEditor::UndoRedo.new(
            :redo('delete', $start, $after),
            :undo('insert', $start, $to-delete))
    }

    #| Create an undo/redo record pair for a replace operation
    multi method create-undo-redo-record('replace', $start, $after, $content) {
        # Because replace includes a content insert, it has the same complexity
        # as the insert case above: the inserted string might start with
        # combining characters, so insert-pos could move less than the full
        # length of the inserted string due to NFG renormalization.

        # XXXX: This is slow (doing multiple string copies), but until there is
        # a fast solution for calculating the replacement it will have to do.
        my $temp     = $.contents;
        my $before   = $temp.chars;
        my $orig     = substr($temp, $start, $after - $start);
        substr-rw($temp, $start, $after - $start) = $content;
        my $adjusted = $after + $temp.chars - $before;


        my $combined-section = '';
        if $start {
            my $prev = substr($.contents, $start - 1, 1);
            my $cur  = substr($temp,      $start - 1, 1);
            $combined-section = $prev if $prev ne $cur;
        }
        my $combined-start = $start - $combined-section.chars;

        $combined-section || $orig
        ?? Terminal::LineEditor::UndoRedo.new(
            :redo('replace', $combined-start, $after, $combined-section ~ $content),
            :undo('replace', $combined-start, $adjusted, $combined-section ~ $orig))
        !! Terminal::LineEditor::UndoRedo.new(
            :redo('insert',  $start, $content),
            :undo('delete',  $start, $adjusted))
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


    ### EXTERNAL EDIT COMMANDS (return True iff actually edited)

    #| Insert a substring at a given position
    method insert($pos, Str $content --> Bool) {
        self.ensure-pos-valid($pos);

        if $content {
            self.new-redo-branch;
            my $record = self.create-undo-redo-record('insert', $pos, $content);
            self.do-redo-record($record);
            True
        }
        else { False }
    }

    #| Yank previously deleted text (if available) at a given position
    method yank($pos --> Bool) {
        self.insert($pos, $.yankable)
    }

    #| Delete a substring at a given position range
    method delete($start, $after --> Bool) {
        self.ensure-range-valid($start, $after);

        if $after - $start {
            self.new-redo-branch;
            my $record = self.create-undo-redo-record('delete', $start, $after);
            self.do-redo-record($record);
            True
        }
        else { False }
    }

    #| Delete a substring defined by starting position and length
    method delete-length($start, $length --> Bool) {
        self.delete($start, $start + $length)
    }

    #| Replace a substring at a given position range
    method replace($start, $after, Str:D $content --> Bool) {
        self.ensure-range-valid($start, $after);

        if $content || $after - $start {
            self.new-redo-branch;
            my $record = self.create-undo-redo-record('replace', $start, $after, $content);
            self.do-redo-record($record);
            True
        }
        else { False }
    }

    #| Replace a substring defined by starting position and length
    method replace-length($start, $length, Str:D $content) {
        self.replace($start, $start + $length, $content)
    }

    #| Undo the previous edit (or silently do nothing if no edits left)
    method undo(--> Bool) {
        if @.undo-records {
            self.do-undo-record(@.undo-records.pop);
            True
        }
        else { False }
    }

    #| Redo a previously undone edit (or silently do nothing if no undos left)
    method redo(--> Bool) {
        if @.redo-records {
            self.do-redo-record(@.redo-records.pop);
            True
        }
        else { False }
    }
}



#| A cursor for a SingleLineTextBuffer
class Terminal::LineEditor::SingleLineTextBuffer::Cursor {
    has Terminal::LineEditor::SingleLineTextBuffer:D $.buffer is required;
    has Bool:D $.auto-edit-move = True;
    has UInt:D $.pos = 0;
    has $.id is required;

    # XXXX: Should there be other failure modes if moving outside contents?

    #| Calculate end position (greatest possible insert position)
    method end() {
        $.buffer.contents.chars
    }

    #| Determine if cursor is already at the end
    method at-end() {
        $.pos == self.end
    }

    #| Move to an absolute position in the buffer; returns new position
    method move-to(UInt:D $pos) {
        # Silently clip to end of buffer
        my $end = self.end;
        $!pos   = $pos > $end ?? $end !! $pos;
    }

    #| Move relative to current position; returns new position
    method move-rel(Int:D $delta) {
        # Silently clip to buffer
        my $pos = $!pos + $delta;
        my $end = self.end;

        $!pos = $pos < 0    ?? 0    !!
                $pos > $end ?? $end !!
                               $pos;
    }
}


#| A SingleLineTextBuffer with (possibly several) active insert cursors
class Terminal::LineEditor::SingleLineTextBuffer::WithCursors
   is Terminal::LineEditor::SingleLineTextBuffer {
    has $.cursor-class = Terminal::LineEditor::SingleLineTextBuffer::Cursor;
    has atomicint $.next-id = 0;
    has %.cursors;


    ### INVARIANT HELPERS

    #| Throw an exception if a cursor ID doesn't exist
    method ensure-cursor-exists($id) {
        X::Terminal::LineEditor::InvalidCursor.new(:$id, :reason('cursor ID does not exist')).throw
            unless $id ~~ Cool && $id.defined && (%!cursors{$id}:exists);
    }


    ### LOW-LEVEL OPERATION APPLIERS, NOW CURSOR-AWARE

    #| Apply a (previously validated) insert operation against current contents
    multi method apply-operation('insert', $pos, $content) {
        my $before = $.contents.chars;
        callsame;
        my $delta  = $.contents.chars - $before;

        for %.cursors.values {
            .move-rel(.auto-edit-move ?? $delta !! 0) if .pos >= $pos;
        }
    }

    #| Apply a (previously validated) delete operation against current contents
    multi method apply-operation('delete', $start, $after) {
        callsame;
        my $delta = $after - $start;

        for %.cursors.values {
            if    .pos >= $after { .move-rel(.auto-edit-move ?? -$delta !! 0) }
            elsif .pos >= $start { .auto-edit-move ?? .move-to($start) !! .move-rel(0) }
        }
    }

    #| Apply a (previously validated) replace operation against current contents
    multi method apply-operation('replace', $start, $after, $replacement) {
        my $before = $.contents.chars;
        callsame;
        my $delta  = $.contents.chars - $before;

        for %.cursors.values {
            if    .pos >= $after { .move-rel(.auto-edit-move ?? $delta !! 0) }
            elsif .pos >= $start { .auto-edit-move ?? .move-to($delta + $after) !! .move-rel(0) }
        }
    }


    ### CURSOR MANAGEMENT

    #| Create a new cursor at $pos (defaulting to buffer start, pos 0),
    #| returning cursor ID (assigned locally to this buffer); the cursor
    #| automatically adjusts position whenever edits change the surrounding
    #| content if auto-edit-move is True (the default)
    method add-cursor(UInt:D $pos = 0, Bool:D :$auto-edit-move = True) {
        self.ensure-pos-valid($pos);

        my $id = ++⚛$!next-id;
        %!cursors{$id} = $.cursor-class.new(:$id, :$pos, :buffer(self),
                                            :$auto-edit-move);
    }

    #| Return cursor object for a given cursor ID
    method cursor(UInt:D $id) {
        self.ensure-cursor-exists($id);

        %!cursors{$id}
    }

    #| Delete the cursor object for a given cursor ID
    method delete-cursor(UInt:D $id) {
        self.ensure-cursor-exists($id);

        %!cursors{$id}:delete
    }
}


role Terminal::LineEditor::SingleLineTextInput {
    has $.buffer-class  = Terminal::LineEditor::SingleLineTextBuffer::WithCursors;
    has $.buffer        = $!buffer-class.new;
    has $.insert-cursor = $!buffer.add-cursor;


    ### Helpers for finding word boundaries
    method word-start($from = $.insert-cursor.pos) {
        return $from unless $from;

        my $target  = $from - 1;
        my $content = $.buffer.contents;
        --$target while $target >= 0 && substr($content, $target, 1) ~~ /\s/;
        --$target while $target >= 0 && substr($content, $target, 1) ~~ /\S/;

        $target + 1
    }

    method word-end($from = $.insert-cursor.pos) {
        my $end = $.insert-cursor.end;
        return $from if $from >= $end;

        my $target  = $from;
        my $content = $.buffer.contents;
        ++$target while $target < $end && substr($content, $target, 1) ~~ /\s/;
        ++$target while $target < $end && substr($content, $target, 1) ~~ /\S/;

        $target
    }

    # NOTE: Return values below indicate whether $!buffer may have been changed

    ### Refresh requests
    method edit-refresh(   --> False) {}
    method edit-refresh-all(--> True) {}


    ### Cursor movement
    method edit-move-to-start(--> False) {
        $.insert-cursor.move-to(0);
    }

    method edit-move-char-back(--> False) {
        $.insert-cursor.move-rel(-1);
    }

    method edit-move-char-forward(--> False) {
        $.insert-cursor.move-rel(+1);
    }

    method edit-move-word-back(--> False) {
        $.insert-cursor.move-to(self.word-start);
    }

    method edit-move-word-forward(--> False) {
        $.insert-cursor.move-to(self.word-end);
    }

    method edit-move-to-end(--> False) {
        $.insert-cursor.move-to($.insert-cursor.end);
    }


    ### Delete
    method edit-delete-char-back(--> Bool) {
        $.insert-cursor.pos
        ?? $.buffer.delete-length($.insert-cursor.move-rel(-1), 1)
        !! False
    }

    method edit-delete-char-forward(--> Bool) {
        $.insert-cursor.at-end
        ?? False
        !! $.buffer.delete-length($.insert-cursor.pos, 1)
    }

    method edit-delete-word-back(--> Bool) {
        my $pos = $.insert-cursor.pos;
        if $pos {
            my $cut = self.word-start;
            $.buffer.delete($cut, $pos);
        }
        else { False }
    }

    method edit-delete-word-forward(--> Bool) {
        my $pos = $.insert-cursor.pos;
        my $end = $.insert-cursor.end;
        if $pos < $end {
            my $cut = self.word-end;
            $.buffer.delete($pos, $cut);
        }
        else { False }
    }

    method edit-delete-to-start(--> Bool) {
        $.buffer.delete(0, $.insert-cursor.pos)
    }

    method edit-delete-to-end(--> Bool) {
        $.buffer.delete($.insert-cursor.pos, $.insert-cursor.end)
    }

    method edit-delete-line(--> Bool) {
        $.buffer.delete(0, $.insert-cursor.end)
    }


    ### Insert/Yank/Swap
    method edit-insert-string(Str:D $string --> Bool) {
        $.buffer.insert($.insert-cursor.pos, $string)
    }

    method edit-yank(--> Bool) {
        $.buffer.yank($.insert-cursor.pos)
    }

    method edit-swap-chars(--> Bool) {
        my $pos = $.insert-cursor.pos;
        my $end = $.insert-cursor.end;
        if $pos && $end > 1 {
            my $at-end   = $pos == $end;
            my $swap-pos = $pos - 1 - $at-end;
            my $content  = $.buffer.contents;
            my $char1    = substr($content, $swap-pos,     1);
            my $char2    = substr($content, $swap-pos + 1, 1);
            $.buffer.replace-length($swap-pos, 2, $char2 ~ $char1);
        }
        else { False }
    }


    ### Case changes
    method recase-char(&change --> Bool) {
        if !$.insert-cursor.at-end {
            my $pos    = $.insert-cursor.pos;
            my $orig   = $.buffer.contents.substr($pos, 1);
            my $recase = &change($orig);

            $orig eq $recase ?? False
                             !! $.buffer.replace-length($pos, 1, $recase);
        }
        else { False }
    }

    method recase-word(&change --> Bool) {
        if !$.insert-cursor.at-end {
            my $pos    = $.insert-cursor.pos;
            my $len    = self.word-end - $pos;
            my $orig   = $.buffer.contents.substr($pos, $len);
            my $recase = &change($orig);

            $orig eq $recase ?? False
                             !! $.buffer.replace-length($pos, $len, $recase);
        }
        else { False }
    }

    method edit-uppercase-char(--> Bool) { self.recase-char(&uc) }
    method edit-lowercase-char(--> Bool) { self.recase-char(&lc) }
    method edit-titlecase-char(--> Bool) { self.recase-char(&tc) }
    method edit-foldcase-char( --> Bool) { self.recase-char(&fc) }

    method edit-uppercase-word(--> Bool) { self.recase-word(&uc) }
    method edit-lowercase-word(--> Bool) { self.recase-word(&lc) }
    method edit-titlecase-word(--> Bool) { self.recase-word(&tc) }
    method edit-foldcase-word( --> Bool) { self.recase-word(&fc) }
    method edit-tclc-word(     --> Bool) { self.recase-word(&tclc) }


    ### Undo/Redo
    method edit-undo(--> Bool) {
        $.buffer.undo
    }

    method edit-redo(--> Bool) {
        $.buffer.redo
    }
}
