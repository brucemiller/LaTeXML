# /=====================================================================\ #
# |  LaTeXML::BibTeX::Common::Object                                    | #
# | Common function for LaTeXML::BibTeX objects                         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::Common::Object;
use strict;
use warnings;

# gets the starting position of this object
# a five-tuple ($path, $startRow, $startColumn, $endRow, $endColumn)
# row-indexes are one-based, column-indexes zero-based
# the start position is inclusive, the end position is not
# never includes any whitespace in positioning
sub getLocator {
  my ($self) = @_;
  return $$self{locator}; }

1;
