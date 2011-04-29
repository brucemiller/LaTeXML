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
  my $forcebold  = $options{forcebold} || 0;
  my $forceshape = $options{forceshape} || 0;
  $class->new_internal($family,$series,$shape,$size,$color,$forcebold,$forceshape); }

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
  my $forcebold  = $options{forcebold} || $$self[5];
  my $forceshape  = $options{forceshape} || $$self[6];
  # In math, setting any one of these, resets the others to default.
#  $family = $DEFFAMILY if $family && !$options{family} && ($options{series} || $options{shape});
#  $series = $DEFSERIES if $series && !$options{series} && ($options{family} || $options{shape});
#  $shape  = $DEFSHAPE  if $shape  && !$options{shape}  && ($options{family} || $options{series});
  $family = $DEFFAMILY if !$options{family} && ($options{series} || $options{shape});
  $series = $DEFSERIES if !$options{series} && ($options{family} || $options{shape});
  $shape  = $DEFSHAPE  if !$options{shape}  && ($options{family} || $options{series});
  (ref $self)->new_internal($family,$series,$shape,$size,$color,$forcebold,$forceshape); }

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
  my($family,$series,$shape,$size,$color,$forcebold,$forceshape)=@$self;
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

my $f=  (ref $self)->new_internal($family,$series,$shape,$size,$color,$forcebold,$forceshape); 
print STDERR " => ".ToString($f)."\n" if $LaTeXML::Font::DEBUG;
$f;
}

#**********************************************************************
package LaTeXML::Font::Encoding;
use strict;
use LaTeXML::Global;
#======================================================================
our %encodings;

sub lookupGlyph {
  my($encoding,$code)=@_;
  if(my $map = $encodings{lc($encoding)}){
    $$map[$code]; }
  else {
    undef; }}

#======================================================================
# See "LaTeX font encodings" by Frank Mittlebach, Robin Fairbairns & Werner Lemberg,
# last version seen Jan.6, 2006.

# Note that for accents, I'm using the spacing versions (whereever I can find them!)
sub UTF {
  my($code)=@_;
  pack('U',$code); }

# Use this to make a "spacing" accent out of a nonspacing one;
# by appending it to a non-breaking space !?!?!
sub ACC {
  UTF(0xA0).$_[0]; }
#======================================================================
# OT1 Original TeX Text font encoding
# NOTE: Isn't there now a dotless j?  What is that thing at 0x20 ?
our $OT1
  =[# \Gamma     \Delta      \Theta      \Lambda      \Xi         \Pi         \Sigma      \Upsilon
    "\x{0393}", "\x{0394}", "\x{0398}", "\x{039B}",  "\x{039E}", "\x{03A0}", "\x{03A3}", "\x{03A5}",
    # \Phi       \Psi        \Omega      lig. ff      lig.fi      lig. fl     lig. ffi    lig. ffl
    "\x{03A6}", "\x{03A8}", "\x{03A9}", "\x{FB00}",  "\x{FB01}", "\x{FB02}", "\x{FB03}", "\x{FB04}",
    # dotless i  dotless j   grave       acute        caron       breve       macron      ring
    "\x{0131}",  undef,      UTF(0x60),  UTF(0xB4),   "\x{}",     "\x{02D8}", UTF(0xAF),  "\x{02DA}",
    # cedilla    esset       ae          oe           oslash      AE          OE          Oslash
    UTF(0xB8),   UTF(0xDF),  UTF(0xE6), "\x{0153}",   UTF(0xF8),  UTF(0xC6), "\x{152}",   UTF(0xD8),
    # cross for \L  !           "           #             $           %          &           '
    undef,      '!',        "\x{201D}", '#',          '$',        '%',       '&',        "\x{2018}",
    # (          )           *           +             ,           -          .           /
    '(',        ')',        '*',        '+',          ',',        '-',       '.',        '/',
    # 0          1           2           3             4           5          6           7
    '0',        '1',        '2',        '3',          '4',        '5',       '6',        '7',
    # 8          9           :           ;             inv !       =          inv ?       ?
    '8',        '9',        ':',        ';',           UTF(0xA1), '=',        UTF(0xBF), '?',
    # @          A           B           C             D           E          F           G
    '@',        'A',        'B',        'C',          'D',        'E',       'F',        'G',
    # H          I           J           K             L           M          N           O
    'H',        'I',        'J',        'K',          'L',        'M',       'N',        'O',
    # P          Q           R           S             T           U          V           W
    'P',        'Q',        'R',        'S',          'T',        'U',       'V',        'W',
    # X          Y           Z           [             left "      ]          circumflex  dot acc
    'X',        'Y',        'Z',        '[',          "\x{201C}", ']',        UTF(0x5F), "\x{02D9}",
    # `          a           b           c             d           e          f           g
    "\x{2019}", 'a',        'b',        'c',          'd',        'e',       'f',        'g',
    # h          i           j           k             l           m          n           o
    'h',        'i',        'j',        'k',          'l',        'm',       'n',        'o',
    # p          q           r           s             t           u          v           w
    'p',        'q',        'r',        's',          't',        'u',       'v',        'w',
    # x          y           z           -             --          dbl.acute  tilde       diaeresis
    'x',        'y',        'z',        "\x{2013}",   "\x{2014}", "\x{02DD}", "\x{02DC}", UTF(0xA8) ];

