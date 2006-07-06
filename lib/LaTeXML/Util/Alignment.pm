# /=====================================================================\ #
# |  LaTeXML::Util::Alignment                                          | #
# | Support for tabular/array environments                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::Alignment;
use strict;
use XML::LibXML;
use LaTeXML::Util::LibXML;
use LaTeXML::Package;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT= (qw(&alignment
		 &alignment_align &alignment_cr &alignment_hline
		 &alignment_multicol
		 &guess_alignment_headers
		 &ReadTabularPattern &makeTabularPattern));

# If in math => XMArray > XMRow > XMCell,
#  else      => tabular > tr    > td
sub alignment {
  my($document,$body,$colspec,$doheaders,%attr)=@_;
  # Open the Array, and an initial row and cell.
  local $LaTeXML::Alignment::ISMATH = $body->isMath;
  local @LaTeXML::TABPATTERN = ($colspec ? @{$$colspec{row}} : ());
  local @LaTeXML::TABSPEC = ();
  local $LaTeXML::TR = ($LaTeXML::Alignment::ISMATH ? 'ltx:XMRow' : 'ltx:tr');
  local $LaTeXML::TD = ($LaTeXML::Alignment::ISMATH ? 'ltx:XMCell' : 'ltx:td');
  my $tag = ($LaTeXML::Alignment::ISMATH ? 'ltx:XMArray' : 'ltx:tabular');
  my $alignment = $document->openElement($tag,%attr);
  # Start with an open row & column.
  open_alignment_row($document);
  open_alignment_column($document);
  # Now process the body (& and // should be bound to alignment_{align|cr} )
  $document->absorb($body);
  close_alignment_column($document);
  close_alignment_row($document);
  # Since the alignment may or may not have ended with an explicit \\,
  # we need to check for an empty row (w/empty cells), and remove it.
  my $lastrow = $document->getElement->lastChild;
  my $empty = ($LaTeXML::Alignment::ISMATH
	       ?"ltx:XMCell/ltx:XMArg[child::* or text()]"
	       :"ltx:td[child::* or text()]");
  if(!$document->findnodes($empty,$lastrow)){
    $lastrow->getParentNode->removeChild($lastrow); }
  $document->closeElement($tag); 
  if($doheaders){
    guess_alignment_headers($document,$alignment); }
}

sub open_alignment_row {
  my($document)=@_;
  # Copy pattern to new specs for this row.
#  @LaTeXML::TABSPEC = map( { %{$_} } , @LaTeXML::TABPATTERN);
  @LaTeXML::TABSPEC = ();
  foreach my $cell (@LaTeXML::TABPATTERN){
    push(@LaTeXML::TABSPEC,{%$cell}); }
  $document->openElement($LaTeXML::TR); }

sub close_alignment_row {
  my($document)=@_;
  while(@LaTeXML::TABSPEC){	# Pad w/empty cells if needed
    open_alignment_column($document);
    close_alignment_column($document); }
  $document->closeElement($LaTeXML::TR); }

sub add_alignment_border {
  my($node,@borders)=@_;
  my $border = join(' ',sort(map(split(/ */,$_),
				 $node->getAttribute('border')||'',@borders)));
  $border =~ s/(.) \1/$1$1/g;
  $node->setAttribute(border=>$border) if $border; }

sub open_alignment_column {
  my($document)=@_;
    $document->openElement($LaTeXML::TD);
  if($LaTeXML::Alignment::ISMATH){
    $document->openElement('ltx:XMArg',rule=>'Anything,'); }}

sub close_alignment_column {
  my($document)=@_;
  if($LaTeXML::Alignment::ISMATH){
    if($document->isCloseable('ltx:XMText')){
      $document->closeElement('ltx:XMText'); }
    $document->closeElement('ltx:XMArg'); }
  my $node = $document->closeElement($LaTeXML::TD);
  my $spec = shift(@LaTeXML::TABSPEC);
  $node->setAttribute(align=>$$spec{align}) if $$spec{align};
  $node->setAttribute(width=>ToString($$spec{width}))
    if $$spec{width};
  $node->setAttribute(colspan=>$$spec{colspan})
    unless ($$spec{colspan}||1) == 1;
  add_alignment_border($node,$$spec{border}) if $$spec{border};
  if(!$LaTeXML::Alignment::ISMATH){ # ?????
    if(my $after = $$spec{after}){
      $document->insertElement('ltx:td-between',$after); }}}

