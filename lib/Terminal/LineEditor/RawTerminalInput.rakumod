# ABSTRACT: Input widgets for raw terminal text input

use Term::termios;
use Terminal::ANSIParser;
use Terminal::LineEditor::DuospaceInput;


#| Unknown keymap action
class X::Terminal::LineEditor::UnknownAction is X::Terminal::LineEditor {
    has Str:D $.action is required;

    method message() { "Unknown editor action '$.action'" }
}


#| Role for UIs that map keyboard combos to edit actions
role Terminal::LineEditor::KeyMappable {
    has %.keymap = self.default-keymap;

    #| Default key map (from input character ord to edit-* method)
    #  Largely based on control characters recognized by POSIX-style shells
    method default-keymap() {
        # 0 => '',                       # CTRL-@, CTRL-SPACE
          1 => 'move-to-start',          # CTRL-A
          2 => 'move-back',              # CTRL-B
          3 => 'abort-input',            # CTRL-C
          4 => 'abort-or-delete',        # CTRL-D (or delete-char-forward)
          5 => 'move-to-end',            # CTRL-E
          6 => 'move-forward',           # CTRL-F
        # 7 => 'abort-modal',            # CTRL-G
          8 => 'delete-char-back',       # CTRL-H
        # 9 => 'tab',                    # CTRL-I, TAB
         10 => 'finish',                 # CTRL-J, LF
         11 => 'delete-to-end',          # CTRL-K
         12 => 'refresh-all',            # CTRL-L
         13 => 'finish',                 # CTRL-M, CR
         14 => 'history-next',           # CTRL-N
       # 15 => '',                       # CTRL-O
         16 => 'history-prev',           # CTRL-P
       # 17 => '',                       # CTRL-Q
       # 18 => 'history-reverse-search', # CTRL-R
       # 19 => 'history-forward-search', # CTRL-S
         20 => 'swap-chars',             # CTRL-T
         21 => 'delete-to-start',        # CTRL-U
         22 => 'literal-next',           # CTRL-V
         23 => 'delete-word-back',       # CTRL-W
       # 24 => 'prefix',                 # CTRL-X
         25 => 'yank',                   # CTRL-Y
         26 => 'suspend',                # CTRL-Z
       # 27 => 'escape',                 # CTRL-[, ESC
       # 28 => 'quit',                   # CTRL-\
       # 29 => '',                       # CTRL-]
       # 30 => '',                       # CTRL-^
         31 => 'undo',                   # CTRL-_
        127 => 'delete-char-back',       # CTRL-?, BACKSPACE
          ;
    }

    #| Class for instantiating input fields; define in composing class
    method input-class() { ... }

    #| Set of valid special actions; override in a composing class
    method special-actions() { set() }

    #| Throw an exception unless $action is a valid edit action
    method ensure-valid-keymap-action(Str:D $action) {
        X::Terminal::LineEditor::UnknownAction.new(:$action).throw
            unless self.special-actions(){$action}
                || $.input-class.^can("edit-$action");
    }

    #| Bind a key (by ord) to an edit action (by short string name)
    method bind-key(UInt:D $ord, Str:D $action) {
        self.ensure-valid-keymap-action($action);
        %!keymap{$ord} = $action;
    }
}


# Below enums and lookup tables taken from Terminal::Print::DecodedInput
# (previous work by japhb)

enum SpecialKey is export <
     Backspace
     CursorUp CursorDown CursorRight CursorLeft CursorHome CursorEnd
     CursorBegin
     Delete Insert Home End PageUp PageDown
     KeypadSpace KeypadTab KeypadEnter KeypadStar KeypadPlus KeypadComma
     KeypadMinus KeypadPeriod KeypadSlash KeypadEqual Keypad0 Keypad1 Keypad2
     Keypad3 Keypad4 Keypad5 Keypad6 Keypad7 Keypad8 Keypad9
     F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 F15 F16 F17 F18 F19 F20
     PasteStart PasteEnd FocusIn FocusOut
