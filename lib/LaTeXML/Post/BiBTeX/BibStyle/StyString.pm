# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::BibStyle::StyString                         | #
# | Representations for strings with source refs to a .bst file         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::BibStyle::StyString;
use strict;
use warnings;

use base qw(LaTeXML::Post::BiBTeX::Common::Object);
use LaTeXML::Post::BiBTeX::Common::Utils;

sub new {
    my ( $class, $kind, $value, $source ) = @_;
    return bless {
        kind => $kind || '',    # the kind of string we have (see getKind)
        value  => $value,       # the value in this string (see getValue)
        source => $source,      # the source position (see getSource)
    }, $class;
}

# get the kind this StyString represents. One of:
#   ''            (other)
#   'NUMBER'      (a literal number)
#   'QUOTE'       (a literal string)
#   'LITERAL'     (any unquoted value)
#   'REFERENCE'   (a reference to a function or variable)
#   'BLOCK'       (a {} enclosed list of other StyStrings)
sub getKind {
    my ($self) = @_;
    return $$self{kind};
}

# get the value of this StyString
sub getValue {
    my ($self) = @_;
    return $$self{value};
}

# turns this StyCommand into a string representing code to create this object
sub stringify {
    my ($self) = @_;
    my ($kind) = $$self{kind};

    my $value;
    if ( $kind eq 'BLOCK' ) {
        my @content = map { $_->stringify; } @{ $$self{value} };
        $value = '[(' . join( ', ', @content ) . ')]';
    }
    elsif ( $kind eq 'NUMBER' ) {
        $value = $$self{value};
    }
    else {
        $value = escapeString( $$self{value} );
    }

    my $ss = $self->getSourceString;
    return 'StyString(' . escapeString($kind) . ', ' . $value . ", $ss)";
}

1;
