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
# General strategy for a linebreaker
# For each child, collect it's linebreaking options
# Determine all break points at this level.
# Form all choices of those breaks  (including nobreak).
# Form all sequences of 1 linebreaking option for this level and each child.
# For each such sequence,
#   compute the effective size & desirability
#
# At the top level, we'd presumably choose the most desirable
# choice that fits within the specified width.
#======================================================================
# NOTE This takes the array form for the MathML, before it has been
# converted to a proper DOM tree.

use strict;

our $DEBUG = 0;
our $INDENTATION = 1;		# the number of ems when indenting a broken row.

# TODO: Integrate default operator dictionary, and recognize attributes
# TODO: all addops, relops,
# TODO: mult ops, but less desirable
sub UTF { pack('U',$_[0]); }

our  %BREAKOPS = map(($_=>1),
		     # Various addops
		     "+","-",UTF(0xB1),"\x{2213}", # pm, mp
		     # Various relops
		     "=", "<",">", "\x{2264}","\x{2265}","\x{2260}","\x{226A}",
		     "\x{2261}","\x{223C}","\x{2243}","\x{224D}","\x{2248}","\x{2260}","\x{221D}",
		     );
our  %CONVERTOPS = ("\x{2062}"=>UTF(0xD7), # Invisible (discretionary) times
		   );

#**********************************************************************
# User-level interface
#**********************************************************************
sub new {
  my($class)=@_; 
  my $self = bless {},$class; 
  $self; }

sub fitToWidth {
  my($self,$math,$width,$displaystyle)=@_;
  my $layouts = $self->computeLayouts($math,$width,$displaystyle);
  map(showLayout($_),@$layouts) if $DEBUG;
  my $best = $$layouts[-1];
  applyLayout($math,$best);
  ($$best{width} <= $width); }

sub computeLayouts {
  my($self,$math,$width,$displaystyle)=@_;
  print STDERR "Starting layout of $math\n" if $DEBUG;
  my $layouts = layout($math,$width,0,$displaystyle, 0, 1);
  print STDERR "Done layout\n" if $DEBUG;
  $layouts; }

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

# For debugging...
sub showLayout {
  my($layout,$indent)=@_;
  $indent = 0 unless $indent;
  my $pre = (' ') x (2*$indent);
  print $pre.$$layout{type}." ".layoutDescriptor($layout)."\n";
  if($$layout{children}){
    map($$_{penalty} && showLayout($_,$indent+1),@{$$layout{children}}); }
}

sub layoutDescriptor {
  my($layout)=@_;
  $$layout{type}." "
    ."(".$$layout{width}." x ".$$layout{height}." + ".$$layout{depth}.")"
      ."@".$$layout{penalty}
	.($$layout{breakset}
	  ? ", b@".join(",",map("[".join(',',@$_)."]",@{$$layout{breakset}}))
	  : ""); }

#======================================================================
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
  my($math,$layout)=@_;
  map(applyLayout($math,$_), @{$$layout{children}} ) if $$layout{children};
  if(my $breakset = $$layout{breakset}){
    my $node = $$layout{node};
    my @children = nodeChildren($node);
    my @rows = split_row($breakset,@children);
    # Replace any "converted" leading operators (ie. invisible times => \times)
    foreach my $row (@rows[1..$#rows]){
      my $op = $$row[0];
      my $newop;
      if((localname($op) eq 'mo') && ($newop=$CONVERTOPS{textContent($op)})){
	splice(@$op,2,scalar(@$op)-2, $newop); }}
    splice(@$node,2,scalar(@children),
	   ["m:mtable",{align=>'baseline 1', columnalign=>'left'},
	    ["m:mtr",{},["m:mtd",{}, @{shift(@rows)}]],
	    map( ["m:mtr",{},["m:mtd",{}, ["m:mspace",{width=>$INDENTATION."em"}],@$_]],@rows)  ] );
  }}

