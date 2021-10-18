# ABSTRACT: Input widgets for duospace (Unicode terminal) text input

use Text::MiscUtils::Layout;
use Terminal::LineEditor::EditableBuffer;


#| Cache the duospace widths for all characters in a single-line string,
#| allowing substring-width() to be an O(1) operation after a string has
#| been analyzed by recompute-widths().
role Terminal::LineEditor::DuospaceLayoutCache {
    has %!char-width-cache;
    has @!char-widths;
    has @!char-widths-prefix-sum;


    #| Cache duospace width calculation per character (grapheme cluster)
    method char-width(Str:D $chr) {
        %!char-width-cache{$chr} //= duospace-width($chr);
    }

    #| Recompute a prefix sum cache of substring widths for a given string,
    #| optionally masked with a per-character replacement for e.g. password
    #| inputs
    method recompute-widths(Str:D $content, Str $mask?) {
        @!char-widths = $mask.defined ?? self.char-width($mask) xx $content.chars
                                      !! $content.comb.map({ self.char-width($_) });
        @!char-widths-prefix-sum = [\+] @!char-widths;
        @!char-widths-prefix-sum.unshift(0);
    }

    #| Calculate a substring width in O(1) time using the prefix sum cache
    method substring-width(UInt:D $start, UInt:D $after) {
        # XXXX: For RTL, auto-swap $start and $after?

        X::Terminal::LineEditor::InvalidRange.new(:$start, :$after, :reason("nonsensical substring range {$start}..^{$after} for string of length { @!char-widths-prefix-sum.elems }.")).throw
            unless 0 <= $start <= $after < @!char-widths-prefix-sum;

        @!char-widths-prefix-sum[$after] - @!char-widths-prefix-sum[$start]
    }
}


#| A single line text input that scrolls within the available input area
class Terminal::LineEditor::ScrollingSingleLineInput
 does Terminal::LineEditor::SingleLineTextInput
 does Terminal::LineEditor::DuospaceLayoutCache {
    has UInt:D $.display-width is required;

    has Str:D $.left-scroll-mark     = '⯇';
    has Str:D $.right-scroll-mark    = '⯈';
    has Str:D $.left-no-scroll-mark  = ' ';
    has Str:D $.right-no-scroll-mark = ' ';

    has $.scroll-cursor = $!buffer.add-cursor;


    #| Determine how much display width is actually available, accounting for
    #| scroll marks; assumes recompute-widths already called
    method available-width() {
        my $left-width  = self.char-width($.scroll-cursor.pos
                                          ?? $.left-scroll-mark
                                          !! $.left-no-scroll-mark);
        # XXXX: Assumes worst-case right mark width
        my $right-width = max(self.char-width($.right-scroll-mark),
                              self.char-width($.right-no-scroll-mark));

        $.display-width - $left-width - $right-width;
    }

    #| Make sure input area is scrolled so that insert pos is visible
    method scroll-to-insert-pos() {
        # If insert position beyond field edge on start end, fix scroll
        # position so insert position is just visible
        $.scroll-cursor.move-to($.insert-cursor.pos)
            if $.scroll-cursor.pos > $.insert-cursor.pos;

        # If insert-cursor position is off the far end, scroll it into view
        while self.substring-width($.scroll-cursor.pos, $.insert-cursor.pos)
            > self.available-width {
            $.scroll-cursor.move-rel(+1);
        }
    }

    #| Compute a string containing entire visible input field (including scroll marks)
    method visible-input-field-string(Str $mask?) {
        # Add correct (no-)scroll-mark on left end
        my $scroll-pos = $.scroll-cursor.pos;
        my $string     = $scroll-pos ?? $.left-scroll-mark !! $.left-no-scroll-mark;

        # Figure out how much buffer we can display; assume we have room for at
        # least the insert-pos (thanks to scroll-to-insert-pos), so start with
        # that to jump-start the process
        my $avail = self.available-width;
        my $last  = $.insert-cursor.pos;
        my $end   = $.insert-cursor.end;
        ++$last while $last < $end
                   && self.substring-width($scroll-pos, $last) < $avail;

        # Check if we overshot by one because final character was wide
        --$last if self.substring-width($scroll-pos, $last) > $avail;

        # Add the determined substring, possibly masked
        my $contents = $mask.defined ?? $mask x $.insert-pos.end
                                     !! $.buffer.contents;
        $string ~= substr($contents, $scroll-pos, $last - $scroll-pos);

        # Add end padding if necessary
        $string ~= ' ' x ($avail - self.substr-wdith($scroll-pos, $last));

        # Add correct (no-)scroll-mark on right end
        $string ~= $last < $end ?? $.right-scroll-mark
                                !! $.right-no-scroll-mark;

        $string
    }

    #| Redraw the input field, scrolled so that insert-pos is visible
    method render(Str :$mask, Bool:D :$edited = False) {
        # If an edit just happened, recompute character widths
        # XXXX: What about mask?
        self.recompute-widths($.buffer.contents, $mask) if $edited || $mask;

        # Make sure insert position will be visible
        self.scroll-to-insert-pos;

        self.visible-input-field-string($mask)
    }
}
