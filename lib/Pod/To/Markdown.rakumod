use Pod::To::HTML:ver<0.9.0+>:auth<zef:raku-community-modules>;

unit class Pod::To::Markdown:ver<0.2.1>:auth<zef:raku-community-modules>;

#my sub Debug(&code) { &code() }
my sub Debug(&code) { }

method render($pod, Bool :$no-fenced-codeblocks --> Str)
{
    my Bool $*fenced-codeblocks := !$no-fenced-codeblocks;
    my Bool $*in-code-block     := False;
    my $*positional-separator   := "\n\n";
    node2md($pod) ~ "\n"
}

my sub pod2markdown($pod, Bool :$no-fenced-codeblocks --> Str) is export {
    Pod::To::Markdown.render($pod, :$no-fenced-codeblocks);
}

my proto sub node2md(|) {*}
multi sub node2md(Pod::Heading:D $pod --> Str:D) {
    # Collapse contents without newlines, is this correct behaviour?
    my $*positional-separator := ' ';
    head2md($pod.level, node2md($pod.contents))
}

multi sub node2md(Pod::Block::Code:D $pod --> Str:D) {
    my $*in-code-block := True;
    code2md markdownify($pod).trim-trailing, :lang($pod.config<lang>)
}

multi sub node2md(Pod::Block::Named:D $pod --> Str:D) {
    given $pod.name {
        when 'pod'    { node2md($pod.contents) }
        when 'para'   { markdownify($pod, ' ') }
        when 'defn'   { node2md($pod.contents) }
        when 'config' { Debug { die "NAMED CONFIG" }; '' }
        when 'nested' { Debug { die "NAMED NESTED" }; '' }
        default       { head2md(1, $pod.name) ~ "\n\n" ~ node2md($pod.contents); }
    }
}

multi sub node2md(Pod::Block::Para:D $pod --> Str:D) {
    markdownify($pod)
}

my sub entity-escape($str) {
    $str.trans:
      [ '&',     '<',    '>'    ] =>
      [ '&amp;', '&lt;', '&gt;' ]
}

multi sub node2md(Pod::Block::Table:D $pod --> Str:D) {
    node2html($pod)
      .trim
      # Rakudo's Pod parsing is incomplete; see Rakudo issue #2863
      #
      # Here we implement a hack to allow Unicode entities to be
      # displayed in tables; it's a specific enough pattern that it
      # should not unintentionally transform the text.
      #
      # See Pod::To::Markdown issue #26
      .subst(:g, rx/ 'E&lt;0x' (<.xdigit> ** 4) '&gt;' /, { "&#x{$0};" })
}

multi sub node2md(Pod::Block::Declarator:D $pod --> Str:D) {
    my $lvl = 2;
    if $pod.WHEREFORE.WHY {
        my $what = do given $pod.WHEREFORE {
            when Method {
                signature2md($lvl, $_, :method);
            }
            when Sub {
                signature2md($lvl, $_, :!method);
            }
            when Attribute {
                my $name = .gist;
                $name .= subst('!', '.') if .has_accessor;
                head2md($lvl+1, "has $name");
            }
            when .HOW ~~ Metamodel::ClassHOW {
                head2md($lvl, "class $_.raku()");
            }
            when .HOW ~~ Metamodel::ModuleHOW {
                head2md($lvl, "module $_.raku()");
            }
            when .HOW ~~ Metamodel::PackageHOW {
                head2md($lvl, "package $_.raku()");
            }
            default {
                ''
            }
        }
        $what ~ "\n\n" ~ node2md($pod.WHEREFORE.WHY.contents)
    }
    else {
        ''
    }
}

multi sub node2md(Pod::Block::Comment:D $pod --> '') { }

my constant %Mformats = U => '_', I => '*', B => '**', C => '`';

my constant %HTMLformats = R => 'var';

