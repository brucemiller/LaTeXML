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
use LaTeXML::Common::Number;
use LaTeXML::Common::Dimension;
use LaTeXML::Common::Font::Metric;
use LaTeXML::Common::Font::StandardMetrics;
use LaTeXML::Common::Color;
use List::Util qw(min max sum);
use base qw(LaTeXML::Common::Object);

# Note that this has evolved way beynond just "font",
# but covers text properties (or even display properties) in general
# including basic font information, color & background color
# as well as encoding and language information.

DebuggableFeature('size-detailed', "Show sizing of boxes in detail");
# NOTE: This is now in Common that it may evolve to be useful in Post processing...

my $DEFFAMILY     = 'serif';      # [CONSTANT]
my $DEFSERIES     = 'medium';     # [CONSTANT]
my $DEFSHAPE      = 'upright';    # [CONSTANT]
my $DEFCOLOR      = Black;        # [CONSTANT]
my $DEFBACKGROUND = undef;        # [CONSTANT] no color; transparent
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
# and (importantly) the encoding needed to lookup unicode in a FontMap!
# I'd like to use Karl Berry's font naming scheme
# (See http://www.tug.org/fontname/html/)
# but it seems to be a one-way mapping, and moreover, doesn't even fit CM fonts!
# We'll assume a sloppier version:
#   family + series + variant + size
# NOTE: This probably doesn't really belong in here...

my %font_family = (
  # Computer Modern
  cm     => { family   => 'serif' },    # base for synthesizing cmbx, cmsl ...
  cmr    => { family   => 'serif' },
  cmm    => { family   => 'math', shape => 'italic', encoding => 'OML' },    # cmmi
  cmsy   => { encoding => 'OMS' },
  cmex   => { encoding => 'OMX' },
  cmss   => { family   => 'sansserif' },
  cmtt   => { family   => 'typewriter' },
  cmvtt  => { family   => 'typewriter' },
  cmssq  => { family   => 'sansserif' },                                     # quote style?
  cmssqi => { family   => 'sansserif', shape => 'italic' },                  # quote style?
  cmt    => { family   => 'serif' },                                         # for cmti "text italic"
  cmmib  => { family   => 'italic', series   => 'bold' },
  cmbsy  => { series   => 'bold',   encoding => 'OMS' },
  cmfib  => { family   => 'serif' },
  cmfr   => { family   => 'serif' },
  cmdh   => { family   => 'serif' },
  cmdunh => { family   => 'serif' },    # like cmr10 but with tall body heights
  cmu    => { family   => 'serif' },    # unslanted italic ??
  cmsltt => { family   => 'typewriter', shape => 'slanted' },
  cmbrm  => { family   => 'sansserif',  shape => 'italic' },
  # Some Blackboard Bold fonts
  bbm   => { family => 'blackboard' },
  bbold => { family => 'blackboard' },
  bbmss => { family => 'blackboard' },
  # Computer Concrete
  ccr   => { family => 'serif' },
  ccm   => { family => 'serif', shape => 'italic' },
  cct   => { family => 'serif' },
  ccitt => { family => 'typewriter', shape => 'italic' },
  # AMS fonts
  msa => { encoding => 'AMSa' },
  msb => { encoding => 'AMSb' },
  msx => { encoding => 'AMSa' },    # Are these really the same? (or even real?)
  msy => { encoding => 'AMSb' },
  # Euler
  eur  => { family   => 'serif' },
  eus  => { family   => 'script' },
  euf  => { family   => 'fraktur' },
  euex => { encoding => 'OMX' },
  # TX Fonts (Times Roman)
  txr   => { family   => 'serif' },
  txmi  => { family   => 'serif', shape => 'italic' },
  txss  => { family   => 'sansserif' },
  txtt  => { family   => 'typewriter' },
  txsya => { encoding => 'AMSa' },
  txsyb => { encoding => 'AMSb' },
  # PX Fonts (Palladio)
  pxr   => { family   => 'serif' },
  pxmi  => { family   => 'serif', shape => 'italic' },
  pxsya => { encoding => 'AMSa' },
  pxsyb => { encoding => 'AMSb' },
  # Pretend to recognize plain & latex's extra fonts (currently no encoding set up)
  manfnt   => { family => 'graphic', encoding => 'manfnt' },
  line     => { family => 'graphic', encoding => 'line' },
  linew    => { family => 'graphic', encoding => 'line', series => 'bold' },
  lcircle  => { family => 'graphic', encoding => 'lcircle' },
  lcirclew => { family => 'graphic', encoding => 'lcircle', series => 'bold' },
  # Pretend to recognize xy's fonts
  xydash => { family => 'graphic' },
  xyatip => { family => 'graphic' },
  xybtip => { family => 'graphic' },
  xybsql => { family => 'graphic' },
  xycirc => { family => 'graphic' },
  xycmat => { family => 'graphic' },
  xycmbt => { family => 'graphic' },
  xyluat => { family => 'graphic' },
  xylubt => { family => 'graphic' },
  # Fourier
  futm  => { family => 'serif', shape => 'italic' },
  futmi => { family => 'serif', shape => 'italic' },
  # More fonts that need to be better sorted, classified & labelled
  # family symbol, dingbats are nonsense: We need an encoding and FontMap!!!
  ptm   => { family => 'serif' },      ppl  => { family => 'serif' },
  pnc   => { family => 'serif' },      pbk  => { family => 'serif' },
  phv   => { family => 'sansserif' },  pag  => { family => 'serif' },
  pcr   => { family => 'typewriter' }, pzc  => { family => 'script' },
  put   => { family => 'serif' },      bch  => { family => 'serif' },
  psy   => { family => 'symbol' },     pzd  => { family => 'dingbats' },
  cmbr  => { family => 'sansserif' },  cmtl => { family => 'typewriter' },
  cmbrs => { family => 'symbol' },     ul9  => { family => 'typewriter' },
  futs  => { family => 'serif' },
  uaq   => { family => 'serif' }, ugq => { family => 'sansserif' },
);

