NAME
====

Terminal::LineEditor - Generalized terminal line editing

SYNOPSIS
========

```raku
use Terminal::LineEditor;
```

DESCRIPTION
===========

`Terminal::LineEditor` is a terminal line editing package similar to `Linenoise` or `Readline`, but **not** a drop-in replacement for either of them. `Terminal::LineEditor` has a few key design differences:

  * Implemented in pure Raku; `Linenoise` and `Readline` are Nativecall wrappers

  * Features strong separation of concerns; all components are exposed and replaceable

  * Useable both directly for simple CLI apps and embedded in TUI interfaces

AUTHOR
======

Geoffrey Broadwell <gjb@sonic.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

