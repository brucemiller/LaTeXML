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
    my ( $class, $type, $tags, $source ) = @_;
    return bless {
        type   => $type,     # the type of entry we have (see getType)
        tags   => $tags,     # a list of tags in this BiBFile
        source => $source    # a source reference
    }, $class;
}

# the type of this entry
# a BibString of type 'LITERAL' (and hence lowercase)
sub getType {
    my ($self) = @_;
    return $$self{type};
}

# a list of BibTag s contained in this entry
sub getTags {
    my ($self) = @_;
    return $$self{tags};
}

# evaluates this entry, i.e. normalizes the type
# and evaluates all tags
sub evaluate {
    my ( $self, %context ) = @_;

    $$self{type}->normalizeValue;

    my @tags = @{ $$self{tags} };
    foreach my $tag (@tags) {
        $tag->evaluate(%context);
    }
}

# turns this BibEntry into a string representing code to create this object
sub stringify {
    my ($self) = @_;
    my ($type) = $self->getType->stringify;
    my @tags = map { $_->stringify; } @{ $self->getTags };
    my $tagStr = '[(' . join( ',', @tags ) . ')]';

    my $ss = $self->getSourceString;
    return 'BibTag(' . $type . ', ' . $tagStr . ", $ss)";
}

1;
