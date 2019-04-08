# /=====================================================================\ #
# |  LaTeXML::Common::Font                                              | #
# | Representaion of Fonts                                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Font;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Core::Token;
use LaTeXML::Common::Error;
use LaTeXML::Common::Object;
use LaTeXML::Common::Dimension;
use List::Util qw(min max sum);
use base qw(LaTeXML::Common::Object);

# Note that this has evolved way beynond just "font",
# but covers text properties (or even display properties) in general
# including basic font information, color & background color
# as well as encoding and language information.

# NOTE: This is now in Common that it may evolve to be useful in Post processing...

my $DEFFAMILY     = 'serif';      # [CONSTANT]
my $DEFSERIES     = 'medium';     # [CONSTANT]
my $DEFSHAPE      = 'upright';    # [CONSTANT]
my $DEFCOLOR      = 'black';      # [CONSTANT]
my $DEFBACKGROUND = 'white';      # [CONSTANT]
my $DEFOPACITY    = '1';          # [CONSTANT]
my $DEFENCODING   = 'OT1';        # [CONSTANT]
my $DEFLANGUAGE   = undef;

sub DEFSIZE { return $STATE->lookupValue('NOMINAL_FONT_SIZE') || 10; }

my $FLAG_FORCE_FAMILY = 0x1;
my $FLAG_FORCE_SERIES = 0x2;
my $FLAG_FORCE_SHAPE  = 0x4;
my $FLAG_EMPH         = 0x10;
#======================================================================
# Mappings from various forms of names or component names in TeX
# Given a font, we'd like to map it to the "logical" names derived from LaTeX,
# (w/ loss of fine grained control).
# I'd like to use Karl Berry's font naming scheme
# (See http://www.tug.org/fontname/html/)
# but it seems to be a one-way mapping, and moreover, doesn't even fit CM fonts!
# We'll assume a sloppier version:
#   family + series + variant + size
# NOTE: This probably doesn't really belong in here...

my %font_family = (
  cmr  => { family => 'serif' },      cmss  => { family => 'sansserif' },
  cmtt => { family => 'typewriter' }, cmvtt => { family => 'typewriter' },
  cmti => { family => 'typewriter', shape => 'italic' },
  cmfib => { family => 'serif' },      cmfr  => { family => 'serif' },
  cmdh  => { family => 'serif' },      cm    => { family => 'serif' },
  ptm   => { family => 'serif' },      ppl   => { family => 'serif' },
  pnc   => { family => 'serif' },      pbk   => { family => 'serif' },
  phv   => { family => 'sansserif' },  pag   => { family => 'serif' },
  pcr   => { family => 'typewriter' }, pzc   => { family => 'script' },
  put   => { family => 'serif' },      bch   => { family => 'serif' },
  psy   => { family => 'symbol' },     pzd   => { family => 'dingbats' },
  ccr   => { family => 'serif' },      ccy   => { family => 'symbol' },
  cmbr  => { family => 'sansserif' },  cmtl  => { family => 'typewriter' },
  cmbrs => { family => 'symbol' },     ul9   => { family => 'typewriter' },
  txr   => { family => 'serif' },      txss  => { family => 'sansserif' },
  txtt  => { family => 'typewriter' }, txms  => { family => 'symbol' },
  txsya => { family => 'symbol' },     txsyb => { family => 'symbol' },
  pxr   => { family => 'serif' },      pxms  => { family => 'symbol' },
  pxsya => { family => 'symbol' },     pxsyb => { family => 'symbol' },
  futs  => { family => 'serif' },
  uaq   => { family => 'serif' },      ugq   => { family => 'sansserif' },
  eur   => { family => 'serif' },      eus   => { family => 'script' },
  euf   => { family => 'fraktur' },    euex  => { family => 'symbol' },
  # The following are actually math fonts.
  ms    => { family => 'symbol' },
  ccm   => { family => 'serif', shape => 'italic' },
  cmm   => { family => 'italic', encoding => 'OML' },
  cmex  => { family => 'symbol', encoding => 'OMX' },       # Not really symbol, but...
  cmsy  => { family => 'symbol', encoding => 'OMS' },
  ccitt => { family => 'typewriter', shape => 'italic' },
  cmbrm => { family => 'sansserif', shape => 'italic' },
  futm  => { family => 'serif', shape => 'italic' },
  futmi => { family => 'serif', shape => 'italic' },
  txmi  => { family => 'serif', shape => 'italic' },
  pxmi  => { family => 'serif', shape => 'italic' },
  bbm   => { family => 'blackboard' },
  bbold => { family => 'blackboard' },
  bbmss => { family => 'blackboard' },
  # some ams fonts
  cmmib => { family => 'italic', series   => 'bold' },
  cmbsy => { family => 'symbol', series   => 'bold' },
  msa   => { family => 'symbol', encoding => 'AMSa' },
  msb   => { family => 'symbol', encoding => 'AMSb' },
  # Are these really the same?
  msx => { family => 'symbol', encoding => 'AMSa' },
  msy => { family => 'symbol', encoding => 'AMSb' },
);

