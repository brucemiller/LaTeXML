# /=====================================================================\ #
# |  LaTeXML::Post::HTMLTable                                           | #
# | Table postprocessing for LaTeXML                                    | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
#======================================================================
# LaTeXML Table postprocessing support
# Transform a LaTeX tabular into some kind of HTML-like table model.
# HTML's isn't as rich, or even particularly great, but it _is_ useful.
# So, with minimal heuristics, we try to approximate the table with HTML characteristics.
# Written as a module since some of the steps become awkward in XSL.
# Also, serves as a guide to converting to other table models (DocBook?...)

# Attempts to convert the pattern attribute (from the tabular's column spec),
# and the sequence of hlines into the appropriate set of
# frame attributes and column groups.
#======================================================================
# Note that HTML separates the rules into the outer frame and inner
# rules that separate cells or groups of cells, horizontally and/or vertically.
#
# Check if there is some nobreak property that can be applied to
# non-justify columns?
#
# Note that the Mozilla folks resent having to correlate the info on colgroups
# to the columns within the table --- it looks unlikely to change.
# So we have to put the alignment on ALL cells.

#======================================================================
package LaTeXML::Post::HTMLTable;
use strict;
use LaTeXML::Util::LibXML;
use Text::Balanced;

sub new {
  my($class,%options)=@_;
  bless {verbosity            => $options{verbosity}||0,
	},$class; }

#**********************************************************************
sub process {
  my($self,$doc,%options)=@_;
  $$self{verbosity} = $options{verbosity}||0;
  foreach my $tabular ($self->find_tabular_nodes($doc)){
    $self->process_tabular($tabular); }
  $doc; }

#**********************************************************************
# Potentially customizable
#**********************************************************************
# If you've got a different XML document model, or even not an XML
# document at all, subclassing MathImages and overriding these methods
# will allow generation of a set of math images.

# Return the list of nodes that have math in them.
# Default is look for XMath elements with a tex attribute.
sub find_tabular_nodes {
  my($self,$doc)=@_;
  $doc->findnodes('.//tabular'); }

#**********************************************************************
# Closest HTML frame value for RLBT (in binary)
our @framespec=qw(void above below hsides
		  lhs above below box
		  rhs above below box
		  vsides box box box);
