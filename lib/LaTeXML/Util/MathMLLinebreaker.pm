# /=====================================================================\ #
# |  LaTeXML::Util::MathMLLinebreaker                                   | #
# | MathML generator for LaTeXML                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::MathMLLinebreaker;
#======================================================================
# General MathML Line-Breaking Strategy.
#
# (1) Preparations: if top-level has trailing punctuation,
#    remove it to be added back, later.
#
# (2) Find all layouts that fit within a specified width.
#    This is done top-down by finding possible breaks within the current
#    node, along with (recursively) the possible layouts for children.
#    The pattern of possible breaks and which children are allowed to break
#    depends on the tag of the current node; eg. sub/superscripts don't break.
#    [handlers for each tag are defined at end of file]
#
#    Each combination of these breaks is then considered by
#    computing the effective size & penalty.
#    The penalty is generally determined by the number of breaks,
#    but possibly weighted.
#
#    These layouts are sorted in increasing width, and increasing penalty
#    for a given width. Layouts which are too wide, or have higher penalty
#    than the previous layout are pruned.
#
# (3) Apply the breaks specified by the best layout.
#     The last layout in a list of layouts will be the best in the sense
#     that it is the longest layout not longer than the target width,
#     and has least penalty of its width.
#======================================================================
# NOTE This takes the array form for the MathML, before it has been
# converted to a proper DOM tree.

use strict;

#######################################################################
# Parameters
#######################################################################
our $DEBUG = 0;
our $NOBREAK = 99999999;  # penalty=$NOBREAK means don't break at all.
our $POORBREAK_FACTOR= 10;	  # to make breaks less desirable.
our $BADBREAK_FACTOR = 100;	  # to make breaks much less desirable.
our $CONVERSION_FACTOR = 5;	  # to make breaks at converted ops less desirable

# TODO: Integrate default operator dictionary, and recognize attributes
# TODO: all addops, relops,
# TODO: mult ops, but less desirable
sub UTF { pack('U',$_[0]); }

our  %BREAKOPS = map(($_=>1),
		     # Various addops
		     "+","-",UTF(0xB1),"\x{2213}", # pm, mp
		     );
our  %RELATIONOPS = map(($_=>1),
		     # Various relops
		     "=", "<",">", "\x{2264}","\x{2265}","\x{2260}","\x{226A}",
		     "\x{2261}","\x{223C}","\x{2243}","\x{224D}","\x{2248}","\x{2260}","\x{221D}",
		     );
our  %CONVERTOPS = ("\x{2062}"=>UTF(0xD7), # Invisible (discretionary) times
		   );
binmode(STDOUT,":utf8") if $DEBUG;

#######################################################################
# Top-level interface
#######################################################################

sub new {
  my($class)=@_; 
  my $self = bless {},$class; 
  $self; }

sub fitToWidth {
  my($self,$math,$mml,$width,$displaystyle)=@_;
  # Check for end punctuation; Remove it, if found.
  my @n;
  local $LaTeXML::MathMLLineBreaker::MATH = $math;
  local $LaTeXML::MathMLLineBreaker::PUNCT = undef;
  if((nodeName($mml) eq 'm:mrow') && (scalar(@n=nodeChildren($mml))==2)
     && (nodeName($n[1]) eq 'm:mo') && (textContent($n[1]) =~ /^[\.\,\;]$/)){
    $mml = $n[0];
    $LaTeXML::MathMLLineBreaker::PUNCT = $n[1]; }

  # Compute the possible layouts
  print STDERR "Starting layout of $mml\n" if $DEBUG;
  my $layouts = layout($mml,$width,0,$displaystyle,0,1);
  if($DEBUG){
    print STDERR "Got ".scalar(@$layouts)." layouts:\n";
    map(showLayout($_),@$layouts); }

  # Apply the best layout
  my $best = $$layouts[-1];
  # Is there a case where $best is so bad we shouldn't even apply it?
  applyLayout($best);
  # If nobody has yet eaten the punctuation, add it back on.
  if($LaTeXML::MathMLLineBreaker::PUNCT){
    $mml = ['m:mrow',{},$mml,$LaTeXML::MathMLLineBreaker::PUNCT]; }

  Warn("Got width $$best{width} > $width") if $$best{width} > $width+1;
  $mml; }

