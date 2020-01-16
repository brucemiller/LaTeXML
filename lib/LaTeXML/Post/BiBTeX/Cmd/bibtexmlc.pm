# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Cmd::bibtexmlc                              | #
# | bibtexmlc entry point                                               | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Cmd::bibtexmlc;
use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);

use LaTeXML::Post::BiBTeX::Runner;
use LaTeXML::Post::BiBTeX::Common::Utils qw(slurp puts);

use LaTeXML::Post::BiBTeX::Common::StreamReader;

sub main {
    shift(@_);    # remove the first argument

    my ( $output, $help ) = ( '', 0 );
    GetOptionsFromArray(
        \@_,
        "destination=s" => \$output,
        "help"          => \$help,
    ) or return usageAndExit(1);

    # if we requested help, or we had a wrong number of arguments, exit
    return usageAndExit(0) if ($help);
    return usageAndExit(1) if scalar(@_) ne 1;

    # check that the bst file exists
    my ($bstfile) = @_;
    unless ( -e $bstfile ) {
        print STDERR "Unable to find bstfile $bstfile\n";
        return 3;
    }

    # create a reader for it
    my $reader = LaTeXML::Post::BiBTeX::Common::StreamReader->new();
    $reader->openFile($bstfile);

    # compile the bst file
    my ( $code, $compile ) = createCompile(
        $reader,
        sub {
            print STDERR @_;
        },
        $bstfile
    );
    return $code, undef if $code ne 0;

    # Write the output file
    if ($output) {
        puts( $output, $compile );
        print STDERR "Wrote    $output. \n";
        return 0;
    }

    print STDOUT $compile;
    print STDERR "Wrote    STDOUT. \n";
    return 0;
}

# helper function to print usage information and exit
sub usageAndExit {
    my ($code) = @_;
    print STDERR
      'bibtexmlc [--help] [--target $TARGET] [--destination $DEST] $BSTFILE'
      . "\n";
    return $code;
}

1;
