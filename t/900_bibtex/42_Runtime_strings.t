use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 11;

subtest "requirements" => sub {
    plan tests => 1;

    use_ok("LaTeXML::Post::BiBTeX::Runtime::Strings");
};

subtest "addPeriod" => sub {
    plan tests => 6;

    sub IsAddPeriod {
        my ( $input, $expected ) = @_;
        is( addPeriod($input), $expected, $input );
    }

    IsAddPeriod( "",              "" );
    IsAddPeriod( "}}",            "}}." );
    IsAddPeriod( "hello world!",  "hello world!" );
    IsAddPeriod( "hello world",   "hello world." );
    IsAddPeriod( "hello world}",  "hello world}." );
    IsAddPeriod( "hello world!}", "hello world!}" );
};

subtest "splitSpecial" => sub {
    plan tests => 18;

    sub IsSplitSpecial {
        my ( $input, $expected ) = @_;
        is_deeply( [ splitSpecial($input) ], $expected, $input );
    }

    # non-command sequence => tail
    IsSplitSpecial( "{w",            [ 0, '', '{w',            undef ] );
    IsSplitSpecial( "{hello world}", [ 0, '', '{hello world}', undef ] );

    # regular command sequence => head
    IsSplitSpecial( "{\\command}",       [ 1, '{\\command}',  '',      undef ] ); # no argument
    IsSplitSpecial( "{\\command{abc}}",  [ 1, '{\\command{',  'abc}}', undef ] ); # argument with {}s
    IsSplitSpecial( "{\\command abc}",   [ 1, '{\\command ',  'abc}',  undef ] ); # argument with ' 's
    IsSplitSpecial( "{\\command {abc}}", [ 1, '{\\command {', 'abc}}', undef ] ); # argument with ' ' and '{' s

    # special command sequence => tail
    IsSplitSpecial( "{\\ss}",       [ 1, '{\\', 'ss}',       'ss' ] ); # no argument
    IsSplitSpecial( "{\\ss{abc}}",  [ 1, '{\\', 'ss{abc}}',  'ss' ] ); # argument with {}s
    IsSplitSpecial( "{\\ss abc}",   [ 1, '{\\', 'ss abc}',   'ss' ] ); # argument with ' 's
    IsSplitSpecial( "{\\ss {abc}}", [ 1, '{\\', 'ss {abc}}', 'ss' ] ); # argument with ' ' and '{' s

    # special command sequence that doesn't start with alphabetical chars => tail
    IsSplitSpecial( "{\\`i}",       [ 1, '{\\', '`i}',       'i' ] ); # no argument
    IsSplitSpecial( "{\\`i{abc}}",  [ 1, '{\\', '`i{abc}}',  'i' ] ); # argument with {}s
    IsSplitSpecial( "{\\`i abc}",   [ 1, '{\\', '`i abc}',   'i' ] ); # argument with ' 's
    IsSplitSpecial( "{\\`i {abc}}", [ 1, '{\\', '`i {abc}}', 'i' ] ); # argument with ' ' and '{' s 

    # special command sequence that doesn't start with alphabetical chars => tail
    IsSplitSpecial( "{\\`g}",       [ 1, '{\\', '`g}',       undef ] ); # no argument
    IsSplitSpecial( "{\\`g{abc}}",  [ 1, '{\\', '`g{abc}}',  undef ] ); # argument with {}s
    IsSplitSpecial( "{\\`g abc}",   [ 1, '{\\', '`g abc}',   undef ] ); # argument with ' 's
    IsSplitSpecial( "{\\`g {abc}}", [ 1, '{\\', '`g {abc}}', undef ] ); # argument with ' ' and '{' s 
};