# Maps the "series code" to an abstract font series name
my %font_series = (
  '' => { series => 'medium' }, m   => { series => 'medium' }, mc => { series => 'medium' },
  b  => { series => 'bold' },   bc  => { series => 'bold' },   bx => { series => 'bold' },
  sb => { series => 'bold' },   sbc => { series => 'bold' },   bm => { series => 'bold' });

# Maps the "shape code" to an abstract font shape name.
my %font_shape = ('' => { shape => 'upright' }, n => { shape => 'upright' }, i => { shape => 'italic' }, it => { shape => 'italic' },
  sl => { shape => 'slanted' }, sc => { shape => 'smallcaps' }, csc => { shape => 'smallcaps' });

# These could be exported...
sub lookupFontFamily {
  my ($familycode) = @_;
  return $font_family{ ToString($familycode) }; }

sub lookupFontSeries {
  my ($seriescode) = @_;
  return $font_series{ ToString($seriescode) }; }

sub lookupFontShape {
  my ($shapecode) = @_;
  return $font_shape{ ToString($shapecode) }; }

# Symbolic font sizes, relative to the NOMINAL_FONT_SIZE (often 10)
# extended logical font sizes, based on nominal document size of 10pts
# Possibly should simply use absolute font point sizes, as declared in class...
my %font_size = (
  tiny   => 0.5, SMALL => 0.7, Small => 0.8,  small => 0.9,
  normal => 1.0, large => 1.2, Large => 1.44, LARGE => 1.728,
  huge => 2.074, Huge => 2.488,
  big => 1.2, Big => 1.6, bigg => 2.1, Bigg => 2.6,
);

sub rationalizeFontSize {
  my ($size) = @_;
  return unless defined $size;
  if (my $symbolic = $font_size{$size}) {
    return $symbolic * DEFSIZE(); }
  return $size; }

# convert to percent
sub relativeFontSize {
  my ($newsize, $oldsize) = @_;
  return int(0.5 + 100 * $newsize / $oldsize) . '%'; }

my $FONTREGEXP
  = '(' . join('|', sort { -($a cmp $b) } keys %font_family) . ')'
  . '(' . join('|', sort { -($a cmp $b) } keys %font_series) . ')'
  . '(' . join('|', sort { -($a cmp $b) } keys %font_shape) . ')'
  . '(\d*)';

sub decodeFontname {
  my ($name, $at, $scaled) = @_;
  if ($name =~ /^$FONTREGEXP$/o) {
    my %props;
    my ($fam, $ser, $shp, $size) = ($1, $2, $3, $4);
    if (my $ffam = lookupFontFamily($fam)) { map { $props{$_} = $$ffam{$_} } keys %$ffam; }
    if (my $fser = lookupFontSeries($ser)) { map { $props{$_} = $$fser{$_} } keys %$fser; }
    if (my $fsh  = lookupFontShape($shp))  { map { $props{$_} = $$fsh{$_} } keys %$fsh; }
    $size = 1 unless $size;    # Yes, also if 0, "" (from regexp)
    $size = $at if defined $at;
    $size *= $scaled if defined $scaled;
    $props{size} = $size;
    # Experimental Hack !?!?!?
    $props{encoding} = 'OT1' unless defined $props{encoding};
    return %props; }
  else {
    return; } }

sub lookupTeXFont {
  my ($fontname, $seriescode, $shapecode) = @_;
  my %props;
  if (my $ffam = lookupFontFamily($fontname)) {
    map { $props{$_} = $$ffam{$_} } keys %$ffam; }
  if (my $fser = lookupFontSeries($seriescode)) {
    map { $props{$_} = $$fser{$_} } keys %$fser; }
  if (my $fsh = lookupFontShape($shapecode)) {
    map { $props{$_} = $$fsh{$_} } keys %$fsh; }
  return %props; }

#======================================================================
# NOTE:  Would it make sense to allow compnents to be `inherit' ??

