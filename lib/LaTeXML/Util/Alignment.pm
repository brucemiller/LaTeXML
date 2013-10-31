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
    Error('unexpected','&',$STATE->getStomach->getGullet,"Extra alignment tab '&'");
    $$self{current_row}->addColumn(align=>'center');
    $colspec = $$self{current_row}->column( $$self{current_column} ); }
  $colspec; }

sub currentColumnNumber {
  my($self)=@_;
  $$self{current_column}; }

sub currentRowNumber {
  my($self)=@_;
  scalar(@{$$self{rows}}); }

sub currentColumn {
  my($self)=@_;
  $$self{current_row}->column($$self{current_column}); }

sub getColumn {
  my($self,$n)=@_;
  $$self{current_row}->column($n); }

# Ugh... these take boxes; adding before/after columns takes tokens!
sub addBeforeRow {
  my($self,@boxes)=@_;
  $$self{current_row}{before} = [@{ $$self{current_row}{before} || []},@boxes]; }

sub addAfterRow {
  my($self,@boxes)=@_;
  $$self{current_row}{after} = [@{ $$self{current_row}{after} || []},@boxes]; }

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
  my $alignment;
  while(! ($alignment=$body->getProperty('alignment'))){
    ($body)=grep($_->getProperty('alignment'),$body->unlist); }
  $alignment->setMath if $body->isMath;

  my %attr = ($props{attributes} ? %{$props{attributes}} : ());
  my $node = $alignment->beAbsorbed($document,%attr);
  # If requested to guess headers (unless cells are already marked)
  if($props{guess_headers} && !$document->findnodes("ancestor::ltx:tabular",$node)){
    if(!$document->findnodes('descendant::ltx:td[contains(@class,"thead")]',$node)){
      guess_alignment_headers($document,$node,$alignment); }
    elsif(!$body->isMath){	# in case already marked w/thead|tbody
      alignment_regroup_rows($document,$node); }}
  $node; }

sub beAbsorbed {
  my($self,$document,%attributes)=@_;
  my $ismath = $$self{isMath};

  # Scan for empty rows and collapse them
  my @filtering = @{$$self{rows}};
  my @rows=();
  while(my $row = shift(@filtering)){
    foreach my $c (@{$$row{columns}}){ # Fill in empty on completely empty columns
      $$c{empty}=1 unless $$c{boxes} && $$c{boxes}->unlist; }
    if(grep(! $$_{empty}, @{$$row{columns}})){ # Not empty! so keep it
      push(@rows,$row); }
    elsif(my $next = $filtering[0]){ # Remove empty row, but copy top border to NEXT row
      if($$row{empty}){              # Only remove middle rows if EXPLICITLY marked (\noalign)
        my $nc = scalar(@{$$row{columns}});
        for(my $c = 0; $c < $nc; $c++){
          my $border = $$row{columns}[$c]{border}||'';
          $border =~ s/[^tTbB]//g; # mask all but top & bottom border
          $border =~ s/./t/g;      # but convert to top
          $$next{columns}[$c]{border} .= $border;  }} # add to next row
      else {
        push(@rows,$row); }}
    else {                      # Remove empty last row, but copy top border to bottom of prev.
      my $prev = $rows[-1];
      my $nc = scalar(@{$$row{columns}});
      for(my $c = 0; $c < $nc; $c++){
        my $border = $$row{columns}[$c]{border}||'';
        $border =~ s/[^tT]//g;  # mask all but top border
        $border =~ s/./b/g;     # convert to bottom
        $$prev{columns}[$c]{border} .= $border; }} # add to previous row.
  }
  $$self{rows}=[@rows];

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
  &{$$self{openContainer}}($document,%attributes);
  foreach my $row (@{$$self{rows}}){
    &{$$self{openRow}}($document,'xml:id'=>$$row{id},
		       refnum=>$$row{refnum},frefnum=>$$row{frefnum},rrefnum=>$$row{rrefnum});
    if(my $before = $$row{before}){
      map($document->absorb($_),@$before); }
    foreach my $cell (@{$$row{columns}}){
      next if $$cell{skipped};
      # Normalize the border attribute
      my $border = join(' ',sort(map(split(/ */,$_),$$cell{border}||'')));
      $border =~ s/(.) \1/$1$1/g;
      my $empty = !$$cell{boxes} || !scalar($$cell{boxes}->unlist);
      $$cell{cell} = &{$$self{openColumn}}($document,
                                           align=>$$cell{align}, width=>$$cell{width},
                                           vattach=>$$cell{vattach},
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
      &{$$self{closeColumn}}($document); }
    if(my $after = $$row{after}){
      map($document->absorb($_),@$after); }
    &{$$self{closeRow}}($document); }
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
      Warn('unexpected',$op,$gullet,"Unrecognized tabular template '".Stringify($op)."'"); }
    last unless $nopens; }
  push(@tokens,T_END);
  $LaTeXML::BUILD_TEMPLATE->setReversion(@tokens);
  return $LaTeXML::BUILD_TEMPLATE; }

