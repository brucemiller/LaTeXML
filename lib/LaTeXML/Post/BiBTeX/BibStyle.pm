# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::BibStyle                                    | #
# | .bst file parsing                                                   | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::BibStyle;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::BibStyle::StyCommand;
use LaTeXML::Post::BiBTeX::BibStyle::StyString;
use LaTeXML::Post::BiBTeX::BibStyle::StyParser;

use base qw(Exporter);
our @EXPORT = qw(
  &StyCommand &StyString
  &readFile &readCommand
  &readAny &readBlock
  &readNumber &readReference &readLiteral &readQuote
);

sub StyCommand { LaTeXML::Post::BiBTeX::BibStyle::StyCommand->new(@_); }
sub StyString  { LaTeXML::Post::BiBTeX::BibStyle::StyString->new(@_); }

1;
