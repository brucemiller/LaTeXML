# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Bibliography::BibString                     | #
# | Representations for string tokens from a .bib file                  | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Bibliography::BibString;
use strict;
use warnings;

use base qw(LaTeXML::Post::BiBTeX::Common::Object);
use LaTeXML::Post::BiBTeX::Common::Utils;

# 'new' creates a new instance of a BibString.
# BibString objects are assumed to be mutable.
sub new {
    my ( $class, $kind, $value, $source ) = @_;
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

        # 'source' contains a source reference to the source of this BibString.
        # See LaTeXML::Post::BiBTeX::Common::Object::getSource for details.
        source => $source,
    }, $class;
}

# 'copy' makes a copy of this BibString.
sub copy {
    my ($self) = @_;

    # we need to make a deep copy of source
    my ( $fn, $sr, $sc, $er, $ec ) = @{ $$self{source} };
    return new( $$self{kind}, $$self{value}, [ ( $fn, $sr, $sc, $er, $ec ) ] );
}

# 'getValue' gets the value of this BiBString, a normal string
sub getValue {
    my ($self) = @_;
    return $$self{value};
}

# 'normalizeValue' normalizes the value of this BibString
sub normalizeValue {
    my ($self) = @_;
    $$self{value} = lc( $$self{value} );
}

# 'evaluate' evaluates this BibString in a given context and returns a boolean indicating if evaluation was succesfull.
# Context means BiBTeX macros defined either inside a .bst file or inside a @string{} entries.
# A context is represented as a simple hash from strings to strings or BibStrings.
sub evaluate {
    my ( $self, %context ) = @_;

    # only literals are evaluated
    return 1 unless $$self{kind} eq 'LITERAL';

    # if lookup fails, we can't evaluate
    my $value = $context{ lc( $$self{value} ) };
    return 0 unless defined($value);

    # update with the actual value and set the new type
    $$self{kind} = 'ALTERED';
    $$self{value} = ref $value ? $value->getValue : $value;

    return 1;
}

# 'append' appends the value of another BiBString to this one and updates source references accordingly.
# Does not perform any type or adjacency checking.
sub append {
    my ( $self, $other ) = @_;

    # append the value to our own class
    $$self{kind} = 'ALTERED';
    $$self{value} .= $other->getValue;

    # create a new source refence spanning the appropriate range
    my ( $fn, $sr, $sc ) = @{ $$self{source} };
    my ( $a, $b, $c, $er, $ec ) = @{ $other->getSource };

    $$self{source} = [ ( $fn, $sr, $sc, $er, $ec ) ];
}

# 'stringify' returns a string representing perl code used to create this object.
sub stringify {
    my ($self) = @_;

    my $ss = $self->getSourceString;
    return
        'BibString('
      . escapeString( $$self{kind} ) . ', '
      . escapeString( $$self{value} )
      . ", $ss)";
}

1;
