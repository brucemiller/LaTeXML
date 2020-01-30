# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Bibliography::BibEntry                      | #
# | Representation for .bib file entries                                | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Bibliography::BibEntry;
use strict;
use warnings;

use base qw(LaTeXML::Post::BiBTeX::Common::Object);
use LaTeXML::Post::BiBTeX::Common::Utils;

sub new {
    my ( $class, $type, $fields, $source ) = @_;
    return bless {
        type   => $type,     # the type of entry we have (see getType)
        fields   => $fields,     # a list of fields in this BiBFile
        source => $source    # a source reference
    }, $class;
}

# the type of this entry
# a BibString of type 'LITERAL' (and hence lowercase)
sub getType {
    my ($self) = @_;
    return $$self{type};
}

# a list of BiBFields s contained in this entry
sub getFields {
    my ($self) = @_;
    return $$self{fields};
}

# evaluates this entry, i.e. normalizes the type
# and evaluates all fields
sub evaluate {
    my ( $self, %context ) = @_;

    $$self{type}->normalizeValue;

    my @fields = @{ $$self{fields} };
    foreach my $field (@fields) {
        $field->evaluate(%context);
    }
}

# turns this BibEntry into a string representing code to create this object
sub stringify {
    my ($self) = @_;
    my ($type) = $self->getType->stringify;
    my @fields = map { $_->stringify; } @{ $self->getFields };
    my $fieldStr = '[(' . join( ',', @fields ) . ')]';

    my $ss = $self->getSourceString;
    return 'BibEntry(' . $type . ', ' . $fieldStr . ", $ss)";
}

1;
