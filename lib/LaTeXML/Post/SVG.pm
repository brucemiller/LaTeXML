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
use Exporter;
use LaTeXML::Global;
use LaTeXML::Post;
use LaTeXML::Util::LibXML;
use LaTeXML::Util::Transform;
use LaTeXML::Util::Geometry;
use base qw(LaTeXML::Post);

our $NSURI = "http://dlmf.nist.gov/LaTeXML";
our $svgURI  = 'http://www.w3.org/2000/svg';

my $NR = '[\-\+\d\.e]+';

####################################
## main function
####################################
sub process {
  my ($self, $doc) = @_;
  local $LaTeXML::Post::SVG::DOCUMENT = $doc;
  if(my @svg = $self->find_svg_nodes($doc)){
    $self->Progress("Converting ".scalar(@svg)." pictures");
    $doc->addNamespace($svgURI,'svg');
    map(ProcessSVG($_), @svg);
    $doc->adjust_latexml_doctype('SVG'); } # Add SVG if LaTeXML dtd.
  $doc; }

sub find_svg_nodes { $_[1]->findnodes('//ltx:picture'); }

sub getQName {
  $LaTeXML::Post::SVG::DOCUMENT->getQName(@_); }

####################################
## fixes an svg node
####################################

sub ProcessSVG {
  my ($node) = @_;
  # holds information about current font
  local @::FONTSTACK=({fill=>'black'});
  # if during processing some definitions are required, they are stored here
  # at end of processing, required definitions are inserted into the tree
  local %::DEFS = ();
  my $newSVG = $node->parentNode->addNewChild($svgURI,'svg');
  $newSVG->setAttribute(version=>'1.1');
  my $newNode = convertNode($newSVG,$node);
  if (%::DEFS) {
    my $defnode = $newSVG->addNewChild($svgURI,'defs');
    foreach my $def (values %::DEFS) {
      $defnode->appendChild($def);
    }
  }
  copy_attributes($newSVG, $node, CA_EXCEPT, qw(tex baseline));
  makeViewBox($newSVG);
  simplifyGroups($newSVG);
  $node->replaceNode($newSVG);
}

sub makeViewBox {
  my ($node) = @_;
  my ($w, $h) = get_attr($node, qw(width height));
  $w = $1 if ($w =~ /^($NR)([a-z]{2})$/);
  $h = $1 if ($h =~ /^($NR)([a-z]{2})$/);
  my ($minx, $maxx, $miny, $maxy) = map($_ || 0, @{getSVGBounds($node)});
  $w = $maxx-$minx if $maxx-$minx>$w; $h = $maxy-$miny if $maxy-$miny>$h;
  $node->setAttribute(viewBox=>"$minx $miny $w $h");
  $node->setAttribute(overflow=>'visible') if (($node->getAttribute('clip') || '') ne 'yes');
  $node->removeAttribute('clip');
}