#======================================================================
# OT2 TeX text for Cyrillic languages (obsolete)
our $OT2
  =[];
#======================================================================
# OT2 TeX phonetic alphabet encoding (obsolete)
our $OT3
  =[];
#======================================================================
# OT4 TeX text with extensions for the Polish language
# This is a sparse extension of OT1
our $OT4
  =[@$OT1,
    #           A ogonek    C acute                                          E ogonek
    undef,      "\x{0104}", "\x{0106}", undef,        undef,      undef,     "\x{0118}", undef,
    #                       Lost L      N acute
    undef,      undef,      "\x{0141}", "\x{0143}",   undef,      undef,     undef,      undef,
    #           S acute
    undef,      "\x{015A}", undef,      undef,        undef,      undef,     undef,      undef,
    #           Z acute                 Z dot
    undef,      "\x{0179}", undef,      "\x{017B}",   undef,      undef,     undef,      undef,
    #           a ogonek    c acute                                          e ogonek
    undef,      "\x{0105}", "\x{0107}", undef,        undef,      undef,     "\x{0119}", undef,
    #                       Lost l      n acute                              l.guil.     r.guil
    undef,      undef,      "\x{0142}", "\x{0144}",   undef,      undef,     UTF(0xAB),  UTF(0xBB),
    #           s acute
    undef,      "\x{015B}", undef,      undef,        undef,      undef,     undef,      undef,
    #           z acute                 z dot
    undef,      "\x{017A}", undef,      "\x{017C}",   undef,      undef,     undef,      undef,
    undef,      undef,      undef,      undef,        undef,      undef,     undef,      undef,
    undef,      undef,      undef,      undef,        undef,      undef,     undef,      undef,
    #                                   O acute
    undef,      undef,      undef,      UTF(0xD3),    undef,      undef,     undef,      undef,
    undef,      undef,      undef,      undef,        undef,      undef,     undef,      undef,
    undef,      undef,      undef,      undef,        undef,      undef,     undef,      undef,
    undef,      undef,      undef,      undef,        undef,      undef,     undef,      undef,
    #                                   o acute
    undef,      undef,      undef,      UTF(0xF3),    undef,      undef,     undef,      undef,
    #                                                                                    lower r "
    undef,      undef,      undef,      undef,        undef,      undef,     undef,      "\x{201E}"];

#======================================================================
# 0T6 TeX text with extensions for the Armenian language
our $OT6
  =[];
