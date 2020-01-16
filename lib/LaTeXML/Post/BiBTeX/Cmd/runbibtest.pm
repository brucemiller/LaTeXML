# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Cmd::runbibtest                             | #
# | runtest utility entry point                                         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Cmd::runbibtest;
use strict;
use warnings;

use Encode;
use Getopt::Long qw(GetOptionsFromArray);
use Module::Load;

sub main {

    # remove the first argument, and display help with a testname is missing
    shift(@_);
    return usageAndExit(1) if scalar(@_) ne 1;

    # declare a test 'manually'
    use LaTeXML::Post::BiBTeX::Common::Test;
    use Test::More tests => 1;
    integrationTest( "runtest", shift(@_), );

    # and return with code 0 by default
    return 0;
}

1;
