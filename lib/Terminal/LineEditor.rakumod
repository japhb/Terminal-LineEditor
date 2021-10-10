unit class Terminal::LineEditor:auth<zef:japhb>:api<0>:ver<0.0.1>;


=begin pod

=head1 NAME

Terminal::LineEditor - Generalized terminal line editing


=head1 SYNOPSIS

=begin code :lang<raku>

use Terminal::LineEditor;


=end code

=head1 DESCRIPTION

C<Terminal::LineEditor> is a terminal line editing package similar to
C<Linenoise> or C<Readline>, but B<not> a drop-in replacement for either of
them.  C<Terminal::LineEditor> has a few key design differences:

=item Implemented in pure Raku; C<Linenoise> and C<Readline> are Nativecall
      wrappers

=item Features strong separation of concerns; all components are exposed and
      replaceable

=item Useable both directly for simple CLI apps and embedded in TUI interfaces


=head1 AUTHOR

Geoffrey Broadwell <gjb@sonic.net>


=head1 COPYRIGHT AND LICENSE

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=end pod
