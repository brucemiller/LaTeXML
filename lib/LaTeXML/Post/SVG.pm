# /=====================================================================\ #
# |  LaTeXML:SVG                                                        | #
# |                                                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::SVG;
use strict;
use warnings;
use LaTeXML::Common::XML;
use LaTeXML::Common::Model;
use LaTeXML::Util::Transform;
use LaTeXML::Util::Geometry;
use LaTeXML::Util::Image;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

my $NSURI  = "http://dlmf.nist.gov/LaTeXML";    # CONSTANT
my $svgURI = 'http://www.w3.org/2000/svg';      # CONSTANT
my $NR     = '[\-\+\d\.e]+';                    # CONSTANT

####################################
## main function
####################################
# We need to find potential nodes to convert,
# but don't want those already containing proper SVG.
# However, we may not have svg as a registered namespace, so...
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes("//ltx:picture[child::*[not(local-name()='svg' and namespace-uri()='$svgURI')]]"); }

sub process {
  my ($self, $doc, @svg) = @_;
  local $::IDCOUNTER = 0;
  if (!$$self{model}) {
    $$self{model} = LaTeXML::Common::Model->new();
    $$self{model}->setRelaxNGSchema("LaTeXML");
    $$self{model}->loadSchema(); }
  $doc->addNamespace($svgURI, 'svg');
  map { $self->ProcessSVG($_) } @svg;
  $doc->adjust_latexml_doctype('SVG');    # Add SVG if LaTeXML dtd.
  return $doc; }

sub getQName {
  my ($node) = @_;
  return $LaTeXML::Post::DOCUMENT->getQName($node); }

sub copy_valid_attributes {
  my ($self, $to, $from) = @_;
  my $qname = getQName($to);
  foreach my $attr ($from->attributes) {
    my $key = $attr->getName;
    if ($$self{model}->canHaveAttribute($qname, $key)) {
      $from->removeAttribute($key) if $key eq 'xml:id';
      $to->setAttribute($key, $from->getAttribute($key)); } }
  return; }

sub copy_position {
  my ($self, $to, $from) = @_;
  my $x = $from->getAttribute('x');
  my $y = $from->getAttribute('y');
  $to->setAttribute(cx => $x) if defined $x;
  $to->setAttribute(cy => $y) if defined $y;
  return; }

