# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Common::Utils                               | #
# | Generic Utility Functions                                           | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Common::Utils;
use strict;
use warnings;

use Encode;

use base qw(Exporter);
our @EXPORT = qw(
  &escapeString &startsWith
  &slurp &puts
  &normalizeString
);

# escapes a string so that it can be used as a perl literal
sub escapeString {
    my ($str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/'/\\'/g;
    return "'$str'";
}

# check if $haystack starts with $needle
sub startsWith {
    my ( $haystack, $needle ) = @_;
    return substr( $haystack, 0, length($needle) ) eq $needle;
}

# read an entire file into a string
sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "Can't open file $path: $!";
    my $file_content = do { local $/; binmode $fh; <$fh> };
    close($fh);
    $file_content =~ s/(?:\015\012|\015|\012)/\n/sg;
    return decode( 'utf-8', $file_content );
}

# write an entire file into a string
sub puts {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "Can't open file $path: $!";
    print $fh encode( 'utf-8', $content );
    close $fh;
}


# 'normalizeString' normalizes whitespace in string
sub normalizeString {
    my ($string) = @_;
    $string =~ s/^\s+|\s+$//g; # remove space on both sides
    $string =~ s/\s+/ /g; # concat multiple whitespace into one
    return $string;
}


1;
