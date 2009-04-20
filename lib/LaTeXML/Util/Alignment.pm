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
use LaTeXML::Package;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT= (qw(
		 &constructAlignment
		 &ReadAlignmentTemplate &parseAlignmentTemplate &MatrixTemplate));

#======================================================================
# An "Alignment" is an array/tabular construct as:
#   <tabular><tr><td>...
# or, for math mode
#   <XMArray><XMRow><XMCell>...
# (where initially, each XMCell will contain an XMArg to indicate
# individual parsing of each cell's content is desired)

# data should have:
#   containerElement => name of the container element
#   rowElement => name of row element
#   colElement => name of col element.
sub new {
  my($class, %data)=@_;
  bless { %data,
	  template=>LaTeXML::AlignmentTemplate->new(), rows=>[],
	  current_column=>0, current_row=>undef}, $class; }

###

sub setMath {
  my($self)=@_;
  $$self{isMath} = 1; }

###
sub getTemplate {
  my($self,$template)=@_;
  $$self{template}; }

sub setTemplate {
  my($self,$template)=@_;
  $$self{template}=$template; }

###
sub currentRow {
  my($self)=@_;
  $$self{current_row}; }

sub newRow {
  my($self)=@_;
  my $row = $$self{template}->clone;
  $$self{current_row} = $row;
  $$self{current_column} = 0;
  push(@{$$self{rows}}, $row);
  $row; }

sub removeRow {
  my($self)=@_;
  my @rows = @{$$self{rows}};
  if(@rows){
    my $row = pop(@rows);
    $$self{rows} = [@rows]; 
    $row; }
  else {
    undef; }}

sub prependRows {
  my($self,@rows)=@_;
  unshift(@{$$self{rows}},@rows); }

sub appendRows {
  my($self,@rows)=@_;
  push(@{$$self{rows}},@rows); }

sub rows {
  my($self)=@_;
  @{$$self{rows}}; }

###

sub addLine {
  my($self,$border,@cols)=@_;
  my $row = $$self{current_row};
  if(@cols){
    foreach my $c (@cols){
      my $colspec = $row->column($c);
      $$colspec{border} .= $border; }}
  else {
    foreach my $colspec (@{$$row{columns}}){
      $$colspec{border} .= $border; }}
  return; }

###
sub nextColumn {
  my($self)=@_;
  my $colspec = $$self{current_row}->column( ++$$self{current_column} );
  if(!$colspec){
    Error(":unexpected:& Extra alignment tab");
    $$self{current_row}->addColumn(align=>'center');
    $colspec = $$self{current_row}->column( $$self{current_column} ); }
  $colspec; }

sub currentColumnNumber {
  my($self)=@_;
  $$self{current_column}; }

sub currentColumn {
  my($self)=@_;
  $$self{current_row}->column($$self{current_column}); }

sub getColumn {
  my($self,$n)=@_;
  $$self{current_row}->column($n); }

# sub missingColumns {
#   my($self)=@_;
#   my $n = scalar(@{$$self{current_row}{columns}});
#   $n - $$self{current_column}; }

#======================================================================
# Constructing the XML for the alignment.
#======================================================================
# Normalize an alignment after construction
# Tasks:
#  (1) a trailing \\ in the alignment will generate an empty row.
#     Note that the trailing \\ is required to get an \hline at the bottom!
#     It is empty in the sense that no cells have "real" content
#     but may have content generated from the template!
#     This emptiness is sensed by inner@column.
#     So, if we find such an empty row, we need to remove it,
#     but copy it's top border to a bottom border of the preceding row!
#  (2) Some table constructs, particularly Knuth's fancy ones,
#     have empty columns for spacing purposes.
#     These likely should be removed from the "logical" table we construct.
#     Here, emptiness should probably be that there is no text content
#     in the cell's at all (template data is presumably meaningful).
#     But here, also, border data may need to be moved (but l/r borders)
#  (3) put border attributes in a "normal" form to ease use as html's class attribute.
#     Ie: group by l/r/t/b w/ spaces between groups.
#
# OR, since I'm doing so much manipulation here,
# maybe it just makes sense to build the entire XML from the alignment construction?
# This would avoid lots of back & forth between the alignment & xml.