# Note: forcefamily, forceseries, forceshape (& forcebold for compatibility)
# are only useful for fonts in math; See the specialize method below.
sub new {
  my ($class, %options) = @_;
  my $family    = $options{family};
  my $series    = $options{series};
  my $shape     = $options{shape};
  my $size      = $options{size};
  my $color     = $options{color};
  my $bg        = $options{background};
  my $opacity   = $options{opacity};
  my $encoding  = $options{encoding};
  my $language  = $options{language};
  my $mathstyle = $options{mathstyle};
  if ($options{forcebold}) {    # for compatibility
    $series = 'bold'; $options{forceseries} = 1; }
  my $flags = 0
    | ($options{forcefamily} ? $FLAG_FORCE_FAMILY : 0)
    | ($options{forceseries} ? $FLAG_FORCE_SERIES : 0)
    | ($options{forceshape}  ? $FLAG_FORCE_SHAPE  : 0);
  return $class->new_internal(
    $family, $series, $shape, rationalizeFontSize($size),
    $color, $bg, $opacity,
    $encoding,  $language,
    $mathstyle, $flags); }

sub new_internal {
  my ($class, @components) = @_;
  return bless [@components], $class; }

sub textDefault {
  my ($self) = @_;
  return $self->new_internal($DEFFAMILY, $DEFSERIES, $DEFSHAPE, DEFSIZE(),
    $DEFCOLOR, $DEFBACKGROUND, $DEFOPACITY, $DEFENCODING, $DEFLANGUAGE, undef, 0); }

sub mathDefault {
  my ($self) = @_;
  return $self->new_internal('math', $DEFSERIES, 'italic', DEFSIZE(),
    $DEFCOLOR, $DEFBACKGROUND, $DEFOPACITY, undef, $DEFLANGUAGE, 'text', 0); }

# Accessors
# Using an array here is getting ridiculous!
sub getFamily     { my ($self) = @_; return $$self[0]; }
sub getSeries     { my ($self) = @_; return $$self[1]; }
sub getShape      { my ($self) = @_; return $$self[2]; }
sub getSize       { my ($self) = @_; return $$self[3]; }
sub getColor      { my ($self) = @_; return $$self[4]; }
sub getBackground { my ($self) = @_; return $$self[5]; }
sub getOpacity    { my ($self) = @_; return $$self[6]; }
sub getEncoding   { my ($self) = @_; return $$self[7]; }
sub getLanguage   { my ($self) = @_; return $$self[8]; }
sub getMathstyle  { my ($self) = @_; return $$self[9]; }
sub getFlags      { my ($self) = @_; return $$self[10]; }

sub toString {
  my ($self) = @_;
  return "Font[" . join(',', map { (defined $_ ? ToString($_) : '*') } @{$self}) . "]"; }

# Perhaps it is more useful to list only the non-default components?
sub stringify {
  my ($self) = @_;
  my ($fam, $ser, $shp, $siz, $col, $bkg, $opa, $enc, $lang, $mstyle, $flags) = @$self;
  $fam = 'serif' if $fam && ($fam eq 'math');
  return 'Font[' . join(',', map { Stringify($_) } grep { $_ }
      (isDiff($fam, $DEFFAMILY) ? ($fam) : ()),
    (isDiff($ser, $DEFSERIES)     ? ($ser) : ()),
    (isDiff($shp, $DEFSHAPE)      ? ($shp) : ()),
    (isDiff($siz, DEFSIZE())      ? ($siz) : ()),
    (isDiff($col, $DEFCOLOR)      ? ($col) : ()),
    (isDiff($bkg, $DEFBACKGROUND) ? ($bkg) : ()),
    (isDiff($opa, $DEFOPACITY)    ? ($opa) : ()),
    ($mstyle ? ($mstyle) : ()),
    ($flags  ? ($flags)  : ()),
    )
    . ']'; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other) && ((ref $self) eq (ref $other))
    && (join('|', map { (defined $_ ? $_ : '*') } @$self)
    eq join('|', map { (defined $_ ? $_ : '*') } @$other)); }

sub match {
  my ($self, $other) = @_;
  return 1 unless defined $other;
  return 0 unless (ref $self) eq (ref $other);
  my @comp  = @$self;
  my @ocomp = @$other;
  # If any components are defined in both fonts, they must be equal.
  while (@comp) {
    my $c  = shift @comp;
    my $oc = shift @ocomp;
    return 0 if (defined $c) && (defined $oc) && ($c ne $oc); }
  return 1; }

sub makeConcrete {
  my ($self, $concrete) = @_;
  my ($family, $series, $shape, $size, $color, $bg, $opacity, $encoding, $lang, $mstyle, $flags) = @$self;
  my ($ofamily, $oseries, $oshape, $osize, $ocolor, $obg, $oopacity, $oencoding, $olang, $omstyle, $oflags) = @$concrete;
  return (ref $self)->new_internal(
    $family || $ofamily, $series || $oseries, $shape || $oshape, $size || $osize,
    $color || $ocolor, $bg || $obg, (defined $opacity ? $opacity : $oopacity),
    $encoding || $oencoding, $lang || $olang, $mstyle || $omstyle,
    ($flags || 0) | ($oflags || 0)); }

