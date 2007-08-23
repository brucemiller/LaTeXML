# /=====================================================================\ #
# |  LaTeXML::Font                                                      | #
# | Representaion of Fonts                                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Font;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

our $DEFFAMILY = 'serif';
our $DEFSERIES = 'medium';
our $DEFSHAPE  = 'upright';
our $DEFSIZE   = 'normal';
our $DEFCOLOR  = 'black';

# NOTE:  Would it make sense to allow compnents to be `inherit' ??

sub new {
  my($class,%options)=@_;
  my $family = $options{family};
  my $series = $options{series};
  my $shape  = $options{shape};
  my $size   = $options{size};
  my $color  = $options{color};
  $class->new_internal($family,$series,$shape,$size,$color); }

sub new_internal {
  my($class,@components)=@_;
  bless [@components],$class; }

sub default { $_[0]->new_internal($DEFFAMILY, $DEFSERIES, $DEFSHAPE,$DEFSIZE, $DEFCOLOR); }

# Accessors
sub getFamily { $_[0]->[0]; }
sub getSeries { $_[0]->[1]; }
sub getShape  { $_[0]->[2]; }
sub getSize   { $_[0]->[3]; }
sub getColor  { $_[0]->[4]; }

sub toString { "Font[".join(',',map($_ || '*', @{$_[0]}))."]"; }
sub stringify{ $_[0]->toString; }

sub equals {
  my($self,$other)=@_;
  (defined $other) && ((ref $self) eq (ref $other)) && (join('|',map($_||'*',@$self)) eq join('|',map($_||'*',@$other))); }

sub match {
  my($self,$other)=@_;
  return 1 unless defined $other;
  return 0 unless (ref $self) eq (ref $other);
  my @comp  = @$self;
  my @ocomp = @$other;
  # If any components are defined in both fonts, they must be equal.
  while(@comp){
    my $c  = shift @comp;
    my $oc = shift @ocomp;
    return 0 if $c && $oc && ($c ne $oc); }
  return 1; }

sub makeConcrete {
  my($self,$concrete)=@_;
  my($family,$series,$shape,$size,$color)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor)=@$concrete;
  (ref $self)->new_internal($family||$ofamily,$series||$oseries,$shape||$oshape,$size||$osize,$color||$ocolor); }

sub merge {
  my($self,%options)=@_;
  my $family = $options{family} || $$self[0];
  my $series = $options{series} || $$self[1];
  my $shape  = $options{shape}  || $$self[2];
  my $size   = $options{size}   || $$self[3];
  my $color  = $options{color}  || $$self[4];
  (ref $self)->new_internal($family,$series,$shape,$size,$color); }

# Really only applies to Math Fonts, but that should be handled elsewhere; We punt here.
sub specialize {
  my($self,$string)=@_;
  $self; }

# Return a string representing the font relative to other.
sub XXrelativeTo {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor)=@$other;
  $family  = 'serif' if $family  && ($family eq 'math');
  $ofamily = 'serif' if $ofamily && ($ofamily eq 'math');
  my @diffs = grep($_, 
		   ($family && (!$ofamily || ($family ne $ofamily)) ? $family : ''),
		   ($series && (!$oseries || ($series ne $oseries)) ? $series : ''),
		   ($shape  && (!$oshape  || ($shape  ne $oshape))  ? $shape : ''),
		   ($size   && (!$osize   || ($size   ne $osize))   ? $size : ''),
		   ($color  && (!$ocolor  || ($color  ne $ocolor))  ? $color : ''));
  join(' ',@diffs); }

# Return a hash of the differences in font, size and color
sub relativeTo {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor)=@$other;
  $family  = 'serif' if $family  && ($family eq 'math');
  $ofamily = 'serif' if $ofamily && ($ofamily eq 'math');
  my @diffs=(($family && (!$ofamily || ($family ne $ofamily)) ? $family : ''),
	     ($series && (!$oseries || ($series ne $oseries)) ? $series : ''),
	     ($shape  && (!$oshape  || ($shape  ne $oshape))  ? $shape : ''));
  my $fdiff=join(' ',grep($_, @diffs)); 
  my $sdiff=($size   && (!$osize   || ($size   ne $osize))   ? $size : '');
  my $cdiff=($color  && (!$ocolor  || ($color  ne $ocolor))  ? $color : '');
  ( ($fdiff ? (font=>$fdiff):()),
    ($sdiff ? (size=>$sdiff):()),
    ($cdiff ? (color=>$cdiff):()) ); }