subtest "splitLetters" => sub {
    plan tests => 10;

    sub IsSplitLetters {
        my ( $input, $expected ) = @_;
        is_deeply( [ splitLetters($input) ], $expected, $input );
    }

    IsSplitLetters( 'hello',
        [ [ 'h', 'e', 'l', 'l', 'o' ], [ 0, 0, 0, 0, 0 ] ] );
    IsSplitLetters( 'h{e}llo',
        [ [ 'h', '{e}', 'l', 'l', 'o' ], [ 0, 1, 0, 0, 0 ] ] );

    IsSplitLetters(
        '{hello} world',
        [
            [ '{h', 'e', 'l', 'l', 'o}', ' ', 'w', 'o', 'r', 'l', 'd' ],
            [ 1,    1,   1,   1,   1,    0,   0,   0,   0,   0,   0 ]
        ]
    );
    IsSplitLetters( '{{ab}c}d{{e}}',
        [ [ '{{a', 'b}', 'c}', 'd', '{{e}}' ], [ 2, 2, 1, 0, 2 ] ] );
    IsSplitLetters( '{{}}{a}', [ ['{{}}{a}'], [1] ] );

    # un-balanced braces
    IsSplitLetters( '}world',
        [ [ '}w', 'o', 'r', 'l', 'd' ], [ 0, 0, 0, 0, 0 ] ] );

    # single accent
    IsSplitLetters(
        '{\ae} world',
        [ [ '{\ae}', ' ', 'w', 'o', 'r', 'l', 'd' ], [ 0, 0, 0, 0, 0, 0, 0 ] ]
    );

    # not-an-accent
    IsSplitLetters(
        '{{\ae}} world',
        [
            [ '{{\\', 'a', 'e}}', ' ', 'w', 'o', 'r', 'l', 'd' ],
            [ 2,      2,   2,     0,   0,   0,   0,   0,   0 ]
        ]
    );

    # empty
    IsSplitLetters( '{}', [ ['{}'], [] ] );

    # zero characters don't break stuff
    IsSplitLetters( '{\0a}', [ ['{\0a}'], [0] ] );
};

subtest "textLength" => sub {
    plan tests => 14;

    sub IsTextLength {
        my ( $input, $expected ) = @_;
        is_deeply( textLength($input), $expected, $input );
    }

    IsTextLength( 'hello',   5 );
    IsTextLength( 'h{e}llo', 5 );

    IsTextLength( '{hello} world', 11 );
    IsTextLength( '{{ab}c}d{{e}}', 5 );
    IsTextLength( '{{}}{a}',       1 );

    # un-balanced braces
    IsTextLength( '}world', 5 );

    # single accent
    IsTextLength( '{\ae} world', 7 );

    # not-an-accent
    IsTextLength( '{{\ae}} world', 9 );

    # empty
    IsTextLength( '{}', 0 );

    # zero characters don't break stuff
    IsTextLength( '{\0a}', 1 );

    IsTextLength( "a normal string",        15 );
    IsTextLength( "a {normal} string",      15 );
    IsTextLength( "a {no{r}mal} string",    15 );
    IsTextLength( "a {\\o{normal}} string", 10 );
};

subtest "getCase" => sub {
    plan tests => 13;

    sub IsGetCase {
        my ( $input, $expected ) = @_;
        is_deeply( getCase($input), $expected, $input );
    }

    IsGetCase( 'hello',       'l' );
    IsGetCase( '',            'l' );
    IsGetCase( '{\\`h}World', 'l' );
    IsGetCase( '{\von}',      'l' );

    IsGetCase( '{\relax von}', 'l' );
    IsGetCase( '{\relax Von}', 'u' );

    IsGetCase( '{von}', 'u' );

    IsGetCase( '{-}hello', 'l' );
    IsGetCase( '{-}Hello', 'u' );

    IsGetCase( 'Hello',       'u' );
    IsGetCase( '{\\`H}world', 'u' );

    IsGetCase( '{\ae}', 'l' );
    IsGetCase( '{\AE}', 'u' );
};

