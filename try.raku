use Terminal::LineEditor;
use Terminal::LineEditor::RawTerminalInput;

class MyCLIInputInput is Terminal::LineEditor::ScrollingSingleLineInput::ANSI {
    method edit-paste-start(|c) { dd; dd c; }
    method edit-paste-end(|c) { dd; dd c; }
}

class MyCLIInput is Terminal::LineEditor::CLIInput {
    method special-actions {
        callsame() (+) set < PasteStart PasteEnd paste-string >
    }
    method do-edit($action, $insert?) {
        if $action eq "paste-string" {
            # tee hee
            ENTER self.leave-raw-mode(:nl);
            # LEAVE self.enter-raw-mode();
            my $regular-cli = Terminal::LineEditor::CLIInput.new;
            my $work = $insert;
            say "I have received your pasted input.";
            say "do you want to do something with this before adding it to your commandline?";
            my @states = $work;
            my $last-command = "";
            loop {
                @states.push: $work unless @states.tail eq $work;
                for $work.lines.pairs {
                    say "  " ~ .key.fmt("% 3d") ~ "> " ~ .value.raku;
                }
                my $lines-to-undo = $work.lines.elems + 2;
                NEXT { $*OUT.print("\e[2K" ~ ("\e[A\e[2K" x $lines-to-undo)) }
                say "";
                $*OUT.flush;
                my $command = $regular-cli.prompt("action>");
                $command ||= $last-command;
                last without $command;
                NEXT $last-command = $command;
                sub do-it(&thing) {
                    with $command.words[1] -> $arg {
                        $work = $work.lines.pairs.map({ .key == $arg ?? thing(.value) !! .value }).grep(*.so).join("\n");
                    }
                    else {
                        $work = $work.lines.map(&thing).grep(*.so).join("\n");
                    }
                }
                given $command.words[0] {
                    when "paste" | "ok" { last }
                    when "upper" { do-it(*.uc) }
                    when "quote" { do-it(*.raku) }
                    when "stop" | "quit" | "abort" { }
                    when "merge" { $work = $work.lines.join($command.words[1] // " ") }
                    when "encode" { do-it(*.encode.list.fmt("%02x", " ")) }
                    when "slice" { do-it(*.substr(1)) }
                    when "sloce" { do-it(*.chop) }
                    when "undo" { if @states > 2 { @states.pop; $work = @states.pop } else { say "no." } }
                    when "drop" { do-it({ "" }) }
                    when "" { $work = ""; last }
                    when Nil { $work = ""; last }
                    when "help" | "h" | "?" { say "Possible actions: paste, upper, quote, stop, merge, encode, slice, undo, drop" }
                    default { $last-command = "" }
                }
            }
            self.enter-raw-mode;
            nextwith('insert-string', $work);
        }
        nextsame
    }
}

my $cli = MyCLIInput.new(:input-class(MyCLIInputInput));

$cli.bind-key("PasteStart", "paste-start");
#$cli.bind-key("PasteEnd", "paste-end");
$cli.set-bracketed-paste-mode(PasteWithBrackets);


say $cli.prompt("hey>").raku;
