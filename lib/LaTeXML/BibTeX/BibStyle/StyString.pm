# /=====================================================================\ #
# |  LaTeXML::BibTeX::BibStyle::StyString                               | #
# | Representations for strings with source refs to a .bst file         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::BibStyle::StyString;
use strict;
use warnings;

use base qw(LaTeXML::BibTeX::Common::Object);

sub new {
  my ($class, $kind, $value, $locator) = @_;
  return bless {
    kind    => $kind || '',    # the kind of string we have (see getKind)
    value   => $value,         # the value in this string (see getValue)
    locator => $locator,       # the locator position (see getLocator)
  }, $class; }

# get the kind this StyString represents. One of:
#   ''            (other)
#   'NUMBER'      (a literal number)
#   'QUOTE'       (a literal string)
#   'LITERAL'     (any unquoted value)
#   'REFERENCE'   (a reference to a function or variable)
#   'BLOCK'       (a {} enclosed list of other StyStrings)
sub getKind {
  my ($self) = @_;
  return $$self{kind}; }

# get the value of this StyString
sub getValue {
  my ($self) = @_;
  return $$self{value}; }

sub stringify {
  my ($self) = @_;
  my ($kind) = $$self{kind};
  my $value;
  if ($kind eq 'BLOCK') {
    my @content = map { $_->stringify; } @{ $$self{value} };
    $value = '[' . join(', ', @content) . ']'; }
  elsif ($kind eq 'NUMBER') {
    $value = $$self{value}; }
  else {
    $value = $$self{value}; }
  return 'StyString(' . $kind . ', ' . $value . ")"; }

1;