>;

enum ModifierKey (
    Shift   => 1,
    Alt     => 2,
    Control => 4,
    Meta    => 8,
);

class ModifiedSpecialKey {
    has SpecialKey $.key;
    has UInt       $.modifiers;

    method shift   { $.modifiers +& Shift   }
    method alt     { $.modifiers +& Alt     }
    method control { $.modifiers +& Control }
    method meta    { $.modifiers +& Meta    }
}

my %special-keys =
    # PC Normal Style      PC Application Style    VT52 Style

    # Cursor Keys
    "\e[A" => CursorUp,    "\eOA" => CursorUp,     "\eA" => CursorUp,
    "\e[B" => CursorDown,  "\eOB" => CursorDown,   "\eB" => CursorDown,
    "\e[C" => CursorRight, "\eOC" => CursorRight,  "\eC" => CursorRight,
    "\e[D" => CursorLeft,  "\eOD" => CursorLeft,   "\eD" => CursorLeft,
    "\e[H" => CursorHome,  "\eOH" => CursorHome,
    "\e[F" => CursorEnd,   "\eOF" => CursorEnd,

    # Not sure if this is a Cursor or Edit key, but it uses a Cursor escape
    "\e[E" => CursorBegin,

    # Cursor key form used with modifiers
    "\e[1A" => CursorUp,
    "\e[1B" => CursorDown,
    "\e[1C" => CursorRight,
    "\e[1D" => CursorLeft,
    "\e[1H" => CursorHome,
    "\e[1F" => CursorEnd,
    "\e[1E" => CursorBegin,

    # VT220-style Editing Keys
    "\e[2~" => Insert,
    "\e[3~" => Delete,
    "\e[1~" => Home,
    "\e[4~" => End,
    "\e[5~" => PageUp,
    "\e[6~" => PageDown,

    # Keypad
                           "\eO " => KeypadSpace,  "\e? " => KeypadSpace,
                           "\eOI" => KeypadTab,    "\e?I" => KeypadTab,
                           "\eOM" => KeypadEnter,  "\e?M" => KeypadEnter,
                           "\eOj" => KeypadStar,   "\e?j" => KeypadStar,
                           "\eOk" => KeypadPlus,   "\e?k" => KeypadPlus,
                           "\eOl" => KeypadComma,  "\e?l" => KeypadComma,
                           "\eOm" => KeypadMinus,  "\e?m" => KeypadMinus,
                           # KeypadPeriod produces Delete on some keyboards
                           "\eOn" => KeypadPeriod, "\e?n" => KeypadPeriod,
                           "\eOo" => KeypadSlash,  "\e?o" => KeypadSlash,
                           "\eOX" => KeypadEqual,  "\e?X" => KeypadEqual,

                           # Mapped to cursor and edit keys on some keyboards
                           "\eOp" => Keypad0,      "\e?p" => Keypad0,
                           "\eOq" => Keypad1,      "\e?q" => Keypad1,
                           "\eOr" => Keypad2,      "\e?r" => Keypad2,
                           "\eOs" => Keypad3,      "\e?s" => Keypad3,
                           "\eOt" => Keypad4,      "\e?t" => Keypad4,
                           "\eOu" => Keypad5,      "\e?u" => Keypad5,
                           "\eOv" => Keypad6,      "\e?v" => Keypad6,
                           "\eOw" => Keypad7,      "\e?w" => Keypad7,
                           "\eOx" => Keypad8,      "\e?x" => Keypad8,
                           "\eOy" => Keypad9,      "\e?y" => Keypad9,

    # Function Keys
    "\e[11~" => F1,        "\eOP" => F1,           "\eP" => F1,
    "\e[12~" => F2,        "\eOQ" => F2,           "\eQ" => F2,
    "\e[13~" => F3,        "\eOR" => F3,           "\eR" => F3,
    "\e[14~" => F4,        "\eOS" => F4,           "\eS" => F4,
    "\e[15~" => F5,
    "\e[17~" => F6,
    "\e[18~" => F7,
    "\e[19~" => F8,
    "\e[20~" => F9,
    "\e[21~" => F10,
    "\e[23~" => F11,
    "\e[24~" => F12,
    "\e[25~" => F13,
    "\e[26~" => F14,
    "\e[28~" => F15,
    "\e[29~" => F16,
    "\e[31~" => F17,
    "\e[32~" => F18,
    "\e[33~" => F19,
    "\e[34~" => F20,

    # Special events: Bracketed Paste and Terminal Focus
    "\e[200~" => PasteStart,
    "\e[201~" => PasteEnd,
    "\e[I"    => FocusIn,
    "\e[O"    => FocusOut,
    ;