#======================================================================
# Helpers for implementing &, \\ and \hline

sub alignment_align {
  my($document)=@_;
    close_alignment_column($document);
    open_alignment_column($document); }

sub alignment_cr {
  my($document)=@_;
    close_alignment_column($document);
    close_alignment_row($document);
    open_alignment_row($document);
    open_alignment_column($document); }

sub add_border_to_previous {
  my($document,$border,$border_if_first,@cols)=@_;
  @cols = (0..$#LaTeXML::TABPATTERN) unless @cols;
  # We'll already have started the next row (tr+td) when we see this.
  my $xp = ($LaTeXML::Alignment::ISMATH
	    ?"ancestor-or-self::ltx:XMCell/parent::ltx:XMRow/preceding-sibling::*[1][local-name()='XMRow']/ltx:XMCell"
	    :"ancestor-or-self::ltx:td/parent::ltx:tr/preceding-sibling::*[1][local-name()='tr']/ltx:td");
  if(my @td = $document->findnodes($xp,$document->getElement)){
    foreach my $c (@cols){
      my $i=0;
      foreach my $td (@td){
	add_alignment_border($td,$border) if ($i == $c);
	$i +=  $td->getAttribute('colspan')||1; }}}
  else {			# hline before 1st row; save as top for 1st.
    map( $$_{border} .= $border_if_first, @LaTeXML::TABSPEC[@cols]); }
}

sub alignment_hline {
  my($document,$border,@cols)=@_;
  add_border_to_previous($document,'b','t',@cols); }

sub alignment_multicol {
  my($document,$ncol,$pattern,$body)=@_;
  # Replace ncol table specs with the new pattern.
  $ncol = $ncol->valueOf;
  my $spec = $$pattern{row}[0];
  $$spec{colspan} = $ncol;
  my $b = $LaTeXML::TABSPEC[0]{border}; # Copy pending top border, if any.
  $b =~ s/[^t]//g;
  $$spec{border} = $b.$$spec{border};
  map(shift(@LaTeXML::TABSPEC), 1..$ncol);
  unshift(@LaTeXML::TABSPEC,$spec);
  $document->absorb($body); }

#======================================================================

sub ReadTabularPattern {
  my($gullet)=@_;
  my $open = $gullet->readToken;		# Better be {
  my @tokens=($open);
  my @row=();
  my $b='';
  while(my $op = $gullet->readToken){
    if($op->equals(T_END)){
      push(@tokens,$op);
      last; }
    elsif($op->equals(T_OTHER('|'))){
      push(@tokens,$op);
      if(@row){
	$row[$#row]{border} .= 'r'; }
      else {
	$b .= 'l'; }}
    elsif($op->equals(T_LETTER('r'))){
      push(@tokens,$op);
      push(@row, {align=>'right', border=>$b}); $b=''; }
    elsif($op->equals(T_LETTER('l'))){
      push(@tokens,$op);
      push(@row, {align=>'left', border=>$b} ); $b=''; }
    elsif($op->equals(T_LETTER('c'))){
      push(@tokens,$op);
      push(@row, {align=>'center', border=>$b} ); $b=''; }
    elsif($op->equals(T_LETTER('p'))){
      my($width) = ReadParameters($gullet,'{Dimension}');
      push(@row, {align=>'justify', width=>$width, border=>$b} );  $b=''; 
      push(@tokens,$op, T_BEGIN,$width->revert,T_END); }
    elsif($op->equals(T_OTHER('*'))){
      my($n,$p)= ReadParameters($gullet,'{Number}{}');
      $n = $n->valueOf;
      for(my $i=0; $i<$n; $i++){
	$gullet->unread($p->unlist); }}
    elsif($op->equals(T_OTHER('@'))){
      # NOTE Special casing: Trim spacing, look for \vline
      my @toks = $gullet->readArg->unlist;
      push(@tokens,$op,@toks);
      while(@toks && $toks[0]->toString =~ /^\\[,:;! ]$/){ shift(@toks); }
      while(@toks && $toks[$#toks]->toString =~ /^\\[,:;! ]$/){ pop(@toks); }
      if(scalar(@toks)==1 && $toks[0]->equals(T_CS('\vline'))){
	shift(@toks); $gullet->unread(T_OTHER('|')); }
      $row[$#row]{after} = Digest(Tokens(@toks)) if @toks; }
    else {
      Warn("Unrecognized tabular pattern \"".Stringify($op)."\""); last; }}
  return LaTeXML::TabularPattern->new(row=>[@row], tokens=>[@tokens]); }

sub makeTabularPattern {
  my($ncols,$alignment)=@_;
  my @row = map( {align=>$alignment, border=>''}, 0..$ncols-1);
  LaTeXML::TabularPattern->new(row=>[@row]); }
  
{
package LaTeXML::TabularPattern;
use base qw(LaTeXML::Object);
sub new {
  my($class,%data)=@_;
    bless {%data}, $class; }
sub revert {
  my($self)=@_;
  @{ $$self{tokens} }; }
}


#======================================================================
# Experimental alignment heading heuristications.
#======================================================================
# We attempt to recognize patterns of rows/columns that indicate which might be headers.
# We'll characterize the cells by alignment, content and borders.
# Then, assuming that headers will be first and be noticably `different' from data lines,
# and also that the data lines will have similar structure,  we'll attempt to
# recognize groups of header lines and groups data lines, possibly alternating.

sub guess_alignment_headers {
  my($document,$alignment)=@_;
  # Assume that headers don't make sense for nested tables.
  # OR Maybe we should only do this within table environments???
  return if $document->findnodes("ancestor::ltx:tabular",$alignment);

  # Build a view of the table by extracting the rows, collecting & characterizing each cell.
  my @rows = collect_alignment_rows($document,$alignment);
  # Flip the rows around to produce a column view.
  my @cols = ();
  for(my $c = 0; $c < scalar(@{$rows[0]}); $c++){
    push(@cols, [map($$_[$c], @rows)]); }
  # Attempt to recognize header lines.
  alignment_characterize_lines(0,@rows);
  alignment_characterize_lines(1,@cols);
  # Did we go overboard?
  my %n=(h=>0,d=>0);
  foreach my $r (@rows){
    foreach my $c (@$r){
      $n{$$c{role}}++; }}
  print STDERR "$n{h} header, $n{d} data cells\n" if $LaTeXML::Alignment::DEBUG;
  if($n{d} == 1){			# Or any other heuristic?
    foreach my $r (@rows){
      foreach my $c (@$r){
	$$c{role}='d'; $$c{cell}->removeAttribute('thead'); }}}
  # Regroup the rows into thead & tbody elements.
  alignment_regroup($document,$alignment,@rows)
    unless $LaTeXML::Alignment::ISMATH;
  # Debugging report!
  summarize_alignment([@rows],[@cols]) if $LaTeXML::Alignment::DEBUG;
}

#======================================================================
# Regroup the rows into thead & tbody
sub alignment_regroup {
  my($document,$alignment,@rows)=@_;
  my ($group,$grouptype)=(undef,0);
  foreach my $xrow ($document->findnodes("ltx:tr",$alignment)){
    my $rowtype = (grep($$_{role} ne 'h', @{ shift(@rows)} ) ? 'tbody' : 'thead');
    if($grouptype ne $rowtype){
      $group = $alignment->addNewChild($xrow->getNamespaceURI, $grouptype = $rowtype);
      $alignment->insertBefore($group,$xrow); }
    $group->appendChild($xrow); }
  }
#======================================================================
# Build a View of the alignment, with characterized cells, for analysis.
sub collect_alignment_rows {
  my($document,$alignment)=@_;
  my @rows = ();
  foreach my $xrow ($document->findnodes($LaTeXML::TR,$alignment)){
    push(@rows, [ ] );
    my $c=0;
    foreach my $xcell ($document->findnodes($LaTeXML::TD,$xrow)){
      my $class = classify_alignment_cell($document,$xcell);
      my $align = $xcell->getAttribute('align')||'center';
      my %border = (t=>0, r=>0, b=>0, l=>0); # Decode border
      map($border{$_}++, split(/ */,$xcell->getAttribute('border')||''));
      $border{t}=$rows[$#rows-1][$c]{b} if $#rows > 0;	   # Copy prev bottom border to top.
      $border{l}=$rows[$#rows][$c-1]{r} if $c > 0;	   # Copy prev right border to left.
      if (my $colspan = $xcell->getAttribute('colspan')) { # From a multicolumn (> 1)
	for (my $i=0; $i<$colspan; $i++) { # Add colspan cells
	  push(@{$rows[$#rows]},{role=>'d', class=>$class, align=>$align,
				 t=>$border{t}, b=>$border{b}, r=>0, l=>0}); }
	# Add left & right borders to first & last spanned cell.
	$rows[$#rows][$c]{cell} = $xcell;
	$rows[$#rows][$c]{l} =  $border{l};
	$rows[$#rows][$c+$colspan-1]{r} =  $border{r};
	$c += $colspan; }
      else {			# Add a regular cell.
	push(@{$rows[$#rows]},{cell=>$xcell, role=>'d', 
			       class=>$class, align=>$align,%border});
	$c++; }
    }}
  @rows; }

# Return one of: i(nteger), t(ext), m(ath), ? (unknown) or '_' (empty) (or some combination)
#  or 'mx' for alternating text & math.
sub classify_alignment_cell {
  my($document,$xcell)=@_;
  my $content = $xcell->textContent;
  my $class='';
  if($content =~ /^\s*\d+\s*$/){
    $class = 'i'; }
  else {
    my @nodes = $xcell->childNodes;
    while(@nodes){
      my $ch = shift(@nodes);
      my $chtype = $ch->nodeType;
      if($chtype == XML_TEXT_NODE){
	my $text = $ch->textContent;
	$class .= 't' 
	  unless $text=~/^\s*$/ || (($class eq 'm') && ($text=~/^\s*[\.,;]\s*$/)); }
      elsif($chtype == XML_ELEMENT_NODE){
	my $chtag = $document->getNodeQName($ch);
	if($chtag eq 'ltx:text'){ # Font would be useful, but haven't "resolved" it, yet!
	  $class .= 't' unless $class eq 't'; }
	elsif($chtag eq 'ltx:Math'){
	  $class .= 'm' unless $class eq 'm'; }
	elsif($chtag eq 'ltx:XMText'){
	  $class .= 't' unless $class eq 't'; }
	elsif($chtag eq 'ltx:XMArg'){
	  unshift(@nodes,$ch->childNodes); }
	elsif($chtag =~ /^ltx:XM/){
	  $class .= 'm' unless $class eq 'm'; }
	else {
	  $class .= '?' unless $class; }
      }}}
  $class = 'mx' if $class && (($class =~ /^((m|i)t)+(m|i)?$/)||($class =~ /^(t(m|i))+t?$/));
  $class || '_'; }

#======================================================================
# Scan pairs of rows/columns attempting to recognize differences that
# might indicate which are headers and which are data.
# Warning: This section is full of "magic numbers"
# guessed by sampling various test cases.

our $MIN_ALIGNMENT_DATA_LINES=1;	#  (or 2?)
our $MAX_ALIGNMENT_HEADER_LINES=4;

# We expect to find header lines at the beginning, noticably different from the eventual data lines.
# But the header lines might be quite similar to each other.  So, the strategy is to look
# for a `hump' in the line differences and consider blocks containing these lines to be potential headers.
sub alignment_characterize_lines {
  my($axis,@lines)=@_;
  my $n = scalar(@lines);
  return unless $n > 1;
  local @::TABLINES = @lines;
  print STDERR "\nCharacterizing $n ".($axis ? "columns" : "rows")."\n   " if $LaTeXML::Alignment::DEBUG;

  # Establish a scale of differences for the table.
  my($diffhi,$difflo)=(0,99999999);
  for(my $l = 0; $l < $n-1; $l++){
    my $d = alignment_compare($axis,1,$l,$l+1);
    $diffhi = $d if $d > $diffhi;
    $difflo = $d if $d < $difflo; }
  print STDERR "Lines are almost identical => Fail\n" if $diffhi < 0.05 && $LaTeXML::Alignment::DEBUG;
  return if $diffhi < 0.05;	# virtually no differences.
#  local $::TAB_THRESHOLD = $difflo + 0.4*($diffhi-$difflo);
  local $::TAB_THRESHOLD = $difflo + 0.2*($diffhi-$difflo);
  local $::TAB_AXIS = $axis;
  print STDERR "\nDifferences $difflo -- $diffhi => threshold = $::TAB_THRESHOLD\n" if $LaTeXML::Alignment::DEBUG;
  # Find the first hump in differences. These are candidates for header lines.
  print STDERR "Scanning for headers\n   " if $LaTeXML::Alignment::DEBUG;
  my $diff;
  my ($minh,$maxh) = (1,1);
  while( ($diff=alignment_compare($axis,1,$maxh-1,$maxh)) < $::TAB_THRESHOLD){
    $maxh++; }
  while( alignment_compare($axis,1,$maxh,$maxh+1) > $difflo + ($diff-$difflo)/6){
    $maxh++; }
  $maxh = $MAX_ALIGNMENT_HEADER_LINES if $maxh > $MAX_ALIGNMENT_HEADER_LINES;
 print STDERR "\nFound from $minh--$maxh potential headers\n" if $LaTeXML::Alignment::DEBUG;

  my $nn = scalar(@{$lines[0]})-1;
  # Now, change all cells marked as header from td => th.
  for(my $nh = $maxh; $nh >= $minh; $nh--){
#  for(my $nh = $minh; $nh <= $maxh; $nh++){
    if(my @heads = alignment_test_headers($nh)){
      foreach my $h (@heads){
	my $i = 0;
	foreach my $cell (@{$lines[$h]}){
	  $$cell{role} = 'h';
	  if(my $xcell = $$cell{cell}){
	    if(($$cell{class} eq '_') # But NOT empty cells on outer edges.
	       && (( ($i==0) && !$$cell{($axis==0 ? 'l' : 't')} )
		   ||(($i==$nn) && !$$cell{($axis == 0 ? 'r' : 'b')}))){}
	    else {
	      $$cell{cell}->setAttribute(thead=>'yes');}}
	  $i++; }}
      last; }}
  1; }

# Test whether $nhead lines makes a good fit for the headers
sub alignment_test_headers {
  my($nhead)=@_;
  print STDERR "Testing $nhead headers\n" if $LaTeXML::Alignment::DEBUG;
  my @heads =(0..$nhead-1);		# The indices of heading lines.
  my $i = $nhead;		# Start from the end of the proposed headings.
  # Watch out for the assumed header being really data that is a repeated pattern.
  my $nrep = scalar(@::TABLINES)/$nhead;
  if(($nhead > 1) && ($nrep == int($nrep))){
    print STDERR "Check for apparent header repeated $nrep times\n" if $LaTeXML::Alignment::DEBUG;
    my $matched = 1;
    for(my $r = 1; $r < $nrep; $r++){
      $matched &&= alignment_match_head(0,$r*$nhead,$nhead); }
    print STDERR "Repeated headers: ".($matched ? "Matched=> Fail" : "Nomatch => Succeed")."\n" if $LaTeXML::Alignment::DEBUG;
    return if $matched; }

  # And find a following grouping of data lines.
  my $ndata = alignment_skip_data($i);
  return unless $ndata >= $nhead; # ???? Well, maybe if _really_ convincing???
  return unless ($ndata >= $nhead) || ($ndata >= 2);
  $i += $ndata;
  my $nd;
  # If there are more lines, they should match either the previous data block, or the head/data pattern.
  while($i < scalar(@::TABLINES)){
    # First try to match a repeat of the 1st data block; 
    # This would be the case when groups of data have borders around them.
    # Could conceivably wnat to match a variable number of datalines, but they should be similar!!!??!?!?

    if(($ndata > 1) && ($nd = alignment_match_data($nhead,$i,$ndata))){
      $i += $nd; }
      # Else, try to match the first header block; less common.
    elsif(alignment_match_head(0,$i,$nhead)){
      push(@heads,$i..$i+$nhead-1);
      $i += $nhead;
      # Then attempt to match a new data block.
#      my $d = alignment_skip_data($i);
#      return unless ($d >= $nhead) || ($d >= 2);
#      $i += $d; }
      # No, better be the same data block?
      return unless ($nd = alignment_match_data($nhead,$i,$ndata));
      $i += $nd; }
    else { return; }}
   print STDERR "Succeeded with $nhead headers\n" if $LaTeXML::Alignment::DEBUG;
  @heads; }

sub alignment_match_head {
  my($p1,$p2,$nhead)=@_;
  print STDERR "Try match $nhead header lines from $p1 to $p2\n   " if $LaTeXML::Alignment::DEBUG;
  my $nh = alignment_match_lines($p1,$p2,$nhead);
  my $ok = $nhead == $nh;
  print STDERR "\nMatched $nh header lines => ".($ok ? "Succeed" : "Failed")."\n" if $LaTeXML::Alignment::DEBUG;
  ($ok ? $nhead : 0); }

sub alignment_match_data {
  my($p1,$p2,$ndata)=@_;
  print STDERR "Try match $ndata data lines from $p1 to $p2\n   " if $LaTeXML::Alignment::DEBUG;
  my $nd = alignment_match_lines($p1,$p2,$ndata);
  my $ok = ($nd*1.0)/$ndata  > 0.66;
  print STDERR "\nMatched $nd data lines => ".($ok ? "Succeed" : "Failed")."\n" if $LaTeXML::Alignment::DEBUG;
  ($ok ? $nd : 0); }

# Match the $n lines starting at $i2 to those starting at $i1.
sub alignment_match_lines {
  my($p1,$p2,$n)=@_;
  for(my $i = 0; $i < $n; $i++){
    return $i if ($p1+$i >= scalar(@::TABLINES)) || ($p2+$i >= scalar(@::TABLINES))
      || alignment_compare($::TAB_AXIS,0, $p1+$i, $p2+$i) >= $::TAB_THRESHOLD; }
  return $n; }

# Skip through a block of lines starting at $i that appear to be data, returning the number of lines.
# We'll assume the 1st line is data, compare it to following lines,
# but also accept `continuation' data lines.
sub alignment_skip_data {
  my($i)=@_;
  return 0 if $i >= scalar(@::TABLINES);
  print STDERR "Scanning for data\n   " if $LaTeXML::Alignment::DEBUG;
  my $n = 1;
  while($i+$n < scalar(@::TABLINES)){
    last unless (alignment_compare($::TAB_AXIS,1, $i+$n-1, $i+$n) < $::TAB_THRESHOLD)
      # Accept an outlying `continuation line' as data, if mostly empty
      || (($n > 1) && (scalar(grep($$_{class} eq '_', @{$::TABLINES[$i+$n]})) > 0.4*scalar($::TABLINES[0])));
    $n++; }
  print STDERR "\nFound $n data lines at $i\n" if $LaTeXML::Alignment::DEBUG;
  ($n >= $MIN_ALIGNMENT_DATA_LINES ? $n : 0); }

#======================================================================
# The comparator.
our %cell_class_diff =
  ('_'=>{'_'=>0.0, m=>0.1, i=>0.1, t=>0.1, '?'=>0.1, mx=>0.1},
   m  =>{'_'=>0.1, m=>0.0, i=>0.1, mx=>0.2},
   i  =>{'_'=>0.1, m=>0.1, i=>0.0, mx=>0.2},
   t  =>{'_'=>0.1, t=>0.0, mx=>0.2},
   '?'=>{'_'=>0.1, '?'=>0.0, mx=>0.2},
   mx=>{'_'=>0.1, m=>0.2, i=>0.2, t=>0.2, '?'=>0.2, mx=>0.0});

# Compare two lines along $axis (0=row,1=column), returning a measure of the difference.
# The borders are compared differently if
#  $foradjacency: we adjacent lines that might belong to the same block,
#  otherwise    : comparing two lines that ought to have identical patterns (eg. in a repeated block)
sub alignment_compare {
  my($axis, $foradjacency, $p1,$p2)=@_;
  my $line1 = $::TABLINES[$p1];
  my $line2 = $::TABLINES[$p2];
  return 0 if !($line1 && $line2);
  return 999999 if $line1 xor $line2;
  my @cells1 = @$line1;
  my @cells2 = @$line2;
  my $diff=0.0;
  while(@cells1 && @cells2){
    my $cell1 = shift(@cells1);
    my $cell2 = shift(@cells2);
    $diff += 0.5 if ($$cell1{align} ne $$cell2{align});
    if(my $d = $cell_class_diff{$$cell1{class}}{$$cell2{class}}){
      $diff += $d; }
    elsif($$cell1{class} ne $$cell2{class}){
      $diff += 0.75; }
    # compare certain edges
    if($foradjacency){		# Compare edges for adjacent rows of potentially different purpose
      $diff += 0.3*scalar(grep($$cell1{$_} != $$cell2{$_}, ($axis == 0 ? qw(r l) : qw(t b))));
      my $pedge  = ($axis == 0 ? 'b' : 'r');
      my $pother = ($axis == 0 ? 't' : 'l');
      # Penalty for apparent divider between.
      $diff += 2.0*$$cell1{$pedge}
	unless ($$cell1{$pedge} == $$cell1{$pother}) && ($$cell1{$pedge} == $$cell2{$pedge});
    }
    else {			# Compare edges for rows from diff places for potential similarity
      $diff += 0.3*scalar(grep($$cell1{$_} != $$cell2{$_}, qw(r l t b))); }
  }
  $diff /= scalar(@$line1);
  print STDERR "$p1-$p2 => $diff; " if $LaTeXML::Alignment::DEBUG;
  return $diff; }

#======================================================================
# Debugging.
sub summarize_alignment {
  my($rows,$cols)=@_;
  my $r=0;
  my %acode = (right=>'r', left=>'l', center=>'c', justify=>'p');
  my ($nrows,$ncols) = (scalar(@$rows),scalar(@{$$rows[0]}));
  print STDERR "\n";
  foreach my $cell (@{$$rows[0]}){
    print STDERR ' '.($$cell{t} ? ('-' x 6) : (' ' x 6)); }
  print STDERR "\n";
  foreach my $row (@$rows){
    my $maxb = 0;
    print STDERR ($$row[0]{l} ? ('|' x $$row[0]{l}) : ' ');
    foreach my $cell (@$row){
      print STDERR sprintf(" %4s ",$$cell{role}.$acode{$$cell{align}}.$$cell{class}).
	($$cell{r} ? ('|' x $$cell{r}) : ' ');
      $maxb = $$cell{b} if $$cell{b} > $maxb; }
#    print STDERR sprintf("%.3f",alignment_compare(0,1,$$rows[$r],$$rows[$r+1])) if ($r < $nrows-1);
    print STDERR "\n";
    for(my $b = 0; $b < $maxb; $b++){
      foreach my $cell (@$row){
	print STDERR ' '.($b < $$cell{b} ? ('-' x 6) : (' ' x 6)); }
      print STDERR "\n"; }
    $r++; }
  print STDERR "   ";
#  for(my $c = 0; $c < $ncols-1; $c++){
#    print STDERR sprintf(" %.3f ",alignment_compare(1,1,$$cols[$c],$$cols[$c+1])); }
  print STDERR "\n";
}


#======================================================================

1;