#======================================================================
# OML TeX math text (italic) as defined by Donald Knuth
# Is there a spacing inverted breve?
# lhook,rhook: is U+2E26,U+2E27 good enough... doubtful...
our $OML
  =[# \Gamma     \Delta      \Theta      \Lambda      \Xi         \Pi         \Sigma      \Upsilon
    "\x{0393}", "\x{0394}", "\x{0398}", "\x{039B}",  "\x{039E}", "\x{03A0}", "\x{03A3}", "\x{03A5}",
    # \Phi       \Psi        \Omega      alpha        beta        gamma       delta       epsilon
    "\x{03A6}", "\x{03A8}", "\x{03A9}", "\x{03B1}",  "\x{03B2}","\x{03B3}",  "\x{03B4}", "\x{03F5}",
    # zeta       eta         theta       iota         kappa      lambda       mu         nu
    "\x{03B6}", "\x{03B7}", "\x{03B8}", "\x{03B9}", "\x{03BA}", "\x{03BB}", "\x{03BC}", "\x{03BD}",
    # xi         pi          rho         sigma       tau         upsilon     phi         chi
    "\x{03BE}", "\x{03C0}", "\x{03C1}", "\x{03C3}", "\x{03C4}", "\x{03C5}", "\x{03D5}", "\x{03C7}",
    # psi        omega       varepsilon  vartheta    varpi       varrho      varsigma    varphi
    "\x{03C8}", "\x{03C9}", "\x{03B5}", "\x{03D1}", "\x{03D6}", "\x{03F1}", "\x{03C2}","\x{03C6}",
    # l.harp.up  l.harp.dn   r.harp.up   r.harp.dn   lhook       rhook       rt.tri     lf.tri
    "\x{21BC}", "\x{21BD}", "\x{21C0}", "\x{21C1}", "\x{2E26}", "\x{2E27}", "\x{25B7}", "\x{25C1}",
    # old style numerals! (no separate codepoints ?)
    # 0          1           2           3             4           5          6           7
    '0',        '1',        '2',        '3',          '4',        '5',       '6',        '7',
    # 8          9           .           ,             <           /          >           star
    '8',        '9',        '.',        ',',           UTF(0x3C), UTF(0x2F),  UTF(0x3E), "\x{22C6}",
    # partial    A           B           C             D           E          F           G
    "\x{2202}", 'A',        'B',        'C',          'D',        'E',       'F',        'G',
    # H          I           J           K             L           M          N           O
    'H',        'I',        'J',        'K',          'L',        'M',       'N',        'O',
    # P          Q           R           S             T           U          V           W
    'P',        'Q',        'R',        'S',          'T',        'U',       'V',        'W',
    # X          Y           Z           flat          natural     sharp      smile       frown
    'X',        'Y',        'Z',        "\x{266D}",   "\x{266E}", "\x{266F}","\x{2323}", "\x{2322}",
    # ell        a           b           c             d           e          f           g
    "\x{2113}", 'a',        'b',        'c',          'd',        'e',       'f',        'g',
    # h          i           j           k             l           m          n           o
    'h',        'i',        'j',        'k',          'l',        'm',       'n',        'o',
    # p          q           r           s             t           u          v           w
    'p',        'q',        'r',        's',          't',        'u',       'v',        'w',
    # x          y           z           dotless i    dotless j    weier-p    arrow acc.  inv.breve
    'x',        'y',        'z',        "\x{0131}",   "j",       "\x{2118}", ACC("\x{1DFE}"),ACC("\x{0311}") ];