# Maps the "series code" to an abstract font series name
my %font_series = (
  ''  => {},    # default medium
  m   => { series => 'medium' },
  mc  => { series => 'medium' },
  b   => { series => 'bold' },
  bc  => { series => 'bold' },
  bx  => { series => 'bold' },
  sb  => { series => 'bold' },
  sbc => { series => 'bold' },
  bm  => { series => 'bold' });

# Maps the "shape code" to an abstract font shape name.
my %font_shape = (
  ''  => {},    # default upright
  n   => { shape => 'upright' },
  i   => { shape => 'italic' },
  it  => { shape => 'italic' },
  sl  => { shape => 'slanted' },
  sc  => { shape => 'smallcaps' },
  csc => { shape => 'smallcaps' });

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
  tiny   => 0.5,   SMALL => 0.7, Small => 0.8,  small => 0.9,
  normal => 1.0,   large => 1.2, Large => 1.44, LARGE => 1.728,
  huge   => 2.074, Huge  => 2.488,
  big    => 1.2,   Big   => 1.6, bigg => 2.1, Bigg => 2.6,
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
    my %props = (series => 'medium', shape => 'upright', encoding => 'OT1');
    my ($fam, $ser, $shp, $size) = ($1, $2, $3, $4);
    if (my $ffam = lookupFontFamily($fam)) { map { $props{$_} = $$ffam{$_} } keys %$ffam; }
    if (my $fser = lookupFontSeries($ser)) { map { $props{$_} = $$fser{$_} } keys %$fser; }
    if (my $fsh  = lookupFontShape($shp))  { map { $props{$_} = $$fsh{$_} } keys %$fsh; }
    $size        = 1 unless $size;    # Yes, also if 0, "" (from regexp)
    $size        = $at             if defined $at;
    $size        = $size * $scaled if defined $scaled;
    $props{name} = $name;
    $props{size} = $size;
    return %props; }
  else {
    Info('unrecognized', 'font', undef, "Unrecognized fontname '$name'");
    return (family => $name, size => DEFSIZE()); } }

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
    $family,    $series, $shape, rationalizeFontSize($size),
    $color,     $bg,     $opacity,
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
    $DEFCOLOR, $DEFBACKGROUND, $DEFOPACITY, 'OT1', $DEFLANGUAGE, 'text', 0); }

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
  no warnings 'recursion';
  my ($self) = @_;
  my ($fam, $ser, $shp, $siz, $col, $bkg, $opa, $enc, $lang, $mstyle, $flags) = @$self;
  # !!!!!
  $fam = 'serif' if $fam && ($fam eq 'math');
  return 'Font[' . join(',', map { Stringify($_) } grep { $_ }
      (isDiff($fam, $DEFFAMILY)   ? ($fam)    : ()),
    (isDiff($ser, $DEFSERIES)     ? ($ser)    : ()),
    (isDiff($shp, $DEFSHAPE)      ? ($shp)    : ()),
    (isDiff($siz, DEFSIZE())      ? ($siz)    : ()),
    (isDiff($col, $DEFCOLOR)      ? ($col)    : ()),
    (isDiff($bkg, $DEFBACKGROUND) ? ($bkg)    : ()),
    (isDiff($opa, $DEFOPACITY)    ? ($opa)    : ()),
    ($mstyle                      ? ($mstyle) : ()),
    ($flags                       ? ($flags)  : ()),
    )
    . ']'; }

