# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Bibliography                                | #
# | .bib file parsing & evaluation                                      | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Bibliography;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Bibliography::BibEntry;
use LaTeXML::Post::BiBTeX::Bibliography::BibField;
use LaTeXML::Post::BiBTeX::Bibliography::BibString;
use LaTeXML::Post::BiBTeX::Bibliography::BibParser;

use base qw(Exporter);
our @EXPORT = qw(
  &BibEntry &BibField &BibString
  &readFile &readEntry
  &readLiteral &readBrace &readQuote
);

sub BibEntry  { LaTeXML::Post::BiBTeX::Bibliography::BibEntry->new(@_); }
sub BibField    { LaTeXML::Post::BiBTeX::Bibliography::BibField->new(@_); }
sub BibString { LaTeXML::Post::BiBTeX::Bibliography::BibString->new(@_); }

1;