#| Class for active terminal queries
class Terminal::LineEditor::Query {
    has Str:D $.request  is required;
    has       $.matcher  is required;
    has       &.callback is required;
}


#| Role for CLIs/TUIs that enter/leave raw terminal mode
role Terminal::LineEditor::RawTerminalIO {
    has IO::Handle:D           $.input         = $*IN;
    has IO::Handle:D           $.output        = $*OUT;

    has Supplier::Preserving:D $!raw-supplier .= new;
    has Supply:D               $!raw-supply    = $!raw-supplier.Supply;
    has Supplier::Preserving:D $!dec-supplier .= new;
    has Supply:D               $.decoded       = $!dec-supplier.Supply;
    has atomicint              $!done          = 0;
    has                        $!parse         = make-ansi-parser(emit-item => { $!raw-supplier.emit($_) });
    has                        $!saved-termios;
    has                        @!active-queries;

    #| Atomically set done, even from outside role
    method set-done() {
        $!done ⚛= 1;
    }

    #| Switch input to raw mode if it's a TTY and not already in raw mode
    method enter-raw-mode() {
        # If input is a TTY and not currently in raw mode (with a saved
        # termios), then start the parser, save current TTY mode, flush
        # previous I/O, and convert TTY to raw mode

        if $.input.t && !$!saved-termios {
            $!done ⚛= 0;
            self.start-parser;

            my $fd = $.input.native-descriptor;
            $!saved-termios = Term::termios.new(:$fd).getattr;
            Term::termios.new(:$fd).getattr.makeraw.setattr(:FLUSH);
        }
    }

    #| Switch input back to normal mode iff it was switched to raw previously
    method leave-raw-mode(Bool:D :$nl = True) {
        # Mark parsing done, indicate a break in input parsing (to output any
        # partial sequences and flush the parser to Ground state), drain
        # output, restore the saved termios state, mark the saved termios as
        # unused, and optionally output a \n to push the cursor to the start of
        # the next line

        if $!saved-termios {
            unless ⚛$!done {
                $!done ⚛= 1;
                $!parse(Nil);
            }

            $!saved-termios.setattr(:DRAIN);
            $!saved-termios = Nil;
            $.output.put('') if $nl;
        }
    }

    #| Start reading input TTY and feeding the parser; parsed stream will
    #| appear at $!raw-supply, _in binary form_ (as bytes and buffers that must
    #| be decoded)
    method start-parser() {
        start {
            until ⚛$!done {
                my $b = $.input.read(1) or last;
                $!parse($b[0]) unless ⚛$!done;
            }
        }
    }

    #| Produce a supply of decoded input events
    method start-decoder() {
        start react {
            my buf8 $buf .= new;
            whenever $!raw-supply {
                when !*.defined {
                    $!dec-supplier.emit($_);
                }
                when Int {
                    $buf.push($_);
                    try my $c = $buf.decode;
                    if $c { $!dec-supplier.emit($c); $buf .= new }
                }
                when Terminal::ANSIParser::SimpleEscape {
                    # No params possible, so just look up full decoded sequence
                    # (which is implicitly utf-8 decoded when stringified)
                    with %special-keys{$_} -> $key {
                        $!dec-supplier.emit($key);
                    }
                    else {
                        !!! "Unknown SimpleEscape"
                    }
                }
                when Terminal::ANSIParser::CSI {
                    # Params possible, separate non-param bytes for lookup
                    # and param bytes for analysis; also determine if string
                    # is a query response and return that to the waiting query
                    my regex csi { ^ ("\e["|\x[9B]) (<-[;0..9]>*) (<[;0..9]>*) (.+) $ };
                    if .sequence.decode ~~ &csi {
                        my @args = split ';', ~$2;
                        my $lead = "\e[$1";
                        my $tail = ~$3;

                        if !$1 && @args && $tail eq '~' {
                            # Special key with possible modifiers
                            my $base = $lead ~ @args[0] ~ $tail;
                            with %special-keys{$base} -> $key {
                                if    @args == 1 {
                                    $!dec-supplier.emit($key);
                                }
                                elsif @args == 2 {
                                    my $modifiers = @args[1] - 1;
                                    $!dec-supplier.emit:
                                        ModifiedSpecialKey.new(:$key, :$modifiers);
                                }
                                else {
                                    !!! "Unrecognized special key format"
                                }
                            }
                            else {
                                !!! "Unrecognized CSI resembling special key"
                            }
                        }
                        elsif @!active-queries
                           && .sequence.decode ~~ @!active-queries[0].matcher {
                            my $query := @!active-queries.shift;
                            my &cb    := $query.callback;
                            cb($_);
                        }
                        else {
                            my $base = $lead ~ $tail;
                            dd $base, @args;
                            !!! "CSI"
                        }
                    }
                    else {
                        dd .sequence;
                        !!! "Undecodeable CSI"
                    }
                }
                when Terminal::ANSIParser::DCS {
                    # Params possible, separate non-param bytes for lookup
                    # and param bytes for analysis; also determine if string
                    # is a query response and return that to the waiting query
                    my $string = ~.string;
                    my regex dcs { ^ ("\eP"|\x[90]) (<-[;0..9]>*) (<[;0..9]>*) (.+) $ };
                    if .sequence.decode ~~ &dcs {
                        my @args = split ';', ~$2;
                        my $lead = "\eP$1";
                        my $tail = ~$3;
                        my $base = $lead ~ $tail;
                        dd $base, @args, $string;
                        !!! "DCS"
                    }
                    else {
                        dd $_;
                        !!! "Undecodeable DCS"
                    }
                }
                default {
                    # XXXX: Ignored bare escape bytes?
                    # Intentionally ignore other Sequence and String types
                }
            }
        }
    }

    #| Query the terminal asynchronously and call a callback when the response
    #| arrives
    multi method query-terminal(Str:D $request, $matcher, &callback) {
        # Add an active query record
        my $query = Terminal::LineEditor::Query.new:
                    :$request, :$matcher, :&callback;
        @!active-queries.push($query);

        # Send request to terminal
        $.output.print($request);
        $.output.flush;
    }

    #| Query the terminal asynchronously and return a vowed Promise kept when
    #| the response arrives
    multi method query-terminal(Str:D $request, $matcher) {
        # Prepare a vowed Promise
        my $p = Promise.new;
        my $v = $p.vow;

        # Add an active query record that will keep the vow
        my &callback = { $v.keep($_) };
        self.query-terminal($request, $matcher, &callback);

        # Return Promise
        $p
    }
}


