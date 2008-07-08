# /=====================================================================\ #
# |  LaTeXML::Util::Color                                               | #
# | Helpful routines for color conversion                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::Color;
use strict;
use LaTeXML::Global;
use LaTeXML::Util::Transform;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT= (qw(&ConvertColor &RGB &Gray2RGB &HSB2RGB &CMYK2RGB));

sub round { int($_[0]+0.5*($_[0] <=> 0)); }

sub ConvertColor {
    my ($model, $spec) = @_; my $color = 0;
    if    ($model =~ /gray/) { $color = '#'.Gray2RGB($spec); }
    elsif ($model =~ /rgb/)  { $color = '#'.RGB($spec); }
    elsif ($model =~ /cmyk/) { $color = '#'.CMYK2RGB($spec); }
    elsif ($model =~ /hsb/)  { $color = '#'.HSB2RGB($spec); }
    elsif ($model =~ /named/){ $color = $spec; }
    else { Warn(":unexpected:$model Unknown color model: $model"); }
    $color; }

sub RGB { my ($_r, $_g, $_b) = map(round($_*255), _ValueList($_[0]));
	  _RGB($_r, $_g, $_b); }

sub Gray2RGB { my $n = round($_[0]*255); _RGB($n, $n, $n); }

# adapted from http://www.ficml.org/jemimap/style/color/hsvwheel.phps
sub HSB2RGB {
    my ($h, $s, $b) = _ValueList($_[0]); my ($_r, $_g, $_b);
    $h = $h*360; $s = $s*100; $b = $b*100;
    my $max = round($b*51/20);
    my $min = round($max*(1 - $s/100));
    if ($min == $max) { ($_r,$_g,$_b) = ($max, $max, $max); }
    else {
	my $d = $max - $min; my $h6 = $h/60;
	if ($h6 <= 1)    { ($_r,$_g,$_b) = ($max, round($min + $h6*$d), $min); }
	elsif ($h6 <= 2) { ($_r,$_g,$_b) = (round($min - ($h6 - 2)*$d), $max, $min); }
	elsif ($h6 <= 3) { ($_r,$_g,$_b) = ($min, $max, round($min + ($h6 - 2)*$d)); }
	elsif ($h6 <= 4) { ($_r,$_g,$_b) = ($min, round($min - ($h6 - 4)*$d), $max); }
	elsif ($h6 <= 5) { ($_r,$_g,$_b) = (round($min + ($h6 - 4)*$d), $min, $max); }
	else             { ($_r,$_g,$_b) = ($max, $min, round($min - ($h6 - 6)*$d)); }}
    _RGB($_r, $_g, $_b); }

# http://en.wikipedia.org/wiki/CMYK#Converting_CMYK_to_RGB
sub CMYK2RGB {
    my ($c, $m, $y, $k) = _ValueList($_[0]);
    my ($_r, $_g, $_b) = map(round((1-$_*(1-$k)-$k)*255), ($c, $m, $y));
    _RGB($_r, $_g, $_b); }


# given R, G, B, compute the RGB value
sub _RGB { toHex((($_[0] << 16) + ($_[1] << 8) + $_[2]), 6); }


# explode a string into the float values it is made of
# separator can be ' ' or ','
sub _ValueList { 
    my $L = $_[0]; 
    return unless $L;
    $L =~ s/^\s+//; $L =~ s/\s+$//; $L =~ s/\s+/ /g; $L =~ s/\s*,\s*/,/g;
    if ($L =~ / /) { split(/ /,$L); }
    else { split(/,/,$L); }}

# toHex(number, digits); 
# if number is to small, it will be padded with '0'es
sub toHex {
    my @N = qw(0 1 2 3 4 5 6 7 8 9 A B C D E F);
    local *makeHex = sub { $_[0]<16?$N[$_[0]]:makeHex(int($_[0]/16)).makeHex($_[0]%16); };
    my $h = makeHex($_[0]);  my $t = ($_[1]?$_[1]:0)-length($h); $t = 0 if $t<0;
    ('0'x$t).$h; }



1;
