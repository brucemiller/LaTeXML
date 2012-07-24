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
our $POORBREAK_FACTOR= 20;	  # to make breaks less desirable.
our $BADBREAK_FACTOR = 100;	  # to make breaks much less desirable.
#our $PENALTY_OK    = 10;
our $PENALTY_OK    = 5;
our $PENALTY_LIMIT = 1000;	  # worst penalty we'll tolerate; prune anything above.
our $CONVERSION_FACTOR = 2;	  # to make breaks at converted ops less desirable

# TODO: Integrate default operator dictionary, and recognize attributes
# TODO: all addops, relops,
# TODO: mult ops, but less desirable
sub UTF { pack('U',$_[0]); }

our  %BREAKBEFOREOPS = map(($_=>1),
			   # Various addops
			   "+","-",UTF(0xB1),"\x{2213}", # pm, mp
			  );
our  %BREAKAFTEROPS = map(($_=>1),
			  ",",
			 );
our  %RELATIONOPS = map(($_=>1),
		     # Various relops
		     "=", "<",">", "\x{2264}","\x{2265}","\x{2260}","\x{226A}",
		     "\x{2261}","\x{223C}","\x{2243}","\x{224D}","\x{2248}","\x{2260}","\x{221D}",
		     );
our  %CONVERTOPS = ("\x{2062}"=>UTF(0xD7), # Invisible (discretionary) times
		   );
our %FENCEOPS = map(($_=>1),
		    "(",")","[","]","{","}","|","||","|||",
		    "\x{2018}","\x{2019}","\x{201C}","\x{201D}","\x{2016}","\x{2016}","\x{2308}",
		    "\x{2309}","\x{230A}","\x{230B}","\x{2772}","\x{2773}","\x{27E6}","\x{27E7}",
		    "\x{27E8}","\x{27E9}","\x{27EA}","\x{27EB}","\x{27EC}","\x{27ED}","\x{27EE}",
		    "\x{27EF}","\x{2980}","\x{2980}","\x{2983}","\x{2984}","\x{2985}","\x{2986}",
		    "\x{2987}","\x{2988}","\x{2989}","\x{298A}","\x{298B}","\x{298C}","\x{298D}",
		    "\x{298E}","\x{298F}","\x{2990}","\x{2991}","\x{2992}","\x{2993}","\x{2994}",
		    "\x{2995}","\x{2996}","\x{2997}","\x{2998}","\x{29FC}","\x{29FD}");
our %SEPARATOROPS = map(($_=>1), ",",";",".","\x{2063}");


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
  if((nodeName($mml) eq 'm:mrow') && (scalar(@n=nodeChildren($mml))==2) && isSeparator($n[1])){
    $mml = $n[0];
    $LaTeXML::MathMLLineBreaker::PUNCT = $n[1]; }

  # Compute the possible layouts
  print STDERR "Starting layout of $mml\n" if $DEBUG;
###  print STDERR "Starting layout of ".showNode($mml)."\n" if $DEBUG;
  my $layouts = layout($mml,$width,0,$displaystyle,0,1);
  if($DEBUG){
    print STDERR "Got ".scalar(@$layouts)." layouts:\n";
    map(showLayout($_),@$layouts); }

  # Apply the best layout
  my $best = $$layouts[-1];
  # Is there a case where $best is so bad we shouldn't even apply it?
  applyLayout_rec($best);
  # If nobody has yet eaten the punctuation, add it back on.
  if($LaTeXML::MathMLLineBreaker::PUNCT){
    $mml = ['m:mrow',{},$mml,$LaTeXML::MathMLLineBreaker::PUNCT]; }

  Warn("Got width $$best{width} > $width") if $$best{width} > $width+1;
  $mml; }