#| Role with utility methods for raw terminal I/O
role Terminal::LineEditor::RawTerminalUtils {
    #| Detect cursor position, returning a Promise that will be kept with
    #| (row, col) or Empty if unable
    method detect-cursor-pos() {
        my regex response { ^ "\e[" (\d+) ';' (\d+) 'R' $ }

        self.query-terminal("\e[6n", &response).then: {
            (~.result) ~~ &response ?? (+$0, +$1) !! Empty
        }
    }

    #| Detect terminal size, returning a Promise that will be kept with
    #| (rows, cols) or Empty if unable
    method detect-terminal-size() {
        # XXXX: This query has been found to have compatibility problems; it
        #       works in xterm and libvte terminals, but not in many others
        #       such as Konsole, Windows Console, linux, etc.
        # my $response = self.query-terminal("\e[18t", 't');
        # $response ~~ /^ "\e[8;" (\d+) ';' (\d+) 't' $/ ?? (+$0, +$1) !! Empty

        # Instead of the above, take advantage of clipping behavior of cursor
        # movement commands by saving the cursor, requesting a move way outside
        # the terminal, detecting the cursor position, and restoring the cursor.

        $.output.print("\e7\e[9999;9999H");
        my $p := self.detect-cursor-pos;
        $.output.print("\e8");
        $p
    }

    #| Suspend using SIGTSTP job control, switching back to normal mode first;
    #| call &on-suspend after leaving raw mode just before suspending, and
    #| call &on-continue just after continuing before re-entering raw mode.
    method suspend(:$buffer, :&on-suspend, :&on-continue) {
        # Return to normal terminal mode and call &on-suspend if any
        self.leave-raw-mode;
        $_() with &on-suspend;

        # Send this process SIGTSTP via the native raise() function
        use NativeCall;
        sub raise(int32 --> int32) is native {*}
        raise(SIGTSTP);

        # Returning from raise(SIGTSTP) means that a SIGCONT has arrived,
        # so run &on-continue if any, then go back into raw mode
        $_() with &on-continue;
        self.enter-raw-mode;
    }
}


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