#======================================================================
# OMS TeX math symbol as defined by Donald Knuth
our $OMS
  =[#minus       dot         times       ast          divide      diamond    plus-minus   minus-plus
    "-",        "\x{22C5}",  UTF(0xD7), "\x{2217}",   UTF(0xF7), "\x{22C4}", UTF(0xB1),  "\x{2213}",
    # oplus      ominus      otimes      oslash       odot        bigcirc     circ        bullet
    "\x{2295}", "\x{2296}", "\x{2297}", "\x{2298}",  "\x{2299}", "\x{25CB}", "\x{2218}", "\x{2219}",
    # asymp      equiv       subseteq    supseteq     leq         geq         preceq      succeq
    "\x{224D}", "\x{2261}", "\x{2286}", "\x{2287}",  "\x{2264}", "\x{2265}", "\x{2AAF}", "\x{2AB0}",
    # sim        approx      subset      supset       ll          gg          prec        succ
    "\x{223C}", "\x{2248}", "\x{2282}", "\x{2283}",  "\x{226A}", "\x{226B}", "\x{227A}", "\x{227B}",
    # leftarrow  rightarrow  uparrow     downarrow    leftrightar nearrow     searrow     simeq
    "\x{2190}", "\x{2192}", "\x{2191}", "\x{2193}",  "\x{2194}", "\x{2197}", "\x{2198}", "\x{2243}",
    # Leftarrow  Rightarrow  Uparrow     Downarrow    Leftrightar nwarrow     swarrow     propto
    "\x{21D0}", "\x{21D2}", "\x{21D1}", "\x{21D3}",  "\x{21D4}", "\x{2196}", "\x{2199}", "\x{221D}",
    # prime      infty       in          ni           bigtri.up   bigtri.dn   slash       mapsto
    "\x{2032}", "\x{221E}", "\x{2208}", "\x{220B}",  "\x{25B3}", "\x{25BD}", "/",         "\x{21A6}",
    # forall     exists      not         emptyset     Re          Im          top         bot
    "\x{2200}", "\x{2203}", UTF(0xAC),  "\x{2205}",  "\x{211C}", "\x{2111}", "\x{22A4}", "\x{22A5}",
    # aleph      cal A       cal B       cal C        cal D       cal E       cal F       cal G
    "\x{2135}", "\x{1D49C}","\x{212C}", "\x{1D49E}", "\x{1D49F}","\x{2130}", "\x{2131}", "\x{1D4A2}",
    # cal H      cal I       cal J       cal K        cal L       cal M       cal N       cal O
    "\x{210B}", "\x{2110}", "\x{1D4A5}","\x{1D4A6}", "\x{2112}", "\x{2133}", "\x{1D4A9}","\x{1D4AA}",
    # cal P      cal Q       cal R       cal S        cal T       cal U       cal V       cal W
    "\x{1D4AB}","\x{1D4AC}","\x{211B}", "\x{1D4AE}", "\x{1D4AF}","\x{1D4B0}","\x{1D4B1}","\x{1D4B2}",
    # cal X      cal Y       cal Z       cup          cap         uplus       wedge       vee
    "\x{1D4B3}","\x{1D4B4}","\x{1D4B5}","\x{222A}",  "\x{2229}", "\x{228C}", "\x{2227}", "\x{2228}",
    # vdash      dashv       lfloor      rfloor       lceil       rceil       lbrace      rbrace
    "\x{22A2}", "\x{22A3}", "\x{230A}", "\x{230B}",  "\x{2308}", "\x{2309}", "{",        "}",
    # langle     rangle       |          \|           updownarrow Updownarrow backslash   wr
    "\x{27E8}", "\x{27E9}", "|",        "\x{2225}",  "\x{2195}", "\x{21D5}",  UTF(0x5C), "\x{2240}",
    # surd       amalg       nabla       int          sqcup      sqcap        sqsubseteq sqsupseteq
    "\x{221A}", "\x{2210}", "\x{2207}", "\x{222B}",  "\x{2294}", "\x{2293}", "\x{2291}", "\x{2292}",
    # section    dagger      ddagger     para         clubsuit    diam.suit   heartsuit  spadesuit
    UTF(0xA7),  "\x{2020}", "\x{2021}",  UTF(0xB6),  "\x{2663}", "\x{2662}", "\x{2661}", "\x{2660}"];
#======================================================================
# OMX TeX math extended symbol as defined by Donald Knuth
# I'll punt on the Sizing issue for now.
# and the fragments as well...

#"\x{}", "\x{}", "\x{}", "\x{}",