sub Warn {
  my($message)=@_;
  my $p = $LaTeXML::MathMLLineBreaker::MATH;
  while($p && !$p->hasAttribute('xml:id')){
    $p=$p->parentNode; }
  my $id = $p && $p->getAttribute('xml:id')||'?';
  my $nm = $p && $p->getAttribute('refnum')||'';
  print STDERR "Warning in MathMLLinebreaker for math in $nm (id=$id):\n  $message\n"; }


#######################################################################
# Apply the breaks described in a layout to the MathML.
#######################################################################
# Modify the mathml to incorporate a set of breaks.

# This strategy uses mtable.
# NOTE: There's an alignment issue.
# In principle, a row could be broken that resides within another row.
# In such a case, you'd want the table to align the 1st row's baseline to the material
# on the left, but the material following should align to the last row's baseline!!!
# MathML spec doesn't give any way of saying that!
# So, currently, we've got code in asRow that forbids a break within anything
# but the _LAST_ item within a line.
sub applyLayout {
  my($layout)=@_;
  return unless $$layout{hasbreak};
  # Do children first, so if there is punctuation & last child breaks, it can take up the punct.
  if($$layout{children}){
    my @children_layout = @{$$layout{children}};
    my $lastchild = pop(@children_layout);
    { local $LaTeXML::MathMLLineBreaker::PUNCT = undef; # Hide from all but last child
      map(applyLayout($_), @children_layout); }
    # Now, do last child; Maybe it will absorb the punctuation!
    applyLayout($lastchild); }
  # Now break up the current level.
  if(my $breakset = $$layout{breakset}){
#    print "Applying ".layoutDescriptor($layout)."\n";
    my $node = $$layout{node};
    my @children = nodeChildren($node);
    # If this is a fenced row, we've got to manually fixup the fence size!
    if(nodeName($node) eq 'm:mrow'){
      if((nodeName($children[0]) eq 'm:mo')
	 && (textContent($children[0]) =~ /[\(\)\[\]\{\}]/)){
	$children[0][1]{mathsize}=$$layout{rowheight}."em"; }
      if((nodeName($children[$#children]) eq 'm:mo')
	 && (textContent($children[$#children]) =~ /[\(\)\[\]\{\}]/)){
	$children[$#children][1]{mathsize}=$$layout{rowheight}."em"; }
    }
    my @rows = split_row($breakset,@children);
    # Replace any "converted" leading operators (ie. invisible times => \times)
    foreach my $row (@rows[1..$#rows]){
      my $op = $$row[0];
# print STDERR "  Split at ".textContent($op)."\n";
      my $newop;
      if((nodeName($op) eq 'm:mo') && ($newop=$CONVERTOPS{textContent($op)})){
	splice(@$op,2,scalar(@$op)-2, $newop); }}
    if($LaTeXML::MathMLLineBreaker::PUNCT){
      $rows[$#rows] = [@{$rows[$#rows]},$LaTeXML::MathMLLineBreaker::PUNCT];
      $LaTeXML::MathMLLineBreaker::PUNCT = undef; }

    my @firstrow = @{shift(@rows)};
    splice(@$node,2,scalar(@children),
	   ($$layout{lhs_pos}
	    ? ["m:mtable",{align=>'baseline 1', columnalign=>'left'},
	       ["m:mtr",{},
		["m:mtd",{}, @firstrow[0..$$layout{lhs_pos}-1]],
		["m:mtd",{}, @firstrow[$$layout{lhs_pos}..$#firstrow]]],
	       map( ["m:mtr",{},
		     ["m:mtd",{}],
		     ["m:mtd",{},@$_]],	@rows)]
	    : ["m:mtable",{align=>'baseline 1', columnalign=>'left'},
	       ["m:mtr",{},["m:mtd",{}, @firstrow]],
	       map( ["m:mtr",{},
		     ["m:mtd",{}, ["m:mspace",{width=>$$layout{indentation}."em"}],@$_]],@rows)]));
  }}

# This would use <mspace> with linebreak attribute to break a row.
# Unfortunately, Mozillae ignore this attribute...
sub XXXXapplyLayout {
  my($layout)=@_;
  map(applyLayout($_), @{$$layout{children}} ) if $$layout{children};
  if(my $breakset = $$layout{breakset}){
    my $node = $$layout{node};
    my @children = nodeChildren($node);
    my @lines = 
    my @newchildren = ();
    foreach my $line (split_row($breakset,@children)){
      push(@newchildren,["m:mspace",{linebreak=>"indentingnewline"}]) if @newchildren;
      push(@newchildren,@$line); }
    splice(@$node,2,scalar(@children), @newchildren);
  }}

#######################################################################
# Utilities & Debugging aids
#######################################################################

sub nodeName {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  $tag; }

sub getAttribute {
  my($node,$key)=@_;
  my($tag,$attr,@children)=@$node;
  $$attr{$key}; }

sub nodeChildren {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  @children; }

sub textContent {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  join('',@children); }

sub min { (!defined $_[0] ? $_[1] : (!defined $_[1] ? $_[0] : ($_[0] < $_[1] ? $_[0] : $_[1]))); }
sub max { (!defined $_[0] ? $_[1] : (!defined $_[1] ? $_[0] : ($_[0] > $_[1] ? $_[0] : $_[1]))); }

sub describeLayouts {
  my($self,$layouts)=@_;
  my @layouts = @$layouts;
  my $min = $layouts[0];
  my $max = $layouts[-1];
  print "Layout ".scalar(@layouts)." layout options\n"
    ."  best = $$max{width} x ($$max{height} + $$max{depth}) penalty = $$max{penalty}\n"
      ."  narrowest = $$min{width} x ($$min{height} + $$min{depth})  penalty = $$min{penalty}\n"; 
  showLayout($max);
}

sub showLayout {
  my($layout,$indent,$pos)=@_;
  $indent = 0 unless $indent;
  my $pre = (' ') x (2*$indent).(defined $pos ? "[$pos] ":"");
  print $pre.layoutDescriptor($layout)."\n";
  if($$layout{children}){
    my $p = 0;
    foreach my $child (@{$$layout{children}}){
      showLayout($child,$indent+1,$p) if $$child{penalty}; 
      $p++; }}
}

sub layoutDescriptor {
  my($layout)=@_;
  $$layout{type}." "
    ."(".$$layout{width}." x ".$$layout{height}." + ".$$layout{depth}.")"
      ."@".$$layout{penalty}
	.($$layout{breakset}
	  ? ", b@".join(",",map("[".join(',',@$_)."]",@{$$layout{breakset}}))
	  : ""); }

#######################################################################
# Permutation things
#######################################################################
# multiplex(@layouts)
#   Given a list of layouts arrays, (each representing the possible layouts of
# each of the children of a node), multiplex them to return a list of
# arrays containing one layout choice for each child.
# That is to say, form all combinations choosing one $layout
# from each of the $layouts lists in @layouts.
sub multiplex {
  my($layouts,@siblings_layouts)=@_;
  if(@siblings_layouts){
    my @multiplexed_siblings_layouts = multiplex(@siblings_layouts);
    my @multiplexed = ();
    foreach my $layout (@$layouts){
      foreach my $multiplexed_sibling_layout (@multiplexed_siblings_layouts){
	push(@multiplexed, [$layout,@$multiplexed_sibling_layout]); }}
    @multiplexed; }
  else {
    map([$_],@$layouts); }}

# Given a list of break's (in order), form all choices of breaks.
sub choices {
  my(@breaks)=@_;
  if(@breaks){
    my $break = shift(@breaks);
    map( ($_,[$break,@$_]),choices(@breaks)); }
  else { ([]); }}

#######################################################################
# Layout determination code
#######################################################################
# The current code computes pretty much every possible layout,
# which we'd select from later.
# If it turns out this is too expensive, it would be good
# to work out some kind of lazy expansion that could prune
# ridiculous layouts before computing everything, or even layouts
# that are worse than the current best for a given size.
# Of course, at this point, we don't know anything about the size
# of something till we do the full expansion, so...
#======================================================================
# "layouts"  == [ layout, ...]
#        represents a list of layout descriptors representing possible
#        arrangements & breakpoints for a given node.
#        Generally sorted by increasing width, and increasing penalty
# "layout" aka layout descriptor
#        is a hash describing a possible layout arrangment.
#     The fields are:
#            node  == the node that this layout applies to.
#            type  == the tag name of the node, for convenience & debugging.
#            width  == width of this layout (in extremely rough ems)
#            height == height of this layout box above baseline
#            depth  == depth below baseline
#            penalty == undesirability of this layout
#            children == [ layout, ...]
#                being the layout descriptor for each child
#            breakset == [ break,...]
#                being a list of points to break at
#            hasbreak = 1 if this node, or any children have a line-break.
# break = [pos,content,demerit]  where pos is the (0 based) index of a breakpoint
#               ie. make child[pos] start the next line.
#======================================================================
sub layout {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;

  # Get the Handler for this tag
  my $name = nodeName($node);
  $name =~ s/\w://;
  my $handler = "layout_$name";
  eval { $handler = \&$handler; };
  print STDERR "",('  ' x $level),"layout $name: ",$node,"...\n" if $DEBUG > 1;

  # Get the handler to compute the layouts
  my $layouts = &$handler($node,$target,$level, $displaystyle||0, $scriptlevel||0, $demerits||1); 
  my $nlayouts = scalar(@$layouts);

  # Sort & prune the layouts
  my @layouts = prunesort($target,@$layouts);
  my $pruned = scalar(@layouts);

  print STDERR "",('  ' x $level),"$name: $nlayouts layouts"
    .($pruned < $nlayouts ? " pruned to $pruned":"")
      ." ".layoutDescriptor($$layouts[0])
	.($nlayouts > 1 ? "...".layoutDescriptor($$layouts[$nlayouts-1]) : "")
      ."\n" if $DEBUG > 1;
  [@layouts]; }

sub prunesort {
  my($target,@layouts)=@_;
  @layouts = sort { ($$a{width} <=> $$b{width}) || ($$a{penalty} <=> $$b{penalty}) } @layouts; 
  my @goodlayouts= ( shift(@layouts) ); # always include at least the shortest/best
  foreach my $layout (@layouts){
    if(($$layout{width} < $target) # If not too wide
       && ($goodlayouts[$#goodlayouts]->{penalty} > $$layout{penalty})){ # not worse than prev
      push(@goodlayouts,$layout); }}
  @goodlayouts; }

#######################################################################
# Row line breaker.
# This is the real workhorse.
#######################################################################
# Here, of course, is where the Interesting stuff will happen.

sub asRow {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $type = nodeName($node);
  my @children = nodeChildren($node);
  if(grep( ref $_ ne 'ARRAY', @children)){
    die "ROW has non-element: ".nodeName($node); }
  my $n = scalar(@children);
  if(!$n){
    return [ { node=>$node, type=>$type,
	       penalty=>0, width   => 0, height  => 0, depth=> 0} ]; }

  # Multiple children, possibly with breaks
  # Get the set of layouts for each child
  my @child_layouts = map(layout($_,$target,$level+1,$displaystyle,$scriptlevel,$demerits),
			  @children);

  # Now, we need all possible break points within the row itself.
  my @breaks = ();
  my ($lhs_pos,$lhs_width);
  if($demerits < $NOBREAK){
    for(my $i=1; $i<$n-1; $i++){
      my $child = $children[$i];
      my $content = (nodeName($child) eq 'm:mo') && textContent($child);
      if(!$content){}
      elsif($RELATIONOPS{$content}){
	push(@breaks, [$i,$content,$demerits]); 
	if(! defined $lhs_pos){
	  $lhs_pos = $i;
	  $lhs_width = sum(map($$_[-1]{width}, @child_layouts[0..$i-1]));
	  $lhs_pos = 0 if $lhs_width > $target/4; }}
      elsif($BREAKOPS{$content}){
	$lhs_pos = 0;
	push(@breaks, [$i,$content,$demerits]); }
      elsif($CONVERTOPS{$content}){
	$lhs_pos = 0;
	push(@breaks, [$i,$content,$demerits*$CONVERSION_FACTOR]); }
    }}
  my $indentation = ($lhs_pos ? $lhs_width : 2);

  # Form the set of all choices from the breaks.
  my @breaksets = choices(@breaks);

  print STDERR "",("  " x $level), $type," ",
      join("x", map(scalar(@$_),@child_layouts))," layouts",
	(@breaks
	 ? ", breaks@".join(",",map("[".join(',',@$_)."]",@breaks))
	 ."(".scalar(@breaksets)." sets;"
	 .    product(map(scalar(@$_),@child_layouts),scalar(@breaksets))." combinations"
	 .")"
	 : "")."\n"
    if $DEBUG > 1;

  my @layouts = ();
  # For each set of breaks within this row
  # And for each layout of children
  # Form composite layouts, computing the size, penalty, and pruning.
  # NOTE: Would we like to prefer more evenly balanced splits?
  my $pruned=0;
BREAKSET:  foreach my $breakset (reverse @breaksets){ # prunes better reversed?
    # Since we only allow to break the last child in a row,
    # form subset of children's layouts
    # Namely, take only last (unbroken?) layout for all but last child in each row
    my @filtered_child_layouts=();
    foreach my $xline (split_row($breakset,@child_layouts)){
      my @xline_children_layouts = @$xline;
      while(@xline_children_layouts){
	my $xchild_layouts = shift(@xline_children_layouts);
	if(@xline_children_layouts){ # More children?
	  my @x = @$xchild_layouts;
	  my $last = $x[$#x];
	  next BREAKSET if $$last{hasbreak};
	  push(@filtered_child_layouts,[$last]); } # take last
	else {
	  push(@filtered_child_layouts,$xchild_layouts); }}}
    my @children_layouts = multiplex(@filtered_child_layouts);

  LAYOUT: foreach my $children_layout (@children_layouts){
	my($width,$height,$depth,$penalty,$indent,$rowheight)=(0,0,0,0,0,0);
	$penalty = sum(map($$_[2],@$breakset));
	# Last (best) layout, for comparison & pruning
	my $last = (@layouts  && $layouts[$#layouts]);
	# Apply the breaks to split the children (actually their layout) into lines.
	foreach my $line (split_row($breakset,@$children_layout)){
	  my($w,$h,$d)=(0,0,0);
	  my @line_children_layout = @$line;
	  while(@line_children_layout){	# For each line of nodes, compute sizes, possibly prune
	    my $child_layout = shift(@line_children_layout);
	    $w += $$child_layout{width};
	    $penalty += $$child_layout{penalty}||0; 
	    # Skip to next breakset if we've gotten too wide, or worse than previous
 	    if($last && (($w > 1.5*$target) 
  #			 || (($$last{width} < 1.5*$target) && ($penalty > $$last{penalty})))){
			 || (($$last{width} <= $w) && ($penalty > $$last{penalty})))){
	      $pruned++;
	      next LAYOUT; }

	    $h = max($h,$$child_layout{height});
	    $d = max($d,$$child_layout{depth});
	  }
	  # Then combine the lines
	  $width = max($width,$w+$indent);
	  $indent = $indentation;
	  if($height == 0){
	    $height = $h;
	    $depth  = $d; }
	  else {
	    $depth += $h + $d; }
	  $rowheight = max($rowheight,$h+$d); }
	push(@layouts, { node=>$node,type=>$type,
			 penalty=>$penalty,
			 width=>$width, height=>$height, depth=>$depth, 
			 indentation=>$indentation, rowheight=>$rowheight, lhs_pos=>$lhs_pos,
			 (scalar(@$breakset) ? (breakset=>$breakset):()),
			 hasbreak=>scalar(@$breakset)||scalar(grep($$_{hasbreak},@$children_layout)),
			 children=>[@$children_layout]});
	@layouts = prunesort($target,@layouts); }}
##      }}
##  @layouts = prunesort($target,@layouts);

##  print STDERR "",("  " x $level), $type," pruned $pruned\n" if $pruned && ($DEBUG>1);
  Warn("Row (".nodeName($node).") got no layouts!") unless @layouts;
  [@layouts]; }

sub split_row {
  my($breakset,@stuff)=@_;
  my @lines=();
  my $pos=0;
  foreach my $break (@$breakset){
    my($breakpos,$content,$demerit)=@$break;
    push(@lines, [ @stuff[$pos..$breakpos-1] ]);
    $pos = $breakpos; }
  push(@lines, [ @stuff[$pos..$#stuff] ]);
  @lines; }

#######################################################################
# Layout handlers for various MathML tags
# These are called layout_<tag>
#######################################################################

#======================================================================
# Trivial cases.
#======================================================================
# These are just empty.
sub layout_none {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $content = textContent($node);
  $scriptlevel = min(0,max($scriptlevel,3));
  [ { node=>$node, type=>"none",
      penalty=>0, width   => 0, height  => 0, depth=> 0} ]; }

sub layout_empty {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $content = textContent($node);
  $scriptlevel = min(0,max($scriptlevel,3));
  [ { node=>$node, type=>"empty",
      penalty=>0, width   => 0, height  => 0, depth=> 0} ]; }

#======================================================================
# Simple cases.
#======================================================================
# These are just simple boxes that don't break.
# Approximate their size.

our @SIZE=(1.0, 0.71, 0.71*0.71,0.71*0.71*0.71);
# TODO: spacing ?
# TODO for mo:  largeop ?
sub simpleSize {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $content = textContent($node);
  $scriptlevel = min(0,max($scriptlevel,3));
  [ { node=>$node, type=>nodeName($node), penalty=>0,
      width   => length($content)*$SIZE[$scriptlevel],
      height  => $SIZE[$scriptlevel],
      depth=> 0} ]; }

sub layout_mi     { simpleSize(@_); }
sub layout_mo     { simpleSize(@_); }
sub layout_mn     { simpleSize(@_); }
sub layout_mtext  { simpleSize(@_); }
sub layout_merror { simpleSize(@_); }

#======================================================================
# Various row-line things.
#======================================================================
sub layout_mrow     { asRow(@_); }
sub layout_mpadded  { asRow(@_); }
sub layout_mphantom { asRow(@_); }
sub layout_menclose { asRow(@_); }
sub layout_mfenced  { asRow(@_); } # Close enough?

sub layout_maction { 
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $selection = getAttribute($node,'selection') || 0;
  my @children = nodeChildren($node);
  layout($children[$selection],$target,$level,$displaystyle,$scriptlevel,$demerits); }

sub layout_mstyle  { 
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  if(my $d = getAttribute($node,'displaystyle')){
    $displaystyle = ($d eq 'true'); }
  if(my $s = getAttribute($node,'scriptlevel')){
    if   ($s =~ /^\+(\d+)$/){ $scriptlevel += $1; }
    elsif($s =~ /^\-(\d+)$/){ $scriptlevel -= $1; }
    elsif($s =~ /^(\d+)$/ ){ $scriptlevel  = $1; }}  
  asRow($node,$target,$level,$displaystyle, $scriptlevel,$demerits); }

#======================================================================
# Fractions & Roots
#======================================================================
# These allow the children to break, but with heavier penalty.

sub layout_mfrac {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  # No break of mfrac itself
  # 2 children; break of children is poor
  [map( { node=>$node, type=>'mfrac',
	  penalty => $$_[0]->{penalty} + $$_[1]->{penalty},
	  width   => max($$_[0]->{width},$$_[1]->{width}),
	  height  => $$_[0]->{height} + $$_[0]->{depth} + 1,
	  depth   => $$_[1]->{height} + $$_[1]->{depth},
	  hasbreak => $$_[0]->{hasbreak} || $$_[1]->{hasbreak},
	  children=>$_},
	multiplex(map( layout($_, $target,$level+1,0 ,$scriptlevel, $demerits*$POORBREAK_FACTOR),
		       nodeChildren($node))))]; }

sub layout_mroot {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  # no break of mroot itself, index doesn't break, break of base is bad
  my ($base,$index) = nodeChildren($node);
  my $indexlayout = layout($index,$target,$level+1, 0 ,$scriptlevel+1, $NOBREAK)->[0];
  $target -= $$indexlayout{width};
  my $baselayouts  = layout($base, $target,$level+1, 0 ,$scriptlevel,   $demerits*$BADBREAK_FACTOR);
  [map( { node=>$node, type=>'mroot',
	  penalty => $$_[0]->{penalty} + $$_[1]->{penalty},
	  width   => $$_[0]->{width} + $$_[1]->{width},
	  height  => $$_[0]->{height},
	  depth   => $$_[0]->{depth},
	  hasbreak => $$_[0]->{hasbreak} || $$_[1]->{hasbreak},
	  children => $_},
	multiplex($baselayouts,[$indexlayout]))]; }

sub layout_msqrt {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  # no break of msqrt itself,
  # 1 child or implied mrow; bad to break
  asRow($node,$target,$level+1,$displaystyle,$scriptlevel,$demerits*$BADBREAK_FACTOR); }

#======================================================================
# Tables
#======================================================================
# We're not allowing breaks within tables, but we still have a mess of sums & max's

sub layout_mtable {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my @widths=();
  my @heights=();
  my @depths=();
  foreach my $row (nodeChildren($node)){
    my ($h,$d)=(0,0);
    my $i = 0;
    foreach my $col (nodeChildren($row)){
      my $layout = layout($col,$target,$level+1, 0 ,$scriptlevel+1, $NOBREAK)->[0];
      $widths[$i] = max($widths[$i] || 0, $$layout{width});
      $h = max($h,$$layout{height});
      $d = max($d,$$layout{depth}); 
      $i++; }
    push(@heights,$h); push(@depths,$d); }
  my $width = sum(@widths);
  my($height,$depth);
  my $align = getAttribute($node,'align') || 'axis';
  my $n = scalar(@heights);
  if($align =~ s/(\d+)//){
    my $i = $1;
    ($height,$depth) = tableVAlignment($align,$heights[$i-1],$depths[$i-1]);
    $height += sum(@heights[0..$i-2])  + sum(@depths[0..$i-2])  if $i > 1;
    $depth  += sum(@heights[$i..$n-1]) + sum(@depths[$i..$n-1]) if $i < $n;  }
  else {
    $height = (sum(@heights)+sum(@depths))/2; $depth = $height;
    ($height,$depth) = tableVAlignment($align,$height,$depth); }
  [ { node=>$node, type=>nodeName($node),
      penalty => 0, width => $width, height => $height, depth => $depth} ]; }

sub tableVAlignment {
  my($align,$height,$depth)=@_;
  if   ($align eq 'top')     { $depth = $height+$depth;    $height = 0; }
  elsif($align eq 'bottom')  { $height= $height+$depth;    $depth  = 0; }
  elsif($align eq 'center')  { $height=($height+$depth)/2; $depth  = $height; }
  elsif($align eq 'axis')    { $height=($height+$depth)/2; $depth  = $height; }
  elsif($align eq 'baseline'){}
  ($height,$depth); }

sub sum { 
  my(@x)=@_;
  my $sum = 0;
  foreach my $x (@x) {
    $sum += $x || 0; }
  $sum; }

sub product { 
  my(@x)=@_;
  my $prod = 1;
  foreach my $x (@x) {
    $prod *= $x || 1; }
  $prod; }

#sub layout_mtr {}
#sub layout_mlabeledtr {}
sub layout_mtd { asRow(@_); }

#======================================================================
# Various sub & super scripts
#======================================================================
# TODO: What about movablelimits, accent on base ?
sub asScripts {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits,
     $stacked,$basenode,@scriptnodes)=@_;
  # Scripts do not break, base is poor to break.
  my @layouts = ();
  foreach my $layoutset (multiplex(layout($basenode,$target,$level+1,
					  $displaystyle,$scriptlevel,$demerits*$POORBREAK_FACTOR),
				   map(layout($_,$target,$level+1,0,$scriptlevel+1,$NOBREAK),
				       @scriptnodes))){
    my($base,@scripts)=@$layoutset;
    my($width,$height,$depth,$penalty)=(0,0,0,0);
    while(@scripts){
      my $sub = shift(@scripts);
      my $sup = shift(@scripts);
      $width  += max($$sub{width},$$sup{width});
      $height += max($height,$$sup{depth}+$$sup{height}); # Roughly..
      $depth  += max($depth, $$sub{depth}+$$sub{height});
      $penalty+= $$sub{penalty}+$$sup{penalty}; }
    $penalty += $$base{penalty};
    if($stacked){
      $width   = max($width,$$base{width});
      $height += $$base{height};
      $depth  += $$base{depth}; }
    else {
      $width  += $$base{width};
      $height  = $$base{height} + 0.5*$height;
      $depth   = $$base{depth}  + 0.5*$depth; }
    push(@layouts,{ node=>$node, type=>nodeName($node),
		    penalty => $penalty, width => $width, height => $height, depth => $depth,
		    hasbreak => scalar(grep($$_{hasbreak}, @$layoutset)),
		    children => $layoutset}); }
  [@layouts]; }

sub layout_msub {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,$sub)=nodeChildren($node);
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 0,$base,$sub,['m:none']); }

sub layout_msup {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,$sup)=nodeChildren($node);
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 0,$base,['m:none'],$sup); }

sub layout_msubsup {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,$sub,$sup)=nodeChildren($node);
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 0,$base,$sub,$sup); }

sub layout_munder {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,$sub)=nodeChildren($node);
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 1,$base,$sub,['m:none']); }

sub layout_mover {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,$sup)=nodeChildren($node);
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 1,$base,['m:none'],$sup); }

sub layout_munderover {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,$sub,$sup)=nodeChildren($node);
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 1,$base,$sub,$sup); }

sub layout_mmultiscripts {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my($base,@scripts)=nodeChildren($node);
  @scripts = grep( nodeName($_) ne "m:mprescripts", @scripts); # Remove prescripts marker (if any).
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 0,$base,@scripts); }

#======================================================================
1;