sub to_px {
  my ($pt) = @_;
  return ($pt =~ s/pt$// ? $pt * $LaTeXML::Util::Image::DPI / 72.27 : $pt); }

####################################
## fixes an svg node
####################################

sub ProcessSVG {
  my ($self, $node) = @_;
  # holds information about current font
  local @::FONTSTACK = ({ fill => 'black' });
  # if during processing some definitions are required, they are stored here
  # at end of processing, required definitions are inserted into the tree
  local %::DEFS = ();
  # assign parent to an explicit variable $parent , to avoid some really tricky segfault edge cases.
  my $parent = $node->parentNode;
  my $newSVG = $parent->addNewChild($svgURI, 'svg');
  $newSVG->setAttribute(version => '1.1');
  my $newNode = convertNode($self, $newSVG, $node);
  if (%::DEFS) {
    my $defnode = $newSVG->addNewChild($svgURI, 'defs');
    foreach my $key (sort keys %::DEFS) {
      $defnode->appendChild($::DEFS{$key});
    }
  }
  $self->copy_valid_attributes($newSVG, $node);
  makeViewBox($newSVG);
  simplifyGroups($newSVG);
  $node->replaceNode($newSVG);
  return; }

sub makeViewBox {
  my ($node) = @_;
  my ($w, $h) = get_attr($node, qw(width height));
####  $node->setAttribute(viewBox => "0 0 $w $h");
  # Does origin-x,origin-y need to be reflected in the initial transform?
  $node->setAttribute(width    => to_px($node->getAttribute('width')));
  $node->setAttribute(height   => to_px($node->getAttribute('height')));
  $node->setAttribute(overflow => 'visible') if (($node->getAttribute('clip') || '') ne 'true');
  $node->removeAttribute('clip');
  return; }

sub simplifyGroups {
  my ($node) = @_;
  map { simplifyGroups($_) } element_nodes($node);
  if ((getQName($node) || '') eq 'ltx:g') {
    my ($parent, @sons) = ($node->parentNode, $node->childNodes);
    if (scalar(@sons) == 0) {
      $parent->removeChild($node);
    } elsif (scalar(@sons) == 1 && isElementNode($sons[0])
      && ($sons[0]->namespaceURI eq $svgURI)) {
      my $son = $sons[0]; my @attr = valid_attributes($node);
      if ($#attr == -1) {
        $parent->insertBefore($son, $node);
        $parent->removeChild($node);
      } elsif ($#attr == 0 && $attr[0]->getName eq 'transform') {
        mergeTransform($son, $attr[0]->getValue);
        $parent->insertBefore($son, $node);
        $parent->removeChild($node);
      }
    }
  }
  return; }

#======================================================================
# Converting specific tags.
#======================================================================
my %converters = (    # CONSTANT
  'ltx:picture' => \&convertPicture, 'ltx:path'   => \&convertPath,
  'ltx:g'       => \&convertG,       'ltx:text'   => \&convertText,
  'ltx:polygon' => \&convertPolygon, 'ltx:line'   => \&convertLine,
  'ltx:rect'    => \&convertRect,    'ltx:bezier' => \&convertBezier,
  'ltx:circle'  => \&convertCircle,
  'ltx:ellipse' => \&convertEllipse, 'ltx:wedge' => \&convertWedge,
  'ltx:arc'     => \&convertArc,     'ltx:dots'  => \&convertDots);

sub convertNode {
  my ($self, $parent, $node) = @_;
  my $tag = getQName($node);
  if (!$tag) {
    $parent->appendChild($node); }
  elsif (my $converter = $converters{$tag}) {
    &$converter($self, $parent, $node); }
  else {
    # Node is random LaTeXML element, and so will need an svg:foreignObject wrapper.
    # Moreover, svg will want to know the size of the foreign thing.
    # Hopefully, this will have been recorded on a containing ltx:g, using innerwidth/innerheight.
    my $oldparent = $node->parentNode;
    my $width     = $node->getAttribute('width')    # Use node's own width, if any
      || $node->getAttribute('imagewidth')          # or if an image
      || $oldparent->getAttribute('innerwidth')     # else hopefully from containing ltx:g
      || $oldparent->getAttribute('width');
    my $height = $node->getAttribute('height')
      || $node->getAttribute('imageheight')
      || $oldparent->getAttribute('innerheight')
      || $oldparent->getAttribute('height');
    my $depth = $node->getAttribute('depth')
      || $oldparent->getAttribute('innerdepth')
      || $oldparent->getAttribute('depth');
    $width  = "1pt" unless defined $width;          # Required but must be non-zero
    $height = "1pt" unless defined $height;
    $depth  = "0pt" unless defined $depth;
    my $g = $parent->addNewChild($svgURI, 'g');
    #    my $y = to_px($height);
    my $y = to_px($height) + to_px($depth);
    $g->setAttribute(transform => "translate(0,$y) scale(1, -1)");
    my $new = $g->addNewChild($svgURI, 'foreignObject');
    $new->setAttribute(width    => to_px($width))  if defined $width;
    $new->setAttribute(height   => to_px($height)) if defined $height;
    $new->setAttribute(overflow => 'visible');
    $new->appendChild($node); }
  return; }

sub convertPath {
  my ($self, $parent, $node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $self->copy_valid_attributes($newNode, $node);
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

# I think we need to shift the origin to the bottom before we mirror the y scale!
sub convertPicture {
  my ($self, $parent, $node) = @_;
  my $h     = to_px($node->getAttribute('height') || '0');
  my $gNode = $parent->addNewChild($svgURI, 'g');
  $gNode->setAttribute(transform => "translate(0,$h) scale(1,-1)");
  map { convertNode($self, $gNode, $_) } element_nodes($node);
  return $gNode; }

sub convertG {
  my ($self, $parent, $node) = @_;
  my ($xoff, $yoff) = boxContentPos($node);
  my $newNode = $parent->addNewChild($svgURI, 'g');
  if ((($node->getAttribute('framed') || '') eq 'true')
    && (($node->getAttribute('fillframe') || '') eq 'true')) {
    my $bgName = getFillFrame($node->getAttribute('fill') || 'white');
    $newNode->setAttribute(filter => "url(#$bgName)"); }
  $self->copy_valid_attributes($newNode, $node);
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

sub convertText {
  my ($self, $parent, $node) = @_;

  my $oldparent = $node->parentNode;
  my $p = ((getQName($oldparent) || '') eq 'ltx:g' ? $oldparent->getAttribute('pos') || '' : 'bl');
  my $newNode = $parent->addNewChild($svgURI, 'text');
  my $x       = $node->getAttribute('x') || 0;
  my $y       = $node->getAttribute('y') || 0;
  $newNode->setAttribute(x => $x);
  $newNode->setAttribute(y => $y);

  ##    if (my $text = text_in_node($node)) { $newNode->appendText($text); }
  mergeTransform($node, 'scale(1, -1)');
  $self->copy_valid_attributes($newNode, $node);
  # Translate the font info.
  push(@::FONTSTACK, {});
  if (my $fontsize = $node->getAttribute('fontsize')) {
    $::FONTSTACK[0]{'font-size'} = $fontsize; }
  if (my $font = $node->getAttribute('font')) {
    my $type = 'fill';
    if ($font =~ /italic/) {
      $type = 'font-style'; }
    elsif ($font =~ /slanted/) {
      $type = 'font-style'; $font = 'oblique'; }
    elsif ($font =~ /bold/) {
      $type = 'font-weight'; }
    elsif ($font =~ /medium/) {
      $type = 'font-weight'; $font = 'normal'; }
    elsif ($font =~ /smallcaps/) {
      $type = 'font-variant'; $font = 'small-caps'; }
    elsif ($font =~ /upright/) {
      $type = 'font-variant'; $font = 'normal'; }
    elsif ($font =~ /tiny|footnote|small|normal|large|Large|LARGE|huge|Huge/) {
      $type = 'font-size'; $font = ''; }
    elsif ($font =~ /serif|sansserif|typewriter|caligraphic|fraktur|script/) {
      $type = 'font-family'; $font = ''; }
    $::FONTSTACK[0]{$type} = $font if $font;
  }
  my %Font = %{ $::FONTSTACK[0] };
  foreach my $attr (sort keys %Font) {
    next if $newNode->hasAttribute($attr);
    $newNode->setAttribute($attr => $Font{$attr}) if $Font{$attr}; }

  my @children = $node->childNodes;
  foreach my $child (@children) {
    if (isTextNode($child)) {
      $newNode->appendText($child->data); }
    else {
      convertNode($self, $newNode, $child); } }
  pop(@::FONTSTACK);
  return $newNode; }

sub convertPolygon {
  my ($self, $parent, $node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d => arcPoints($node) . ' z');
  $self->copy_valid_attributes($newNode, $node);
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

sub convertLine {
  my ($self, $parent, $node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d => arcPoints($node));
  $self->copy_valid_attributes($newNode, $node);
  setArrows($newNode, $node, $node->getAttribute('stroke'));
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

sub convertRect {
  my ($self, $parent, $node) = @_;
  my $newNode;
  if (my $part = $node->getAttribute('part')) {
    $newNode = $parent->addNewChild($svgURI, 'path');
    $newNode->setAttribute(d => ovalPath($part, get_attr($node, qw(x y width height rx))));
    $self->copy_valid_attributes($newNode, $node); }
  else {
    $newNode = $parent->addNewChild($svgURI, 'rect');
    $self->copy_valid_attributes($newNode, $node); }
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

sub convertBezier {
  my ($self, $parent, $node) = @_;
  my @p       = explodeCoord($node->getAttribute('points') || '');
  my $n       = ($#p + 1) / 2; my $x0 = shift(@p); my $y0 = shift(@p);
  my %cmd     = (4 => 'C', 3 => 'Q');
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d => "M $x0,$y0 " . ($cmd{$n} || 'T') . ' ' . coordList(@p));
  $self->copy_valid_attributes($newNode, $node);
  setArrows($newNode, $node, $newNode->getAttribute('stroke'));
  $newNode->setAttribute('stroke-dasharray' => '2') if $node->hasAttribute('displayedpoints');
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

# NOTE: I messed this one up!
sub convertVbox {
  my ($self, $parent, $node) = @_;
  my $text = '';
  foreach my $child (element_nodes($node)) {
    my $cn = getQName($child);
    if ((($cn || '') =~ /^ltx:(text|hbox)$/) && (my $t = text_in_node($node))) { $text .= $t . "\n"; } }
  my $dummynode = new_node($NSURI, 'text');
  $dummynode->appendText($text);
  my $newNode = $parent->addNewChild($svgURI, 'text');
  $self->copy_valid_attributes($newNode, $node);
  convertText($newNode, $dummynode);
  return $newNode; }

sub convertCircle {
  my ($self, $parent, $node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'circle');
  $self->copy_valid_attributes($newNode, $node);
  $self->copy_position($newNode, $node);
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

#?
sub convertDots {
  my ($self, $parent, $node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'g');
  my @p       = explodeCoord($node->getAttribute('points') || '');
  while (@p) {
    my ($x, $y) = (shift(@p), shift(@p));
    my $dot = $newNode->addNewChild($svgURI, 'circle');
    ### copy_attributes($dot, $node);
    $self->copy_valid_attributes($newNode, $node);
    if (my $size = $node->getAttribute('dotsize')) {
      $dot->setAttribute(r => $size); }
    $dot->setAttribute(cx => $x);
    $dot->setAttribute(cy => $y); }
  return $newNode; }

sub convertEllipse {
  my ($self, $parent, $node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'ellipse');
  $self->copy_valid_attributes($newNode, $node);
  $self->copy_position($newNode, $node);
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

sub convertWedge {
  my ($self, $parent, $node) = @_;
  my ($x, $y, $r, $a1, $a2) = get_attr($node, qw(x y r angle1 angle2));
  my $bb = $a2 - $a1; $bb += 360 if $bb < 0;
  $bb = $bb > 180 ? 1 : 0; ($a1, $a2) = radians($a1, $a2);
  my ($x1, $y1, $x2, $y2) = trunc(2, $x + $r * cos($a1), $y + $r * sin($a1), $x + $r * cos($a2), $y + $r * sin($a2));
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d => "M $x $y L $x1 $y1 A $r $r 0 $bb 1 $x2 $y2 z");
  $self->copy_valid_attributes($newNode, $node);
  map { convertNode($self, $newNode, $_) } element_nodes($node);
  return $newNode; }

sub convertArc {
  my ($self, $parent, $node) = @_;
  my ($x, $y, $r, $a1, $a2, $sp, $stroke, $fill) =
    get_attr($node, qw(x y r angle1 angle2 showpoints stroke fill));
  my $bb = $a2 - $a1;
  $bb += 360 if $bb < 0; $bb = $bb > 180 ? 1 : 0; ($a1, $a2) = radians($a1, $a2);
  my ($x1, $y1, $x2, $y2) = trunc(2, $x + $r * cos($a1), $y + $r * sin($a1), $x + $r * cos($a2), $y + $r * sin($a2));
  my $linestroke = ($stroke || '') eq 'none' ? $fill : $stroke;

  my $newNode = $parent->addNewChild($svgURI, 'g');
  if (my $transform = $node->getAttribute('transform')) {
    $newNode->setAttribute(transform => $transform); }
  if (($sp || '') eq 'true') {
    my $newLine = $newNode->addNewChild($svgURI, 'path');
    $newLine->setAttribute(d                  => "M $x1 $y1 $x $y $x2 $y2");
    $newLine->setAttribute(fill               => 'none');
    $newLine->setAttribute('stroke-dasharray' => '2');
    $newLine->setAttribute(stroke             => $linestroke);
    $self->copy_valid_attributes($newLine, $node); }
  my $newArc = $newNode->addNewChild($svgURI, 'path');
  $newArc->setAttribute(d => "M $x1 $y1 A $r $r 0 $bb 1 $x2 $y2");
  $self->copy_valid_attributes($newArc, $node);
  setArrows($newArc, $node, $linestroke);
  #  map { $newNode->appendChild(convertNode($self,$_)) } element_nodes($node);
  return $newNode; }

#################################################################

sub getFillFrame {
  my ($fill) = @_;
  my $bgName = 'bg' . $fill; $bgName =~ s/\#//g;
  $bgName .= ($::IDCOUNTER++);
  $::DEFS{$bgName} =
    new_node($svgURI, 'filter', [new_node($svgURI, 'feFlood', undef, 'flood-color' => $fill, 'flood-opacity' => 1, result => 'bg'),
      new_node($svgURI, 'feMerge', [new_node($svgURI, 'feMergeNode', undef, in => 'bg'),
          new_node($svgURI, 'feMergeNode', undef, in => 'SourceGraphic')])],
    id => $bgName, primitiveUnits => 'objectBoundingBox', x => '-0.1', y => '-0.1', width => '1.2', height => '1.2') unless $::DEFS{$bgName};
  return $bgName;
}

sub getArrow {
  my ($fill, $type) = @_; my $ar = 'AR' . ($fill || ''); $ar =~ s/\#//g;
  if ($type eq '>') {
    $ar .= '_R'; }
  elsif ($type eq '<') {
    $ar .= '_L'; }
  $ar .= ($::IDCOUNTER++);
  $::DEFS{$ar} = new_node($svgURI, 'marker', new_node($svgURI, 'path', undef, fill => $fill, stroke => 'none',
      d => ($type eq '>') ? 'M 0 0 L 20 10 L 0 20 L 8 9 z' : 'M 0 10 L 20 0 L 12 10 L 20 20 z'),
    id => $ar, viewBox => '0 0 20 20', markerUnits => 'strokeWidth', markerWidth => 20, markerHeight => 12, orient => 'auto', refX => 20, refY => 10)
    unless $::DEFS{$ar};
  return $ar; }

sub setArrows {
  my ($node, $from, $fill) = @_;
  return unless $from->hasAttribute('terminators');
  my $t = $from->getAttribute('terminators');    ###remove_attr($node, qw(terminators arrowlength));
  return unless $t =~ /([^\-]*)-(.*)/;
  my ($start, $end) = ($1, $2);
  if ($start =~ s/(>|<)//) {
    $node->setAttribute('marker-start' => 'url(#' . getArrow($fill, $1) . ')'); }
  if ($end =~ s/(>|<)//) {
    $node->setAttribute('marker-end' => 'url(#' . getArrow($fill, $1) . ')'); }
  return; }

sub mergeTransform {
  my ($node, $new_t) = @_;
  my $old_t = $node->getAttribute('transform');
  my $t     = ($old_t && $new_t) ? Transform("$new_t $old_t")->toString :
    ($old_t ? $old_t : ($new_t ? $new_t : undef));
  $node->setAttribute(transform => $t) if $t;
  return; }

sub ovalPath {
  my ($opt, $x, $y, $w, $h, $r) = @_;

  my $trStart = "M " . ($x + $w / 2) . " $y ";
  my $trContent = "L " . ($x + $w - $r) . " $y A $r $r 0 0 1 " . ($x + $w) . " " . ($y - $r) . " L " . ($x + $w) . " " . ($y - $h / 2) . " ";
  my $tlStart = "M $x " . ($y - $h / 2) . " ";
  my $tlContent = "L $x " . ($y - $r) . " A $r $r 0 0 1 " . ($x + $r) . " $y L " . ($x + $w / 2) . " $y ";

  my $brStart = "M " . ($x + $w) . " " . ($y - $h / 2) . " ";
  my $brContent = "L " . ($x + $w) . " " . ($y - $h + $r) . " A $r $r 0 0 1 " . ($x + $w - $r) . " " . ($y - $h) .
    " L " . ($x + $w / 2) . " " . ($y - $h) . " ";
  my $blStart = "M " . ($x + $w / 2) . " " . ($y - $h) . " ";
  my $blContent = "L " . ($x + $r) . " " . ($y - $h) . " A $r $r 0 0 1 $x " . ($y - $h + $r) . " L $x " . ($y - $h / 2) . " ";
  my $path = '';
  if ($opt eq 't') {
    $path = $tlStart . $tlContent . $trContent; }
  elsif ($opt eq 'b') {
    $path = $brStart . $brContent . $blContent; }
  elsif ($opt eq 'l') {
    $path = $blStart . $blContent . $tlContent; }
  elsif ($opt eq 'r') {
    $path = $trStart . $trContent . $brContent; }
  elsif ($opt eq 'tr' || $opt eq 'rt') {
    $path = $trStart . $trContent; }
  elsif ($opt eq 'tl' || $opt eq 'lt') {
    $path = $tlStart . $tlContent; }
  elsif ($opt eq 'br' || $opt eq 'rb') {
    $path = $brStart . $brContent; }
  elsif ($opt eq 'bl' || $opt eq 'lb') {
    $path = $blStart . $blContent; }
  chop($path);
  return $path; }

sub boxContentPos {
  my ($node) = @_;
  my ($nw, $nh, $npos) = get_attr($node, qw(width height pos));
  return (0, 0) unless defined $nw && defined $nh;
  $nw =~ s/pt$//;
  $nh =~ s/pt$//;
  if (!$npos) {
    return ($nw / 2, $nh / 2); }
  elsif ($npos eq 't') {
    return ($nw / 2, $nh); }
  elsif ($npos eq 'b') {
    return ($nw / 2, 0); }
  elsif ($npos eq 'l') {
    return (0, $nh / 2); }
  elsif ($npos eq 'r') {
    return ($nw, $nh / 2); }
  elsif ($npos eq 'tr' || $npos eq 'rt') {
    return ($nw, $nh); }
  elsif ($npos eq 'tl' || $npos eq 'lt') {
    return (0, $nh); }
  elsif ($npos eq 'br' || $npos eq 'rb') {
    return ($nw, 0); }
  else {
    return (0, 0); } }

sub arcPoints {
  my ($node) = @_;
  my ($pts, $r) = get_attr($node, qw(points arc));
  return 'M ' . $pts if !$r && $pts;
  local *getP = sub {
    my ($x1, $y1, $x2, $y2) = @_;
    # TODO: Do we need a warning if $dst is zero?
    #       Default to 0.01 since we'll use it as a denominator
    my $dst = sqrt(($x1 - $x2)**2 + ($y1 - $y2)**2) || 0.01;
    my $s   = ($x2 - $x1) * ($y2 - $y1) >= 0 ? 1 : -1;
    trunc(2, $s, $x1 + ($x2 - $x1) * $r / $dst, $y1 + ($y2 - $y1) * $r / $dst); };
  my @p = explodeCoord($pts); my $n = ($#p + 1) / 2;
  my $d = "M $p[0] $p[1] ";
  for (my $i = 1 ; $i < $n - 1 ; $i++) {
    my ($x2, $y2)      = ($p[2 * $i - 2], $p[2 * $i - 1]);
    my ($x1, $y1)      = ($p[2 * $i], $p[2 * $i + 1]);
    my ($sa, $xa, $ya) = getP($x1, $y1, $x2, $y2);
    ($x2, $y2) = ($p[2 * $i + 2], $p[2 * $i + 3]);
    my ($sb, $xb, $yb) = getP($x1, $y1, $x2, $y2);
    my $sf = ($sa >= $sb) ? 0 : 1;
    $d .= "L $xa $ya A $r $r 0 0 $sf $xb $yb ";
  }
  $d .= "L $p[2*$n-2] $p[2*$n-1]";
  return $d; }

1;