sub bestFitToWidth {
  my($self,$math,$mml,$width,$displaystyle)=@_;
  # Check for end punctuation; Remove it, if found.
  my @n;
  local $LaTeXML::MathMLLineBreaker::MATH = $math;
  # Extract math without trailing punctuation (if any).
  if((nodeName($mml) eq 'm:mrow') && (scalar(@n=nodeChildren($mml))==2) && isSeparator($n[1])){
    $mml = $n[0]; }

  # Compute the possible layouts
  print STDERR "Starting layout of $mml\n" if $DEBUG;
###  print STDERR "Starting layout of ".showNode($mml)."\n" if $DEBUG;
  my @layouts = @{ layout($mml,$width,0,$displaystyle,0,1) };

  # Add a penalty for larger overall area.
  my($maxarea,$minarea) = (0,999999999);
  map( $$_{area}=$$_{width}*($$_{depth}+$$_{height}), @layouts);
  map($maxarea = max($maxarea,$$_{area}),@layouts);
  map($minarea = min($minarea,$$_{area}),@layouts);
  map( $$_{penalty} *= (1+($$_{area} -$minarea)/($maxarea-$minarea)), @layouts) if $maxarea > $minarea;

  if($DEBUG){
    print STDERR "Got ".scalar(@layouts)." layouts:\n";
    map(showLayout($_),@layouts); }

  # Depending on the pruning algorithm & parameters used,
  # we may have layouts above $width, and some below $width may have really bad breaks.

  # If the widest layout is less than target width,
  # it should have lowest penalty --maybe even unbroken-- so use it.
  my $best = $layouts[-1];
  return $best if $$best{width} < $width; 

  # If the lowest penalty layout that fits has a not-very-bad penalty, let's go with it.
  my @fit = sort { $$a{penalty} <=> $$b{penalty} } grep($$_{width}<$width, @layouts);
  if(@fit && ($fit[0]->{penalty} < $PENALTY_OK)){
    return $fit[0]; }

  # Otherwise, let's try to weight the over-width against the penalty.
  # How to weight over-width against penalty?
  # Since "Nice breaks" end up with a penalty of just "a few"
  # and a handfull of ems is not too bad either.
  # let's just try weighting them nominally equally.... let's try
  my $weight=2;
  my @sorted = sort { ($weight*$$a{penalty} + $$a{width}) <=> ($weight*$$b{penalty}+$$b{width}) }
    @layouts;
  $best = $sorted[0];

  Warn("Got width $$best{width} > $width") if $$best{width} > $width+1;
  # Return the best layout
  $best; }

sub applyLayout {
  my($self,$mml,$layout)=@_;
  my @n;
  # Extract trailing punctuation which might be placed during layout
  local $LaTeXML::MathMLLineBreaker::PUNCT = undef;
  if((nodeName($mml) eq 'm:mrow') && (scalar(@n=nodeChildren($mml))==2) && isSeparator($n[1])){
    $mml = $n[0];
    $LaTeXML::MathMLLineBreaker::PUNCT = $n[1]; }

  # Is there a case where $best is so bad we shouldn't even apply it?
  applyLayout_rec($layout);
  # If nobody has yet eaten the punctuation, add it back on.
  if($LaTeXML::MathMLLineBreaker::PUNCT){
    $mml = ['m:mrow',{},$mml,$LaTeXML::MathMLLineBreaker::PUNCT]; }

  $mml; }

