# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Cmd::makebbl                                | #
# | makebbl utility entry point                                         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Cmd::makebbl;
use strict;
use warnings;

use Encode;
use Getopt::Long qw(GetOptionsFromArray);
use Module::Load;

sub main {
    shift(@_);    # remove the first argument

    my ( $output, $cites, $help ) = ( undef, "*", 0 );
    GetOptionsFromArray(
        \@_,
        "destination=s" => \$output,
        "cites=s"       => \$cites,
        "help"          => \$help,
    ) or return usageAndExit(1);

    # if we requested help, or we had a wrong number of arguments, exit
    return usageAndExit(0) if ($help);
    return usageAndExit(1) if scalar(@_) eq 0;

    # selected bibliography style
    my $style = shift(@_);
    $style =~ s/\.bst$//i if (-e $style);
    my $bibliographystyle = "\\bibliographystyle{$style}";

    # macro to load the bib files
    my $bibliography = join( "\n", map { "\\bibliography{" . $_ . "}{}" } @_ );

    # macro for the cites of the bib files
    my $nocite = join( "", map { "\\nocite{$_}" } split( ",", $cites ) );

    # generate tex code
    my $texcode = <<"end_of_tex";
\\documentclass{standalone}
\\usepackage{cite}

\\begin{document}
$nocite
$bibliography
$bibliographystyle
\\end{document}
end_of_tex

    # surpress STDOUT for a bit
    open my $out, ">&STDOUT";
    open STDOUT, '>', "/dev/null";

    my $jobname = 'temp';

    # run latex
    open( my $fh, '|-', 'latex', '-jobname', $jobname );
    print $fh $texcode;
    close($fh);

    # run bibtex
    system("bibtex $jobname 1>&2");

    # be loud again
    open STDOUT, ">&", $out;

    # cleanup a little bit
    unlink("$jobname.aux");
    unlink("$jobname.dvi");
    unlink("$jobname.log");
    unlink("$jobname.blg");

    # open the bbl
    open $fh, '<', "$jobname.bbl" or die "no bbl file was produced $!";

    # create an output file (or STDOUT)
    my $ofh;
    if ( defined($output) ) {
        open( $ofh, ">", $output );
    }
    else {
        $ofh = *STDOUT;
    }

    # print the .bbl into it
    print $ofh do { local $/; <$fh> };

    # and close both
    close($ofh);
    close($fh);

    # and remove the file
    unlink("$jobname.bbl");

    return 0;
}

# helper function to print usage information and exit
sub usageAndExit {
    my ($code) = @_;
    print STDERR
'makebbl [--help] [--destination $DEST] [--cites $CITES] $BSTFILE [$BIBFILE [$BIBFILE ...]]'
    . "\n";
    return $code;
}

1;