# ABSTRACT: Input widgets for raw terminal text input

use Terminal::MakeRaw;
use Terminal::ANSIParser;
use Terminal::LineEditor::DuospaceInput;
use Terminal::LineEditor::History;


#| To make runtime require happy
module Terminal::LineEditor::RawTerminalInput { }


#| Unknown keymap action
class X::Terminal::LineEditor::UnknownAction is X::Terminal::LineEditor {
    has Str:D $.action is required;

    method message() { "Unknown editor action '$.action'" }
}


# Below enums and lookup tables taken from Terminal::Print::DecodedInput
# (previous work by japhb)

enum SpecialKey is export <
     Backspace ShiftTab
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

enum MouseModifier is export (
    # Note: No support for Alt separate from Meta in modifier protocol
    MouseButtonMask =>   3,
    MouseShift      =>   4,
    MouseControl    =>   8,
    MouseMeta       =>  16,
    MouseMotion     =>  32,
    MouseHighMask   => 192,
    MouseHighShift  =>   6,
);

enum MouseEventMode is export (
    MouseNoEvents        => 0,     # No events
    MouseNormalEvents    => 1000,  # Press and release only
  # MouseHighlightEvents => 1001,  # UNSUPPORTED
    MouseButtonEvents    => 1002,  # Press, release, move while pressed
    MouseAnyEvents       => 1003,  # Press, release, any movement
);


class ModifiedSpecialKey {
    has SpecialKey $.key;
    has UInt       $.modifiers;

    method shift   { $.modifiers +& Shift   }
    method alt     { $.modifiers +& Alt     }
    method control { $.modifiers +& Control }
    method meta    { $.modifiers +& Meta    }
}

class MouseTrackingEvent {
    has UInt $.x;
    has UInt $.y;
    has UInt $.button;
    has Bool $.pressed;
    has Bool $.motion;
    has Bool $.shift;
    has Bool $.control;
    has Bool $.meta;
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

