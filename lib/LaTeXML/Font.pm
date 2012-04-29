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

our $DEFFAMILY     = 'serif';
our $DEFSERIES     = 'medium';
our $DEFSHAPE      = 'upright';
our $DEFSIZE       = 'normal';
our $DEFCOLOR      = 'black';
our $DEFBACKGROUND = 'white';
our $DEFOPACITY    = '1';
our $DEFENCODING   = 'OT1';

# NOTE:  Would it make sense to allow compnents to be `inherit' ??

sub new {
  my($class,%options)=@_;
  my $family = $options{family};
  my $series = $options{series};
  my $shape  = $options{shape};
  my $size   = $options{size};
  my $color  = $options{color};
  my $bg     = $options{background};
  my $opacity= $options{opacity};
  my $encoding= $options{encoding};
  $class->new_internal($family,$series,$shape,$size,$color,$bg,$opacity,$encoding); }

sub new_internal {
  my($class,@components)=@_;
  bless [@components],$class; }

sub default { $_[0]->new_internal($DEFFAMILY, $DEFSERIES, $DEFSHAPE,$DEFSIZE,
				  $DEFCOLOR,$DEFBACKGROUND,$DEFOPACITY,
				  $DEFENCODING); }
# Accessors
sub getFamily      { $_[0]->[0]; }
sub getSeries      { $_[0]->[1]; }
sub getShape       { $_[0]->[2]; }
sub getSize        { $_[0]->[3]; }
sub getColor       { $_[0]->[4]; }
sub getBackground  { $_[0]->[5]; }
sub getOpacity     { $_[0]->[6]; }
sub getEncoding    { $_[0]->[7]; }

sub toString { "Font[".join(',',map( (defined $_ ? $_ : '*'), @{$_[0]}))."]"; }
sub stringify{ $_[0]->toString; }

sub equals {
  my($self,$other)=@_;
  (defined $other) && ((ref $self) eq (ref $other))
    && (join('|',map( (defined $_ ? $_ : '*'),@$self))
	eq join('|',map((defined $_ ? $_ : '*'),@$other))); }

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
    return 0 if (defined $c) && (defined $oc) && ($c ne $oc); }
  return 1; }

sub makeConcrete {
  my($self,$concrete)=@_;
  my($family,$series,$shape,$size,$color,$bg,$opacity,$encoding)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor,$obg,$oopacity,$oencoding)=@$concrete;
  (ref $self)->new_internal($family||$ofamily,$series||$oseries,$shape||$oshape,$size||$osize,
			    $color||$ocolor,$bg||$obg, (defined $opacity ? $opacity : $oopacity),
			    $encoding||$oencoding); }

sub merge {
  my($self,%options)=@_;
  my $family  = (defined $options{family}     ? $options{family}     : $$self[0]);
  my $series  = (defined $options{series}     ? $options{series}     : $$self[1]);
  my $shape   = (defined $options{shape}      ? $options{shape}      : $$self[2]);
  my $size    = (defined $options{size}       ? $options{size}       : $$self[3]);
  my $color   = (defined $options{color}      ? $options{color}      : $$self[4]);
  my $bg      = (defined $options{background} ? $options{background} : $$self[5]);
  my $opacity = (defined $options{opacity}    ? $options{opacity}    : $$self[6]);
  my $encoding= (defined $options{encoding}   ? $options{encoding}   : $$self[7]);
  (ref $self)->new_internal($family,$series,$shape,$size,$color,$bg,$opacity,$encoding); }

# Really only applies to Math Fonts, but that should be handled elsewhere; We punt here.
sub specialize {
  my($self,$string)=@_;
  $self; }

# Return a hash of the differences in font, size and color
# [does encoding play a role here?]
# Note that this returns a hash of Fontable.attributes & Colorable.attributes,
# NOT the font keywords!!!
sub relativeTo {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color,$bg,$opacity,$encoding)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor,$obg,$oopacity,$oencoding)=@$other;
  $family  = 'serif' if $family  && ($family eq 'math');
  $ofamily = 'serif' if $ofamily && ($ofamily eq 'math');
  my @diffs=((defined $family && (!defined $ofamily || ($family ne $ofamily)) ? $family : undef),
	     (defined $series && (!defined $oseries || ($series ne $oseries)) ? $series : undef),
	     (defined $shape  && (!defined $oshape  || ($shape  ne $oshape))  ? $shape  : undef));
  @diffs = grep(defined $_, @diffs);
  my $fdiff=(@diffs ? join(' ',@diffs) : undef);
  my $sdiff=(defined $size   && (!defined $osize   || ($size   ne $osize))     ? $size : undef);
  my $cdiff=(defined $color  && (!defined $ocolor  || ($color  ne $ocolor))    ? $color : undef);
  my $bdiff=(defined $bg     && (!defined $obg     || ($bg  ne $obg))          ? $bg : undef);
  my $odiff=(defined $opacity&& (!defined $oopacity|| ($opacity ne $oopacity)) ? $opacity : undef);