# (only called during layout; not applying layout)
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
sub applyLayout_rec {
  my($layout)=@_;
  return unless $$layout{hasbreak};
  # Do children first, so if there is punctuation & last child breaks, it can take up the punct.
  if($$layout{children}){
    my @children_layout = @{$$layout{children}};
    my $lastchild = pop(@children_layout);
    { local $LaTeXML::MathMLLineBreaker::PUNCT = undef; # Hide from all but last child
      map(applyLayout_rec($_), @children_layout); }
    # Now, do last child; Maybe it will absorb the punctuation!
    applyLayout_rec($lastchild); }
  # Now break up the current level.
  my $node = $$layout{node};
  my @children = nodeChildren($node);
  if(my $breakset = $$layout{breakset}){
#    print "Applying ".layoutDescriptor($layout)."\n";
    # If this is a fenced row, we've got to manually fixup the fence size!
    if(nodeName($node) eq 'm:mrow'){
      if(isFence($children[0])){
	## $children[0][1]{mathsize}=$$layout{rowheight}."em"; 
	$children[0][1]{symmetric}='false'; }
      if(isFence($children[$#children])){
	## $children[$#children][1]{mathsize}=$$layout{rowheight}."em";
	$children[$#children][1]{symmetric}='false'; }
    }
    my @rows = split_row($breakset,@children);
    # Replace any "converted" leading operators (ie. invisible times => \times)
    foreach my $row (@rows[1..$#rows]){
      my $op = $$row[0];
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
  }
  # If this is a row, and there are breaks underneath, adjust any fences!
  elsif((nodeName($node) eq 'm:mrow') && $$layout{hasbreak}){
    if(isFence($children[0])){
      $children[0][1]{symmetric}='false'; }
    if(isFence($children[$#children])){
      $children[$#children][1]{symmetric}='false'; }
    }
  # HACK: If this is an mfenced whose single mrow child was linebroken,
  # we'll want to replace the fences with explicit mo with symmetric=false.
  # Otherwise, the alignment to "baseline 1" creates a HUGE empty space on top!
  elsif((nodeName($node) eq 'm:mfenced')
	&& (nodeName($children[0]) eq 'm:mrow')
	&& $$layout{children} && (@{$$layout{children}} == 1) && $$layout{children}[0]{breakset}){
    # (or could remove the mfenced & reuse the redundant m:row???)
    my $open = getAttribute($node,'open');
    my $close = getAttribute($node,'close');
    splice(@$node,0,2,'m:mrow',{},['m:mo',{symmetric=>'false'},$open]);
    push(@$node,['m:mo',{symmetric=>'false'},$close]); }
}

# This would use <mspace> with linebreak attribute to break a row.
# Unfortunately, Mozillae ignore this attribute...
sub XXXXapplyLayout_rec {
  my($layout)=@_;
  map(applyLayout_rec($_), @{$$layout{children}} ) if $$layout{children};
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

sub isFence {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  my $t = $$attr{fence}||'';
  ($tag eq 'm:mo') && (($t eq 'true') || (($t ne 'false') && $FENCEOPS{join('',@children)})); }

sub isSeparator {
  my($node)=@_;
  my($tag,$attr,@children)=@$node;
  my $t = $$attr{separator}||'';
  ($tag eq 'm:mo') && (($t eq 'true') || (($t ne 'false') && $SEPARATOROPS{join('',@children)})); }

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

# Note that this sorts first by width, then penalty.
# It prunes layouts wider than the target width (or now, twice it?)
# and those with higher penalty than preceding layout (w/narrower or equal width)
# BUT, it AT LEAST returns the shortest layout, no matter how bad the penalty!
# meaning that a much better layout, particularly if it exceeds the target, will be pruned!
sub prunesort {
  my($target,@layouts)=@_;
  @layouts = sort { ($$a{width} <=> $$b{width}) || ($$a{penalty} <=> $$b{penalty}) } @layouts; 
  my @goodlayouts= ( shift(@layouts) ); # always include at least the shortest/best
  my $pp =$goodlayouts[0]->{penalty};
  my $p;

  # Cut out any layouts whose penalty is too bad.
  # (Hopefully the one we've already pulled off isn't that bad!?!?!)
  @layouts = grep($$_{penalty} < $PENALTY_LIMIT, @layouts);
  my $cutoff = 2*$target+5;	# ?
  foreach my $layout (@layouts){
    if(($$layout{width} < $cutoff) # If not too wide
       && ($pp > ($p=$$layout{penalty}))){ # not worse than prev
      push(@goodlayouts,$layout); $pp=$p; }}
  @goodlayouts; }

#######################################################################
# Row line breaker.
# This is the real workhorse.
#######################################################################
# Here, of course, is where the Interesting stuff will happen.

sub showNode {
  my($node)=@_;
  if(ref $node){
    my($e,$a,@c)=@$node;
    join(' ',"<$e",map("$_=$$a{$_}",keys %$a)).">".join('',map(showNode($_),@c))."</$e>"; }
  else {
    "$node"; }}

sub asRow {
  my($node,$target,$level,$displaystyle,$scriptlevel,$demerits)=@_;
  my $type = nodeName($node);
  my @children = nodeChildren($node);
  if(grep( ref $_ ne 'ARRAY', @children)){
    die "ROW has non-element: ".nodeName($node); }
  # fences will be handled separately
  my($open,$close);
  if(@children && isFence($children[0])){
    $open = shift(@children); }
  if(@children && isFence($children[$#children])){
    $close = pop(@children); }

  my $n = scalar(@children);
  if(!$n){
    return [ { node=>$node, type=>$type,
	       penalty=>0, width   => 0, height  => 0, depth=> 0} ]; }

  # Multiple children, possibly with breaks
  # Get the set of layouts for each child
  my @child_layouts = map(layout($_,$target,$level+1,$displaystyle,$scriptlevel,$demerits+1),
			  @children);

  # Now, we need all possible break points within the row itself.
  my @breaks = ();
  my $lhs_pos;
  my $normal_indentation = 2;
  my $next_indentation = 0;
  if($demerits < $NOBREAK){
    my $pass_indent=2*$normal_indentation;		# minimum width to pass next indentation
    my $running=$child_layouts[0]->[-1]{width};
    for(my $i=1; $i<$n-1; $i++){
      my $child = $children[$i];
      my $content = (nodeName($child) eq 'm:mo') && textContent($child);
      if(!$content){}
      elsif($RELATIONOPS{$content}){
	push(@breaks, [$i,$content,$demerits]) if $running > $pass_indent;
	if(! defined $lhs_pos){
	  if($running < $target/4){
	    $lhs_pos = $i; $next_indentation = $running; }
	  else {
	    $lhs_pos = 0; $next_indentation = $normal_indentation; }}}
      elsif($BREAKBEFOREOPS{$content}){
	$lhs_pos = 0;
	$next_indentation = $normal_indentation;
	push(@breaks, [$i,$content,$demerits]) if $running > $pass_indent; }
      elsif($BREAKAFTEROPS{$content}){
	$lhs_pos = 0;
	$next_indentation = 0;
	push(@breaks, [$i+1,$content,$demerits]); }
      elsif($CONVERTOPS{$content}){
	$lhs_pos = 0;
	$next_indentation = $normal_indentation;
	push(@breaks, [$i,$content,$demerits+$CONVERSION_FACTOR]) if $running > $pass_indent; }
      $running +=  $child_layouts[$i]->[-1]{width};
    }}
  my $indentation = $next_indentation;
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
    # (otherwise we can't arrange the layout with an mtable????
    # presumably because we don't have distinct left & right vertical alignment??)
    # [But this could still work if break was immediately after the child???]    
    # form subset of children's layouts
    # Namely, take only last (unbroken?) layout for all but last child in each row
    # Unfortunately, this CAN end up giving no layouts at all
    my @filtered_child_layouts=();
    foreach my $xline (split_row($breakset,@child_layouts)){
      my @xline_children_layouts = @$xline;
      while(@xline_children_layouts){
	my $xchild_layouts = shift(@xline_children_layouts);
	if(@xline_children_layouts){ # More children?
	  
	  my @x = @$xchild_layouts;
	  my $last = $x[$#x];
	  next BREAKSET if $$last{hasbreak} && (scalar(@breaksets)==1);
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
##			 area=>$width*($depth+$height),
			 indentation=>$indentation, rowheight=>$rowheight, lhs_pos=>$lhs_pos,
			 (scalar(@$breakset) ? (breakset=>$breakset):()),
			 hasbreak=>scalar(@$breakset)||scalar(grep($$_{hasbreak},@$children_layout)),
			 children=>[@$children_layout]});
	@layouts = prunesort($target,@layouts); }}
##      }}
##  @layouts = prunesort($target,@layouts);

  ## Add a penalty for smallest area (?)
## TRY PUTTING THIS AT TOP LEVEL
##  my($maxarea,$minarea) = (0,999999999);
##  map($maxarea = max($maxarea,$$_{area}),@layouts);
##  map($minarea = min($minarea,$$_{area}),@layouts);
##  map( $$_{penalty} *= (1+($$_{area} -$minarea)/$maxarea), @layouts) if $maxarea > $minarea;

  @layouts = prunesort($target,@layouts);

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
  $scriptlevel = min(0,max($scriptlevel + ($displaystyle?1:0),3));
  my $len = length($content);
  my $size = $SIZE[$scriptlevel];
  [ { node=>$node, type=>nodeName($node), penalty=>0,
      width=> $len*$size, height=> $size,
      depth=> 0} ]; }

sub layout_mi     { simpleSize(@_); }
sub layout_mo     { simpleSize(@_); }
sub layout_mn     { simpleSize(@_); }
sub layout_mspace { simpleSize(@_); }
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