our $OMX
  =[# (          )           [           ]             lfloor      rfloor      lceil        rceil
    "(",        ")",        "[",        "]",          "\x{230A}", "\x{230B}", "\x{2308}", "\x{2309}",
    #lbrace      rbrace      langle      rangle        |           ||          /           \
    "{",        "}",        "\x{27E8}", "\x{27E9}",   "|",        "\x{2225}", "/",        UTF(0x5C),
    "(",        ")",        "(",        ")",          "[",        "]",        "\x{230A}", "\x{230B}",
    "\x{2308}", "\x{2309}", "{",        "}",          "\x{27E8}", "\x{27E9}", "/",        UTF(0x5C),
    "(",        ")",        "[",        "]",          "\x{230A}", "\x{230B}", "\x{2308}", "\x{2309}",
    "{",        "}",        "\x{27E8}", "\x{27E9}",   "/",        UTF(0x5C),  "/",        UTF(0x5C),
    # next two rows are just fragments
    # l.up.paren r.up.paren  l.up.brak   r.up.brak    l.bot.brak  r.bot.brak  l.brak.ext  r.brak.ext
    "\x{239B}", "\x{239E}", "\x{23A1}", "\x{23A4}",  "\x{23A3}", "\x{23A6}", "\x{23A2}", "\x{23A5}",
    # l.up.brace r.up.brace  l.bot.brace r.bot.brace  l.brace.mid r.brace.mid brace.ext  v.arrow.ext
    "\x{23A7}", "\x{23AB}", "\x{23A9}", "\x{23AD}",  "\x{23A8}", "\x{23AC}", "\x{23AA}", "\x{23D0}",
    # l.bot.paren r.bot.paren l.paren.ext r.paren.ext 
    "\x{239D}", "\x{23A0}", "\x{239C}", "\x{239F}",   "\x{27E8}", "\x{27E9}", "\x{2294}", "\x{2294}",
    "\x{222E}", "\x{222E}", "\x{2299}", "\x{2299}",   "\x{2295}", "\x{2295}", "\x{2297}", "\x{2297}",
    "\x{2211}", "\x{220F}", "\x{222B}", "\x{22C3}",   "\x{22C2}", "\x{228C}", "\x{2227}", "\x{2228}",
    "\x{2211}", "\x{220F}", "\x{222B}", "\x{22C3}",   "\x{22C2}", "\x{228C}", "\x{2227}", "\x{2228}",
    "\x{2210}", "\x{2210}",  UTF(0x5E),  UTF(0x5E),  UTF(0x5E),   "\x{02DC}", "\x{02DC}", "\x{02DC}",
    "[",        "]",        "\x{230A}", "\x{230B}",   "\x{2308}", "\x{2309}", "{",        "}",
    #                                                              [missing rad frags]     double arrow ext.
    "\x{23B7}", "\x{23B7}", "\x{23B7}", "\x{23B7}",   "\x{23B7}",  undef,      undef,      undef,
    #                        [missing tips for horizontal curly braces]
    "\x{2191}", "\x{2193}",  undef,      undef,        undef,      undef,     "\x{21D1}", "\x{21D3}"];

#======================================================================
# X2 Extended text encoding (Cyrillic)
our $X2
  =[];

#======================================================================
# U Unknown encoding (for arbitrary rubbish)
# We really should subclass this for the actual font tables.
# Eg. the various ams math fonts!
our $U
  =[];

#======================================================================
# T1  LaTeX text encoding (Latin) aka Cork
our $T1
  =[];

#======================================================================
# TS1  LaTeX symbol encoding (Latin)
our $TS1
  =[];

#======================================================================
# T2A,T2B,T2C  LaTeX text encoding (Cyrillic)
our $T2A
  =[];
our $T2B
  =[];
our $T2C
  =[];
#======================================================================
# T3  LaTeX phonetic alphabet encoding
our $T3
  =[];
#======================================================================
# T4  LaTeX text encoding (African languages)
our $T4
  =[];
#======================================================================
# T5  LaTeX text encoding (Vietnamese)
our $T5
  =[];
#======================================================================
# T7  LaTeX text encoding (reserved fro Greek)
our $T7
  =[];

#     undef,       undef,      undef,      undef,        undef,      undef,     undef,      undef, 
#"\x{}", "\x{}", "\x{}", "\x{}",


%encodings = ( ot1=>$OT1, ot2=>$OT2, ot3=>$OT3, ot4=>$OT4, ot6=>$OT6,
	       oml=>$OML, oms=>$OMS, omx=>$OMX,
	       # Also store symbolic names as "encodings"
	       letters=>$OML, symbols=>$OMS, largesymbols=>$OMX,
	       # Also store the (apparent) family numbers
	       '0'=>$OT1, 1=>$OML, 2=>$OMS, 3=>$OMX
	     );

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