sub distance {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor)=@$other;
  $family  = 'serif' if $family  && ($family eq 'math');
  $ofamily = 'serif' if $ofamily && ($ofamily eq 'math');
  ($family && (!$ofamily || ($family ne $ofamily)) ? 1 : 0)
    + ($series && (!$oseries || ($series ne $oseries)) ? 1 : 0)
      + ($shape  && (!$oshape  || ($shape  ne $oshape))  ? 1 : 0)
	+ ($size   && (!$osize   || ($size   ne $osize))   ? 1 : 0)
	  + ($color  && (!$ocolor  || ($color  ne $ocolor))  ? 1 : 0); }

# This matches fonts when both are converted to strings (toString),
# such as when they are set as attributes.
sub XXmatch_font {
  my($font1,$font2)=@_;
#print STDERR "Match font \"".($font1 || 'none')."\" to \"".($font2||'none')."\"\n";
return 1;

  return 0 unless $font1 && $font2;
  $font1 =~ /^Font\[(.*)\]$/;
  my @comp1  = split(',',$1);
  $font2 =~ /^Font\[(.*)\]$/;
  my @comp2  = split(',',$1);
  while(@comp1){
    my $c1 = shift @comp1;
    my $c2 = shift @comp2;
    return 0 if ($c1 ne '*') && ($c2 ne '*') && ($c1 ne $c2); }
  return 1; }


our %FONT_REGEXP_CACHE=();

sub match_font {
  my($font1,$font2)=@_;
  my $regexp = $FONT_REGEXP_CACHE{$font1};
  if(!$regexp){
    $font1 =~ /^Font\[(.*)\]$/;
    my @comp  = split(',',$1);
    my $re= '^Font\['
      . join(',', map( ($_ eq '*' ? "[^,]+" : "\Q$_\E"), @comp))
	.'\]$';
    print STDERR "\nCreating re for \"$font1\" => $re\n";
    $regexp = $FONT_REGEXP_CACHE{$font1} = qr/$re/; }
  $font2 =~ /$regexp/; }


sub font_match_xpaths {
  my($font)=@_;
  $font =~ /^Font\[(.*)\]$/;
  my @comps  = split(',',$1);
  my($frag,@frags) = ();
  for(my $i=0; $i<=$#comps; $i++){
    my $comp = $comps[$i];
    if($comp eq '*'){
      push(@frags,$frag) if $frag;
      $frag = undef; }
    else {
      my $post = ($i == $#comps ? ']' : ',');
      if($frag){
	$frag .= $comp . $post; }
      else {
	$frag = ($i==0 ? 'Font[' : ',') . $comp . $post; }}}
  push(@frags,$frag) if $frag;
  join(' and ','@_font',
       map("contains(\@_font,'$_')",@frags)); }

#**********************************************************************
package LaTeXML::MathFont;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Font);

our $DEFFAMILY = 'serif';
our $DEFSERIES = 'medium';
our $DEFSHAPE  = 'upright';
our $DEFSIZE   = 'normal';
our $DEFCOLOR  = 'black';

sub new { 
  my($class,%options)=@_;
#  my $family = $options{family} || 'math';
  my $family = $options{family};
  my $series = $options{series};
  my $shape  = $options{shape};
  my $size   = $options{size};
  my $color  = $options{color};
  my $force  = $options{forcebold} || 0;
  $class->new_internal($family,$series,$shape,$size,$color,$force); }

sub default { $_[0]->new_internal('math', $DEFSERIES, 'italic',$DEFSIZE, $DEFCOLOR,0); }

sub isSticky {
  $_[0]->[0] && ($_[0]->[0] =~ /^(serif|sansserif|typewriter)$/); }

