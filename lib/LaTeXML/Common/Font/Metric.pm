# /=====================================================================\ #
# |  LaTeXML::Common::Font::Metric                                      | #
# | Representaion of Font Metrics                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Font::Metric;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Common::Object;
use LaTeXML::Common::Dimension;
use base qw(LaTeXML::Common::Object);

# Likely options will include family, face, etc...
#  encoding,
#  designsize, exheight, quad (emwidth),
sub new {
  my ($class, $encoding, $file, %options) = @_;
  my $self = bless { encoding => $encoding, file => $file,
    sizes => {}, kerns => {}, ligatures => {}, parameters => [], %options }, $class;
  $self->read_tfm();
  return $self; }

# TeX's rendering of characters uses little drawings stored by position within a font;
# A font encoding implies which (somewhat abstract) chracter is at which position.
# The metrics (size, kerning, etc) are stored within a TeX Font Metric (tfm) file,
# which is also indexed by the glyph's position within the font.

# LaTeXML uses "font maps" to associate each position within a font (encoding)
# with a Unicode codepoint. Here, we use a representaive tfm to determine what
# TeX might think an appropriate size for each such codepoint. Of course, it will
# certainly be different on whatever eventual rendering device, according to browser fonts, etc.

# The tfm reading code is freely adapted from Font::TFM.
# See TeX the Program, Section 539
sub read_tfm {
  my ($self) = @_;
  my $fontmap = $STATE->lookupValue($$self{encoding} . '_fontmap');
  #  my $pathname = FindFile($$self{file}, 'tfm');
  my $pathname = $$self{file};
  # Read the TFM raw data.
  my $TFM;
  if (!pathname_openfile($TFM, '<', $pathname)) {
    Error('expected', $pathname, undef,
      "Couldn't open TFM files '$pathname': $!");
    return; }
  # ----------------------------------------
  # read & extract heading info
  my $buffer = '';
  if (read($TFM, $buffer, 24) != 24) {
    Error("Error reading TFM header: $!"); return; }

  # Extract 12 unsigned short (16bit, network order) fields from the header
  # length of file & header; begin & end char,
  # number of widths,heights,depts,italic corrections, ligkern, extensions, parameters
  my ($lf, $lh, $bc, $ec, $nw, $nh, $nd, $ni, $nl, $nk, $ne, $np) = unpack("n12", $buffer);
  my $nc = $ec - $bc + 1;

  # ----------------------------------------
  # Read & extract data tables
  my $lt = $lf * 4 - 24;    # length of tables.
  if (read($TFM, $buffer, $lt) != $lt) {
    Error("Error reading body: $!"); return; }
  close $TFM;

  # Disassemble the relevant data tables
  my (@header, @char_info, @width, @height, @depth, @italic, @lig_kern, @kern, @exten, @param);
  (@header[0 .. $lh - 1],
    @char_info[0 .. $nc - 1],    # a4 x $ncodes
    @width[0 .. $nw - 1],
    @height[0 .. $nh - 1],
    @depth[0 .. $nd - 1],
    @italic[0 .. $ni - 1],
    @lig_kern[0 .. $nl - 1],     # a4 x $nl
    @kern[0 .. $nk - 1],
    @exten[0 .. $ne - 1],        # a4 x $ne
    @param[0 .. $np - 1],
    ) = unpack "N$lh" . "a4" x $nc . "l>$nw" . "l>$nh" . "l>$nd" . "l>$ni" .
    "a4" x $nl . "l>$nk" . "a4" x $ne . "l>$np", $buffer;
  # Mostly can ignore the header; but $header[1] is the design size; do we need that?
  # Note: fixword are fixed point being 16 scaled points !
  # But: MetaFont book says "sharp units (printers points)" TTP says "design size units" ???
  # Note that these sizes DO still get multiplied by the font size (design size?) in Font.pm
  # Question: should we just store them that way (more compact?) and deal w/units in Font.pm?
  @width  = map { $_ / 16 } @width;
  @height = map { $_ / 16 } @height;
  @depth  = map { $_ / 16 } @depth;
  @italic = map { $_ / 16 } @italic;
  @kern   = map { $_ / 16 } @kern;
  @param  = map { $_ / 16 } @param;

  # First & last lig_kern entries relate to "boundary" char (what IS that???)
  if (@lig_kern) {    # check for boundary char
    my ($skip, $next, $op, $remainder);
    ($skip, $next) = unpack "CC", $lig_kern[0];
    if (($skip == 255) && (defined $$fontmap[$next])) {
      $$self{boundary} = $$fontmap[$next]; }
    ($skip, $next, $op, $remainder) = unpack "CCCC", $lig_kern[-1];
    if ($skip == 255) {
      $self->process_lig_kern("boundary", \@lig_kern, 256 * $op + $remainder, $fontmap, \@kern); }
  }
  # Interpret char_info (for w,h,d,ital) and lig_kern program
  my $sizes = $$self{sizes};
  for (my $code = $bc ; $code <= $ec ; $code++) {
    my $char = $$fontmap[$code];
    if (defined $char) {
      my ($wloc, $hdloc, $ixloc, $remainder) = unpack "C4", $char_info[$code];
      my ($hloc, $dloc, $iloc, $tag) = ($hdloc >> 4, $hdloc & 0x0F, $ixloc >> 2, $ixloc & 0x03);
      if (!$$sizes{$char}) {    # Don't replace?
        $$sizes{$char} = [$width[$wloc], $height[$hloc], $depth[$dloc], $italic[$iloc]]; }
      if ($tag == 1) {          # lig/kern program; Ignore tag=2 (larger); tag=3 (extensible)
        $self->process_lig_kern($char, \@lig_kern, $remainder, $fontmap, \@kern); }
  } }
  # And install interesting parameters (offset by 1)
  $$self{parameters}   = [@param];
  $$self{slant}        = $param[0];
  $$self{space}        = $param[1];
  $$self{spacestretch} = $param[2];
  $$self{spaceshrink}  = $param[3];
  $$self{exheight}     = $param[4];
  $$self{emwidth}      = $param[5];
  $$self{quad}         = $param[5];
  $$self{extraspace}   = $param[6];
  # Add metrics for fake chars (from TeX perspective; Basically various space-like things)
  # What about \x{2002}, \x{2009} ?
  my $em   = $param[5];
  my $mu   = $em / 18;
  my %para = (" " => $param[1], pack('U', 0xA0) => $param[1], "\n" => $param[1],
    "\x{2002}" => $em / 2, "\x{2003}" => $em,
    "\x{2006}" => $em / 6, "\x{2009}" => $em / 6,
    "\x{200b}" => 3 * $mu, "\x{2005}" => 4 * $mu, "\x{2004}" => 5 * $mu);
  foreach my $char (sort keys %para) {
    if (!$$sizes{$char}) {    # Don't replace?
      $$sizes{$char} = [$para{$char}, 0, 0]; } }
  return $self; }