# This would use <mspace> with linebreak attribute to break a row.
# Unfortunately, Mozillae ignore this attribute...
sub XXXXapplyLayout {
  my($math,$layout)=@_;
  map(applyLayout($math,$_), @{$$layout{children}} ) if $$layout{children};
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
#**********************************************************************
# Internals
#**********************************************************************
our $NOBREAK = 99999999;  # penalty=$NOBREAK means don't break at all.
our $POORBREAK= 10;	  # factor to make breaks less desirable.
our $BADBREAK = 100;	  # factor to make breaks much less desirable.

sub nodeName {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  $tag; }

sub localname {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  $tag =~ s/\w+://;
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

#**********************************************************************
# Layout determination code
#
# The current code computes pretty much every possible layout,
# which we'd select from later.
# If it turns out this is too expensive, it would be good
# to work out some kind of lazy expansion that could prune
# ridiculous layouts before computing everything, or even layouts
# that are worse than the current best for a given size.
# Of course, at this point, we don't know anything about the size
# of something till we do the full expansion, so...
#**********************************************************************
sub layout {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $name = nodeName($node);
  $name =~ s/\w://;
  my $handler = "layout_$name";
  eval { $handler = \&$handler; };
  print STDERR "",('  ' x $level),"$name: ",$node,"...\n" if $DEBUG;
  my $layouts = &$handler($node,$target,$level, $displaystyle||0, $scriptlevel||0, $demerits||1); 
  my $nlayouts = scalar(@$layouts);
  my @layouts = prunesort($target,@$layouts);
  my $pruned = scalar(@layouts);

  print STDERR "",('  ' x $level),"$name: $nlayouts layouts"
    .($pruned < $nlayouts ? " pruned to $pruned":"")
      ." ".layoutDescriptor($$layouts[0])
	.($nlayouts > 1 ? "...".layoutDescriptor($$layouts[$nlayouts-1]) : "")
      ."\n" if $DEBUG;
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

sub minwidth {
  my($layouts)=@_;
  my $w = $$layouts[0]{width};
  foreach my $layout (@$layouts){
    $w = min($w,$$layout{width}); }
  $w; }

#======================================================================
# Given a list of arrays of layouts, representing the possible layouts of
# each of the children of a node, multiplex them to return a list of
# arrays containing one layout choice for each child.
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

#======================================================================
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
# Here, of course, is where the Interesting stuff will happen.

sub asRow {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my @children = nodeChildren($node);
  if(grep( ref $_ ne 'ARRAY', @children)){
    die "ROW has non-element: ".nodeName($node); }

  # Multiple children, possibly with breaks
  my @child_layouts = map(layout($_,$target,$level+1,$displaystyle,$scriptlevel,$demerits),
			  @children);
  my @children_layouts = multiplex(@child_layouts);

  # Now, we need all possible break points within the row.
  my $n = scalar(@children);
  my @breaks = ();
  if($demerits < $NOBREAK){
    for(my $i=1; $i<$n-1; $i++){
      my $child = $children[$i];
      my $content = (localname($child) eq 'mo') && textContent($child);
      push(@breaks, [$i,$content]) if $content && ($BREAKOPS{$content} || $CONVERTOPS{$content}); }}
  my @breaksets = choices(@breaks);

  print STDERR "",("  " x $level), "mrow ",
      join("x", map(scalar(@$_),@child_layouts))," layouts",
	(@breaks
	 ? ", breaks@".join(",",map("[".join(',',@$_)."]",@breaks))."(".scalar(@breaksets)." sets)"
	 : "")."\n"
    if $DEBUG;

  my @layouts = ();
  # For each set of breaks within the row and for each set of sizings of children
  BREAKS: foreach my $breakset (@breaksets){
      foreach my $children_layout (@children_layouts){
	my($width,$height,$depth,$penalty,$indent)=(0,0,0,0,0);
	$penalty = - $demerits;
	foreach my $line (split_row($breakset,@$children_layout)){
	  my($w,$h,$d)=(0,0,0);
	  $penalty+= $demerits;
	  my @kids = @$line;
	  while(@kids){		# For each line of nodes, compute sizes, possibly prune
	    my $layout = shift(@kids);
	    $w += $$layout{width};
	    $penalty += $$layout{penalty}; 
	    # Last (best) layout, for comparison & pruning
	    my $last = (@layouts  && $layouts[$#layouts]);
	    # MTABLE HACK: Don't want a broken child unless it is LAST in the line.
	    $penalty += 1000*$demerits if @kids && $$layout{breakset};
	    # Skip if too wide, or worse than previous
	    next BREAKS
	      if $last && (($w > $target) 
			   || ($$last{width} < $target) && ($penalty > $$last{penalty}));
	    $h = max($h,$$layout{height});
	    $d = max($d,$$layout{depth});
	  }
	  # Then combine the lines
	  $width = max($width,$w+$indent);
	  $indent = $INDENTATION;
	  if($height == 0){
	    $height = $h;
	    $depth  = $d; }
	  else {
	    $depth += $h + $d; }}
	push(@layouts, { node=>$node,type=>nodeName($node),
			 penalty=>$penalty, width=>$width, height=>$height, depth=>$depth,
			 (scalar(@$breakset) ? (breakset=>$breakset):()),
			 children=>[@$children_layout]});
	@layouts = prunesort($target,@layouts); }}
  print STDERR "Warning! row got no layouts!!!\n" unless @layouts;
  [@layouts]; }

sub choices {
  my(@choices)=@_;
  if(@choices){
    my $i = shift(@choices);
    map( ($_,[$i,@$_]),choices(@choices)); }
  else { ([]); }}

sub split_row {
  my($breakset,@stuff)=@_;
  my @lines=();
  my $pos=0;
  foreach my $break (@$breakset){
    my($breakpos,$note)=@$break;
    push(@lines, [ @stuff[$pos..$breakpos-1] ]);
    $pos = $breakpos; }
  push(@lines, [ @stuff[$pos..$#stuff] ]);
  @lines; }

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

#======================================================================
# Tables (ugh)
# No breaks within tables, but still have a mess of sums & max's
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

#sub layout_mtr {}
#sub layout_mlabeledtr {}
sub layout_mtd { asRow(@_); }
#======================================================================
sub layout_mfrac {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  # No break of mfrac itself
  # 2 children; break of children is poor
  [map( { node=>$node, type=>'mfrac',
	  penalty => $$_[0]->{penalty} + $$_[1]->{penalty},
	  width   => max($$_[0]->{width},$$_[1]->{width}),
	  height  => $$_[0]->{height} + $$_[0]->{depth} + 1,
	  depth   => $$_[1]->{height} + $$_[1]->{depth},
	  children=>$_},
	multiplex(map( layout($_, $target,$level+1,0 ,$scriptlevel, $demerits*$POORBREAK),
		       nodeChildren($node))))]; }

sub layout_mroot {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  # no break of mroot itself, index doesn't break, break of base is bad
  my ($base,$index) = nodeChildren($node);
  my $indexlayout = layout($index,$target,$level+1, 0 ,$scriptlevel+1, $NOBREAK)->[0];
  $target -= $$indexlayout{width};
  my $baselayouts  = layout($base, $target,$level+1, 0 ,$scriptlevel,   $demerits*$BADBREAK);
  [map( { node=>$node, type=>'mroot',
	  penalty => $$_[0]->{penalty} + $$_[1]->{penalty},
	  width   => $$_[0]->{width} + $$_[1]->{width},
	  height  => $$_[0]->{height},
	  depth   => $$_[0]->{depth},
	  children => $_},
	multiplex($baselayouts,[$indexlayout]))]; }

sub layout_msqrt {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  # no break of msqrt itself,
  # 1 child or implied mrow; bad to break
  asRow($node,$target,$level+1,$displaystyle,$scriptlevel,$demerits*$BADBREAK); }

#======================================================================
# TODO: What about movablelimits, accent on base ?
sub asScripts {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits,
     $stacked,$basenode,@scriptnodes)=@_;
  # Scripts do not break, base is poor to break.
  my @layouts = ();
  foreach my $layoutset (multiplex(layout($basenode,$target,$level+1,
					  $displaystyle,$scriptlevel,$demerits*$POORBREAK),
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
  @scripts = grep( localname($_) ne "mprescripts", @scripts); # Remove prescripts marker (if any).
  asScripts($node,$target,$level,$displaystyle,$scriptlevel,$demerits, 0,$base,@scripts); }

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
1;