    # Weird special case for a shifted key
    "\e[Z" => ShiftTab,

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


#| Role for UIs that map keyboard combos to edit actions
role Terminal::LineEditor::KeyMappable {
    has %.keymap = self.default-keymap;

    #| Default key map (from input character name to edit-* method)
    #  Largely based on control characters recognized by POSIX-style shells
    method default-keymap() {
       # 'Ctrl-@' => '',                       # CTRL-@, CTRL-SPACE (or set-mark)
          Ctrl-A  => 'move-to-start',          # CTRL-A
          Ctrl-B  => 'move-char-back',         # CTRL-B
          Ctrl-C  => 'abort-input',            # CTRL-C
          Ctrl-D  => 'abort-or-delete',        # CTRL-D (or delete-char-forward)
          Ctrl-E  => 'move-to-end',            # CTRL-E
          Ctrl-F  => 'move-char-forward',      # CTRL-F
       #  Ctrl-G  => 'abort-modal',            # CTRL-G (or cancel-search)
          Ctrl-H  => 'delete-char-back',       # CTRL-H
          Ctrl-I  => 'complete',               # CTRL-I, TAB
          Ctrl-J  => 'finish',                 # CTRL-J, LF
          Ctrl-K  => 'delete-to-end',          # CTRL-K (or delete-line-forward)
          Ctrl-L  => 'refresh-all',            # CTRL-L
          Ctrl-M  => 'finish',                 # CTRL-M, CR
          Ctrl-N  => 'history-next',           # CTRL-N
       #  Ctrl-O  => '',                       # CTRL-O
          Ctrl-P  => 'history-prev',           # CTRL-P
       #  Ctrl-Q  => '',                       # CTRL-Q (or literal-next)
       #  Ctrl-R  => 'history-reverse-search', # CTRL-R
       #  Ctrl-S  => 'history-forward-search', # CTRL-S
          Ctrl-T  => 'swap-chars',             # CTRL-T
          Ctrl-U  => 'delete-to-start',        # CTRL-U (or delete-line-back)
          Ctrl-V  => 'literal-next',           # CTRL-V
          Ctrl-W  => 'delete-word-back',       # CTRL-W
       #  Ctrl-X  => 'prefix',                 # CTRL-X (or doubled: move-to-mark)
          Ctrl-Y  => 'yank',                   # CTRL-Y
          Ctrl-Z  => 'suspend',                # CTRL-Z
       # 'Ctrl-[' => 'escape',                 # CTRL-[, ESC
       # 'Ctrl-\' => 'quit',                   # CTRL-\ (or quit-process)
       # 'Ctrl-]' => '',                       # CTRL-]
       # 'Ctrl-^' => '',                       # CTRL-^
         'Ctrl-_' => 'undo',                   # CTRL-_

         Backspace   => 'delete-char-back',    # CTRL-?, BACKSPACE
         Delete      => 'delete-char-forward',

         CursorLeft  => 'move-char-back',
         CursorRight => 'move-char-forward',
         CursorHome  => 'move-to-start',
         CursorEnd   => 'move-to-end',
         CursorUp    => 'history-prev',
         CursorDown  => 'history-next',

          Alt-b      => 'move-word-back',
          Alt-c      => 'tclc-word',           # Readline treats this as Capitalize
          Alt-d      => 'delete-word-forward',
          Alt-f      => 'move-word-forward',
          Alt-h      => 'delete-word-back',
          Alt-l      => 'lowercase-word',
          Alt-t      => 'swap-words',
          Alt-u      => 'uppercase-word',
         "Alt-\x3C"  => 'history-start',       # ALT-<
         "Alt-\x3E"  => 'history-end',         # ALT->

         # XXXX: From jart/bestline
         # Alt-CursorLeft  => 'move-expr-back',
         # Alt-CursorRight => 'move-expr-forward',
         # Ctrl-Alt-b  => 'move-expr-back',
         # Ctrl-Alt-f  => 'move-expr-forward',
         # Ctrl-Alt-h  => 'delete-word-back',
         # Alt-y       => 'rotate-ring-and-yank-again',
         # 'Alt-\'     => 'squeeze-whitespace',

         # XXXX: Additional default bindings from Bash Readline can be found via:
         # INPUTRC=/dev/null bash -c 'bind -pm emacs' | grep -vE '^#|: (do-lowercase-version|self-insert)$' | raku -e '.say for lines().sort'
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

    #| Bind a key (by name) to an edit action (by short string name);
    #| modifiers are represented by prefixed Meta-/Ctrl-/Alt-/Shift-
    method bind-key(Str:D $key-name, Str:D $action) {
        self.ensure-valid-keymap-action($action);
        %!keymap{$key-name} = $action;
    }

    #| Decode keyname for a control, modified, or special key
    #| (or return Nil if not one of the above)
    method decode-keyname($input) {
        do given $input {
            when Str {
                my $ord = .ord;
                $ord <  32  ?? 'Ctrl-' ~ ($ord + 64).chr !!
                $ord == 127 ?? 'Backspace' !!
                               Nil
            }
            when Pair {
                my $key = .key;
                $key ~~ Str        ??  $key !!
                $key ~~ SpecialKey ?? ~$key !!
                                        ('Meta-'  if $key.meta)
                                      ~ ('Ctrl-'  if $key.control)
                                      ~ ('Alt-'   if $key.alt)
                                      ~ ('Shift-' if $key.shift)
                                      ~ $key.key
            }
        }
    }
}


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
    has MouseEventMode:D       $!previous-mouse-mode = MouseNoEvents;
    has                        $!saved-termios;
    has int                    $!saved-fd;
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
            $!saved-fd = $.input.native-descriptor;
            $!saved-termios = Terminal::MakeRaw::getattr($!saved-fd);
            Terminal::MakeRaw::makeraw($!saved-fd, :FLUSH);

            $!done ⚛= 0;
            self.start-parser;
        }
    }

    #| Switch input back to normal mode iff it was switched to raw previously
    method leave-raw-mode(Bool:D :$nl = True) {
        # Mark parsing done, drain output, restore the saved termios state,
        # mark the saved termios as unused, and optionally output a \n to push
        # the cursor to the start of the next line

        if $!saved-termios {
            $!done ⚛= 1;
            Terminal::MakeRaw::setattr($!saved-fd, $!saved-termios, :DRAIN);
            $!saved-termios = Nil;
            $.output.put('') if $nl;
        }
    }

    #| Set a new mouse tracking event mode, disabling previous mode first if needed
    method set-mouse-event-mode(MouseEventMode:D $mode) {
        # Encoding/extras:
        #   1004: Focus events
        #   1006: SGR encoding

        $.output.print("\e[?{+$!previous-mouse-mode}l\e[?1004l\e[?1006l")
            if $!previous-mouse-mode != MouseNoEvents;

        $.output.print("\e[?1006h\e[?1004h\e[?{+$mode}h")
            if $mode != MouseNoEvents;

        $.output.flush;
        $!previous-mouse-mode = $mode;
    }


    #| Start reading input TTY and feeding the ANSI parser; parsed stream will
    #| appear at $!raw-supply, _in tokenized form_ (as codepoints and buffers
    #| that must be further decoded into input events)
    method start-parser() {
        start {
            LOOP: until ⚛$!done {
                my $buf = Buf.new;

                repeat {
                    my $b = $.input.read(1) or last LOOP;
                    $buf.push($b);
                } until ⚛$!done || try my $c = $buf.decode;

                $!parse($c.ord) unless ⚛$!done;
            }
        }
    }

    #| Produce a supply of decoded input events
    method start-decoder() {
        start react {
            whenever $!raw-supply {
                # note "Got {.raku}"; $*ERR.flush;
                when !*.defined {
                    $!dec-supplier.emit($_);
                }
                when Int {
                    try my $c = chr($_);
                    $!dec-supplier.emit($c) if $c;
                }
                when Terminal::ANSIParser::SimpleEscape {
                    # No params possible, so just look up full decoded sequence
                    my $decoded = ~$_;
                    with %special-keys{$decoded} -> $key {
                        $!dec-supplier.emit($key => $_);
                    }
                    elsif $decoded.chars == 2 {
                        my $key = 'Alt-' ~ $decoded.substr(1);
                        $!dec-supplier.emit($key => $_);
                    }
                    else {
                        !!! "Unknown SimpleEscape"
                    }
                }
                when Terminal::ANSIParser::CSI {
                    # Params possible, separate non-param bytes for lookup
                    # and param bytes for analysis; also determine if string
                    # is a query response and return that to the waiting query
                    my constant TAILS = set(|< ~ A B C D E F H >);
                    my regex csi { ^ "\e[" (<-[;0..9]>*) (<[;0..9]>+) (.+) $ };
                    my $decoded = .sequence[0] == 0x9B
                                  ?? "\e[" ~ (~$_).substr(1)
                                  !! ~$_;

                    if %special-keys{$decoded} -> $key {
                        # Unmodified special key/event in CSI form
                        $!dec-supplier.emit($key => $_);
                    }
                    elsif $decoded ~~ &csi {
                        # note "CSI regex match: {$/.raku}"; $*ERR.flush;
                        my $tail = ~$2;
                        if (!$0 || !~$0) && ($tail ∈ TAILS) {
                            # Special key with possible modifiers
                            my @args = split(';', ~$1);
                            my $base = "\e[$0@args[0]$tail";

                            with %special-keys{$base} -> $key {
                                if    @args == 1 {
                                    $!dec-supplier.emit($key => $_);
                                }
                                elsif @args == 2 {
                                    my $modifiers = @args[1] - 1;
                                    $!dec-supplier.emit:
                                        ModifiedSpecialKey.new(:$key, :$modifiers) => $_;
                                }
                                else {
                                    !!! "Unrecognized special key format"
                                }
                            }
                            else {
                                !!! "Unrecognized CSI resembling special key"
                            }
                        }
                        elsif $0 && (~$0 eq '<') && ($tail eq 'M' || $tail eq 'm') {  # <
                            # Mouse tracking report
                            my $pressed = $tail eq 'M';
                            my @args    = split(';', ~$1);
                            my $encoded = @args[0];
                            my $shift   = ?($encoded +& MouseShift);
                            my $control = ?($encoded +& MouseControl);
                            my $meta    = ?($encoded +& MouseMeta);
                            my $motion  = ?($encoded +& MouseMotion);
                            my $masked  =   $encoded +& MouseButtonMask;
                            my $high    =  ($encoded +& MouseHighMask) +> MouseHighShift;
                            my $is-low  = $high == 0;
                            my $button  = $is-low && $masked == MouseButtonMask
                                          ?? UInt !! ($masked + $is-low) + 4 * $high;
                            my $event   = MouseTrackingEvent.new(
                                              :x(+@args[1]), :y(+@args[2]),
                                              :$shift, :$control, :$meta,
                                              :$motion, :$button, :$pressed);
                            $!dec-supplier.emit($event);
                        }
                        elsif @!active-queries
                           && $decoded ~~ @!active-queries[0].matcher {
                            my $query := @!active-queries.shift;
                            my &cb    := $query.callback;
                            cb($_);
                        }
                        elsif @!active-queries {
                            note "AQNM"; note self.WHICH; $*ERR.flush;
                            dd .sequence, $decoded;
                            !!! "Active terminal query waiting, but decoded response did not match"
                        }
                        else {
                            note "NoAQ"; note self.WHICH; $*ERR.flush;
                            dd .sequence, $decoded;
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
                    my $sequence = .sequence;
                    if ~Terminal::ANSIParser::Sequence.new(:$sequence) ~~ &dcs {
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

    #| Force the virtual cursor pos to field-start, WITHOUT moving it;
    #| this allows recovery from suspend/continue
    method force-pos-to-start() {
        $!pos = $!field-start;
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
    has &.get-completions;

    #| Start the decoder reactor as soon as everything else is set up
    submethod TWEAK() {
        self.start-decoder;
    }

    #| Valid special actions
    method special-actions() {
        constant $special
            = set < abort-input abort-or-delete finish literal-next suspend
                    history-start history-end history-next history-prev
                    complete >;
    }

    #| Fetch completions based on current buffer contents and cursor pos
    method fetch-completions() {
        with &.get-completions {
            my $contents = $.input-field.buffer.contents;
            my $pos      = $.input-field.insert-cursor.pos;
            $_($contents, $pos);
        }
        else { Empty }
    }

    #| Do edit in current input field, then print and flush the full refresh string
    method do-edit($action, $insert?) {
        $.output.print($.input-field.do-edit($action, $insert));
        $.output.flush;
    }

    #| Set $!input-field, with both compile-time and runtime type checks
    method set-input-field(Terminal::LineEditor::ScrollingSingleLineInput:D $new-field) {
        die "New input-field is not a $.input-class"
            unless $new-field ~~ $.input-class;
        $!input-field = $new-field;
    }

    #| Clear $!input-field
    method clear-input-field() {
        $!input-field = Nil;
    }

    #| Clear and replace existing current input field (if any), then create and
    #| draw a new input field
    method replace-input-field(UInt:D :$display-width, UInt:D :$field-start,
                               Str:D :$content = '', Str :$mask) {
        # Output clear string for old field (if any), but don't bother to flush yet
        $.output.print($.input-field.clear-string) if $.input-field;

        # Create a new input field using the new metrics
        self.set-input-field($.input-class.new(:$display-width, :$field-start, :$mask));

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
            $.unfinished-entry = '';
            self.clear-input-field;
        }

        # Detect current cursor position and terminal size
        my ($row,  $col)  = await self.detect-cursor-pos;
        my ($rows, $cols) = await self.detect-terminal-size;

        # Set up an editable input buffer
        my $display-width = ($cols //= 80) - $col;
        self.replace-input-field(:$display-width, :field-start($col), :$mask);

        # History helpers
        my sub do-history-start() {
            return unless @.history && $.history-cursor && !$mask.defined;

            $.unfinished-entry = $.input-field.buffer.contents
                if self.history-cursor-at-end;

            self.jump-to-history-start;
            self.replace-input-field(:$display-width, :field-start($col),
                                     :$mask, :content(self.history-entry));
        }

        my sub do-history-prev() {
            return unless @.history && $.history-cursor && !$mask.defined;

            $.unfinished-entry = $.input-field.buffer.contents
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

        my sub do-history-end() {
            return if self.history-cursor-at-end || $mask.defined;

            self.jump-to-history-end;
            self.replace-input-field(:$display-width, :field-start($col),
                                     :$mask, :content(self.history-entry));
        }

        # Completion helpers
        my $completions;
        my $completion-index;
        my sub do-complete() {
            if $completions {
                # Undo previous completion if any
                my $max = $completions.elems;
                self.do-edit('undo') if $completion-index < $max;

                # Revert to non-completion if at end
                return if ++$completion-index == $max;

                $completion-index = 0 if $completion-index > $max;
            }
            else {
                $completions      = self.fetch-completions or return;
                $completion-index = 0;
            }

            my $edited = $.input-field.buffer.replace(0, $.input-field.insert-cursor.pos,
                                                      $completions[$completion-index]);
            $.output.print($.input-field.refresh-string($edited));
            $.output.flush;
        }

        # If not currently completing, all other actions reset completions
        my sub reset-completions() {
            $completions      = Nil;
            $completion-index = Nil;
        }

        # Read raw characters and dispatch either as actions or chars to insert
        my $literal-mode = False;
        my $aborted      = False;
        react whenever $.decoded {
            # note "Decoded as {.raku}"; $*ERR.flush;
            done unless .defined;

            if $_ ~~ MouseTrackingEvent {
                # Intentionally ignore mouse events for now
            }
            elsif $literal-mode {
                my $string = $_ ~~ Str ?? $_ !! ~(.value);
                self.do-edit('insert-string', $string);
                $literal-mode = False;
            }
            else {
                my $key = self.decode-keyname($_);
                if !$key {
                    self.do-edit('insert-string', $_);
                    reset-completions;
                }
                orwith $key && %!keymap{$key} {
                    when 'complete'        { do-complete }
                    reset-completions;

                    when 'literal-next'    { $literal-mode = True }
                    when 'history-start'   { do-history-start }
                    when 'history-prev'    { do-history-prev }
                    when 'history-next'    { do-history-next }
                    when 'history-end'     { do-history-end }
                    when 'suspend'         { self.suspend(:&on-suspend, :&on-continue);
                                             $.input-field.force-pos-to-start;
                                             self.do-edit('insert-string', ''); }
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
            }
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