multi sub node2md(Pod::FormattingCode:D $pod --> Str:D) {
    my str $type = $pod.type;
    return '' if $pod.type eq 'Z';

    my $text = markdownify($pod);

    # It is safer to strip formatting in code blocks
    return $text if $*in-code-block;

    if $type eq 'L' {
        if $pod.meta.elems > 0 {
            $text =  '[' ~ $text ~ '](' ~ $pod.meta[0] ~ ')';
        }
        else {
            $text = '[' ~ $text.subst(/ ^ '#' /, '') ~ '](' ~ $text ~ ')';
        }
    }

    # If the code contains a backtick, we need to do more work
    elsif $pod.type eq 'C' and $text.contains('`') {

        # We need to open and close with some number larger than the largest
        # contiguous number of backticks
        my int $length = $text.match(/'`'*/, :g).sort.tail.chars + 1;
        my $symbol = %Mformats{$type} x $length;

        # If text starts with a backtick we need to pad it with a space
        my $begin = $text.starts-with('`')
            ?? $symbol ~ ' '
            !! $symbol;

        # likewise if it ends with a backtick that must be padded as well
        my $end = $text.ends-with('`')
            ?? ' ' ~ $symbol
            !! $symbol;
        $text = $begin ~ $text ~ $end
    }
    elsif %Mformats{$pod.type} :exists {  # UNCOVERABLE
        $text = %Mformats{$type} ~ $text ~ %Mformats{$type}
    }

    %HTMLformats{$type}:exists
      ?? sprintf '<%s>%s</%s>', %HTMLformats{$type}, $text, %HTMLformats{$type}
      !! $text
}

multi sub node2md(Pod::Item:D $pod --> Str:D) {
    my $contents := $pod.contents;
    my $level    := $pod.level // 1;

    my $markdown = '* ' ~ node2md($contents[0]);
    $markdown ~= "\n\n" ~ node2md($contents[1..*]).indent(2)
      if $contents.elems > 1;

    $markdown.indent($level * 2)
}

multi sub node2md(Pod::Defn:D $pod --> Str:D) {
    my $fmt := %Mformats{$pod.config<formatted> // 'B'} // '';
    $fmt ~ node2md($pod.term) ~ $fmt ~ "\n\n" ~ node2md($pod.contents)
}

multi sub node2md(Positional:D $pod --> Str:D) {
    $pod>>.&node2md.grep(*.?chars).join($*positional-separator)
}

multi sub node2md(Pod::Config:D $pod --> Str:D) {
    ''
}

multi sub node2md($pod --> Str:D) {
    $pod.Str
}

#- helper subs -----------------------------------------------------------------
my sub markdownify($pod, Str:D $joiner = '' --> Str:D) {
    $pod.contents.map({ node2md($_) }).join($joiner)
}

my sub head2md(Int:D $lvl, Str:D $head) {
    given min($lvl, 6) {
        when 1  { $head ~ "\n" ~ ('=' x $head.chars) }
        when 2  { $head ~ "\n" ~ ('-' x $head.chars) }
        default { '#' x $_ ~ ' ' ~ $head }
    }
}

my sub code2md(Str:D $code, :$lang) {
    if $lang and $*fenced-codeblocks {
        "```$lang\n$code\n```"
    }
    else {
        $code.indent(4)
    }
}

my sub signature2md(Int:D $lvl, Callable:D $sig, Bool :$method! --> Str:D) {
    # TODO Add proto? How?
    my $name := (
      $sig.multi ?? 'multi' !! Empty,
      $method ?? 'method' !! 'sub',
      $sig.name
    ).join(' ');

    my @params = $sig.signature.params;
    if $method {
        # Ignore invocant
        @params.shift;
        # Ignore default slurpy named parameter
        @params.pop
          if do given @params.tail { .slurpy and .name eq '%_' }
    }

    my $code = $name;
    $code ~= @params.elems
      ?? "(\n{ @params.map({ .raku.indent(4) }).join(",\n") }\n)"
      !! "()";

    $code ~= ' returns ' ~ $sig.signature.returns.raku
      unless $sig.signature.returns.WHICH =:= Mu;

    $code = code2md($code, :lang<raku>);

    head2md($lvl+1, $name) ~ "\n\n" ~ $code
}

=begin comment
This isn't useful as long as all tables are rendered as HTML. It
could still come in handy if, esthetically, we'd want simple
tables rendered as plain Markdown.

sub table2md(Pod::Block::Table $pod) {
    my @rows = $pod.contents;
    my @maxes;
    for @rows, $pod.headers.item -> @row {
      for 0..^@row -> $i {
          @maxes[$i] = max @maxes[$i], @row[$i].chars;
      }
    }
    my $fmt = Arr@maxes>>.sprintf('%%-%ds)
    @rows.map({
      my @cols = @_;
      my @ret;
      for 0..@_ -> $i {
          @ret.push: sprintf('%-'~$i~'s',

    if $pod.headers {
      @rows.unshift([$pod.headers.item>>.chars.map({'-' x $_})]);
      @rows.unshift($pod.headers.item);
    }
    @rows>>.join(' | ') ==> join("\n");
}
=end comment

# vim: expandtab shiftwidth=4
