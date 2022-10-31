# /=====================================================================\ #
# |  LaTeXML::BibTeX::BibStyle::StyCommand                              | #
# | Representations for commands with source refs to a .bst file        | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::BibStyle::StyCommand;
use strict;
use warnings;

use base qw(LaTeXML::BibTeX::Common::Object);

sub new {
  my ($class, $name, $arguments, $locator) = @_;
  return bless {
    name      => $name || '',    # the name of the command (see getName)
    arguments => $arguments,     # the arguments to the command (see getArguments)
    locator   => $locator,       # the locator position of the command (see getLocator)
  }, $class; }

sub getKind {
  my ($self) = @_;
  return 'COMMAND ' . $$self{name}; }

# the name of the command. Should be a STYString of type Literal.
sub getName {
  my ($self) = @_;
  return $$self{name}; }

# the arguments of this command. Should be StyStrings of type LITERAL.
sub getArguments {
  my ($self) = @_;
  return @{ $$self{arguments} }; }

sub stringify {
  my ($self) = @_;
  return 'StyCommand(' . join(', ', $$self{name}, map { $_->stringify; } @{ $$self{arguments} }) . ")"; }

1;
