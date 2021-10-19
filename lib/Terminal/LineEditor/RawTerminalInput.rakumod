# ABSTRACT: Input widgets for raw terminal text input

use Term::termios;
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
        # 0 => '',                       # CTRL-@
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
       # 14 => 'history-next',           # CTRL-N
       # 15 => '',                       # CTRL-O
       # 16 => 'history-prev',           # CTRL-P
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

    #| Set of valid special actions; override in a composing class
    method special-actions() { set() }

    #| Throw an exception unless $action is a valid edit action
    method ensure-valid-keymap-action(Str:D $action) {
        X::Terminal::LineEditor::UnknownAction.new(:$action).throw
            unless self.special-actions(){$action} || self.^can("edit-$action");
    }

    #| Bind a key (by ord) to an edit action (by short string name)
    method bind-key(UInt:D $ord, Str:D $action) {
        self.ensure-valid-keymap-action($action);
        %!keymap{$ord} = $action;
    }
}


#| Role for CLIs/TUIs that enter/leave raw terminal mode
role Terminal::LineEditor::RawTerminalIO {
    has IO::Handle:D $.input  = $*IN;
    has IO::Handle:D $.output = $*OUT;
    has              $!saved-termios;

    #| Switch input to raw mode if it's a TTY, returning saved state
    method enter-raw-mode() {
        # If a TTY, convert to raw mode, saving current mode first
        if $.input.t {
            my $fd = $.input.native-descriptor;
            $!saved-termios = Term::termios.new(:$fd).getattr;
            Term::termios.new(:$fd).getattr.makeraw.setattr(:FLUSH);
        }
    }

    #| Switch input back to normal mode (iff it was switched to raw previously)
    method leave-raw-mode(Bool:D :$nl = True) {
        $!saved-termios.setattr(:DRAIN) if $!saved-termios;
        $!saved-termios = Any;
        $.output.put('') if $nl;
    }

    #| Read a single raw character, decoding bytes, returning Str if input cut off;
    #| assumes input already in raw mode
    method read-raw-char(--> Str) {
        my $buf = Buf.new;

        # TimToady++ for suggesting this decode loop idiom
        repeat {
            my $b = $.input.read(1) or return Str;
            $buf.push($b);
        } until try my $c = $buf.decode;

        $c
    }

    #| Query the terminal and return a raw response string;
    #| assumes input set up so read-raw-char works
    method query-terminal(Str:D $request, Str:D $stopper) {
        # Send request to terminal
        $.output.print($request);
        $.output.flush;

        # Grab the response
        my $response = '';
        my $c;
        repeat {
            $c = self.read-raw-char // last;
            $response ~= $c;
        } while $c ne $stopper;

        $response
    }
}


#| Role with utility methods for raw terminal I/O
role Terminal::LineEditor::RawTerminalUtils {
    #| Detect cursor position, returning (row, col) or Empty if unable
    method detect-cursor-pos() {
        my $response = self.query-terminal("\e[6n", 'R');
        $response ~~ /^ "\e[" (\d+) ';' (\d+) 'R' $/ ?? (+$0, +$1) !! Empty
    }

    #| Detect terminal size, returning (rows, cols) or Empty if unable
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
        my $answer := self.detect-cursor-pos;
        $.output.print("\e8");
        $answer
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
        # so run &on-continue if any, then go back into raw mode and
        # refresh the displayed edit buffer, offsetting the cursor as needed.

        $_() with &on-continue;
        self.enter-raw-mode;

        # XXXX: BOGUS
        my $offset-move = $buffer.cursor-move-command(  $buffer.cursor-pos
                                                      - $buffer.cursor-start);
        $.output.print($offset-move ~ $buffer.refresh);
    }
}


#| A complete CLI input class
class Terminal::LineEditor::CLIInput
   is Terminal::LineEditor::ScrollingSingleLineInput
 does Terminal::LineEditor::KeyMappable
 does Terminal::LineEditor::RawTerminalIO
 does Terminal::LineEditor::RawTerminalUtils {
    #| Valid special actions
    method special-actions() {
        constant $special
            = set < abort-input abort-or-delete finish literal-next suspend >;
    }

    #| Full input/edit loop; returns final user input or Str if aborted
    # XXXX: Bool:D :$history = False, Str:D :$context = 'default',
    method read-input(Str :$mask, :&on-continue --> Str) {
        # If not a terminal, just read a line from input and return it
        return $.input.get // Str unless $.input.t;

        # Switch terminal to raw mode while editing
              self.enter-raw-mode;
        LEAVE self.leave-raw-mode;

        # Detect current cursor position and terminal size
        my ($row,  $col ) = self.detect-cursor-pos // return Str;
        my ($rows, $cols) = self.detect-terminal-size;

        # XXXX: BOGUS
        # Set up an editable input buffer
        my $buffer = Buffer.new(:cursor-start($col),
                                :cursor-end($cols // 80),
                                :$mask);

        # DRY helper
        my sub do-edit($command, $insert?) {
            my $edited = $insert ?? $buffer.edit-insert-string($insert)
                                 !! $buffer."edit-$command"();
            $.output.print($buffer.refresh($edited));
            $.output.flush
        }

        # Read raw characters and dispatch either as actions or chars to insert
        my $literal-mode = False;
        loop {
            my $c = self.read-raw-char // last;

            if $literal-mode {
                do-edit('insert-string', $c);
                $literal-mode = False;
            }
            orwith %!keymap{$c.ord} {
                when 'literal-next'    { $literal-mode = True }
                when 'suspend'         { self.suspend(:$buffer, :&on-continue) }
                when 'finish'          { last }
                when 'abort-input'     { return Str }
                when 'abort-or-delete' { return Str unless $buffer.buffer;
                                         do-edit('delete-char-forward') }
                default                { do-edit($_) }
            }
            else { do-edit('insert-string', $c) }
        }

        # Return final buffer
        $buffer.buffer
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
