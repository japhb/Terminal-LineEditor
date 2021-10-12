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