# Process the ligature/kerning program for a character
sub process_lig_kern {
  my ($self, $char, $lig_kernref, $prognum, $fontmap, $kernref) = @_;
  my $firstinstr = 1;
  my $kerns      = $$self{kerns};
  my $ligs       = $$self{ligatures};
  while (1) {
    my ($skip, $next, $op, $remainder) = unpack "CCCC", $$lig_kernref[$prognum];
    if ($firstinstr && ($skip > 128)) {    # Effectively a goto
      $prognum = 256 * $op + $remainder; $firstinstr = 0;
      next; }
    $next = $$fontmap[$next];
    my $pair = $char . $next;
    if (($op >= 128) && !exists $$kerns{$pair}) {
      $$kerns{$pair} = $$kernref[256 * ($op - 128) + $remainder]; }
    if (($op < 128) && !exists $$ligs{$pair}) {
      my ($pass, $keepc, $keepn) = ($op >> 2, ($op >> 1) & 0x01, $op & 0x01);
      my $lig = ($keepc ? $char : "") . $$fontmap[$remainder] . ($keepn ? $next : '');
      $$ligs{$pair} = [$lig, $pass]; }    # ligature & number of chars to "passover" (always 0???)
    last if ($skip >= 128);
    $prognum += $skip + 1;
    $firstinstr = 0; }
  return; }

1;