sub parseAlignmentTemplate {
  my($spec)=@_;
  $STATE->getStomach->getGullet->readingFromMouth(LaTeXML::Mouth->new("{".$spec."}"), sub {
     ReadAlignmentTemplate($_[0]); }); }

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
  $data{save_between} = [] unless $data{save_between}; # between comes before before!

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

# These add material before & after the current column
sub addBeforeColumn {
  my($self,@tokens)=@_;
  unshift(@{$$self{save_before}},@tokens); } # NOTE: goes all the way to front!

sub addAfterColumn {
  my($self,@tokens)=@_;
 $$self{current_column}{after} = Tokens(@tokens,@{ $$self{current_column}{after}}); }

# Or between this column & next...
sub addBetweenColumn {
  my($self,@tokens)=@_;
  my @cols = @{$$self{columns}};
  if($$self{current_column}){
    $$self{current_column}{after} = Tokens(@{ $$self{current_column}{after}},@tokens); }
  else                      { 
    push(@{$$self{save_between}},@tokens); }}

sub addColumn {
  my($self,%properties)=@_;
  my $col = {%properties};
  my @before=();
  push(@before,@{$$self{save_between}}) if $$self{save_between};
  push(@before,$properties{before}->unlist) if $properties{before};
  push(@before,@{$$self{save_before}}) if $$self{save_before};
  $$col{before} = Tokens(@before);
  $$col{after}  = Tokens() unless $properties{after};
  $$col{head}   = $properties{head};
  $$col{empty}  = 1;
  $$self{save_between}=[];
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
  my $x;
  print STDERR "\n".('='x50)."\nGuessing alignment headers for "
    .(($x=$document->findnode('ancestor-or-self::*[@xml:id]',$table))? $x->getAttribute('xml:id') : $tag)."\n"
      if $LaTeXML::Alignment::DEBUG;

  my $ismath = $tag eq 'ltx:XMArray';
  local $LaTeXML::TR = ($ismath ? 'ltx:XMRow' : 'ltx:tr');
  local $LaTeXML::TD = ($ismath ? 'ltx:XMCell' : 'ltx:td');
  my $reversed=0;
  # Build a view of the table by extracting the rows, collecting & characterizing each cell.
  my @rows = collect_alignment_rows($document,$table,$alignment);
  # Flip the rows around to produce a column view.
  my @cols = ();
  return unless @rows;
  for(my $c = 0; $c < scalar(@{$rows[0]}); $c++){
    push(@cols, [map($$_[$c], @rows)]); }

  # Attempt to recognize header lines.
  if(alignment_characterize_lines(0,0,@rows)){}
  # This usually does something unpleasant
##  else { 
##    print STDERR "Retry characterizing lines in reverse\n" if $LaTeXML::Alignment::DEBUG;
##    $reversed=alignment_characterize_lines(0,1,reverse(@rows)); }
  alignment_characterize_lines(1,0,@cols);
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
  # But not if it's a math array, or if reversed (since browsers get confused?)
  if(!$ismath && !$reversed){
    alignment_regroup_rows($document,$table); }
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

# this version works w/o the row data
sub alignment_regroup_rows {
  my($document,$table)=@_;
  my ($group,$grouptype)=(undef,0);
  foreach my $xrow ($document->findnodes("ltx:tr",$table)){
    # if any non thead cells, we'll consider it tbody...
    my $rowtype = (grep( (!$_->getAttribute('thead')) && (($_->getAttribute('class')||'') !~/\bthead\b/),
			 $document->findnodes('ltx:td',$xrow) )
		   ? 'tbody' : 'thead');
    if($grouptype ne $rowtype){
      $group = $table->addNewChild($xrow->getNamespaceURI, $grouptype = $rowtype);
      $table->insertBefore($group,$xrow); }
    $group->appendChild($xrow); }
  }

#======================================================================
# Build a View of the alignment, with characterized cells, for analysis.
our %ALIGNMENT_CODE = (right=>'r', left=>'l', center=>'c', justify=>'p');

sub collect_alignment_rows {
  my($document,$table,$alignment)=@_;
  my @arows = @{$$alignment{rows}};
  my $nrows = scalar(@arows);
  my $ncols = 0;
  foreach my $arow (@arows){
    my $n = scalar(@{$$arow{columns}});
    $ncols = $n if $n > $ncols; }
  my @rows = ();
  my ($h,$v)=(0,0);
  foreach my $arow (@arows){
    push(@rows, [ ] );
    my @cols = @{$$arow{columns}};
    foreach my $col (@cols){
      push(@{$rows[$#rows]}, $col);
      $$col{cell_type} = 'd';
      $$col{content_class} = (($$col{align}||'') eq 'justify' ? 'mx' # Assume mixed content for any justified cell???
			      : ($$col{cell} ? classify_alignment_cell($document,$$col{cell}) : '?'));
      $$col{content_length} = ($$col{content_class} eq 'g' ? 1000
			       : ($$col{cell} ? length($$col{cell}->textContent) : 0));
      my %border = (t=>0, r=>0, b=>0, l=>0); # Decode border
      map($border{$_}++, split(/ */,$$col{border}||''));
      $h = 1 if $border{t} || $border{b};
      $v = 1 if $border{r} || $border{l};
      map($$col{$_} = $border{$_}, keys %border); }
    # pad the columns out.
    for(my $c=scalar(@cols); $c < $ncols; $c++){
      my $col = {};
      push(@{$rows[$#rows]}, $col);
      $$col{align} = 'c';
      $$col{cell_type} = 'd';
      $$col{content_class} = '_';
      $$col{content_length} =0;
      map($$col{$_} = 0, qw(t r b l)); }
  }
  # copy the characterizations to spanned cells
  for(my $r=0; $r<$nrows; $r++){
    for(my $c=0; $c<$ncols; $c++){
      my $rs = $rows[$r][$c]{rowspan}||1;
      my $cs = $rows[$r][$c]{span}||1; # NOT colspan!!!!!!
      my $ca = $rows[$r][$c]{align};
      my $cc = $rows[$r][$c]{content_class};
      my $cl = $rows[$r][$c]{content_length};
      my $rb = $rows[$r][$c]{r};  $rows[$r][$c]{r} = 0;
      my $bb = $rows[$r][$c]{b};  $rows[$r][$c]{b} = 0;
      for(my $sc = 1; $sc < $cs; $sc++){
	$rows[$r][$c+$sc]{align} = $ca;
	$rows[$r][$c+$sc]{content_class} = $cc;
	$rows[$r][$c+$sc]{content_length} = $cl; }
      for(my $sr = 1; $sr < $rs; $sr++){
	for(my $sc = 0; $sc < $cs; $sc++){
	  $rows[$r+$sr][$c+$sc]{align} = $ca;
	  $rows[$r+$sr][$c+$sc]{content_class} = $cc;
	  $rows[$r+$sr][$c+$sc]{content_length} = $cl; }}
      # move the outer borders
      for(my $sr = 0; $sr < $rs; $sr++){
	$rows[$r+$sr][$c+$cs-1]{r} = $rb; }
      for(my $sc = 0; $sc < $cs; $sc++){
	$rows[$r+$rs-1][$c+$sc]{b} = $bb; }
      }}

  # Now, do some border massaging...
  for(my $r=0; $r<$nrows; $r++){
    $rows[$r][0]{l}=$v;
    $rows[$r][0]{r}=$rows[$r][1]{l} if ($ncols>1) && $rows[$r][1]{l}; 
    $rows[$r][$ncols-1]{l}=$rows[$r][$ncols-2]{r} if ($ncols>1) && $rows[$r][$ncols-2]{r};
    $rows[$r][$ncols-1]{r}=$v; }
  for(my $c=0; $c<$ncols; $c++){
    $rows[0][$c]{t}=$h;
    $rows[0][$c]{b}=$rows[1][$c]{t} if ($nrows>1) && $rows[1][$c]{t};
    $rows[$nrows-1][$c]{t}=$rows[$nrows-2][$c]{b} if ($nrows>1) && $rows[$nrows-2][$c]{b};
    $rows[$nrows-1][$c]{b}=$h; }
  for(my $r=1; $r<$nrows-1; $r++){
    for(my $c=1; $c<$ncols-1; $c++){
      $rows[$r][$c]{t}=$rows[$r-1][$c]{b} if $rows[$r-1][$c]{b};
      $rows[$r][$c]{b}=$rows[$r+1][$c]{t} if $rows[$r+1][$c]{t};
      $rows[$r][$c]{l}=$rows[$r][$c-1]{r} if $rows[$r][$c-1]{r};
      $rows[$r][$c]{r}=$rows[$r][$c+1]{l} if $rows[$r][$c+1]{l}; }}
  if($LaTeXML::Alignment::DEBUG){
    print STDERR "\nCell characterizations:\n";
    for(my $r=0; $r<$nrows; $r++){
      for(my $c=0; $c<$ncols; $c++){
	my $col = $rows[$r][$c];
	print STDERR "[$r,$c]=>".($$col{cell_type}||'?')
	  .($$col{align} ? $ALIGNMENT_CODE{$$col{align}} : ' ')
	    .($$col{content_class}||'?')
	      .' '.$$col{content_length}
		.' '.$$col{border}."=>".join('',grep($$col{$_},qw(t r b l)))
		  .(($$col{rowspan}||1)>1 ? " rowspan=".$$col{rowspan} :'')
		    .(($$col{span}||1)>1 ? " colspan=".$$col{span} :'')
		      ."\n";}}}
  @rows; }

# Return one of: i(nteger), t(ext), m(ath), ? (unknown) or '_' (empty) (or some combination)
#  or 'mx' for alternating text & math.
sub classify_alignment_cell {
  my($document,$xcell)=@_;
  my $content = $xcell->textContent;
  my $class='';
#  if($content =~ /^\s*\d+\s*$/){
  if($content =~ /^[\s\d]+$/){
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
	elsif($chtag eq 'ltx:graphics'){
	  $class .= 'g' unless $class eq 'g'; }
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
  my($axis,$reversed,@lines)=@_;
  my $n = scalar(@lines);
  return unless $n > 1;
  local @::TABLINES = @lines;
  print STDERR "\nCharacterizing $n ".($axis ? "columns" : "rows")."\n   " if $LaTeXML::Alignment::DEBUG;

  # Establish a scale of differences for the table.
  my($diffhi,$difflo,$diffavg)=(0,99999999,0);
  for(my $l = 0; $l < $n-1; $l++){
    my $d = alignment_compare($axis,1,$reversed,$l,$l+1);
    $diffavg += $d;
    $diffhi = $d if $d > $diffhi;
    $difflo = $d if $d < $difflo; }
  $diffavg = $diffavg/($n-1);
  if($diffhi < 0.05){		# virtually no differences.
    print STDERR "Lines are almost identical => Fail\n" if $LaTeXML::Alignment::DEBUG;
    return; }
  if(($n > 2) && (($diffhi-$difflo) < $diffhi*0.5)){ # differences too similar to establish pattern
    print STDERR "Differences between lines are almost identical => Fail\n" if $LaTeXML::Alignment::DEBUG;
    return; }
#  local $::TAB_THRESHOLD = $difflo + 0.4*($diffhi-$difflo);
  local $::TAB_THRESHOLD = $difflo + 0.3*($diffhi-$difflo);
#  local $::TAB_THRESHOLD = $difflo + 0.2*($diffhi-$difflo);
#  local $::TAB_THRESHOLD = $diffavg;
  local $::TAB_AXIS = $axis;
  print STDERR "\nDifferences $difflo -- $diffhi => threshold = $::TAB_THRESHOLD\n" if $LaTeXML::Alignment::DEBUG;
  # Find the first hump in differences. These are candidates for header lines.
  print STDERR "Scanning for headers\n   " if $LaTeXML::Alignment::DEBUG;
  my $diff;
  my($minh,$maxh)=(1,1);
  while( ($diff=alignment_compare($axis,1,$reversed,$maxh-1,$maxh)) < $::TAB_THRESHOLD){
    $maxh++; }
  return if $maxh > $MAX_ALIGNMENT_HEADER_LINES; # too many before even finding diffs? give up!
#  while( alignment_compare($axis,1,$reversed,$maxh,$maxh+1) > $difflo + ($diff-$difflo)/6){
  while( alignment_compare($axis,1,$reversed,$maxh,$maxh+1) > $::TAB_THRESHOLD){
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
      return 1; }}
  undef; }

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
##  if(($headlength > 10) && (0.3*$headlength > $datalength)){
  if(($headlength > 10) && (0.25*$headlength > $datalength)){
    print STDERR "header content too much longer than data content\n" if $LaTeXML::Alignment::DEBUG;
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
      || alignment_compare($::TAB_AXIS,0,0, $p1+$i, $p2+$i) >= $::TAB_THRESHOLD; }
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
    last unless (alignment_compare($::TAB_AXIS,1,0, $i+$n-1, $i+$n) < $::TAB_THRESHOLD)
      # Accept an outlying `continuation line' as data, if mostly empty
      || (($n > 1) && (scalar(grep($$_{content_class} eq '_', @{$::TABLINES[$i+$n]})) > 0.4*scalar($::TABLINES[0])));
    $n++; }
  print STDERR "\nFound $n data lines at $i\n" if $LaTeXML::Alignment::DEBUG;
  ($n >= $MIN_ALIGNMENT_DATA_LINES ? $n : 0); }

sub XXXalignment_max_content_length {
  my($length,$from,$to)=@_;
  foreach my $j ( ($from..$to) ){
    foreach my $cell (@{$::TABLINES[$j]}){
      $length = $$cell{content_length}
	if $$cell{content_length} && ($$cell{content_length} > $length); }}
  $length; }

# Return the maximum "content length" for lines from $from to $to.
sub alignment_max_content_length {
  my($length,$from,$to)=@_;
  foreach my $j ( ($from..$to) ){
    my $l=0;
    foreach my $cell (@{$::TABLINES[$j]}){
      $l += $$cell{content_length}; }
    $length = $l if $l > $length; }
  $length; }

#======================================================================
# The comparator.
# our %cell_class_diff =
#   ('_'=>{'_'=>0.0, m=>0.1, i=>0.1, t=>0.1, '?'=>0.1, mx=>0.1},
#    m  =>{'_'=>0.1, m=>0.0, i=>0.1, mx=>0.2},
#    i  =>{'_'=>0.1, m=>0.1, i=>0.0, mx=>0.2},
#    t  =>{'_'=>0.1, t=>0.0, mx=>0.2},
#    '?'=>{'_'=>0.1, '?'=>0.0, mx=>0.2},
#    mx=>{'_'=>0.1, m=>0.2, i=>0.2, t=>0.2, '?'=>0.2, mx=>0.0});

our %cell_class_diff =
  ('_'=>{'_'=>0.0, m=>0.05, i=>0.05, t=>0.05, '?'=>0.05, mx=>0.05},
   m  =>{'_'=>0.05, m=>0.0, i=>0.1, mx=>0.2},
   i  =>{'_'=>0.05, m=>0.1, i=>0.0, mx=>0.2},
   t  =>{'_'=>0.05, t=>0.0, mx=>0.2},
   '?'=>{'_'=>0.05, '?'=>0.0, mx=>0.2},
   mx=>{'_'=>0.05, m=>0.2, i=>0.2, t=>0.2, '?'=>0.2, mx=>0.0});

# Compare two lines along $axis (0=row,1=column), returning a measure of the difference.
# The borders are compared differently if
#  $foradjacency: we adjacent lines that might belong to the same block,
#  otherwise    : comparing two lines that ought to have identical patterns (eg. in a repeated block)
sub alignment_compare {
  my($axis, $foradjacency,$reversed, $p1,$p2)=@_;
  my $line1 = $::TABLINES[$p1];
  my $line2 = $::TABLINES[$p2];
  return 0 if !($line1 && $line2);
  return 999999 if $line1 xor $line2;
  my @cells1 = @$line1;
  my @cells2 = @$line2;
  my $ncells = scalar(@cells1);
  my $diff=0.0;
  while(@cells1 && @cells2){
    my $cell1 = shift(@cells1);
    my $cell2 = shift(@cells2);
#    $diff += 0.5 if (($$cell1{align}||'') ne ($$cell2{align}||''))
    $diff += 0.75 if (($$cell1{align}||'') ne ($$cell2{align}||''))
      && ($$cell1{content_class} ne '_') && ($$cell2{content_class} ne '_');
    if(my $d = $cell_class_diff{$$cell1{content_class}}{$$cell2{content_class}}){
      $diff += $d; }
    elsif($$cell1{content_class} ne $$cell2{content_class}){
      $diff += 0.75; }
    # compare certain edges
    if($foradjacency){		# Compare edges for adjacent rows of potentially different purpose
      $diff += 0.3*scalar(grep($$cell1{$_} != $$cell2{$_}, ($axis == 0 ? qw(r l) : qw(t b))));
      # Penalty for apparent divider between.
      my $pedge  = ($axis == 0 ? ($reversed ? 't' : 'b') : ($reversed ? 'l' : 'r'));
      if($$cell1{$pedge} && ($$cell1{$pedge} != $$cell2{$pedge})){
#	print STDERR "Penalty on axis $axis for $p1 ($$cell1{$pedge}) & $p2 ($$cell2{$pedge})\n";
#	$diff += 2; }
#	$diff += abs($$cell1{$pedge}-$$cell2{$pedge}) * 2.0/ $ncells; }
	$diff += abs($$cell1{$pedge}-$$cell2{$pedge}) * 1.0; }
    }
    else {			# Compare edges for rows from diff places for potential similarity
      $diff += 0.3*scalar(grep($$cell1{$_} != $$cell2{$_}, qw(r l t b))); }
  }
  $diff /= $ncells;
  print STDERR "$p1-$p2 => $diff; " if $LaTeXML::Alignment::DEBUG;
  return $diff; }

#======================================================================
# Debugging.
sub summarize_alignment {
  my($rows,$cols)=@_;
  my $r=0;
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
			   .($$cell{align} ? $ALIGNMENT_CODE{$$cell{align}} : ' ')
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
