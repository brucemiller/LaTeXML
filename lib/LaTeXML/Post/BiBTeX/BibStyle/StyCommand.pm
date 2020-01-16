# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::BibStyle::StyCommand                        | #
# | Representations for commands with source refs to a .bst file        | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::BibStyle::StyCommand;
use strict;
use warnings;

use base qw(LaTeXML::Post::BiBTeX::Common::Object);
use LaTeXML::Post::BiBTeX::Common::Utils;

sub new {
    my ( $class, $name, $arguments, $source ) = @_;
    return bless {
        name => $name || '',    # the name of the command (see getName)
        arguments =>
          $arguments,    # the arguments to the command (see getArguments)
        source => $source,  # the source position of the command (see getSource)
    }, $class;
}

# the name of the command. Should be a STYString of type Literal.
sub getName {
    my ($self) = @_;
    return $$self{name};
}

# the arguments of this command. Should be StyStrings of type LITERAL.
sub getArguments {
    my ($self) = @_;
    return $$self{arguments};
}

# turns this StyCommand into a string representing code to create this object
sub stringify {
    my ($self) = @_;
    my ($name) = $$self{name}->stringify;

    my @arguments = map { $_->stringify; } @{ $$self{arguments} };
    my $value = '[(' . join( ', ', @arguments ) . ')]';

    my $ss = $self->getSourceString;
    return 'StyCommand(' . $name . ', ' . $value . ", $ss)";
}

1;