##  my $ediff=($encoding && (!$oencoding || ($encoding ne $oencoding)) ? $encoding : '');
  ( (defined $fdiff ? (font=>$fdiff):()),
    (defined $sdiff ? (fontsize=>$sdiff):()),
    (defined $cdiff ? (color=>$cdiff):()),
    (defined $bdiff ? (backgroundcolor=>$bdiff):()),
    (defined $odiff ? (opacity=>$odiff):()),
##    ($ediff ? (encoding=>$ediff):()),
  ); }

sub distance {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color,$bg,$opacity,$encoding)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor,$obg,$oopacity,$oencoding)=@$other;
  $family  = 'serif' if $family  && ($family eq 'math');
  $ofamily = 'serif' if $ofamily && ($ofamily eq 'math');
  (    defined $family  && (!defined $ofamily  || ($family  ne $ofamily))  ? 1 : 0)
    + (defined $series  && (!defined $oseries  || ($series  ne $oseries))  ? 1 : 0)
    + (defined $shape   && (!defined $oshape   || ($shape   ne $oshape))   ? 1 : 0)
    + (defined $size    && (!defined $osize    || ($size    ne $osize))    ? 1 : 0)
    + (defined $color   && (!defined $ocolor   || ($color   ne $ocolor))   ? 1 : 0)
    + (defined $bg      && (!defined $obg      || ($bg      ne $obg))      ? 1 : 0)
    + (defined $opacity && (!defined $oopacity || ($opacity ne $oopacity)) ? 1 : 0)
##	    + ($encoding  && (!$oencoding  || ($encoding  ne $oencoding))  ? 1 : 0)
; }

# This matches fonts when both are converted to strings (toString),
# such as when they are set as attributes.
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

our $DEFFAMILY     = 'serif';
our $DEFSERIES     = 'medium';
our $DEFSHAPE      = 'upright';
our $DEFSIZE       = 'normal';
our $DEFCOLOR      = 'black';
our $DEFBACKGROUND = 'white';
our $DEFOPACITY    = '1';

sub new { 
  my($class,%options)=@_;
  my $family     = $options{family};
  my $series     = $options{series};
  my $shape      = $options{shape};
  my $size       = $options{size};
  my $color      = $options{color};
  my $bg         = $options{background};
  my $opacity    = $options{opacity};
  my $encoding   = $options{encoding};
##  my $forcebold  = $options{forcebold} || 0;
##  my $forceshape = $options{forceshape} || 0;
  my $forcebold  = $options{forcebold};
  my $forceshape = $options{forceshape};
  $class->new_internal($family,$series,$shape,$size,
		       $color,$bg,$opacity,
		       $encoding,$forcebold,$forceshape); }

sub default { $_[0]->new_internal('math', $DEFSERIES, 'italic',$DEFSIZE,
				  $DEFCOLOR,$DEFBACKGROUND,$DEFOPACITY,
##				  undef,0,undef); }
				  undef,undef,undef); }

sub isSticky {
  $_[0]->[0] && ($_[0]->[0] =~ /^(serif|sansserif|typewriter)$/); }

sub merge {
  my($self,%options)=@_;
  my $family     = (defined $options{family}     ? $options{family}     : $$self[0]);
  my $series     = (defined $options{series}     ? $options{series}     : $$self[1]);
  my $shape      = (defined $options{shape}      ? $options{shape}      : $$self[2]);
  my $size       = (defined $options{size}       ? $options{size}       : $$self[3]);
  my $color      = (defined $options{color}      ? $options{color}      : $$self[4]);
  my $bg         = (defined $options{background} ? $options{background} : $$self[5]);
  my $opacity    = (defined $options{opacity}    ? $options{opacity}    : $$self[6]);
  my $encoding   = (defined $options{encoding}   ? $options{encoding}   : $$self[7]);
  my $forcebold  = (defined $options{forcebold}  ? $options{forcebold}  : $$self[8]);
  my $forceshape = (defined $options{forceshape} ? $options{forceshape} : $$self[9]);
  # In math, setting any one of these, resets the others to default.
  $family = $DEFFAMILY if !$options{family} && ($options{series} || $options{shape});
  $series = $DEFSERIES if !$options{series} && ($options{family} || $options{shape});
  $shape  = $DEFSHAPE  if !$options{shape}  && ($options{family} || $options{series});
  (ref $self)->new_internal($family,$series,$shape,$size,
			    $color,$bg,$opacity,
			    $encoding,$forcebold,$forceshape); }

# Instanciate the font for a particular class of symbols.
# NOTE: This works in `normal' latex, but probably needs some tunability.
# Depending on the fonts being used, the allowable combinations may be different.
# Getting the font right is important, since the author probably
# thinks of the identity of the symbols according to what they SEE in the printed
# document.  Even though the markup might seem to indicate something else...

# Use Unicode properties to determine font merging.
sub specialize {
  my($self,$string)=@_;
  return $self unless defined $string;
  my($family,$series,$shape,$size,$color,$bg,$opacity,$encoding,$forcebold,$forceshape)=@$self;
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
      $shape='italic' if !$shape || !$forceshape;  # always ?
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

  (ref $self)->new_internal($family,$series,$shape,$size,
			    $color,$bg,$opacity,
			    $encoding,$forcebold,$forceshape); }

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

=head2 C<LaTeXML::MathFont>

=begin latex

\label{LaTeXML::MathFont}

=end latex

C<LaTeXML::MathFont> supports C<$font->specialize($string);> for
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