# Return a Fontinfo-like hash
# Eventually a more integrated representation of Fonts that accommodates
# both low-level TeX-like commands, and higher-level CSS-like ones.
sub asFontinfo {
  my ($self) = @_;
  my ($fam, $ser, $shp, $siz, $col, $bkg, $opa, $enc, $lang, $mstyle, $flags) = @$self;
  return { family => $fam, series => $ser, shape => $shp, size => $siz,
    color    => $col,          background => $bkg,  opacity   => $opa,
    encoding => $enc || 'OT1', language   => $lang, mathstyle => $mstyle }; }

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
    $family   || $ofamily,   $series || $oseries, $shape || $oshape, $size || $osize,
    $color    || $ocolor,    $bg     || $obg, (defined $opacity ? $opacity : $oopacity),
    $encoding || $oencoding, $lang   || $olang, $mstyle || $omstyle,
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
  # !!!!
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
    (isDiff($enc, $oenc)
      ? (encoding => { value => $enc, properties => { encoding => $enc } })
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
      my $re   = '^Font\['
        . join(',', map { ($_ eq '*' ? "[^,]+" : "\Q$_\E") } @comp)
        . '\]$';
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

# Map Font family_series_shape to a TeX fontname (tfm)
# Leave off the size, so we can punt to a loaded size in a pinch
my %metric_map = (
  serif_medium_upright       => 'cmr',
  serif_medium_slanted       => 'cmsl',
  serif_medium_italic        => 'cmti',
  serif_medium_uprightitalic => 'cmu',
  serif_bold_upright         => 'cmbx',
  serif_medum_smallcaps      => 'cmcsc',
  sansserif_medium_upright   => 'cmss',
  sansserif_medium_italic    => 'cmssi',
  sansserif_bold_upright     => 'cmssbx',
  typewriter_medium_upright  => 'cmtt',
  typewriter_medium_slanted  => 'cmsltt',
  math_medium_italic         => 'cmmi',
  math_medium_upright        => 'cmr',
  math_bold_italic           => 'cmiib',
);
# Fallback fontnames for looking up random Unicode,
# when they're not in the indicated FontMap
my @metric_fallbacks = (qw(cmr cmmi cmsy cmex msam msbm ifgeo));

# Find a Font Metric corresponding to this font's family_series_shape_size
# that contains the given $char, if given.
# Try to find a fallback metric if $char is not in the current Font
sub getMetric {
  my ($self, $char) = @_;
  my $key  = join('_', $$self[0] || 'serif', $$self[1] || 'medium', $$self[2] || 'upright');
  my $size = int($$self[3] || 10);
  if (my $name = $metric_map{$key}) {
    if (my $metric = getMetricForName($name . $size)) {
      if ((!defined $char) || $$metric{sizes}{$char}) {
        return $metric; } } }
  if (defined $char) {    # Look for a fallback metric
    foreach my $name (@metric_fallbacks) {
      if (my $metric = getMetricForName($name . $size)) {
        if ($$metric{sizes}{$char}) {
          return $metric; } } } }
  return getMetricForName('cmr10'); }

# Find a Font Metric for a given fontname, fallback to 10pt or cmr as needed.
sub getMetricForName {
  my ($name) = @_;
  my ($base, $size) = ($name, 10);
  if ($name =~ /^(.*?)(\d+)$/) {
    $base = $1; $size = $2; }
  if (my $metric = $$LaTeXML::Common::Font::StandardMetrics::STDMETRICS{$name}
    || $$LaTeXML::Common::Font::StandardMetrics::STDMETRICS{ $base . 10 }
    || $$LaTeXML::Common::Font::StandardMetrics::STDMETRICS{ 'cmr' . $size }) {
    return $metric; }
  else {
    Error('unexpected', 'font', undef, "Couldn't find a font for $name");
    return $$LaTeXML::Common::Font::StandardMetrics::STDMETRICS{cmr10}; } }

#======================================================================
our %mathstylesize = (display => 1, text => 1,
  script => 0.7, scriptscript => 0.5);

sub getEMWidth {
  my ($self) = @_;
  my $size   = ($self->getSize || DEFSIZE() || 10);
  my $m      = getMetric($self, undef);
  return int($size * $$m{emwidth}); }

sub getEXHeight {
  my ($self) = @_;
  my $size   = ($self->getSize || DEFSIZE() || 10);
  my $m      = getMetric($self, undef);
  return int($size * $$m{exheight}); }

sub getMUWidth {
  my ($self) = @_;
  my $size   = ($self->getSize || DEFSIZE() || 10);
  my $m      = getMetric($self, undef);
  return int($size * $$m{emwidth} / 18); }

# NOTE: that we assume the size has already been adjusted for mathstyle, if necessary.
sub computeStringSize {
  my ($self, $string) = @_;
  if ((!defined $string) || ($string eq '') || ($self->getFamily eq 'nullfont')) {
    return (Dimension(0), Dimension(0), Dimension(0)); }
  my $size = ($self->getSize || DEFSIZE() || 10); ## * $mathstylesize{ $self->getMathstyle || 'text' };
  my $ismath = $self->getFamily eq 'math';
  my ($w, $h, $d) = (0, 0, 0);
  my @chars = split(//, $string);
  while (@chars) {
    my $char   = shift(@chars);
    my $metric = $self->getMetric($char);
    my $entry  = $$metric{sizes}{$char};
##    Debug("No size entry for '$char' (" . sprintf("%x", ord($char)) . ")") unless $entry;
    # Need a better guess for missing fonts
    my ($cw, $ch, $cd, $ci) = ($entry ? @$entry
      : (0.75 * $UNITY, 0.7 * $UNITY, 0.2 * $UNITY, 0));
    # for CJK?                 : (1.0 * $UNITY, 0.88 * $UNITY, 0.12 * $UNITY, 0));
    $w += int($cw * $size);
    if (my $kern = $chars[0] && $$metric{kerns}{ $char . $chars[0] }) {
      $w += int($size * $kern); }
    if ($ismath && $ci) {
      $w += int($size * $ci); }
    $h = max($h, int($ch * $size));
    $d = max($d, int($cd * $size)); }
  # The 1 is so that any actual glyph appears to be non-empty.
  # This is presumably only necessary to deal with the flawed emptiness heiristics in Alignment?
  return (Dimension(int($w || 1)), Dimension(int($h)), Dimension(int($d))); }

# Get nominal width, height base ?
# Probably should be using data from FontMetric ???
sub getNominalSize {
  my ($self) = @_;
  my $size = ($self->getSize || DEFSIZE() || 10); ## * $mathstylesize{ $self->getMathstyle || 'text' };
  my $u    = $size * $UNITY;
  return (Dimension(0.75 * $u), Dimension(0.7 * $u), Dimension(0.2 * $u)); }

# Nominal baseline size for a given font size
# This really should be tracked within the TeX
my %baseline_map = (
  5  => 6,    6  => 7,  7    => 8,  8  => 9.5, 9  => 10, 10 => 12,
  11 => 13.6, 12 => 14, 14.4 => 18, 17 => 22,  20 => 25, 25 => 30);

# Compute the size of a box (Box, List, Whatsit).
# Primarily, we're interested in Lists of various modes,
# since Box & Whatsit handle their own sizing.
# Here's where I avoid trying to emulate Knuth's line-breaking...
# Mostly for List & Whatsit: compute the size of a List of boxes.
# the Boxes mode determines layout vertical, paragraph (horizontal) or simple horizontal
# Options include:
#   width:  if given, pretend to simulate line breaking to that width
#   height,depth : ? ignored?
#   totalheight : stretch height & depth to fill.
#   vattach : top, bottom, middle (...?) affects how the height & depth are
#      allocated when there are multiple lines.
#   baseline : the baseline determines spacing between lines.
# Boxes that arent a Core Box, List, Whatsit or a string are IGNORED
sub computeBoxesSize {
  my ($self, $boxes, %options) = @_;
  my $ref = ref $boxes;
  if (!$ref) {
    return computeStringSize($self, $boxes); }
  elsif ($ref =~ /^LaTeXML::Core::(?:Box|Whatsit|Alignment)$/) {
    return $boxes->getSize; }
  elsif ($ref ne 'LaTeXML::Core::List') {
    Warn('unexpected', $ref, undef, "Can't compute size of $boxes");
    return (Dimension(0), Dimension(0), Dimension(0)); }
  # So, now we're a List; What mode?
  # math or display_math Lists should be contained within a Whatsit, so can ignore those.
  # vertical and internal_vertical are equivalent.
  # A horizontal list is formatted as a paragraph IFF a width is supplied,
  # else treat as restricted_horizontal.
  # restricted_horizontal is just a single line, w/o any line breaking.
  my $mode = $boxes->getProperty('mode') || 'restricted_horizontal';
  # $boxes's vattach & width override any passed as options
  my $vattach  = $boxes->getProperty('vattach') || $options{vattach} || 'baseline';
  my $baseline = ($boxes->getProperty('baseline') || $options{baseline} || Dimension('12pt'))->spValue;
  my $maxwidth = 0;
  no warnings 'recursion';
  # ----------------------------------------------------------------------
  my @lines = ();
  if ($mode =~ /vertical$/) {    # For vertical, ALL boxes are lines
    foreach my $box ($boxes->unlist) {
      # In TeX, a paragraph would have already been typeset into lines
      my $width;
      if ((ref $box eq 'LaTeXML::Core::List')
        && (($box->getProperty('mode') || '') eq 'horizontal')
        && ($width = $box->getProperty('width'))) {
        $width    = $width->valueOf if ref $width;
        $maxwidth = $width          if $width && $width > $maxwidth;
        push(@lines, linebreak_paragraph($self, $box, $width, $baseline)); }
      else {
        my ($w, $h, $d) = $box->getSPSize;
        my $bs = ($box->getProperty('isVerticalSpace')    # maybe disable baseline
            || $box->getProperty('isHorizontalRule')
          ? -1 : $baseline);
        push(@lines, [$bs, $w, $h, $d, $box]) if $w || $h || $d; } } }
  elsif (my $width = ($mode =~ /horizontal$/) && $boxes->getProperty('width')) {
    $width    = $width->valueOf if ref $width;                     # Proper paragraph
    $maxwidth = $width          if $width && $width > $maxwidth;
    @lines    = linebreak_paragraph($self, $boxes, $width, $baseline); }
  else {    # Else restricted_horizontal or math
    ## Strictly, no need to split words, but that handles breaks, kerns,...
    my @words = split_words($boxes->unlist);
    @lines = collect_lines(undef, $baseline, @words); }

  # ----------------------------------------------------------------------
  # Now, stack up the multiple lines
  my $mathaxis = int($self->getSize || DEFSIZE() || 10) * $UNITY / 4;
  my ($wd, $ht, $dp) = stack_lines($vattach, $mathaxis, @lines);
  $wd = $maxwidth if $wd && $maxwidth;     # Set to maxwidth, unless empty.
  if (my $th = $options{totalheight}) {    # divie up totalheight, if requested
    my $diff = $th->valueOf - $ht - $dp;
    if ($diff > 0) {
      if ($vattach eq 'bottom')    { $ht += $diff; }
      elsif ($vattach eq 'middle') { $ht += $diff / 2; $dp += $diff / 2; }
      else                         { $dp += $diff; } } }
  $options{baseline} = Dimension($baseline);
  Debug("Size boxes $mode: " . join(',', map { $_ . '=' . ToString($options{$_}); } sort keys %options) . "\n"
      . "  Boxes: " . ToString($boxes) . "\n"
      . "  Boxes: " . Stringify($boxes) . "\n"
      . " Options:" . join(',',  map { $_ . "=" . ToString($options{$_}); } sort keys %options) . "\n"
      . "  Sizes: " . join("\n", map { _showline(@$_); } @lines) . "\n"
      . "  => " . _showsize($wd, $ht, $dp)) if $LaTeXML::DEBUG{'size-detailed'};
  return (Dimension($wd), Dimension($ht), Dimension($dp)); }

# Format a horizontal list (with width) as a paragraph, breaking it into lines.
# A line is [baseline, width, height, depth, @contents]
# (all dimensions as numeric scaled points; @contents is for debugging)
# The baseline is the baselineskip to determine spacing between lines;
# basically increases previous depth + next height.
# baseline == -1 means to make NO adjustments on either side (eg. \vskip, \hrule)
sub linebreak_paragraph {
  my ($self, $list, $width, $baseline) = @_;
  $width    = $list->getProperty('width')    || $width;
  $baseline = $list->getProperty('baseline') || $baseline || Dimension('12pt');
  $width    = $width->spValue    if ref $width;
  $baseline = $baseline->spValue if ref $baseline;
  my @boxes = flatten_paragraph($list);
  my @words = split_words(@boxes);
  return collect_lines($width, $baseline, @words); }

# Flatten a horizontal List (to be treated as a paragraph) by opening up any
# contained horizontal Lists, and ALSO any Whatsits that format AS IF they were
# embedded paragraph material (eg. \emph).
sub flatten_paragraph {
  my ($list)    = @_;
  my @boxes     = $list->unlist;
  my @flattened = ();
  while (@boxes) {
    my $box  = shift(@boxes);
    my $type = ref $box;
    if    (!ref $box) { }
    elsif (($type eq 'LaTeXML::Core::List')
      && (($box->getProperty('mode') || '') eq 'horizontal')) {
      unshift(@boxes, $box->unlist); }
    elsif (my @replacement = ($type eq 'LaTeXML::Core::Whatsit' ? $box->flattenForSizing : ())) {
      unshift(@boxes, @replacement); }
    else {
      push(@flattened, $box); } }
  return @flattened; }

# Compute a list of sizes of space-delimited "words" within a NON-vertical list.
# A word is [space, width, height, depth, @contents]
# space is the amount of space preceding the "word"
# space == 0 is initial word, or breakable before word w/o any space
# space == -1 means forced line break before the word.
sub split_words {
  no warnings 'recursion';
  my (@boxes) = @_;
  my @words   = ();
  my @word    = ();
  my $prevbox;
  my $prevspace = 0;
  my ($wd, $ht, $dp) = (0, 0, 0);

  foreach my $box (@boxes) {
    my ($w, $h, $d) = $box->getSPSize;
    # Check for possible line-break points
    if    ((!ref $box) || $box->getProperty('isEmpty')) { }
    elsif ($box->getProperty('isBreak')) {
      if ($wd || $ht || $dp || ($prevspace > 0)) {
        push(@words, [$prevspace, $wd, $ht, $dp, @word]);
        $wd = $ht = $dp = 0; $prevspace = -1; @word = (); }
      else {
        $prevspace = -1; } }
    # Pernaps not "isSpace", but excluding struts, neg space, etc ???
    elsif ($box->getProperty('isSpace') && !$box->getProperty('isVerticalSpace')) {
      if ($wd || $ht || $dp || ($prevspace < 0)) {
        push(@words, [$prevspace, $wd, $ht, $dp, @word]);
        $wd = $ht = $dp = 0; $prevspace = $w; @word = (); }
      else {
        $prevspace += $w; } }
    elsif ($box->getProperty('isIdeographic')) {    # These amount to words
      push(@words, [$prevspace, $wd, $ht, $dp, @word]) if $wd;    # previous word?
      push(@words, [0, $w, $h, $d, $box]);
      $wd = $ht = $dp = 0; $prevspace = 0; @word = (); }
    else {                                                        # Else accumulate into "word"
      $wd += $w;
      $ht = max($ht, $h);
      $dp = max($dp, $d);
      push(@word, $box);
      # Kern HACK for lists of individual Box's
      if ($prevbox && (ref $prevbox eq 'LaTeXML::Core::Box') && (ref $box eq 'LaTeXML::Core::Box')) {
        my $font     = $box->getFont;
        my $prevfont = $prevbox->getFont;
        my $prevchar = substr($prevbox->getString || '', -1, 1);
        my $curchar  = substr($box->getString     || '', 0,  1);
        my $metric   = $prevfont->getMetric($curchar);
        if (my $kern = $$metric{kerns}{ $prevchar . $curchar }) {
          $wd += $font->getSize * $kern; }
        if (my $f = (($font->getFamily eq 'math') && $font)
          || (($prevfont->getFamily eq 'math') && $prevfont)) {
          $wd += $f->math_bearing($box, $prevbox); } }
    }
    $prevbox = $box; }
  if ($wd || $ht || $dp || $prevspace || @word) {    # be sure to get last bit
    push(@words, [$prevspace, $wd, $ht, $dp, @word]); }
  return @words; }

# do line breaking of words into lines, according to $wrapwidth (if), or explicit breaks.
sub collect_lines {
  my ($wrapwidth, $baseline, @words) = @_;
  my @lines = ();
  my @line  = ();
  my $fuzz  = Dimension('1pt')->valueOf;
  my ($wd, $ht, $dp) = (0, 0, 0);
  foreach my $item (@words) {
    my ($space, $w, $h, $d, @word) = @$item;
    if (($space == -1)    # Forced linebreak, or wrapped linebreak
      || ((defined $wrapwidth) && ($wd + $space * 0.5 + $w > $wrapwidth + $fuzz))) {
      push(@lines, [$baseline, $wd, $ht, $dp, @line]) if $wd;
      $wd = $w; $ht = $h; $dp = $d; @line = @word; }
    else {
      $wd += $space + $w;
      $ht = max($ht, $h);
      $dp = max($dp, $d);
      push(@line, @word); } }
  push(@lines, [$baseline, $wd, $ht, $dp, @line]) if $wd || $ht || $dp;
  return @lines; }

# Sum up a stack of lines, determining w as max, and h & d according to $vattach.
sub stack_lines {
  my ($vattach, $mathaxis, @lines) = @_;
  my ($baseline, $wd, $ht, $dp) = (0, 0, 0, 0);
  my $nlines = scalar(@lines);
  if ($nlines == 0) {
    $wd = $ht = $dp = 0; }
  elsif ($nlines == 1) {
    ($baseline, $wd, $ht, $dp) = @{ $lines[0] }; }
  else {
    # baseline adjustment
    my $lineskip  = $STATE->lookupDefinition(T_CS('\lineskip'))->valueOf->valueOf;
    my $prevdepth = -99999;
    my $th        = 0;
    foreach my $line (@lines) {
      my ($bs, $w, $h, $d) = @$line;
      $wd = max($w, $wd);
      $th += $h + $d;
      if (($prevdepth >= 0) && ($bs >= 0)) {
        if ($prevdepth + $h < $bs) {
          $th += $bs - $prevdepth - $h; }
        else {
          $th += $lineskip; } }
      $prevdepth = ($bs >= 0 ? $d : -99999); }
    if ($vattach eq 'middle') {
      $ht = $th / 2 + $mathaxis; $dp = $th / 2 - $mathaxis; }
    elsif ($vattach eq 'bottom') {    # align to baseline of Bottom row
      $dp = $lines[-1][3]; $ht = $th - $dp; }
    else {                            # else align to baseline of top row
      $ht = $lines[0][2]; $dp = $th - $ht; } }
  return ($wd, $ht, $dp); }

#======================================================================
# Probably a clumsy way of dealing with math spacing...
# 0=Ord, 1=Op, 2=Bin, 3=Rel, 4=Open, 5=Close, 6=Punct, 7=Inner
my %mathatomtype = (ID => 0,
  BIGOP => 1, SUMOP     => 1, INTOP => 1, OPERATOR  => 1, LIMITOP => 1, DIFFOP  => 1,
  ADDOP => 2, MULOP     => 2, BINOP => 2, COMPOSEOP => 2, MIDDLE  => 2, VERTBAR => 2,
  RELOP => 3, METARELOP => 3, ARROW => 3,
  OPEN  => 4, CLOSE     => 5,
  PUNCT => 6, PERIOD    => 6,
  ARRAY => 7, MODIFIER  => 7);
# mysterious: MODIFIEROP, POSTFIX, APPLYOP, SUPOP
my $mathbearings = [
  [0,  1,  -2, -3, 0,  0,  0,  -1],
  [1,  1,  0,  -3, 0,  0,  0,  -1],
  [-2, -2, 0,  0,  -2, 0,  0,  -2],
  [-3, -3, 0,  0,  -3, 0,  0,  -3],
  [0,  0,  0,  0,  0,  0,  0,  0],
  [0,  1,  -2, -3, 0,  0,  0,  -1],
  [-1, -1, 0,  -1, -1, -1, -1, -1],
  [-1, 1,  -2, -3, -1, 0,  -1, -1]];
my $mathbearingreg = [undef, T_CS('\thinmuskip'), T_CS('\medmuskip'), T_CS('\thickmuskip')];

sub math_bearing {
  my ($self, $box, $prevbox) = @_;
  my $r0      = $prevbox->getProperty('role') || 'ID';
  my $r1      = $box->getProperty('role')     || 'ID';
  my $t0      = $mathatomtype{$r0}            || 0;
  my $t1      = $mathatomtype{$r1}            || 0;
  my $bearing = $$mathbearings[$t0][$t1];
  my $style   = $self->getMathstyle || 'text';
  if (!$bearing || (($bearing < 0) && ($style ne 'display') && ($style ne 'text'))) {
    return 0; }
  return $STATE->lookupDefinition($$mathbearingreg[abs($bearing)])->valueOf->spValue; }

sub _showsize {
  my ($wd, $ht, $dp) = @_;
  return ($wd / $UNITY) . " x " . ($ht / $UNITY) . " + " . ($dp / $UNITY); }

sub _showline {
  my ($sp, $wd, $ht, $dp, @stuff) = @_;
  return ($wd / $UNITY) . " x " . ($ht / $UNITY) . " + " . ($dp / $UNITY)
    . (@stuff ? ' ' . join('', map { ToString($_); } @stuff) : ''); }

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
  $family    = $$self[0] if (!defined $family) || ($oflags & $FLAG_FORCE_FAMILY);
  $series    = $$self[1] if (!defined $series) || ($oflags & $FLAG_FORCE_SERIES);
  $shape     = $$self[2] if (!defined $shape)  || ($oflags & $FLAG_FORCE_SHAPE);
  $size      = $$self[3] if (!defined $size);
  $color     = $$self[4] if (!defined $color);
  $bg        = $$self[5] if (!exists $options{background});
  $opacity   = $$self[6] if (!defined $opacity);
  $encoding  = $$self[7] if (!defined $encoding);
  $language  = $$self[8] if (!defined $language);
  $mathstyle = $$self[9] if (!defined $mathstyle);
  $flags     = ($$self[10] || 0) | $flags;

  if (my $scale = $options{scale}) {
    $size = $scale * $size; }
  # Set the mathstyle, and also the size from the mathstyle
  # But we may need to scale that size against the existing or requested size.
  my $stylescale = ($$self[3] ? $$self[3] / $stylesize{ $$self[9] || 'display' } : 1);
  if    ($options{size}) { }       # Explicitly requested size, use it
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
    $color,     $bg, $opacity,
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
  if ($string =~ /^(?=\p{LC})(?!\p{Script=Common})\p{Latin}$/) {    # Latin Letter, NOT a modifier
    $shape = 'italic' if !$shape && !$family; }
  elsif ($string =~ /^\p{Greek}$/) {                                # Single Greek character?
    if ($string =~ /^\p{Lu}$/) {                                    # Uppercase
      if (!$family || ($family eq 'math')) {
        $family = $deffamily;
        $shape  = $defshape if $shape && ($shape ne $DEFSHAPE); } }    # if ANY shape, must be default
    else {                                                             # Lowercase
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
    $color,    $bg, $opacity,
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
  my $othercolor     = $other->getColor;
  return (
    scale => $other->getSize / $self->getSize,
    (isDiff($othercolor, $DEFCOLOR) ? (color => $othercolor) : ()),
    background => $other->getBackground,
    opacity    => $other->getOpacity,      # should multiply or replace?
    ($mathstyle && $othermathstyle
      ? (mathstylestep => $mathstylestep{$mathstyle}{$othermathstyle})
      : ()),
  ); }

sub mergePurestyle {
  my ($self, %stylechanges) = @_;
  my $new = $self->new_internal(@$self);
  $$new[3] = $$self[3] * $stylechanges{scale}                            if $stylechanges{scale};
  $$new[4] = $stylechanges{color}                                        if $stylechanges{color};
  $$new[5] = $stylechanges{background}                                   if $stylechanges{background};
  $$new[6] = $stylechanges{opacity}                                      if $stylechanges{opacity};
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
 color  : any named color, default is Black

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
