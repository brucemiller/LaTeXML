use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 4;
use File::Spec;

subtest "requirements" => sub {
    plan tests => 1;

    use_ok("LaTeXML::Post::BiBTeX::Runtime::Buffer");
};

sub makeBuffer {
    my $text = shift(@_);
    open( my $handle, '>', $text );
    return LaTeXML::Post::BiBTeX::Runtime::Buffer->new( $handle, @_ );
}

sub feedBuffer {
    my ($buffer, $file) = @_;
    my @lines = split(/^/, slurp($file));
    foreach my $line (@lines) {
        chomp($line);
        $buffer->write($line);
        $buffer->writeLn;
    }
    $buffer->finalize;
}

subtest "synthetic wrapEnabled=0" => sub {
    plan tests => 1;

    my $text   = '';
    my $buffer = makeBuffer( \$text, 0 );

    feedBuffer($buffer, File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '01_synthetic', 'input.txt' ) );

    # to generate the test cases
    # puts(File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '01_synthetic', 'output_nowrap.txt' ), $text);
    is(
        $text,
        slurp(
            File::Spec->catfile(
                't', '900_bibtex', 'fixtures', 'buffer', '01_synthetic', 'output_nowrap.txt'
            )
        )
    );
};

subtest "synthetic wrapEnabled=1" => sub {
    plan tests => 1;

    my $text   = '';
    my $buffer = makeBuffer( \$text, 1 );

    feedBuffer($buffer, File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '01_synthetic', 'input.txt' ) );

    # to generate the test cases
    # puts(File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '01_synthetic', 'output_wrap.txt' ), $text);
    is(
        $text,
        slurp(
            File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '01_synthetic', 'output_wrap.txt' )
        )
    );
};


subtest "real wrapEnabled=1" => sub {
    plan tests => 1;

    my $text   = '';
    my $buffer = makeBuffer( \$text, 1 );

    feedBuffer($buffer, File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '02_real', 'input.txt' ) );

    is(
        $text,
        slurp(
            File::Spec->catfile( 't', '900_bibtex', 'fixtures', 'buffer', '02_real', 'output.txt' )
        )
    );
};
