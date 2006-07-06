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
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

our $DEFFAMILY = 'serif';
our $DEFSERIES = 'medium';
our $DEFSHAPE  = 'upright';
our $DEFSIZE   = 'normal';
our $DEFCOLOR  = 'black';

# NOTE:  Would it make sense to allow compnents to be `inherit' ??

sub new {
  my($class,%options)=@_;
  my $family = $options{family} || $DEFFAMILY;
  my $series = $options{series} || $DEFSERIES;
  my $shape  = $options{shape}  || $DEFSHAPE;
  my $size   = $options{size}   || $DEFSIZE;
  my $color  = $options{color}  || $DEFCOLOR;
  $class->new_internal($family,$series,$shape,$size,$color); }

sub new_internal {
  my($class,@components)=@_;
  bless [@components],$class; }

# Accessors
sub getFamily { $_[0]->[0]; }
sub getSeries { $_[0]->[1]; }
sub getShape  { $_[0]->[2]; }
sub getSize   { $_[0]->[3]; }
sub getColor  { $_[0]->[4]; }

sub untex { "Font[".join(',',@{$_[0]})."]"; }
sub stringify { "Font[".join(',',@{$_[0]})."]"; }

sub equals {
  my($self,$other)=@_;
  join('|',@$self) eq   join('|',@$other); }

sub merge {
  my($self,%options)=@_;
  my $family = $options{family} || $$self[0];
  my $series = $options{series} || $$self[1];
  my $shape  = $options{shape}  || $$self[2];
  my $size   = $options{size}   || $$self[3];
  my $color  = $options{color}  || $$self[4];
  (ref $self)->new_internal($family,$series,$shape,$size,$color); }

# Return a string representing the font relative to other.
sub relativeTo {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor)=@$other;
  $family = 'serif' if $family eq 'math';
  $ofamily = 'serif' if $ofamily eq 'math';
  my @diffs = grep($_, 
		($family ne $ofamily ? $family : ''),
		($series ne $oseries ? $series : ''),
		($shape  ne $oshape  ? $shape : ''),
		($size   ne $osize   ? $size : ''),
		($color  ne $ocolor  ? $color : ''));
  join(' ',@diffs); }

sub distance {
  my($self,$other)=@_;
  my($family,$series,$shape,$size,$color)=@$self;  
  my($ofamily,$oseries,$oshape,$osize,$ocolor)=@$other;
  $family = 'serif' if $family eq 'math';
  $ofamily = 'serif' if $ofamily eq 'math';
  ($family ne $ofamily ? 1 : 0)
    +($series ne $oseries ? 1 : 0)
      +($shape  ne $oshape  ? 1 : 0)
	+($size   ne $osize   ? 1 : 0)
	  +($color  ne $ocolor  ? 1 : 0); }

#**********************************************************************
package LaTeXML::MathFont;
use strict;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Font);

our $DEFFAMILY = 'serif';
our $DEFSERIES = 'medium';
our $DEFSHAPE  = 'upright';
our $DEFSIZE   = 'normal';
our $DEFCOLOR  = 'black';

sub new { 
  my($class,%options)=@_;
  my $family = $options{family} || 'math';
  my $series = $options{series} || $DEFSERIES;
  my $shape  = $options{shape}  || $DEFSHAPE;
  my $size   = $options{size}   || $DEFSIZE;
  my $color  = $options{color}  || $DEFCOLOR;
  my $force  = $options{forcebold} || 0;
  $class->new_internal($family,$series,$shape,$size,$color,$force); }

sub isSticky {
  $_[0]->[0] =~ /^(serif|sansserif|typewriter)$/; }

sub merge {
  my($self,%options)=@_;
  my $family = $options{family} || $$self[0];
  my $series = $options{series} || $$self[1];
  my $shape  = $options{shape}  || $$self[2];
  my $size   = $options{size}   || $$self[3];
  my $color  = $options{color}  || $$self[4];
  my $force  = $options{forcebold} || $$self[5];
  # In math, setting any one of these, resets the others to default.
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
sub specialize {
  my($self,$mathclass)=@_;
  my($family,$series,$shape,$size,$color,$forcebold)=@$self;
  $series = 'bold' if $forcebold;
  if($mathclass eq 'letter'){}
  elsif($mathclass eq 'number'){
    if($family eq 'math'){ $family=$DEFFAMILY; $shape=$DEFSHAPE; }}
  elsif($mathclass eq 'ucgreek'){
    if($family eq 'math'){ $family=$DEFFAMILY; $shape=$DEFSHAPE; }}
  elsif($mathclass eq 'lcgreek'){
    $family=$DEFFAMILY; $shape='italic';  # always ?
    $series=($forcebold ? 'bold' : $DEFSERIES); }
  elsif($mathclass eq 'symbol'){
    $family=$DEFFAMILY; $shape=$DEFSHAPE; # defaults, always.
    $series=($forcebold ? 'bold' : $DEFSERIES); }
  (ref $self)->new_internal($family,$series,$shape,$size,$color,$forcebold); }


#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Font and LaTeXML::MathFont

=head2 SYNOPSIS

use LaTeXML::Font;

=head2 DESCRIPTION

This module defines Font objects.
I'm not completely happy with the arrangement, or
maybe just the use of it.

=cut
