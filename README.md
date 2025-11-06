[![Actions Status](https://github.com/raku-community-modules/Pod-To-Markdown/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-Markdown/actions) [![Actions Status](https://github.com/raku-community-modules/Pod-To-Markdown/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-Markdown/actions) [![Actions Status](https://github.com/raku-community-modules/Pod-To-Markdown/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-Markdown/actions)

NAME
====

Pod::To::Markdown - Render Pod as Markdown

SYNOPSIS
========

From command line:

    $ raku --doc=Markdown lib/To/Class.rakumod

From Raku:

```raku
use Pod::To::Markdown;  # exports pod2markdown

print pod2markdown($=pod);

=head1 DESCRIPTION

=head2 method render

=begin code :lang<raku>
method render($pod, Bool :$no-fenced-codeblocks --> Str)
```

### Render Pod as Markdown

To render without fenced codeblocks (```` ``` ````), as some markdown engines don't support this, use the :no-fenced-codeblocks option. If you want to have code show up as ```` ```raku```` to enable syntax highlighting on certain markdown renderers, use:

    =begin code :lang<raku>

sub pod2markdown
----------------

```raku
sub pod2markdown($pod, Bool :$no-fenced-codeblocks --> Str)
```

Render Pod as Markdown, see .render()

AUTHORS
=======

  * Jorn van Engelen

  * Tim Smith

  * Samantha McVey

  * Tim Siegel

and many others.

COPYRIGHT AND LICENSE
=====================

Copyright 2014 - 2015 Jorn van Engelen

Copyright 2016 - 2020 Tim Smith

Copyright 2021 - 2024 Tim Siegel

Copyright 2025 The Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