# NOTE: Another cleanup issue:
# With \halign, Knuth seems to like to introduce many empty columns for spacing.
# It may be useful to remove such columns?
# Probably have to 

sub constructAlignment {
  my($document,$body,%props)=@_;
  my $alignment = $body->getProperty('alignment');
  $alignment->setMath if $body->isMath;

  my %attr = ($props{attributes} ? %{$props{attributes}} : ());
  my $node = $alignment->beAbsorbed($document,%attr);
  # If requested to guess headers (unless cells are already marked)
  if($props{guess_headers}
     && !$document->findnodes('descendant::ltx:td[contains(@class,"thead")]',$node)){
    guess_alignment_headers($document,$node,$alignment); }
  $node; }

sub beAbsorbed {
  my($self,$document,%attributes)=@_;
  my $ismath = $$self{isMath};

  my @rows = @{$$self{rows}};
  # If last row is "empty", remove it, while copying it's top border to the bottom of prev.
  if(!grep(! $$_{empty}, @{$rows[-1]->{columns}})){
    my $nc = scalar(@{$rows[-1]->{columns}});
    for(my $c = 0; $c < $nc; $c++){
      my $border = $rows[$#rows]{columns}[$c]{border}||'';
      $border =~ s/[^tT]//g;
      $border =~ s/./b/g;
      $rows[$#rows-1]{columns}[$c]{border} .= $border; }
    pop(@rows); pop(@{$$self{rows}}); }
  # Mark any cells that are covered by rowspans
  for(my $i=0; $i<scalar(@rows); $i++){
    my @row = @{$rows[$i]->{columns}};
    for(my $j=0; $j<scalar(@row); $j++){
      my $col = $row[$j];
      my $nr = $$col{rowspan}||1;
      if($nr > 1){
	my $nc = $$col{colspan}||1;
	for(my $ii=$i+1; $ii<$i+$nr; $ii++){
	  if(my $rrow = $rows[$ii]){
	    for(my $jj=$j; $jj<$j+$nc; $jj++){
	      if(my $ccol = $$rrow{columns}[$jj]){
		$$ccol{skipped}=1; }}}}}}}

  # We _should_ attach boxes to the alignment and rows,
  # but (ATM) we've only got sensible boxes for the cells.
#  $document->openElement($$self{containerElement},%attributes);
  &{$$self{openContainer}}($document,%attributes);
  foreach my $row (@{$$self{rows}}){
#    $document->openElement($$self{rowElement},
#			   'xml:id'=>$$row{id},refnum=>$$row{refnum});
    &{$$self{openRow}}($document,'xml:id'=>$$row{id},refnum=>$$row{refnum});
    foreach my $cell (@{$$row{columns}}){
      next if $$cell{skipped};
      # Normalize the border attribute
      my $border = join(' ',sort(map(split(/ */,$_),$$cell{border}||'')));
      $border =~ s/(.) \1/$1$1/g;
      my $empty = !$$cell{boxes} || !scalar($$cell{boxes}->unlist);
#      $$cell{cell} = $document->openElement($$self{colElement},
      $$cell{cell} = &{$$self{openColumn}}($document,
					    align=>$$cell{align}, width=>$$cell{width},
					    (($$cell{span}||1) != 1 ? (colspan=>$$cell{span}) : ()),
					    (($$cell{rowspan}||1) != 1 ? (rowspan=>$$cell{rowspan}) : ()),
					    ($border ? (border=>$border):()),
					    ($$cell{head} ? (thead=>'true'):()));
      if(!$empty){
	local $LaTeXML::BOX = $$cell{boxes};
	$document->openElement('ltx:XMArg', rule=>'Anything,') if $ismath;
	$document->absorb($$cell{boxes});
	$document->closeElement('ltx:XMArg') if $ismath;
      }
#      $document->closeElement($$self{colElement}); }
      &{$$self{closeColumn}}($document); }
#    $document->closeElement($$self{rowElement}); }
    &{$$self{closeRow}}($document); }
#  $document->closeElement($$self{containerElement});
  &{$$self{closeContainer}}($document);
}

#======================================================================

#======================================================================

# newcolumntype
#  defines \NC@rewrite@<char>
#    As macro
#    or "constructor" (or just sub that creates a column)

sub ReadAlignmentTemplate {
  my($gullet)=@_;
  $gullet->skipSpaces;
  local $LaTeXML::BUILD_TEMPLATE = 
    LaTeXML::AlignmentTemplate->new(columns=>[], tokens=>[]);
  my @tokens=(T_BEGIN);
  my $nopens = 0;
  while(my $open = $gullet->readToken){
    if($open->equals(T_BEGIN)){ $nopens++; }
    else { $gullet->unread($open); last; }}
  my $defn;
  while(my $op = $gullet->readToken){
    if($op->equals(T_SPACE)){}
    elsif($op->equals(T_END)){
      while(--$nopens && ($op=$gullet->readToken)->equals(T_END)){}
      last unless $nopens; 
      $gullet->unread($op); }
    elsif(defined($defn=$STATE->lookupDefinition(T_CS('\NC@rewrite@'.ToString($op))))
       && $defn->isExpandable){
      # A variation on $defn->invoke, so we can reconstruct the reversion
      my @args = $defn->readArguments($gullet);
      my @exp = $defn->doInvocation($gullet,@args);
      if(@exp){			# This just expanded into other stuff
	$gullet->unread(@exp); }
      else {
	push(@tokens,$op);
	if(my $param = $defn->getParameters){
	  push(@tokens,$param->revertArguments(@args)); }}}
    elsif($op->equals(T_BEGIN)){ # Wrong, but a safety valve
      $gullet->unread($gullet->readBalanced->unlist); }
    else {
      Warn(":unexpected:".Stringify($op)." Unrecognized tabular template \"".Stringify($op)."\""); }}
  push(@tokens,T_END);
  $LaTeXML::BUILD_TEMPLATE->setReversion(@tokens);
  return $LaTeXML::BUILD_TEMPLATE; }

sub parseAlignmentTemplate {
  my($spec)=@_;
  my $gullet = $STATE->getStomach->getGullet;
  $gullet->openMouth(LaTeXML::Mouth->new("{".$spec."}"),1);
  my $template = ReadAlignmentTemplate($gullet);
  $gullet->closeMouth(1);
  $template; }

sub MatrixTemplate {
  LaTeXML::AlignmentTemplate->new(repeated=>[{before=>Tokens(T_CS('\hfil')),
					      after=>Tokens(T_CS('\hfil'))}]); }
{
package LaTeXML::AlignmentTemplate;
use base qw(LaTeXML::Object);
use LaTeXML::Global;

sub new {
  my($class,%data)=@_;
  $data{columns}=[] unless $data{columns};
  $data{repeating} = 1 if $data{repeating} || $data{repeated};
  $data{repeated} = [] unless $data{repeated};
  $data{non_repeating} = scalar(@{$data{columns}});
  $data{save_before} = [] unless $data{save_before};

  map( $$_{empty}=1, @{$data{columns}});
  map( $$_{empty}=1, @{$data{repeated}});
  bless {%data}, $class; }

sub revert {
  my($self)=@_;
  @{ $$self{tokens} }; }

# Methods for constructing a template.

sub setReversion {
  my($self,@tokens)=@_;
  $$self{tokens} = [@tokens]; }

sub setRepeating {
  my($self)=@_; 
  $$self{repeating}=1; }

sub addBefore {
  my($self,@tokens)=@_;
  push(@{$$self{save_before}},@tokens); }

sub addAfter {
  my($self,@tokens)=@_;
  $$self{current_column}{after} = Tokens(@{ $$self{current_column}{after}},@tokens); }

sub addBetween {
  my($self,@tokens)=@_;
  my @cols = @{$$self{columns}};
  if($$self{current_column}){ $self->addAfter(@tokens); }
  else                      { $self->addBefore(@tokens); }}

sub addColumn {
  my($self,%properties)=@_;
  my $col = {%properties};
  my @before=();
  push(@before,@{$$self{save_before}}) if $$self{save_before};
  push(@before,$properties{before}->unlist) if $properties{before};
  $$col{before} = Tokens(@before);
  $$col{after}  = Tokens() unless $properties{after};
  $$col{head}   = $properties{head};
  $$col{empty}  = 1;
  $$self{save_before}=[];
  $$self{current_column} = $col;
  if($$self{repeating}){
    $$self{non_repeating} = scalar(@{$$self{columns}});
    push(@{$$self{repeated}},$col); }
  else {
    push(@{$$self{columns}},$col); }}

# Methods for using a template.
sub clone {
  my($self)=@_;
  my @dup = ();
  foreach my $cell (@{$$self{columns}}){
    push(@dup, { %$cell }); }
  bless {columns=>[@dup], 
	 repeated=>$$self{repeated}, non_repeating=>$$self{non_repeating},
	 repeating=>$$self{repeating}}, ref $self; }

sub show {
  my($self)=@_;
  my @strings=();
  push(@strings,"\nColumns:\n");
  foreach my $col(@{$$self{columns}}){
    push(@strings, "\n{".join(', ',map("$_=>".Stringify($$col{$_}),keys %$col)).'}'); }
  if($$self{repeating}){
    push(@strings,"\nRepeated Columns:\n");
    foreach my $col(@{$$self{repeated}}){
      push(@strings, "\n{".join(', ',map("$_=>".Stringify($$col{$_}),keys %$col)).'}'); }}
  join(', ',@strings); }

sub column {
  my($self,$n)=@_;
  my $N = scalar(@{$$self{columns}});
  if(($n > $N) && $$self{repeating}){
    my @rep = @{$$self{repeated}};
    if(my $m = scalar(@rep)){
      for(my $i=$N; $i<$n; $i++){
	my %dup = %{  $rep[($i-$$self{non_repeating}) % $m] };
	push(@{$$self{columns}},{%dup}); }}}
  $$self{columns}->[$n-1]; }

sub columns {
  my($self)=@_;
  @{$$self{columns}}; }

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
  my($document,$table,$alignment)=@_;
  # Assume that headers don't make sense for nested tables.
  # OR Maybe we should only do this within table environments???
  return if $document->findnodes("ancestor::ltx:tabular",$table);

  my $tag = $document->getModel->getNodeQName($table);
  my $ismath = $tag eq 'ltx:XMArray';
  local $LaTeXML::TR = ($ismath ? 'ltx:XMRow' : 'ltx:tr');
  local $LaTeXML::TD = ($ismath ? 'ltx:XMCell' : 'ltx:td');

  # Build a view of the table by extracting the rows, collecting & characterizing each cell.
  my @rows = collect_alignment_rows($document,$table,$alignment);
  # Flip the rows around to produce a column view.
  my @cols = ();
  return unless @rows;
  for(my $c = 0; $c < scalar(@{$rows[0]}); $c++){
    push(@cols, [map($$_[$c], @rows)]); }
  # Attempt to recognize header lines.
  alignment_characterize_lines(0,@rows);
  alignment_characterize_lines(1,@cols);
  # Did we go overboard?
  my %n=(h=>0,d=>0);
  foreach my $r (@rows){
    foreach my $c (@$r){
      $n{$$c{cell_type}}++; }}
  print STDERR "$n{h} header, $n{d} data cells\n" if $LaTeXML::Alignment::DEBUG;
  if($n{d} == 1){			# Or any other heuristic?
    foreach my $r (@rows){
      foreach my $c (@$r){
	$$c{cell_type}='d'; 
	$$c{cell}->removeAttribute('thead') if $$c{cell}; }}}
  # Regroup the rows into thead & tbody elements.
  alignment_regroup($document,$table,@rows)
    unless $ismath;
  # Debugging report!
  summarize_alignment([@rows],[@cols]) if $LaTeXML::Alignment::DEBUG;
}

#======================================================================
# Regroup the rows into thead & tbody
sub alignment_regroup {
  my($document,$table,@rows)=@_;
  my ($group,$grouptype)=(undef,0);
  foreach my $xrow ($document->findnodes("ltx:tr",$table)){
    my $rowtype = (grep($$_{cell_type} ne 'h', @{ shift(@rows)} ) ? 'tbody' : 'thead');
    if($grouptype ne $rowtype){
      $group = $table->addNewChild($xrow->getNamespaceURI, $grouptype = $rowtype);
      $table->insertBefore($group,$xrow); }
    $group->appendChild($xrow); }
  }
#======================================================================
# Build a View of the alignment, with characterized cells, for analysis.

sub collect_alignment_rows {
  my($document,$table,$alignment)=@_;

  my @rows = ();
  foreach my $arow (@{$$alignment{rows}}){
    push(@rows, [ ] );
    my $c=0;
    foreach my $col (@{$$arow{columns}}){
      push(@{$rows[$#rows]}, $col);
      $$col{cell_type} = 'd';
      $$col{content_class} = ($$col{cell} ? classify_alignment_cell($document,$$col{cell}) : '?');
      $$col{content_length} =($$col{cell} ? length($$col{cell}->textContent) : 0);
      my %border = (t=>0, r=>0, b=>0, l=>0); # Decode border
      map($border{$_}++, split(/ */,$$col{border}||''));
      $border{t}=$rows[$#rows-1][$c]{b} if $#rows > 0;	   # Copy prev bottom border to top.
      $border{l}=$rows[$#rows][$c-1]{r} if $c > 0;	   # Copy prev right border to left.
      map($$col{$_} = $border{$_}, keys %border);
      $c++; }}
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
	my $chtag = $document->getModel->getNodeQName($ch);
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
# Both header lines and data lines can consist of several neighboring lines.
# Check that header lines are `similar' to each other.  So, the strategy is to look
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
  my($minh,$maxh)=(1,1);
  while( ($diff=alignment_compare($axis,1,$maxh-1,$maxh)) < $::TAB_THRESHOLD){
    $maxh++; }
  while( alignment_compare($axis,1,$maxh,$maxh+1) > $difflo + ($diff-$difflo)/6){
    $maxh++; }
  $maxh = $MAX_ALIGNMENT_HEADER_LINES if $maxh > $MAX_ALIGNMENT_HEADER_LINES;
 print STDERR "\nFound from $minh--$maxh potential headers\n" if $LaTeXML::Alignment::DEBUG;

  my $nn = scalar(@{$lines[0]})-1;
  # The sets of lines 1--$minh, .. 1--$maxh are potential headers.
  for(my $nh = $maxh; $nh >= $minh; $nh--){
#  for(my $nh = $minh; $nh <= $maxh; $nh++){
    # Check whether the set 1..$nh is plausable.
    if(my @heads = alignment_test_headers($nh)){
      # Now, change all cells marked as header from td => th.
      foreach my $h (@heads){
	my $i = 0;
	foreach my $cell (@{$lines[$h]}){
	  $$cell{cell_type} = 'h';
	  if(my $xcell = $$cell{cell}){
	    if(($$cell{content_class} eq '_') # But NOT empty cells on outer edges.
	       && (( ($i==0) && !$$cell{($axis==0 ? 'l' : 't')} )
		   ||(($i==$nn) && !$$cell{($axis == 0 ? 'r' : 'b')}))){}
	    else {
	      $$cell{cell}->setAttribute(thead=>'true');}}
	  $i++; }}
      last; }}
  1; }

# Test whether $nhead lines makes a good fit for the headers
sub alignment_test_headers {
  my($nhead)=@_;
  print STDERR "Testing $nhead headers\n" if $LaTeXML::Alignment::DEBUG;
  my ($headlength,$datalength)=(0,0);
  my @heads =(0..$nhead-1);		# The indices of heading lines.
  $headlength = alignment_max_content_length($headlength,0,$nhead-1);
  my $nextline = $nhead;		# Start from the end of the proposed headings.

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
  my $ndata = alignment_skip_data($nextline);
  return unless $ndata >= $nhead; # ???? Well, maybe if _really_ convincing???
  return unless ($ndata >= $nhead) || ($ndata >= 2);
  # Check that the content of the headers isn't dramatically larger than the content in the data
  $datalength = alignment_max_content_length($datalength,$nextline,$nextline+$ndata-1);
  $nextline += $ndata;

  my $nd;
  # If there are more lines, they should match either the previous data block, or the head/data pattern.
  while($nextline < scalar(@::TABLINES)){
    # First try to match a repeat of the 1st data block; 
    # This would be the case when groups of data have borders around them.
    # Could want to match a variable number of datalines, but they should be similar!!!??!?!?
    if(($ndata > 1) && ($nd = alignment_match_data($nhead,$nextline,$ndata))){
      $datalength = alignment_max_content_length($datalength,$nextline,$nextline+$nd-1);
      $nextline += $nd; }
      # Else, try to match the first header block; less common.
    elsif(alignment_match_head(0,$nextline,$nhead)){
      push(@heads,$nextline..$nextline+$nhead-1);
      $headlength = alignment_max_content_length($headlength,$nextline,$nextline+$nhead-1);
      $nextline += $nhead;
      # Then attempt to match a new data block.
#      my $d = alignment_skip_data($nextline);
#      return unless ($d >= $nhead) || ($d >= 2);
#      $nextline += $d; }
      # No, better be the same data block?
      return unless ($nd = alignment_match_data($nhead,$nextline,$ndata));
      $datalength = alignment_max_content_length($datalength,$nextline,$nextline+$nd-1);
      $nextline += $nd; }
    else { return; }}
  # Header content seems too large relative to data?
  print STDERR "header content = $headlength; data content = $datalength\n"
      if $LaTeXML::Alignment::DEBUG;
  if(($headlength > 10) && ($headlength > 0.9*$datalength)){
    print STDERR "header content longer than data content\n" if $LaTeXML::Alignment::DEBUG;
    return; }

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
      || (($n > 1) && (scalar(grep($$_{content_class} eq '_', @{$::TABLINES[$i+$n]})) > 0.4*scalar($::TABLINES[0])));
    $n++; }
  print STDERR "\nFound $n data lines at $i\n" if $LaTeXML::Alignment::DEBUG;
  ($n >= $MIN_ALIGNMENT_DATA_LINES ? $n : 0); }

sub alignment_max_content_length {
  my($length,$from,$to)=@_;
  foreach my $j ( ($from..$to) ){
    foreach my $cell (@{$::TABLINES[$j]}){
      $length = $$cell{content_length}
	if $$cell{content_length} && ($$cell{content_length} > $length); }}
  $length; }

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
    $diff += 0.5 if (($$cell1{align}||'') ne ($$cell2{align}||''));
    if(my $d = $cell_class_diff{$$cell1{content_class}}{$$cell2{content_class}}){
      $diff += $d; }
    elsif($$cell1{content_class} ne $$cell2{content_class}){
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
      print STDERR sprintf(" %4s ",
			   ($$cell{cell_type}||'?')
			   .($$cell{align} ? $acode{$$cell{align}} : ' ')
			   .($$cell{content_class}||'?')
			   .($$cell{r} ? ('|' x $$cell{r}) : ' '));
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
