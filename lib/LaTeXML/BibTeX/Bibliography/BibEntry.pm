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
  my ($class, $type, $key, $fields, $locator) = @_;
  return bless {
    type    => $type,      # the type of entry we have (see getType)
    key     => $key,       # THe identifing key
    fields  => $fields,    # a list of fields in this BiBFile
    locator => $locator    # a locator reference
  }, $class; }

# the type of this entry (lowercase string)
sub getType {
  my ($self) = @_;
  return $$self{type}; }

# Get the identifying key (string, case-sensitive)
sub getKey {
  my ($self) = @_;
  return $$self{key}; }

# a list of BiBFields s contained in this entry
sub getFields {
  my ($self) = @_;
  return @{ $$self{fields} }; }

sub stringify {
  my ($self) = @_;
  return 'BibEntry(' . $$self{type} . ', ' . $$self{key} . ', [' .
    join(',', map { $_->stringify; } $self->getFields) . "])"; }

1;