sub process_tabular {
  my($self,$tabular)=@_;

  # --- Analyze Table ----
  # Split columns & rows into groups separated by | or hlines, resp.
  # Each is alternating list of counts (of hlines or |) and arrays of alignments or rows.
  my @colgroups = group_cols($tabular->getAttribute('pattern'));
  my @rowgroups = group_rows(element_nodes($tabular));
  my @cols = map(@$_, grep(ref $_, @colgroups));
  my @rows = map(@$_, grep(ref $_, @rowgroups));

  # Determine the outer frame, based on leading/trailing vbars/hlines (numbers)
  my $frame = $framespec[(!ref $rowgroups[0]           ? 1 : 0)+
			 (!ref $rowgroups[$#rowgroups] ? 2 : 0)+
			 (!ref $colgroups[0]           ? 4 : 0)+
			 (!ref $colgroups[$#colgroups] ? 8 : 0)];

  # Count rows|columns and groups of them.
  my $ncols      = scalar(@cols);
  my $ncolgroups = scalar(grep(ref $_, @colgroups));
  my $nrows      = scalar(@rows);
  my $nrowgroups = scalar(grep(ref $_, @rowgroups));

  # Determine inner rules based on grouping.
  # Particularly, whether each col|row is a group to itself, or all are in a single group.
  my $rules = 'groups';
  if   (($ncolgroups == $ncols) && ($nrowgroups == $nrows)){ $rules='all'; }
  elsif(($ncolgroups == $ncols) && ($nrowgroups == 1)     ){ $rules='cols'; }
  elsif(($ncolgroups == 1)      && ($nrowgroups == $nrows)){ $rules='rows'; }
  elsif(($ncolgroups == 1)      && ($nrowgroups == 1)     ){ $rules='none'; }

  # --- Clear and Rebuild the Table ----
  # Remove all elements & text nodes from table.
  clear_node($tabular);

  # Add the computed frame & rule to the tabular, and alignment attributes to the cells
  $tabular->setAttribute('frame',$frame);
  $tabular->setAttribute('rules',$rules);
  foreach my $row (@rows){
    my $j=0;
    foreach my $cell ($row->getChildrenByTagName('td')){
      if(my $span = $cell->getAttribute('colspan')){ # From \multicolumn
	$cell->setAttribute('align',map(@$_, grep(ref $_, group_cols($cell->getAttribute('pattern')))));
	$cell->removeAttribute('pattern');
	$j += $span; }
      else {
	$cell->setAttribute('align',$cols[$j++]); }}}

  # Add column groups, if there is non-trivial grouping
  if($rules eq 'groups'){
    foreach my $cols (grep(ref $_, @colgroups)){
      if(!grep($cols->[0] ne $_, @$cols)){ # All alignments are same?
	append_nodes($tabular,new_node('colgroup',undef,span=>scalar(@$cols),align=>$cols->[0])); }
      else {
	append_nodes($tabular,new_node('colgroup',[map(new_node('col',undef,align=>$_),@$cols)])); }}}

  # Finally, add the rows back in, possibly grouped into tbody's
  if($rules eq 'groups'){
    # Here'd be a good place to guess whether the 1st group might be a header????
    append_nodes($tabular,map(new_node('tbody',$_), grep(ref $_, @rowgroups))); }
  else {
    append_nodes($tabular, @rows); }
}

#======================================================================
# Parse a tabular column specification, returning an alternating list of:
#   number: representing the repeat count of '|'
#   ARRAY : representing the sequence of column alignments: (right|left|center|justify)
sub group_cols {
  my($pattern)=@_;
  my (@groups,@group);
  while($pattern){
    if   ($pattern =~ s/^(\|+)//){ 
      push(@groups,[@group]) if @group; @group=();
      push(@groups,length($1));  }
    elsif($pattern =~ s/^r// ){ push(@group,'right'); }
    elsif($pattern =~ s/^l// ){ push(@group,'left'); }
    elsif($pattern =~ s/^c// ){ push(@group,'center'); }
    elsif($pattern =~ s/^p//){ 	# Paragraph: p{width}
      my $ignore;
      ($ignore,$pattern)=Text::Balanced::extract_bracketed($pattern,"{}");
      push(@group,'justify'); }
    elsif($pattern =~ s/^\*\{(\d+)\}//){ # Repeated pattern: *{n}{subpattern}; expand & put back
      my $n=$1;
      my ($sub,$rest)=Text::Balanced::extract_bracketed($pattern,"{}");
      $pattern=join('',map($sub,1..$n),$rest); }
    elsif($pattern =~ s/^\@//){	# Insertion between columns: Ignore it!!!
      my $ignore;
      ($ignore,$pattern)=Text::Balanced::extract_bracketed($pattern,"{}"); }
  }
  push(@groups,[@group]) if @group;
  @groups; }

# Group the tabular rows, returning an alternating list of:
#   number : representing the repeat count of <hline/>'s
#   ARRAY  : being the sequence of <tr>..</tr> between sets of <hlines/>
sub group_rows {
  my(@rows)=@_;
  my (@groups,@group);
  my $prevhline;
  foreach my $row (@rows){
    my $type = $row->nodeName;
    if($type eq 'hline'){ 
      if($prevhline){ $groups[$#groups]++; }
      else {
	push(@groups,[@group]) if @group; @group=();
	push(@groups,1); 
	$prevhline=1;}}
    elsif($type eq 'tr'){
      $prevhline=undef;
      push(@group,$row); }
    else {
      warn("What's a <$type> doing in a tabular?"); }
  }
  push(@groups,[@group]) if @group;
  @groups; }

#======================================================================
#======================================================================
#======================================================================

# 6th step: Guess if we have a header.
#   an hline near top (especially if the only one)?
#   alternatively a doubled hline near top when singles are used later?
#   the 1st rowgroup is diff length than all others?
#   1st row(s) are significantly different from renaining rows. eg. diff tags within td?
# To impliment a row header, Wrap in thead (or change tbody to thead) and change all td's to th's
# Should also look for a leading column as unique and change them to th's !!
sub guess_header {
  my($self)=@_;
#  my $pos=0;
#  if((@hlines == 1) &&($hlines[0] < 2)){ # hline likely delimits heading?
#    @rows = grep($_->tag eq 'tr', @rows);
#    my @head = @rows[0..$hlines[0]];
#    map( map( (($_->tag eq 'td') && ($_->set_tag('th'))), $_->content), @head);
#    map($table->remove($_), @head);
#    my $thead = LaTeXML::DOM::Node->new('thead');
#    map($thead->insert($_),@head);
#    $table->insert($thead,$pos);
#  }
}

#======================================================================
1;