sub isDiff {
  my ($x, $y) = @_;
  return (defined $x) && (!(defined $y) || ($x ne $y)); }

# This method compares 2 fonts, returning the differences between them.
# Noting that the font-related attributes in the schema distill the
# font properties into fewer attributes (font,fontsize,color,background,opacity),
# the return value encodes both the attribute changes that would be needed to effect
# the font change, along with the font properties that differed
# Namely, the result is a hash keyed on the attribute name and whose value is a hash
#    value      => "new_attribute_value"
#    properties => { %fontproperties }
# Note in particular 2 interesting keys
#   element: can specify the element tagname to use for wrapping instead of ltx:text
#   class: can be used to add a class attribute to the wrapping element
sub relativeTo {
  my ($self, $other) = @_;
  my ($fam,  $ser,  $shp,  $siz,  $col,  $bkg,  $opa,  $enc,  $lang,  $mstyle,  $flags)  = @$self;
  my ($ofam, $oser, $oshp, $osiz, $ocol, $obkg, $oopa, $oenc, $olang, $omstyle, $oflags) = @$other;
  $fam  = 'serif' if $fam  && ($fam eq 'math');
  $ofam = 'serif' if $ofam && ($ofam eq 'math');
##  my $emph = 0;
##  $emph ||= $shp && $shp =~ s/^emph-//;
## ##  $emph ||= $oshp && $oshp =~ s/^emph-//;
##   $oshp && $oshp =~ s/^emph-//;
  my @diffs = (
    (isDiff($fam, $ofam) ? ($fam) : ()),
    (isDiff($ser, $oser) ? ($ser) : ()),
    (isDiff($shp, $oshp) ? ($shp) : ()));
  return (
    (@diffs ?
        (font => { value => join(' ', @diffs),
          properties => { (isDiff($fam, $ofam) ? (family => $fam) : ()),
            (isDiff($ser, $oser) ? (series => $ser) : ()),
            (isDiff($shp, $oshp) ? (shape  => $shp) : ()) } })
      : ()),
    (isDiff($siz, $osiz)
###      ? (fontsize => { value => $siz, properties => { size => $siz } })
      ? (fontsize => { value => relativeFontSize($siz, $osiz), properties => { size => $siz } })
      : ()),
    (isDiff($col, $ocol)
      ? (color => { value => $col, properties => { color => $col } })
      : ()),
    (isDiff($bkg, $obkg)
      ? (backgroundcolor => { value => $bkg, properties => { background => $bkg } })
      : ()),
    (isDiff($opa, $oopa)
      ? (opacity => { value => $opa, properties => { opacity => $opa } })
      : ()),
    (isDiff($lang, $olang)
      ? ('xml:lang' => { value => $lang, properties => { language => $lang } })
      : ()),
    (!$mstyle && $flags && ($flags & $FLAG_EMPH) && (!$oflags || !($oflags & $FLAG_EMPH))
      ? (
        #         class => { value => 'ltx_emph' },
        element => { value => 'ltx:emph' }
        )
      : ()),
    ### Contemplate this: We do NOT want mathstyle showing up (automatically) in the attributes
    ### So, we presumably want to ignore differences in mathstyle
    ### They shouldn't (by themselves) affect the display?
###    (isDiff($mstyle, $omstyle)
###      ? ('mathstyle' => { value => $mstyle, properties => { mathstyle => $mstyle } })
###      : ()),
  ); }

sub distance {
  my ($self, $other) = @_;
  my ($fam,  $ser,  $shp,  $siz,  $col,  $bkg,  $opa,  $enc,  $lang,  $mstyle,  $flags)  = @$self;
  my ($ofam, $oser, $oshp, $osiz, $ocol, $obkg, $oopa, $oenc, $olang, $omstyle, $oflags) = @$other;
  $fam  = 'serif' if $fam  && ($fam eq 'math');
  $ofam = 'serif' if $ofam && ($ofam eq 'math');
  return
    (isDiff($fam, $ofam) ? 1 : 0)
    + (isDiff($ser, $oser) ? 1 : 0)
    + (isDiff($shp, $oshp) ? 1 : 0)
    + (isDiff($siz, $osiz) ? 1 : 0)
    + (isDiff($col, $ocol) ? 1 : 0)
    + (isDiff($bkg, $obkg) ? 1 : 0)
    + (isDiff($opa, $oopa) ? 1 : 0)
##  + (isDiff($enc,$oenc)  ? 1 : 0)
    + (isDiff($lang, $olang) ? 1 : 0)
    # Let's not consider mathstyle differences here, either.
###    + (isDiff($mstyle, $omstyle) ? 1 : 0)
    + (($flags & $FLAG_EMPH) ^ ($oflags & $FLAG_EMPH) ? 1 : 0)
    ; }