#| A ScrollingSingleLineInput enhanced with ANSI/VT cursor control knowledge
class Terminal::LineEditor::ScrollingSingleLineInput::ANSI
   is Terminal::LineEditor::ScrollingSingleLineInput {
    has UInt:D $.field-start is required;
    has UInt:D $.field-end   = $!field-start + self.display-width;
    has UInt:D $.pos         = $!field-start;


    #| ANSI VT sequence to move cursor
    method cursor-move-command(Int:D $distance --> Str:D) {
        $distance == 0 ?? ''                 !!
        $distance  > 0 ?? "\e[{ $distance}C" !!
                          "\e[{-$distance}D" ;
    }

    #| Compute a string to clear the current field, including cursor movement
    method clear-string() {
        # Start by moving screen cursor back to field start
        my $clear = self.cursor-move-command($.field-start - $.pos);

        # Draw plain spaces to cover display-width;
        $clear ~= ' ' x $.display-width;

        # Close by moving cursor back to start
        $clear ~= self.cursor-move-command($.field-start - $.field-end);
    }

    #| Compute full field refresh string, including cursor movements
    method refresh-string(Bool:D $edited) {
        # Start by moving screen cursor back to field start
        my $refresh = self.cursor-move-command($.field-start - $.pos);

        # Next, include our self-render
        $refresh ~= self.render(:$edited);

        # Close by moving cursor back to where it belongs
        $!pos     = $.field-start
                  + self.left-mark-width
                  + self.scroll-to-insert-width;
        $refresh ~= self.cursor-move-command($.pos - $.field-end);

        $refresh
    }

    #| Resolve an edit action and compute a new refresh string
    method do-edit($action, $insert?) {
        # Do edit and determine if contents actually changed
        my $edited = $insert.defined ?? self.edit-insert-string($insert)
                                     !! self."edit-$action"();

        self.refresh-string($edited)
    }
}


