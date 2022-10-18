# /=====================================================================\ #
# |  LaTeXML::BibTeX::Bibliography::BibField                            | #
# | Representation for tags inside .bib entries                         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::Bibliography::BibField;
use strict;
use warnings;

###use List::Util qw(reduce);

use base qw(LaTeXML::BibTeX::Common::Object);

sub new {
  my ($class, $name, $content, $locator) = @_;
  return bless {
    name    => $name,       # name of this tag
    content => $content,    # content of this tag (see getContent)
    locator => $locator,    # the locator position (see getLocator)
  }, $class; }

# the name of this field (lowercase string)
sub getName {
  my ($self) = @_;
  return $$self{name}; }

# gets the content of this BibField,
# NOTE: this is either an ARRAY of values or a single value!!!
sub getContent {
  my ($self) = @_;
  return $$self{content}; }

sub stringify {
  my ($self) = @_;
  # get the content of this field
  my $content = $self->getContent;
  if (ref $content eq 'ARRAY') {
    my @scontent = map { $_->stringify; } @{ $self->getContent };
    $content = '[' . join(', ', @scontent) . ']'; }
  else {
    $content = $content->stringify; }
  return 'BibField(' . $$self{name} . ', ' . $content . ")";
}

1;
