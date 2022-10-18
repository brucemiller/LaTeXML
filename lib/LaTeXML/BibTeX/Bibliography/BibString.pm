# /=====================================================================\ #
# |  LaTeXML::BibTeX::Bibliography::BibString                           | #
# | Representations for string tokens from a .bib file                  | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::Bibliography::BibString;
use strict;
use warnings;

use base qw(LaTeXML::BibTeX::Common::Object);

# 'new' creates a new instance of a BibString.
# BibString objects are assumed to be mutable.
sub new {
  my ($class, $kind, $value, $locator) = @_;
  return bless {
# 'kind' contains the kind of string this is.
# Should be one of:
# - ''          (unknown / other)
# - 'LITERAL'   (an unquoted literal from the source file)
# - 'BRACE'     (a braced string from the source file)
# - 'QUOTE'     (a quoted string from the source file)
# - 'ALTERED'   (any of the above that for which the value has been altered using e.g. a macro context or appending)
# This value is not used outside this class, but we retain it for uniformity with StyString.
    kind => $kind || '',

    # 'value' contains the value of this string. It is a normal string.
    value => $value,

    # 'locator' contains a locator reference to the source of this BibString.
    # See LaTeXML::BibTeX::Common::Object::getLocator for details.
    locator => $locator,
  }, $class; }

# 'copy' makes a copy of this BibString.
sub copy {
  my ($self) = @_;
  # we need to make a deep copy of source
##  my ($fn, $sr, $sc, $er, $ec) = @{ $$self{source} };
##  return new($$self{kind}, $$self{value}, [($fn, $sr, $sc, $er, $ec)]); }
  return new($$self{kind}, $$self{value}, $$self{locator}); }

sub getKind {
  my ($self) = @_;
  return $$self{kind}; }

# 'getValue' gets the value of this BiBString, a normal string
sub getValue {
  my ($self) = @_;
  return $$self{value}; }

# 'normalizeValue' normalizes the value of this BibString
sub normalizeValue {
  my ($self) = @_;
  $$self{value} = lc($$self{value});
  return; }

# 'append' appends the value of another BiBString to this one and updates locator references accordingly.
# Does not perform any type or adjacency checking.
sub append {
  my ($self, $other) = @_;
  # append the value to our own class
  $$self{kind} = 'ALTERED';
  $$self{value} .= $other->getValue;
  $$self{locator} = $$self{locator}->merge($other->getLocator);
  return; }

sub stringify {
  my ($self) = @_;
  return 'BibString(' . $$self{kind} . ', ' . $$self{value} . ")"; }

1;