# This matches fonts when both are converted to strings (toString),
# such as when they are set as attributes.
# This accumulates regular expressions used by match_font
# (which, in turn, is used in various XPath searches!)
# It is NOT really Daemon safe....
# Need to work out how to do this and/or cache it in STATE????
our %FONT_REGEXP_CACHE = ();

sub match_font {
  my ($font1, $font2) = @_;
  my $regexp = $FONT_REGEXP_CACHE{$font1};
  if (!$regexp) {
    if ($font1 =~ /^Font\[(.*)\]$/) {
      my @comp = split(',', $1);
      my $re = '^Font\['
        . join(',', map { ($_ eq '*' ? "[^,]+" : "\Q$_\E") } @comp)
        . '\]$';
      print STDERR "\nCreating re for \"$font1\" => $re\n";
      $regexp = $FONT_REGEXP_CACHE{$font1} = qr/$re/; } }
  return $font2 =~ /$regexp/; }

sub XXXfont_match_xpaths {
  my ($font) = @_;
  if ($font =~ /^Font\[(.*)\]$/) {
    my @comps = split(',', $1);
    my ($frag, @frags) = ();
    for (my $i = 0 ; $i <= $#comps ; $i++) {
      my $comp = $comps[$i];
      if ($comp eq '*') {
        push(@frags, $frag) if $frag;
        $frag = undef; }
      else {
        my $post = ($i == $#comps ? ']' : ',');
        if ($frag) {
          $frag .= $comp . $post; }
        else {
          $frag = ($i == 0 ? 'Font[' : ',') . $comp . $post; } } }
    push(@frags, $frag) if $frag;
    return join(' and ', '@_font',
      map { "contains(\@_font,'$_')" } @frags); } }

sub font_match_xpaths {
  my ($font) = @_;
  if ($font =~ /^Font\[(.*)\]$/) {
    my ($family, $series, $shape, $size, $color, $bg, $opacity, $encoding, $language,
      $mstyle, $force) = split(',', $1);
    # Ignore differences in:
    #    size, background, opacity, encoding, language(?), mathstyle,
    # force bits assumed NOT relevant, also.
    # For now, ignore color, too
    my @frags = ();
    push(@frags, '[' . $family . ',') if ($family ne '*');
    push(@frags, ',' . $series . ',') if ($series ne '*');
    push(@frags, ',' . $shape . ',')  if ($shape ne '*');
    #    push(@frags, ',' . $color . ',')  if ($color ne '*');
    return join(' and ', '@_font',
      map { "contains(\@_font,'$_')" } @frags); } }

# # Presumably a text font is "sticky", if used in math?
# sub isSticky { return 1; }

#======================================================================
our %mathstylesize = (display => 1, text => 1,
  script => 0.7, scriptscript => 0.5);

# NOTE: that we assume the size has already been adjusted for mathstyle, if necessary.
sub computeStringSize {
  my ($self, $string) = @_;
  my $size = ($self->getSize || DEFSIZE() || 10); ## * $mathstylesize{ $self->getMathstyle || 'text' };
  my $l = (defined $string ? length($string) : 0);
  my $u = $size * 65535;
  return (Dimension(0.75 * $u * $l), Dimension(0.7 * $u), Dimension(0.2 * $u)); }

# Get nominal width, height base ?
sub getNominalSize {
  my ($self) = @_;
  my $size = ($self->getSize || DEFSIZE() || 10); ## * $mathstylesize{ $self->getMathstyle || 'text' };
  my $u = $size * 65535;
  return (Dimension(0.75 * $u), Dimension(0.7 * $u), Dimension(0.2 * $u)); }

# Here's where I avoid trying to emulate Knuth's line-breaking...
# Mostly for List & Whatsit: compute the size of a list of boxes.
# Options _SHOULD_ include:
#   width:  if given, pretend to simulate line breaking to that width
#   height,depth : ?
#   vattach : top, bottom, center, baseline (...?) affects how the height & depth are
#      allocated when there are multiple lines.
#   layout : horizontal or vertical !!!
# Boxes that arent a Core Box, List, Whatsit or a string are IGNORED
#
# The big problem with width is to have it propogate down from where
# it may have been specified to the actual nested box that will get wrapped!
# Try to mask this (temporarily) by unlisting, and (pretending to ) breaking up too wide items
#
# Another issue; SVG needs (sometimes) real sizes, even if the programmer
# set some dimensions to 0 (eg.)   We may need to distinguish & store
# requested vs real sizes?
sub computeBoxesSize {
  my ($self, $boxes, %options) = @_;
  my $font = (ref $self ? $self : $STATE->lookupValue('font'));
  my $fillwidth = $options{width};
  if ((!defined $fillwidth) && ($fillwidth = $STATE->lookupDefinition(T_CS('\textwidth')))) {
    $fillwidth = $fillwidth->valueOf; }    # get register
  my $maxwidth = $fillwidth && $fillwidth->valueOf;
  my @lines = ();
  my ($wd, $ht, $dp) = (0, 0, 0);
  my $vattach = $options{vattach} || 'baseline';
  foreach my $box (@$boxes) {
    next unless defined $box;
    next if ref $box && !$box->can('getSize');    # Care!! Since we're asking ALL args/compoments
    my ($w, $h, $d) = (ref $box ? $box->getSize(%options) : $font->computeStringSize($box));
    if (ref $w) {
      $wd += $w->valueOf; }
    else {
      Warn('expected', 'Dimension', undef,
        "Width of " . Stringify($box) . " yeilded a non-dimension: " . Stringify($w)); }
    if (ref $h) {
      $ht = max($ht, $h->valueOf); }
    else {
      Warn('expected', 'Dimension', undef,
        "Height of " . Stringify($box) . " yeilded a non-dimension: " . Stringify($h)); }
    if (ref $d) {
      $dp = max($dp, $d->valueOf); }
    else {
      Warn('expected', 'Dimension', undef,
        "Depth of " . Stringify($box) . " yeilded a non-dimension: " . Stringify($d)); }
    if ((($options{layout} || '') eq 'vertical')    # EVERY box is a row?
                                                    # || $box is a <ltx:break> (or similar)!!!!
    ) {
      push(@lines, [$wd, $ht, $dp]); $wd = $ht = $dp = 0; }
    elsif ((defined $maxwidth) && ($wd >= $maxwidth)) {    # or we've reached the requested width
          # Compounding errors with wild abandon.
          # If an underlying box is too wide, we'll split it up into multiple rows
          # [Rather than correctly break it?]
          # BUT How do we know if it should break at alL!?!?!?!?!
##     while ($wd >= $maxwidth) {
##       push(@lines, [$maxwidth, $ht, $dp]); $wd = $wd - $maxwidth; }
##      $ht = $h->valueOf; $dp = $d->valueOf;     # continue with the leftover
      push(@lines, [$wd, $ht, $dp]); $wd = $ht = $dp = 0;
    }
  }
  if ($wd) {    # be sure to get last line
    push(@lines, [$wd, $ht, $dp]); }
  # Deal with multiple lines
  my $nlines = scalar(@lines);
  if ($nlines == 0) {
    $wd = $ht = $dp = 0; }
  else {
    $wd = max(map { $$_[0] } @lines);
    $ht = sum(map { $$_[1] } @lines);
    $dp = sum(map { $$_[2] } @lines);
    if ($vattach eq 'top') {    # Top of box is aligned with top(?) of current text
      my ($w, $h, $d) = $font->getNominalSize;
      $h = $h->valueOf;
      $dp = $ht + $dp - $h; $ht = $h; }
    elsif ($vattach eq 'bottom') {    # Bottom of box is aligned with bottom (?) of current text
      $ht = $ht + $dp; $dp = 0; }
    elsif ($vattach eq 'middle') {
      my ($w, $h, $d) = $font->getNominalSize;
      $h = $h->valueOf;
      my $c = ($ht + $dp) / 2;
      $ht = $c + $h / 2; $dp = $c - $h / 2; }
    else {                            # default is baseline (of the 1st line)
      my $h = $lines[0][1];
      $dp = $ht + $dp - $h; $ht = $h; } }
  #print "BOXES SIZE ".($wd/65536)." x ".($ht/65536)." + ".($dp/65336)." for "
  #  .join(' ',grep {$_} map { Stringify($_) } @$boxes)."\n";
  return (Dimension($wd), Dimension($ht), Dimension($dp)); }

sub isSticky {
  my ($self) = @_;
  return $$self[0] && ($$self[0] =~ /^(?:serif|sansserif|typewriter)$/); }

our %scriptstylemap = (display => 'script', text => 'script',
  script => 'scriptscript', scriptscript => 'scriptscript');
our %fracstylemap = (display => 'text', text => 'script',
  script => 'scriptscript', scriptscript => 'scriptscript');
our %stylesize = (display => 10, text => 10,
  script => 7, scriptscript => 5);

# NOTE: In math, NORMALLY, setting any one of
#    family, series or shape
# will, usually, automatically reset the others to thier defaults!
# You must arrange this in the calls....
sub merge {
  my ($self, %options) = @_;
  # Evaluate any functional values given.
  foreach my $k (keys %options) {
    $options{$k} = &{ $options{$k} }() if ref $options{$k} eq 'CODE'; }

  my $family    = $options{family};
  my $series    = $options{series};
  my $shape     = $options{shape};
  my $size      = rationalizeFontSize($options{size});
  my $color     = $options{color};
  my $bg        = $options{background};
  my $opacity   = $options{opacity};
  my $encoding  = $options{encoding};
  my $language  = $options{language};
  my $mathstyle = $options{mathstyle};
  if ($options{forcebold}) {    # for compatibility
    $series = 'bold'; $options{forceseries} = 1; }
  my $flags = 0
    | ($options{forcefamily} ? $FLAG_FORCE_FAMILY : 0)
    | ($options{forceseries} ? $FLAG_FORCE_SERIES : 0)
    | ($options{forceshape}  ? $FLAG_FORCE_SHAPE  : 0);

  my $oflags = $$self[10];
  # Fallback to positional invocation:
  $family = $$self[0] if (!defined $family) || ($oflags & $FLAG_FORCE_FAMILY);
  $series = $$self[1] if (!defined $series) || ($oflags & $FLAG_FORCE_SERIES);
  $shape  = $$self[2] if (!defined $shape)  || ($oflags & $FLAG_FORCE_SHAPE);
  $size   = $$self[3] if (!defined $size);
  $color  = $$self[4] if (!defined $color);
  $bg     = $$self[5] if (!defined $bg);
  $opacity   = $$self[6] if (!defined $opacity);
  $encoding  = $$self[7] if (!defined $encoding);
  $language  = $$self[8] if (!defined $language);
  $mathstyle = $$self[9] if (!defined $mathstyle);
  $flags = ($$self[10] || 0) | $flags;

  if (my $scale = $options{scale}) {
    $size = $scale * $size; }
  # Set the mathstyle, and also the size from the mathstyle
  # But we may need to scale that size against the existing or requested size.
  my $stylescale = ($$self[3] ? $$self[3] / $stylesize{ $$self[9] || 'display' } : 1);
  if ($options{size}) { }    # Explicitly requested size, use it
  elsif ($options{mathstyle}) {    # otherwise set the size from mathstyle
    $size = $stylescale * $stylesize{$mathstyle}; }
  elsif ($options{scripted}) {     # Or adjust both the mathstyle & size for scripts
    $mathstyle = $scriptstylemap{ $mathstyle          || 'display' };
    $size      = $stylescale * $stylesize{ $mathstyle || 'display' }; }
  elsif ($options{fraction}) {     # Or adjust both for fractions
    $mathstyle = $fracstylemap{ $mathstyle            || 'display' };
    $size      = $stylescale * $stylesize{ $mathstyle || 'display' }; }

  if ($options{emph}) {
    $shape = ($shape eq 'italic' ? 'upright' : 'italic');
    $flags |= $FLAG_EMPH; }
  $flags &= ~$FLAG_EMPH if $mathstyle;    # Disable emph in math

  my $newfont = (ref $self)->new_internal($family, $series, $shape, $size,
    $color, $bg, $opacity,
    $encoding,  $language,
    $mathstyle, $flags);
  if (my $specialize = $options{specialize}) {
    $newfont = $newfont->specialize($specialize); }
  return $newfont; }

# Instanciate the font for a particular class of symbols.
# NOTE: This works in `normal' latex, but probably needs some tunability.
# Depending on the fonts being used, the allowable combinations may be different.
# Getting the font right is important, since the author probably
# thinks of the identity of the symbols according to what they SEE in the printed
# document.  Even though the markup might seem to indicate something else...

# Use Unicode properties to determine font merging.
sub specialize {
  my ($self, $string) = @_;
  return $self if !(defined $string) || ref $string;    # ?
  my ($family, $series, $shape, $size, $color, $bg, $opacity,
    $encoding, $language, $mathstyle, $flags) = @$self;
  my $deffamily = ($flags & $FLAG_FORCE_FAMILY ? $family || $DEFFAMILY : $DEFFAMILY);
  my $defseries = ($flags & $FLAG_FORCE_SERIES ? $series || $DEFSERIES : $DEFSERIES);
  my $defshape  = ($flags & $FLAG_FORCE_SHAPE  ? $shape  || $DEFSHAPE  : $DEFSHAPE);
  if (($string =~ /^\p{Latin}$/) && ($string =~ /^\p{L}$/)) {    # Latin Letter
    $shape = 'italic' if !$shape && !$family; }
  elsif ($string =~ /^\p{Greek}$/) {                             # Single Greek character?
    if ($string =~ /^\p{Lu}$/) {                                 # Uppercase
      if (!$family || ($family eq 'math')) {
        $family = $deffamily;
        $shape = $defshape if $shape && ($shape ne $DEFSHAPE); } }    # if ANY shape, must be default
    else {    # Lowercase
      $family = $deffamily if !$family || ($family ne $DEFFAMILY);
      $shape  = 'italic'   if !$shape  || !($flags & $FLAG_FORCE_SHAPE);    # always ?
      if ($series && ($series ne $DEFSERIES)) { $series = $defseries; }
  } }
  elsif ($string =~ /^\p{N}$/) {                                            # Digit
    if (!$family || ($family eq 'math')) {
      $family = $deffamily;
      $shape  = $defshape; } }                                              # defaults, always.
  else {                                                                    # Other Symbol
    $family = $deffamily;
    $shape  = $defshape;                                                    # defaults, always.
    if ($series && ($series ne $DEFSERIES)) { $series = $defseries; } }
  return (ref $self)->new_internal($family, $series, $shape, $size,
    $color, $bg, $opacity,
    $encoding, $language, $mathstyle, $flags); }

# A special form of merge when copying/moving nodes to a new context,
# particularly math which become scripts or such.
our %mathstylestep = (
  display      => { display => 0,  text => 1,  script => 2,  scriptscript => 3 },
  text         => { display => -1, text => 0,  script => 1,  scriptscript => 2 },
  script       => { display => -2, text => -1, script => 0,  scriptscript => 1 },
  scriptscript => { display => -3, text => -2, script => -1, scriptscript => 0 });
our %stepmathstyle = (
  display => { -3 => 'display', -2 => 'display', -1 => 'display',
    0 => 'display', 1 => 'text', 2 => 'script', 3 => 'scriptscript' },
  text => { -3 => 'display', -2 => 'display', -1 => 'display',
    0 => 'text', 1 => 'script', 2 => 'scriptscript', 3 => 'scriptscript' },
  script => { -3 => 'display', -2 => 'display', -1 => 'text',
    0 => 'script', 1 => 'scriptscript', 2 => 'scriptscript', 3 => 'scriptscript' },
  scriptscript => { -3 => 'display', -2 => 'text', -1 => 'script',
    0 => 'scriptscript', 1 => 'scriptscript', 2 => 'scriptscript', 3 => 'scriptscript' });

sub purestyleChanges {
  my ($self, $other) = @_;
  my $mathstyle      = $self->getMathstyle;
  my $othermathstyle = $other->getMathstyle;
  return (
    scale      => $other->getSize / $self->getSize,
    color      => $other->getColor,
    background => $other->getBackground,
    opacity    => $other->getOpacity,                 # should multiply or replace?
    ($mathstyle && $othermathstyle
      ? (mathstylestep => $mathstylestep{$mathstyle}{$othermathstyle})
      : ()),
  ); }

sub mergePurestyle {
  my ($self, %stylechanges) = @_;
  my $new = $self->new_internal(@$self);
  $$new[3] = $$self[3] * $stylechanges{scale} if $stylechanges{scale};
  $$new[4] = $stylechanges{color}             if $stylechanges{color};
  $$new[5] = $stylechanges{background}        if $stylechanges{background};
  $$new[6] = $stylechanges{opacity}           if $stylechanges{opacity};
  $$new[9] = $stepmathstyle{ $$self[9] }{ $stylechanges{mathstylestep} } if $stylechanges{mathstylestep};
  return new; }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Font> - representation of fonts

=head1 DESCRIPTION

C<LaTeXML::Common::Font> represent fonts in LaTeXML.
It extends L<LaTeXML::Common::Object>.

This module defines Font objects.
I'm not completely happy with the arrangement, or
maybe just the use of it, so I'm not going to document extensively at this point.

The attributes are

 family : serif, sansserif, typewriter, caligraphic,
          fraktur, script
 series : medium, bold
 shape  : upright, italic, slanted, smallcaps
 size   : TINY, Tiny, tiny, SMALL, Small, small,
          normal, Normal, large, Large, LARGE,
          huge, Huge, HUGE, gigantic, Gigantic, GIGANTIC
 color  : any named color, default is black

They are usually merged against the current font, attempting to mimic the,
sometimes counter-intuitive, way that TeX does it,  particularly for math

=head1 Methods

=over 4

=item  C<< $font->specialize($string); >>

In math mode, C<LaTeXML::Common::Font> supports computing a font reflecting
how the specific C<$string> would be printed when
C<$font> is active; This (attempts to) handle the curious ways that lower case
greek often doesn't get a different font.  In particular, it recognizes the
following classes of strings: single latin letter, single uppercase greek character,
single lowercase greek character, digits, and others.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
