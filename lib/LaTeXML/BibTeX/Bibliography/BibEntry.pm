# /=====================================================================\ #
# |  LaTeXML::BibTeX::Bibliography::BibEntry                            | #
# | Representation for .bib file entries                                | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::Bibliography::BibEntry;
use strict;
use warnings;

use base qw(LaTeXML::BibTeX::Common::Object);

sub new {
  my ($class, $type, $fields, $locator) = @_;
  return bless {
    type    => $type,      # the type of entry we have (see getType)
    fields  => $fields,    # a list of fields in this BiBFile
    locator => $locator    # a locator reference
  }, $class; }

# the type of this entry
# a BibString of type 'LITERAL' (and hence lowercase)
sub getType {
  my ($self) = @_;
  return $$self{type}; }

# a list of BiBFields s contained in this entry
sub getFields {
  my ($self) = @_;
  return $$self{fields}; }

# evaluates this entry, i.e. normalizes the type
# and evaluates all fields
sub evaluate {
  my ($self, %context) = @_;
  # normalize the type
  $$self{type}->normalizeValue;
  # evaluate all fields
  my @fields = @{ $$self{fields} };
  foreach my $field (@fields) {
    $field->evaluate(%context); }
  return; }

sub stringify {
  my ($self)   = @_;
  my ($type)   = $self->getType->stringify;
  my @fields   = map { $_->stringify; } @{ $self->getFields };
  my $fieldStr = '[' . join(',', @fields) . ']';
  return 'BibEntry(' . $type . ', ' . $fieldStr . ")"; }

1;