sub merge {
  my($self,%options)=@_;
  my $family = $options{family} || $$self[0];
  my $series = $options{series} || $$self[1];
  my $shape  = $options{shape}  || $$self[2];
  my $size   = $options{size}   || $$self[3];
  my $color  = $options{color}  || $$self[4];
  my $force  = $options{forcebold} || $$self[5];
  # In math, setting any one of these, resets the others to default.
#  $family = $DEFFAMILY if $family && !$options{family} && ($options{series} || $options{shape});
#  $series = $DEFSERIES if $series && !$options{series} && ($options{family} || $options{shape});
#  $shape  = $DEFSHAPE  if $shape  && !$options{shape}  && ($options{family} || $options{series});
  $family = $DEFFAMILY if !$options{family} && ($options{series} || $options{shape});
  $series = $DEFSERIES if !$options{series} && ($options{family} || $options{shape});
  $shape  = $DEFSHAPE  if !$options{shape}  && ($options{family} || $options{series});
  (ref $self)->new_internal($family,$series,$shape,$size,$color,$force); }

# Instanciate the font for a particular class of symbols.
# NOTE: This works in `normal' latex, but probably needs some tunability.
# Depending on the fonts being used, the allowable combinations may be different.
# Getting the font right is important, since the author probably
# thinks of the identity of the symbols according to what they SEE in the printed
# document.  Even though the markup might seem to indicate something else...

# Use Unicode properties to determine font merging.
sub specialize {
  my($self,$string)=@_;
  my($family,$series,$shape,$size,$color,$forcebold)=@$self;
print STDERR "Specialized font ".ToString($self)." for $string " if $LaTeXML::Font::DEBUG;

  $series = 'bold' if $forcebold;
  if(($string =~ /^\p{Latin}$/) && ($string =~ /^\p{L}$/)){	# Latin Letter
    print STDERR "Letter"  if $LaTeXML::Font::DEBUG;
    $shape  = 'italic' if !$shape && !$family; }
  elsif($string =~ /^\p{Greek}$/){	# Single Greek character?
    if($string =~ /^\p{Lu}$/){	# Uppercase
print STDERR "Greek Upper"  if $LaTeXML::Font::DEBUG;
      if(!$family || ($family eq 'math')){
	$family=$DEFFAMILY; 	
	$shape=$DEFSHAPE if $shape && ($shape ne $DEFSHAPE); }}
    else {			# Lowercase
print STDERR "Greek Lower"  if $LaTeXML::Font::DEBUG;
      $family=$DEFFAMILY if !$family || ($family ne $DEFFAMILY);
      $shape='italic';  # always ?
      if($forcebold){ $series = 'bold';}
      elsif($series && ($series ne $DEFSERIES)){ $series = $DEFSERIES; }}}
  elsif($string =~ /^\p{N}$/){	# Digit
print STDERR "Digit"  if $LaTeXML::Font::DEBUG;
    if(!$family || ($family eq 'math')){
      $family = $DEFFAMILY;
      $shape  = $DEFSHAPE if !$shape || ($shape ne $DEFSHAPE); }}
  else {			# Other Symbol
print STDERR "Symbol" if $LaTeXML::Font::DEBUG;
    $family=$DEFFAMILY; $shape=$DEFSHAPE; # defaults, always.
    if($forcebold){ $series = 'bold';}
    elsif($series && ($series ne $DEFSERIES)){ $series = $DEFSERIES; }}

my $f=  (ref $self)->new_internal($family,$series,$shape,$size,$color,$forcebold); 
print STDERR " => ".ToString($f)."\n" if $LaTeXML::Font::DEBUG;
$f;
}


#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Font> - representation of fonts,
along with the specialization C<LaTeXML::MathFont>.

=head1 DESCRIPTION

This module defines Font objects.
I'm not completely happy with the arrangement, or
maybe just the use of it, so I'm not going to document extensively at this point.

C<LaTeXML::Font> and C<LaTeXML::MathFont> represent fonts 
(the latter, fonts in math-mode, obviously) in LaTeXML. 

The attributes are

 family : serif, sansserif, typewriter, caligraphic,
          fraktur, script
 series : medium, bold
 shape  : upright, italic, slanted, smallcaps
 size   : tiny, footnote, small, normal, large,
          Large, LARGE, huge, Huge
 color  : any named color, default is black

They are usually merged against the current font, attempting to mimic the,
sometimes counter-intuitive, way that TeX does it,  particularly for math

Additionally, C<LaTeXML::MathFont> supports C<$font->specialize($string);> for
computing a font reflecting how the specific C<$string> would be printed when
C<$font> is active; This (attempts to) handle the curious ways that lower case
greek often doesn't get a different font.  In particular, it recognizes the
following classes of strings: single latin letter, single uppercase greek character,
single lowercase greek character, digits, and others.


=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