#| A complete CLI input class
class Terminal::LineEditor::CLIInput
 does Terminal::LineEditor::HistoryTracking
 does Terminal::LineEditor::KeyMappable
 does Terminal::LineEditor::RawTerminalIO
 does Terminal::LineEditor::RawTerminalUtils {
    has $.input-class = Terminal::LineEditor::ScrollingSingleLineInput::ANSI;
    has $.input-field;

    #| Start the decoder reactor as soon as everything else is set up
    method TWEAK() {
        self.start-decoder;
    }

    #| Valid special actions
    method special-actions() {
        constant $special
            = set < abort-input abort-or-delete finish
                    history-next history-prev literal-next suspend >;
    }

    #| Do edit in current input field, then print and flush the full refresh string
    method do-edit($action, $insert?) {
        $.output.print($.input-field.do-edit($action, $insert));
        $.output.flush;
    }

    #| Clear and replace existing current input field (if any), then create and
    #| draw a new input field
    method replace-input-field(UInt:D :$display-width, UInt:D :$field-start,
                               Str:D :$content = '', Str :$mask) {
        # Output clear string for old field (if any), but don't bother to flush yet
        $.output.print($.input-field.clear-string) if $.input-field;

        # Create a new input field using the new metrics
        $!input-field = $.input-class.new(:$display-width, :$field-start, :$mask);

        # "Prime the render pump" and insert initial content
        $.input-field.render(:edited);
        self.do-edit('insert-string', $content);
    }

    #| Full input/edit loop; returns final user input or Str if aborted
    # XXXX: Bool:D :$history = False, Str:D :$context = 'default',
    method read-input(Str :$mask, :&on-suspend, :&on-continue --> Str) {
        # If not a terminal, just read a line from input and return it
        return $.input.get // Str unless $.input.t;

        # Switch terminal to raw mode while editing
              self.enter-raw-mode;
        LEAVE self.leave-raw-mode;

        # Clear temporaries when leaving
        LEAVE {
            $!unfinished-entry = '';
            $!input-field = Nil;
        }

        # Detect current cursor position and terminal size
        my @pending;
        my ($row, $col, $rows, $cols);
        react {
            whenever self.detect-cursor-pos {
                ($row, $col) = @$_;
                whenever self.detect-terminal-size {
                    ($rows, $cols) = @$_;
                    done;
                }
            }
        }

        # Set up an editable input buffer
        my $display-width = ($cols //= 80) - $col;
        self.replace-input-field(:$display-width, :field-start($col), :$mask);

        my sub do-history-prev() {
            return unless @.history && $.history-cursor && !$mask.defined;

            $!unfinished-entry = $.input-field.buffer.contents
                if self.history-cursor-at-end;

            self.history-prev;
            self.replace-input-field(:$display-width, :field-start($col),
                                     :$mask, :content(self.history-entry));
        }

        my sub do-history-next() {
            return if self.history-cursor-at-end || $mask.defined;

            self.history-next;
            self.replace-input-field(:$display-width, :field-start($col),
                                     :$mask, :content(self.history-entry));
        }

        # Read raw characters and dispatch either as actions or chars to insert
        my $literal-mode = False;
        my $aborted      = False;
        react whenever $.decoded -> $c {
            done unless $c.defined;

            if $literal-mode {
                self.do-edit('insert-string', $c);
                $literal-mode = False;
            }
            orwith %!keymap{$c.ord} {
                when 'literal-next'    { $literal-mode = True }
                when 'history-prev'    { do-history-prev }
                when 'history-next'    { do-history-next }
                when 'suspend'         { self.suspend(:&on-suspend, :&on-continue) }
                when 'finish'          { self.set-done; done }
                when 'abort-input'     { self.set-done; $aborted = True; done }
                when 'abort-or-delete' { unless $.input-field.buffer.contents {
                                             self.set-done;
                                             $aborted = True;
                                             done
                                         }
                                         self.do-edit('delete-char-forward') }
                default                { self.do-edit($_) }
            }
            else { self.do-edit('insert-string', $c) }
        }

        # Return final buffer contents (or Str if aborted)
        $aborted ?? Str !! $.input-field.buffer.contents
    }

    #| Print and flush prompt then enter input loop, optionally masking password
    method prompt(Str:D $prompt = '', Str :$mask --> Str) {
        my sub flush-prompt() {
            $.output.print($prompt);
            $.output.flush;
        }

        flush-prompt;
        self.read-input(:$mask, :on-continue(&flush-prompt))
    }
}