subtest "changeCase" => sub {
    plan tests => 12;

    sub IsChangeCase {
        my ( $input, $format, $expected ) = @_;
        is( changeCase( $input, $format ),
            $expected, $format . ' => ' . $input );
    }

    # changing case of a single world
    IsChangeCase( "HeLlo", "u", "HELLO" );
    IsChangeCase( "HeLlo", "l", "hello" );
    IsChangeCase( "HeLlo", "t", "Hello" );

    # case of something with brackets
    IsChangeCase( "HeLlo {WeIrD} world", "u", "HELLO {WeIrD} WORLD" );
    IsChangeCase( "HeLlo {WeIrD} world", "l", "hello {WeIrD} world" );
    IsChangeCase( "HeLlo {WeIrD} world", "t", "Hello {WeIrD} world" );

    # nested brackets
    IsChangeCase( "a{b{c}}d", "u", "A{b{c}}D" );

    # accents
    IsChangeCase( "{}{\\ae}",     "u", "{}{\\AE}" );
    IsChangeCase( "{\\'a} world", "u", "{\\'A} WORLD" );
    IsChangeCase( "{}{\\ss}",     "u", "{}{SS}" );         # special case

    # not-an-accent
    IsChangeCase( "{\\0a} world", "u", "{\\0A} WORLD" );

    # weird commands
    IsChangeCase( "{\\relax von}", "u", "{\\relax VON}" );    # commands
};

subtest "textWidth" => sub {
    plan tests => 6;

    sub IsTextWidth {
        my ( $input, $expected ) = @_;
        is( textWidth($input), $expected, $input );
    }

    IsTextWidth( "hello world",       4782 );
    IsTextWidth( "thing",             2279 );
    IsTextWidth( "{hello world}",     5782 );
    IsTextWidth( "{\\ae}",            722 );
    IsTextWidth( "{\\ab}",            0 );
    IsTextWidth( "{\\example thing}", 2279 );
};

subtest "textSubstring" => sub {
    plan tests => 7;

    sub isTextSubstring {
        my ( $input, $start, $length, $expected ) = @_;
        is( textSubstring( $input, $start, $length ), $expected, $input );
    }

    isTextSubstring( "Charles",           1,  1, "C" );
    isTextSubstring( "{Ch}arles",         1,  1, "{" );
    isTextSubstring( "{\\relax Ch}arles", 1,  2, "{\\" );
    isTextSubstring( "Hello World",       -1, 1, "d" );
    isTextSubstring( "Hello World",       -1, 2, "ld" );
    isTextSubstring( "Hello World",       -1, 3, "rld" );
    isTextSubstring( "B{\\`a}rt{\\`o}k",  -2, 3, "`o}" );
};

subtest "textPrefix" => sub {
    plan tests => 3;

    sub isTextPrefix {
        my ( $input, $length, $expected ) = @_;
        is( textPrefix( $input, $length ), $expected, $input );
    }

    isTextPrefix( "hello world",          2, "he" );
    isTextPrefix( "{{hello world}}",      2, "{{he}}" );
    isTextPrefix( "{\\accent world}1234", 2, "{\\accent world}1" );
};

subtest "textPurify" => sub {
    plan tests => 9;

    sub IsTextPurify {
        my ( $input, $expected ) = @_;
        is( textPurify($input), $expected, $input );
    }

    # an example which encapsulates pretty much everything
    IsTextPurify( 'The {\relax stuff} and {\ae} things~-42',
        'The stuff and ae things  42' );

    # examples from Tame the BeaST, page 22
    IsTextPurify( 't\^ete',     'tete' );
    IsTextPurify( 't{\^e}te',   'tete' );
    IsTextPurify( 't{\^{e}}te', 'tete' );

    IsTextPurify( 'Bib{\TeX}', 'Bib' );
    IsTextPurify( 'Bib\TeX',   'BibTeX' );

    IsTextPurify( '\OE', 'OE' );

    IsTextPurify( 'The {\LaTeX} {C}ompanion',  'The  Companion' );
    IsTextPurify( 'The { \LaTeX} {C}ompanion', 'The  LaTeX Companion' );
};
