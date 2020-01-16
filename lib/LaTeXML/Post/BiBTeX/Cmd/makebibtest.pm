# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Cmd::makebibtest                            | #
# | makebibtest utility entry point                                     | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Cmd::makebibtest;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Common::Test qw(integrationTestPaths);
use LaTeXML::Post::BiBTeX::Cmd::makebbl;
use LaTeXML::Post::BiBTeX::Cmd::bibtexml;

sub main {

    # remove the first argument, and display help with a testname is missing
    shift(@_);
    return usageAndExit(1) if scalar(@_) ne 1;

    # figure out paths
    my ( $bstIn, $bibIn, $citesIn, $macroIn, $resultOut ) =
      integrationTestPaths( shift(@_) );

    # prepare makebbl args
    my @makebbl = (
        '--cites', join( ',', @{$citesIn} ),
        '--destination', $resultOut . '.org',
        $bstIn, $bibIn
    );

    # run makebbl
    print STDERR "./tools/makebbl " . join( ' ', @makebbl ) . "\n";
    my $code = LaTeXML::Post::BiBTeX::Cmd::makebbl->main(@makebbl);
    return $code unless $code eq 0;

    # prepare bibtexml args
    my @bibtexml = (
        '--wrap', '--cites', join( ',', @{$citesIn} ),
        '--destination', $resultOut, $bstIn, $bibIn,
    );
    push( @bibtexml, '--macro', $macroIn ) if defined($macroIn);

    # run bibtexml
    print STDERR "./bin/bibtexml " . join( ' ', @bibtexml ) . "\n";
    return LaTeXML::Post::BiBTeX::Cmd::bibtexml->main(@bibtexml);
}

# helper function to print usage information and exit
sub usageAndExit {
    my ($code) = @_;
    print STDERR 'maketest $NAME' . "\n";
    return $code;
}

1;
