# ABSTRACT: History tracking role

role Terminal::LineEditor::HistoryTracking {
    has UInt:D $.history-cursor   = 0;
    has Str:D  $.unfinished-entry = '';
    has @.history;

    #| Retrieve history entry by index (defaults to current history-cursor)
    method history-entry(UInt:D $index = $.history-cursor) {
        @.history[$index] // $.unfinished-entry
    }

    #| Add history entries to the end, then jump the cursor to the new end
    method add-history(*@entries) {
        @.history.append(@entries);
        self.jump-to-history-end;
    }

    #| Delete the history entry at a particular index (defaults to current
    #| history-cursor); silently ignores if outside history range
    method delete-history-index(UInt:D $index = $.history-cursor) {
        return unless 0 <= $index <= @.history.end;

        splice @.history, $index, 1;
    }

    #| Search for a substring in the input history, returning Seq of Pair of
    #| (index => input-line)
    method filter-history-by-substring(Str:D $substring) {
        @.history.grep(*.contains($substring), :p)
    }

    #| Jump cursor to the start of available history entries
    method jump-to-history-start() {
        $!history-cursor = 0;
    }

    #| Move cursor to the previous available history entry (or leave unchanged at start)
    method history-prev() {
        $!history-cursor-- if $!history-cursor;
    }

    #| Move cursor to the next available history entry (or leave unchanged at end)
    method history-next() {
        $!history-cursor++ if $!history-cursor < @.history.elems;
    }

    #| Jump cursor to the unfinished entry after the end of available history entries
    method jump-to-history-end() {
        $!history-cursor = @.history.elems;
    }

    #| Jump cursor to a particular history index
    method jump-to-history-index(UInt:D $index) {
        $!history-cursor = min $index, @.history.elems;
    }

    #| Check if history cursor is at the end (on the unfinished entry)
    method history-cursor-at-end() {
        $!history-cursor >= @.history.elems
    }
}
