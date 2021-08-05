# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Common::Object                              | #
# | Common function for LaTeXML::Post::BiBTeX objects                   | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Common::Object;
use strict;
use warnings;
use LaTeXML::Post::BiBTeX::Common::Utils;

# gets the starting position of this object
# a five-tuple ($path, $startRow, $startColumn, $endRow, $endColumn)
# row-indexes are one-based, column-indexes zero-based
# the start position is inclusive, the end position is not
# never includes any whitespace in positioning
sub getSource {
  my ($self) = @_;
  return $$self{source}; }

# same as getSource, but returns a string that can be evaluated
# to be a perl object
sub getSourceString {
  my ($self) = @_;
  my ($fn, $sr, $sc, $er, $ec) = @{ $self->getSource };
  # encode the filename as either 'undef' or the escaped string
  my $fns;
  if (defined($fn)) {
    $fns = escapeString($fn); }
  else {
    $fns = 'undef'; }
  return "[($fns, $sr, $sc, $er, $ec)]";
}

# checks if this object equals another object
sub equals {
  my ($self, $other) = @_;
  $other = ref $other ? $other->stringify : $other;
  return $self->stringify eq $other; }

1;