sub simplifyGroups {
  my ($node) = @_;
  map(simplifyGroups($_), element_nodes($node));
  if ((getQName($node) || '') eq 'ltx:g') {
    my ($parent, @sons) = ($node->parentNode, $node->childNodes);
    if (scalar(@sons) == 0) {
      $parent->removeChild($node);
    } elsif (scalar(@sons) ==  1 && isElementNode($sons[0])
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
}

#======================================================================
# Converting specific tags.
#======================================================================
our %converters = ('ltx:picture'=>\&convertPicture, 'ltx:path'  =>\&convertPath,
		   'ltx:g'      =>\&convertG,       'ltx:text'  =>\&convertText,
		   'ltx:polygon'=>\&convertPolygon, 'ltx:line'  =>\&convertLine,
		   'ltx:rect'   =>\&convertRect,    'ltx:bezier'=>\&convertBezier,
		   'ltx:vbox'   =>\&convertVbox,    'ltx:circle'=>\&convertCircle,
		   'ltx:ellipse'=>\&convertEllipse, 'ltx:wedge' =>\&convertWedge,
		   'ltx:arc'    =>\&convertArc);
sub convertNode {
  my ($parent,$node) = @_;
  my $tag = getQName($node);
  my $converter = $converters{$tag};
  if($converter){
    &$converter($parent,$node); }
  else {
    my $new = $parent->addNewChild($svgURI,'foreignObject');
    $new->appendChild($node); }}

sub convertPath {
  my ($parent,$node) = @_;
  my $newNode = $parent->addNewChild($svgURI,'path');
  copy_attributes($newNode, $node);
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertPicture {
  my ($parent,$node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'g');
  $newNode->setAttribute(transform=>'scale(1 -1)');
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertG {
  my ($parent,$node) = @_; 
  my ($xoff, $yoff) = boxContentPos($node);
  my $newNode = $parent->addNewChild($svgURI, 'g');
  mergeTransform($node, "translate($xoff, $yoff)") if ($xoff || $yoff);
  if((($node->getAttribute('framed') || '') eq 'yes')
     && (($node->getAttribute('fillframe') || '') eq 'yes')){
    my $bgName = getFillFrame($node->getAttribute('fill') || 'white');
    $newNode->setAttribute(filter=>"url(#$bgName)"); }
  copy_attributes($newNode, $node, CA_EXCEPT,
		  qw(width height framed fillframe stroke stroke-width boxsep
		     doubleline shadowbox frametype));
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertText {
  my ($parent,$node) = @_;
  my $p; my $oldparent = $node->parentNode;
  if ((getQName($oldparent) || '') eq 'ltx:g') {
    $p = $oldparent->getAttribute('pos') || '';
  } else {
    $p = 'bl';
  }
  my $newNode = $parent->addNewChild($svgURI, 'text');
  $newNode->setAttribute('dominant-baseline'=>'middle');
  $newNode->setAttribute('baseline-shift'=>'sub') if $p =~ /t/;
  $newNode->setAttribute('baseline-shift'=>'super') if $p =~ /b/;
  if ($p =~ /l/) {
    $newNode->setAttribute('text-anchor'=>'start');
  } elsif ($p =~ /r/) {
    $newNode->setAttribute('text-anchor'=>'end');
  } else {
    $newNode->setAttribute('text-anchor'=>'middle');
  }
  $newNode->setAttribute(x=>$node->getAttribute('x') || 0);
  $newNode->setAttribute(y=>$node->getAttribute('y') || 0);
  ##    if (my $text = text_in_node($node)) { $newNode->appendText($text); }
  mergeTransform($node, 'scale(1 -1)');
  copy_attributes($newNode, $node, CA_OVERWRITE, qw(transform));
  # Translate the font info.
  push(@::FONTSTACK,{});
  if (my $font =  $node->getAttribute('font')) {
    my $type = 'fill';
    if ($font =~ /italic/) {
      $type = 'font-style';
    } elsif ($font =~ /slanted/) {
      $type = 'font-style'; $font = 'oblique';
    } elsif ($font =~ /bold/) {
      $type = 'font-weight';
    } elsif ($font =~ /medium/) {
      $type = 'font-weight'; $font = 'normal';
    } elsif ($font =~ /smallcaps/) {
      $type = 'font-variant'; $font = 'small-caps';
    } elsif ($font =~ /upright/) {
      $type = 'font-variant'; $font = 'normal';
    } elsif ($font =~ /tiny|footnote|small|normal|large|Large|LARGE|huge|Huge/) { 
      $type = 'font-size'; $font = '';
    } elsif ($font =~ /serif|sansserif|typewriter|caligraphic|fraktur|script/) { 
      $type = 'font-family'; $font = '';
    }
    $::FONTSTACK[0]{$type} = $font if $font;
  }
  my %Font = %{$::FONTSTACK[0]};
  foreach my $attr (keys %Font) {
    next if $newNode->hasAttribute($attr);
    $newNode->setAttribute($attr=>$Font{$attr});
  }

  my @children = $node->childNodes;
  foreach my $child (@children) {
    if (isTextNode($child)) {
      ##	my $new = new_node($svgURI, 'text');
      ##	$new->appendText($child->data);
      ##	$newNode->appendChild($new); }
      $newNode->appendText($child->data);
    } else {
      convertNode($newNode,$child);
    }
  }
  pop(@::FONTSTACK);
  $newNode;
}

sub convertPolygon {
  my($parent,$node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d=>arcPoints($node).' z');
  copy_attributes($newNode, $node, CA_OVERWRITE, 
		  qw(stroke stroke-width stroke-dasharray fill transform));
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertLine {
  my($parent,$node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d=>arcPoints($node));
  copy_attributes($newNode, $node, CA_OVERWRITE,
		  qw(stroke stroke-width stroke-dasharray fill transform
		     terminators arrowlength));
  setArrows($newNode, $node->getAttribute('stroke'));
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertRect {
  my($parent,$node) = @_;
  my $newNode;
  if(my $part = $node->getAttribute('part')) {
    $newNode = $parent->addNewChild($svgURI, 'path');
    $newNode->setAttribute(d=>ovalPath($part, get_attr($node, qw(x y width height rx))));
    copy_attributes($newNode, $node, CA_OVERWRITE,
		    qw(fill stroke stroke-width transform)); }
  else {
    $newNode = $parent->addNewChild($svgURI, 'rect');
    copy_attributes($newNode, $node); }
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertBezier {
  my($parent,$node) = @_; 
  my @p = explodeCoord($node->getAttribute('points') || '');
  my $n = ($#p + 1)/2; my $x0 = shift(@p); my $y0 = shift(@p);
  my %cmd = (4=>'C', 3=>'Q');
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d=>"M $x0,$y0 ".($cmd{$n} || 'T').' '.coordList(@p));
  copy_attributes($newNode, $node, CA_OVERWRITE, 
		  qw(stroke stroke-width fill transform terminators arrowlength));
  setArrows($newNode, $newNode->getAttribute('stroke'));
  $newNode->setAttribute('stroke-dasharray'=>'2') if $node->hasAttribute('displayedpoints');
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

# NOTE: I messed this one up!
sub convertVbox {
  my($parent,$node) = @_;
  my $text = '';
  foreach my $child(element_nodes($node)) {
    my $cn = getQName($child);
    if ((($cn || '') =~/^ltx:(text|hbox)$/) && (my $t = text_in_node($node))) { $text.=$t."\n" ; }}
  my $dummynode = new_node($NSURI,'text');
  $dummynode->appendText($text);
  my $newNode = $parent->addNewChild($svgURI, 'text');
##  $newNode->appendText($text);
  copy_attributes($newNode, $node, CA_OVERWRITE, qw(x y));
  #    $node->removeChildNodes;
  #    map(convertNode($newNode,$_), element_nodes($node));
  convertText($newNode,$dummynode);
  $newNode; }

sub convertCircle {
  my($parent,$node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'circle');
  copy_attributes($newNode, $node);
  rename_attribute($newNode, 'x', 'cx');
  rename_attribute($newNode, 'y', 'cy'); 
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertEllipse {
  my($parent,$node) = @_;
  my $newNode = $parent->addNewChild($svgURI, 'ellipse');
  copy_attributes($newNode, $node);
  rename_attribute($newNode, 'x', 'cx');
  rename_attribute($newNode, 'y', 'cy'); 
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertWedge {
  my($parent,$node) = @_;
  my ($x, $y, $r, $a1, $a2) = get_attr($node, qw(x y r angle1 angle2));
  my $b = $a2-$a1; $b+=360 if $b<0; $b = $b>180 ? 1 : 0; ($a1, $a2) = radians($a1,$a2);
  my ($x1, $y1, $x2, $y2) = trunc(2, $x+$r*cos($a1), $y+$r*sin($a1), $x+$r*cos($a2), $y+$r*sin($a2));
  my $newNode = $parent->addNewChild($svgURI, 'path');
  $newNode->setAttribute(d=>"M $x $y L $x1 $y1 A $r $r 0 $b 1 $x2 $y2 z");
  copy_attributes($newNode, $node, CA_OVERWRITE, qw(fill stroke stroke-width transform));
  map(convertNode($newNode,$_), element_nodes($node));
  $newNode; }

sub convertArc {
  my($parent,$node) = @_;
  my ($x, $y, $r, $a1, $a2, $sp, $stroke, $fill) = 
    get_attr($node, qw(x y r angle1 angle2 showpoints stroke fill));
  my $b = $a2-$a1; $b+=360 if $b<0; $b = $b>180 ? 1 : 0;  ($a1, $a2) = radians($a1,$a2);
  my ($x1, $y1, $x2, $y2) = trunc(2, $x+$r*cos($a1), $y+$r*sin($a1), $x+$r*cos($a2), $y+$r*sin($a2));
  my $linestroke = ($stroke || '') eq 'none' ? $fill : $stroke;

  my $newNode = $parent->addNewChild($svgURI, 'g');
  $newNode->setAttribute(transform=>$node->getAttribute('transform'));
  if (($sp || '') eq 'true') {
    my $newLine = $newNode->addNewChild($svgURI, 'path');
    $newLine->setAttribute(d=>"M $x1 $y1 $x $y $x2 $y2");
    $newLine->setAttribute(fill=>'none');
    $newLine->setAttribute('stroke-dasharray'=>'2');
    $newLine->setAttribute(stroke=>$linestroke);
    copy_attributes($newLine, $node, CA_OVERWRITE, qw(stroke-width)); }
  my $newArc = $newNode->addNewChild($svgURI, 'path');
  $newArc->setAttribute(d=>"M $x1 $y1 A $r $r 0 $b 1 $x2 $y2");
  copy_attributes($newArc, $node, CA_OVERWRITE,
		  qw(fill stroke stroke-width terminators arrowlength));
  setArrows($newArc, $linestroke);
#  map($newNode->appendChild(convertNode($_)), element_nodes($node));
  $newNode; }

#################################################################

sub getFillFrame {
  my ($fill) = @_;
  my $bgName = 'bg'.$fill; $bgName =~ s/\#//g;
  $::DEFS{$bgName} = 
    new_node($svgURI, 'filter', [new_node($svgURI, 'feFlood', undef, 'flood-color'=>$fill, 'flood-opacity'=>1, result=>'bg'),
				 new_node($svgURI, 'feMerge', [new_node($svgURI, 'feMergeNode', undef, in=>'bg'),
							       new_node($svgURI, 'feMergeNode', undef, in=>'SourceGraphic')])],
	     id=>$bgName, primitiveUnits=>'objectBoundingBox', x=>'-0.1', y=>'-0.1', width=>'1.2', height=>'1.2') unless $::DEFS{$bgName};
  $bgName;
}

sub getArrow {
  my ($fill, $type) = @_; my $ar = 'AR'.($fill || ''); $ar =~ s/\#//g;
  if ($type eq '>') {
    $ar .= '_R';
  } elsif ($type eq '<') {
    $ar .= '_L';
  }
  $::DEFS{$ar} = new_node($svgURI, 'marker', new_node($svgURI, 'path', undef, fill=>$fill, stroke=>'none',
						      d=>($type eq '>') ? 'M 0 0 L 10 5 L 0 10 L 4 5 z' : 'M 0 5 L 10 0 L 6 5 L 10 10 z'),
			  id=>$ar, viewBox=>'0 0 10 10', markerUnits=>'strokeWidth', markerWidth=>10, markerHeight=>6, orient=>'auto', refX=>4, refY=>5)
    unless $::DEFS{$ar};
  $ar;
}

sub setArrows {
  my ($node, $fill) = @_;
  return unless $node->hasAttribute('terminators');
  my $t = $node->getAttribute('terminators'); remove_attr($node, qw(terminators arrowlength));
  return unless $t =~ /([^\-]*)-(.*)/;
  my ($start, $end) = ($1, $2); 
  if ($start =~ s/(>|<)//) {
    $node->setAttribute('marker-start'=>'url(#'.getArrow($fill, $1).')');
  }
  if ($end =~ s/(>|<)//) {
    $node->setAttribute('marker-end'=>  'url(#'.getArrow($fill, $1).')');
  }
}

sub mergeTransform {
  my ($node, $new_t) = @_;
  my $old_t = $node->getAttribute('transform');
  my $t = ($old_t && $new_t) ? Transform("$new_t $old_t")->toString : 
    ($old_t ? $old_t : ($new_t ? $new_t : undef));
  $node->setAttribute(transform=>$t) if $t;
}

sub ovalPath {
  my ($opt, $x, $y, $w, $h, $r) = @_;

  my $trStart = "M ".($x+$w/2)." $y ";
  my $trContent = "L ".($x+$w-$r)." $y A $r $r 0 0 1 ".($x+$w)." ".($y-$r)." L ".($x+$w)." ".($y-$h/2)." ";
  my $tlStart = "M $x ".($y-$h/2)." ";
  my $tlContent = "L $x ".($y-$r)." A $r $r 0 0 1 ".($x+$r)." $y L ".($x+$w/2)." $y ";

  my $brStart = "M ".($x+$w)." ".($y-$h/2)." ";
  my $brContent = "L ".($x+$w)." ".($y-$h+$r)." A $r $r 0 0 1 ".($x+$w-$r)." ".($y-$h).
    " L ".($x+$w/2)." ".($y-$h)." ";
  my $blStart = "M ".($x+$w/2)." ".($y-$h)." ";
  my $blContent = "L ".($x+$r)." ".($y-$h)." A $r $r 0 0 1 $x ".($y-$h+$r)." L $x ".($y-$h/2)." ";
  my $path = '';
  if ($opt eq 't') {
    $path = $tlStart.$tlContent.$trContent;
  } elsif ($opt eq 'b') {
    $path = $brStart.$brContent.$blContent;
  } elsif ($opt eq 'l') {
    $path = $blStart.$blContent.$tlContent;
  } elsif ($opt eq 'r') {
    $path = $trStart.$trContent.$brContent;
  } elsif ($opt eq 'tr' || $opt eq 'rt') {
    $path = $trStart.$trContent;
  } elsif ($opt eq 'tl' || $opt eq 'lt') {
    $path = $tlStart.$tlContent;
  } elsif ($opt eq 'br' || $opt eq 'rb') {
    $path = $brStart.$brContent;
  } elsif ($opt eq 'bl' || $opt eq 'lb') {
    $path = $blStart.$blContent;
  }
  chop($path); $path;
}

sub boxContentPos {
  my ($node) = @_; 
  my ($nw, $nh, $npos) = get_attr($node, qw(width height pos));
  return (0,0) unless defined $nw && defined $nh;
  if (!$npos) {
    ($nw/2, $nh/2);
  } elsif ($npos eq 't') {
    ($nw/2, $nh);
  } elsif ($npos eq 'b') {
    ($nw/2, 0);
  } elsif ($npos eq 'l') {
    (0, $nh/2);
  } elsif ($npos eq 'r') {
    ($nw, $nh/2);
  } elsif ($npos eq 'tr' || $npos eq 'rt') {
    ($nw, $nh);
  } elsif ($npos eq 'tl' || $npos eq 'lt') {
    (0, $nh);
  } elsif ($npos eq 'br' || $npos eq 'rb') {
    ($nw, 0);
  } else {
    (0,0);
  }
}

sub arcPoints {
  my ($node) = @_;
  my ($pts, $r) = get_attr($node, qw(points arc));
  return 'M '.$pts if !$r && $pts; 
  local *getP = sub {
    my ($x1, $y1, $x2, $y2) = @_;
    my $dst = sqrt(($x1-$x2)**2 + ($y1-$y2)**2);
    my $s = ($x2-$x1)*($y2-$y1) >= 0 ? 1 : -1;
    trunc(2, $s, $x1 + ($x2-$x1)*$r/$dst, $y1 + ($y2-$y1)*$r/$dst); };
  my @p = explodeCoord($pts); my $n = ($#p + 1)/2;
  my $d = "M $p[0] $p[1] ";
  for (my $i = 1; $i < $n-1; $i++) {
    my ($x2, $y2) = ($p[2*$i-2], $p[2*$i-1]);
    my ($x1, $y1) = ($p[2*$i], $p[2*$i+1]);
    my ($sa, $xa, $ya) = getP($x1, $y1, $x2, $y2);
    ($x2, $y2) = ($p[2*$i+2], $p[2*$i+3]);
    my ($sb, $xb, $yb) = getP($x1, $y1, $x2, $y2);
    my $sf = ($sa >= $sb) ? 0 : 1;
    $d .= "L $xa $ya A $r $r 0 0 $sf $xb $yb ";
  }
  $d .= "L $p[2*$n-2] $p[2*$n-1]";
  $d;
}


################# Determine SVG boundary #######################

sub getSVGBounds {
  my ($node) = @_; my @boundary = ();
  map(combBoundary(\@boundary, getSVGBounds($_)), element_nodes($node));
  [SVGObjectBoundary($node, @boundary)];
}

sub SVGObjectBoundary {
  my ($node, @boundary) = @_;
  my $tag = getQName($node);
  return undef unless $tag;
  my @xs=($boundary[0], $boundary[1]), my @ys = ($boundary[2], $boundary[3]);

  if ($tag eq 'ltx:circle') {
    my ($cx, $cy, $r) = get_attr($node, qw (cx cy r));
    $r = $r*sqrt(2); push(@xs, $cx-$r,$cx+$r); push(@ys, $cy-$r,$cy+$r);
  } elsif (($tag eq 'ltx:polygon') || ($tag eq 'ltx:line')) {
    my $points = $node->getAttribute('points');
    $points =~ s/,/ /g;
    while ($points =~ s/^\s*($NR)\s+($NR)//) {
      push(@xs, $1); push(@ys,$2);
    }
  } elsif ($tag eq 'ltx:path') {
    my ($data, $mode) = ($node->getAttribute('d'), '');
    $data =~ s/,/ /g;
    while ($data) {
      if ($data =~ s/^\s*(L|l|M|m|C|c|S|s|Q|q|T|t)\s*//) {
	$mode = 'xy';
      } elsif ($data =~ s/^\s*(Z|z)\s*//) {
	$mode = '';
      } elsif ($data =~ s/^\s*(H|h)\s*//) {
	$mode = 'x';
      } elsif ($data =~ s/^\s*(V|v)\s*//) {
	$mode = 'y';
      } elsif ($data =~ s/^\s*(A|a)\s*//) {
	$mode = 'i5xy';
      } elsif ($mode eq 'x' && $data =~ s/^\s*($NR)\s*//) {
	push(@xs,$1); push(@ys, $ys[$#ys] || 0);
      } elsif ($mode eq 'y' && $data =~ s/^\s*($NR)\s*//) {
	push(@ys,$1); push(@xs, $xs[$#xs] || 0);
      } elsif (($mode eq 'xy' && $data =~ s/^\s*($NR)\s+($NR)\s*//) ||
	       ($mode eq 'i5xy' && $data =~ s/^\s*$NR\s+$NR\s+$NR
		    \s+$NR\s+$NR\s+($NR)\s+($NR)\s*//x)) {
	push(@xs,$1); push(@ys,$2);
      }
    }
  } elsif ($tag eq 'ltx:rect') {
    my ($x, $y, $w, $h) = get_attr($node, qw(x y width height));
    if (defined $x && defined $y && defined $w && defined $h) {
      push(@xs,$x, $x+$w); push(@ys,$y, $y+$h);
    }
  } elsif ($tag eq 'ltx:ellipse') {
    my ($ex, $ey, $rx, $ry) = get_attr($node, qw (cx cy rx ry));
    ($rx, $ry) = map($_*sqrt(2), ($rx, $ry)); 
    push(@xs,$ex-$rx,$ex+$rx); push(@ys,$ey-$ry,$ey+$ry);
  }
    
  @xs = grep(defined $_, @xs); @ys = grep(defined $_, @ys);
  if (my $tr = $node->getAttribute('transform')) {
    $tr = Transform($tr);
    map(($xs[$_], $ys[$_]) = $tr->apply($xs[$_], $ys[$_]), 0..$#xs);
  }
  @xs=sort {$a <=> $b} @xs; @ys=sort {$a <=> $b} @ys;
  ($xs[0], $xs[$#xs], $ys[0], $ys[$#ys]);
}

# boundary = (minX, maxX, minY, maxY)
sub combBoundary {
  my ($a, $b) = @_;
  return unless @$b;
  @$a = @$b and return unless @$a;
  $$a[0] = $$b[0] if (!defined $$a[0] || (defined $$b[0] && $$a[0]>$$b[0]));
  $$a[2] = $$b[2] if (!defined $$a[2] || (defined $$b[2] && $$a[2]>$$b[2]));
  $$a[1] = $$b[1] if (!defined $$a[1] || (defined $$b[1] && $$a[1]<$$b[1]));
  $$a[3] = $$b[3] if (!defined $$a[3] || (defined $$b[3] && $$a[3]<$$b[3]));
  return;
}

1;
