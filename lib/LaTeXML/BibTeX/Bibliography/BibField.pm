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

# gets the content of this BibField, a string
sub getContent {
  my ($self) = @_;
  return $$self{content}; }

sub stringify {
  my ($self) = @_;
  return 'BibField(' . $$self{name} . ', ' . $$self{content} . ")"; }

1;
