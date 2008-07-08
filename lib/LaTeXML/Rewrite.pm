# /=====================================================================\ #
# |  LaTeXML::Rewrite                                                   | #
# | Rewrite Rules that modify the Constructed Document                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#======================================================================
package LaTeXML::Rewrite;
use strict;
use LaTeXML::Global;

sub new {
  my($class,$mode,@specs)=@_;
  my @clauses = ();
  while(@specs){
    my($op,$pattern) = (shift(@specs),shift(@specs));
   push(@clauses,['uncompiled',$op,$pattern]); }
  bless {mode=>$mode, math=>($mode eq 'math'), clauses=>[@clauses], labels=>{}}, $class; }

sub clauses { @{$_[0]->{clauses}}; }

sub rewrite {
  my($self,$document,$node)=@_;
  foreach my $node ($document->findnodes('//*[@labels]')){
    my $labels = $node->getAttribute('labels');
    if(my $id = $node->getAttribute('xml:id')){
      foreach my $label (split(/ /,$labels)){
	$$self{labels}{$label}=$id; }}
    else {
      Warn(":malformed Node has labels \"$labels\" but no xml:id ".Stringify($node)); }}
    $self->applyClause($document,$node,0,$self->clauses); }

sub getLabelID {
  my($self,$label)=@_;
  if(my $id = $$self{labels}{LaTeXML::Package::CleanLabel($label)}){ $id; }
  else {
    Error(":malformed:<rewrite> No id for label $label in Rewrite");
    undef; }}

# Rewrite spec as input
#   scope  => $scope  : a scope like "section:1.2.3" or "label:eq.one"; translated to xpath
#   select => $xpath  : selects subtrees based on xpath expression.
#   match  => $code   : called on $document and current $node: tests current node, returns $nnodes, if match
#   match  => $string : Treats as TeX, converts Box, then DOM tree, to xpath 
#                      (The matching top-level nodes will be replaced, if replace is the next op.)
#   replace=> $code   : removes the current $nnodes, calls $code with $document and removed nodes
#   replace=> $string : removes $nnodes 
#                       Treats $string as TeX, converts to Box and inserts to replace
#                       the removed nodes.
#   attributes=>$hash : adds data from hash as attributes to the current node. 
#   regexp  => $string: apply regexp (subst) to all text nodes in/under the current node.

# Compiled rewrite spec:
#   select => $xpath  : operate on nodes selected by $xpath.
#   test   => $code   : Calls $code on $document and current $node.
#                       Returns number of nodes matched.
#   replace=> $code   : removes the current $nnodes, calls $code on them.
#   action => $code   : invoke $code on current $node, without removing them.
#   regexp  => $string: apply regexp (subst) to all text nodes in/under the current node.

sub applyClause {
  my($self,$document,$tree,$n_to_replace,$clause,@more_clauses)=@_;
  if($$clause[0] eq 'uncompiled'){
    $self->compileClause($document,$clause); }
  my($ignore,$op,$pattern)=@$clause;
  if($op eq 'trace'){
    local $LaTeXML::Rewrite::DEBUG = 1;
    $self->applyClause($document,$tree,$n_to_replace,@more_clauses); }
  elsif($op eq 'ignore'){
    $self->applyClause($document,$tree,$n_to_replace,@more_clauses); }
  elsif($op eq 'select'){
    my($xpath,$nnodes)=@$pattern;
    my @matches = $document->findnodes($xpath,$tree);
    print STDERR "Rewrite selecting \"$xpath\" => ".scalar(@matches)." matches\n" if $LaTeXML::Rewrite::DEBUG;
    foreach my $node (@matches){
      next unless $node->ownerDocument->isSameNode($tree->ownerDocument); # If still attached to original document!
      $self->applyClause($document,$node,$nnodes,@more_clauses); }}
  elsif($op eq 'multi_select'){
    foreach my $subpattern (@$pattern){
      my($xpath,$nnodes)=@$subpattern;
      my @matches = $document->findnodes($xpath,$tree);
      print STDERR "Rewrite selecting \"$xpath\" => ".scalar(@matches)." matches\n" if $LaTeXML::Rewrite::DEBUG;
      foreach my $node (@matches){
	next unless $node->ownerDocument->isSameNode($tree->ownerDocument); # If still attached to original document!
	$self->applyClause($document,$node,$nnodes,@more_clauses); }}}
  elsif($op eq 'test'){
    my $nnodes = &$pattern($document,$tree);
    print STDERR "Rewrite test at ".$tree->toString.": ".($nnodes ? $nnodes." to replace" : "failed")."\n" 
      if $LaTeXML::Rewrite::DEBUG;
    $self->applyClause($document,$tree,$nnodes,@more_clauses) if $nnodes; }
  elsif($op eq 'wrap'){
    if($n_to_replace > 1){
      my $parent = $tree->parentNode;
      # Remove & separate nodes to be replaced, and sibling nodes following them.
      my @following = ();		# Collect the matching and following nodes
      while(my $sib = $parent->lastChild){
	$parent->removeChild($sib);
	unshift(@following,$sib);
	last if $$sib == $$tree; }
      my @replaced = map(shift(@following), 1..$n_to_replace); # Remove the nodes to be replaced
      $document->setNode($parent);
      $tree = $document->openElement('ltx:XMWrap', font=>$document->getNodeFont($parent));
      print STDERR "Wrapping ".join(' ',map(Stringify($_),@replaced))."\n" if $LaTeXML::Rewrite::DEBUG;
      map($tree->appendChild($_), @replaced); # Add matched nodes to XMWrap
      map( $parent->appendChild($_), @following); # Add back the following nodes.
    }
    $self->applyClause($document,$tree,1,@more_clauses); }
  elsif($op eq 'replace'){
    print STDERR "Rewrite replace at ".$tree->toString." using $pattern\n" if $LaTeXML::Rewrite::DEBUG;
    my $parent = $tree->parentNode;

    # Remove & separate nodes to be replaced, and sibling nodes following them.
    my @following = ();		# Collect the matching and following nodes
    while(my $sib = $parent->lastChild){
      $parent->removeChild($sib);
      unshift(@following,$sib);
      last if $$sib == $$tree; }
    my @replaced = map(shift(@following), 1..$n_to_replace); # Remove the nodes to be replaced

    # Carry out the operation, inserting whatever nodes.
    $document->setNode($parent);
    my $point = $parent->lastChild;
    &$pattern($document,@replaced);	# Carry out the insertion.

    # Now collect the newly inserted nodes and store in a _Capture_ node.
    my @inserted = ();		# Collect the newly added nodes.
    if($point){
      while(my $sib = $parent->lastChild){
	$parent->removeChild($sib);
	unshift(@inserted,$sib); 
	last if $$sib == $$point; }}
    else {
      @inserted = $parent->childNodes; }
    my $insertion = $document->openElement('_Capture_', font=>$document->getNodeFont($parent));
    map($insertion->appendChild($_), @inserted);

    # Apply PRECEDING rules to the insertion.
#####    $document->getModel->applyRewrites($document,$insertion,$self);
    # Now remove the insertion and replace with rewritten nodes and replace the following siblings.
    @inserted = $insertion->childNodes;
    $parent->removeChild($insertion);
    map( $parent->appendChild($_), @inserted, @following);
  }
  elsif($op eq 'action'){
    print STDERR "Rewrite action at ".$tree->toString." using $pattern\n" if $LaTeXML::Rewrite::DEBUG;
    &$pattern($tree); }
  elsif($op eq 'attributes'){
    map( $tree->setAttribute($_,$$pattern{$_}), keys %$pattern); 
    print STDERR "Rewrite attributes for ".Stringify($tree)."\n" if $LaTeXML::Rewrite::DEBUG;
  }
  elsif($op eq 'regexp'){
    my @matches = $document->findnodes('descendant-or-self::text()',$tree);
    print STDERR "Rewrite regexp => ".scalar(@matches)." matches\n" if $LaTeXML::Rewrite::DEBUG;
    foreach my $text (@matches){
      my $string = $text->textContent;
      if(&$pattern($string)){
	$text->setData($string); }}}
  else {
    Error(":malformed:<rewrite> Unknown directive \"$op\" in Compiled Rewrite spec"); }
}

#**********************************************************************
sub compileClause {
  my($self,$document,$clause)=@_;
  my($ignore,$op,$pattern)= @$clause;
  my($oop,$opattern)=($op,$pattern);
  if   ($op eq 'label'){
    if(ref $pattern eq 'ARRAY'){
#      $op='multi_select'; $pattern = [map(["descendant-or-self::*[\@label='$_']",1], @$pattern)]; }
      
      $op='multi_select'; $pattern = [map(["descendant-or-self::*[\@xml:id='$_']",1],
					  map($self->getLabelID($_),@$pattern))]; }
    else {
#      $op='select'; $pattern=["descendant-or-self::*[\@label='$pattern']",1]; }}
      $op='select'; $pattern=["descendant-or-self::*[\@xml:id='".$self->getLabelID($pattern)."']",1]; }}
  elsif($op eq 'scope'){
    $op='select';
    if($pattern =~ /^label:(.*)$/){
#      $pattern=["descendant-or-self::*[\@label='$1']",1]; }
      $pattern=["descendant-or-self::*[\@xml:id='".$self->getLabelID($1)."']",1]; }
    elsif($pattern =~ /^id:(.*)$/){
      $pattern=["descendant-or-self::*[\@xml:id='$1']",1]; }
    elsif($pattern =~ /^(.*):(.*)$/){
      $pattern=["descendant-or-self::*[local-name()='$1' and \@refnum='$2']",1]; }
    else {
      Error(":malformed:<rewrite> Unrecognized scope pattern in Rewrite clause: \"$pattern\"; Ignoring it."); 
      $op='ignore'; $pattern=[]; }}
  elsif($op eq 'xpath'){
    $op='select'; $pattern=[$pattern,1]; }
  elsif($op eq 'match'){
    if(ref $pattern eq 'CODE'){
      $op='test'; }
    elsif(ref $pattern eq 'ARRAY'){ # Multiple patterns!
      $op = 'multi_select'; 
      $pattern = [map(  $self->compile_match($document,$_), @$pattern)]; }
    else {
      $op = 'select'; $pattern= $self->compile_match($document,$pattern); }}
  elsif($op eq 'replace'){
    if(ref $pattern eq 'CODE'){}
    else {
      $pattern = $self->compile_replacement($document,$pattern); }}
  elsif($op eq 'regexp'){
    $pattern = $self->compile_regexp($pattern); }
  print STDERR "Compiled clause $oop=>".ToString($opattern)."  ==> $op=>".ToString($pattern)."\n"
    if $LaTeXML::Rewrite::DEBUG;
  $$clause[0]='compiled'; $$clause[1]=$op; $$clause[2]=$pattern; }

#**********************************************************************
sub compile_match {
  my($self,$document,$pattern)=@_;
  if(!ref $pattern){
    $self->compile_match1($document,digest_rewrite(($$self{math} ? '$'.$pattern.'$' : $pattern))); }
  elsif($pattern->isaBox){
    $self->compile_match1($document,$pattern); }
  else {
    Error(":malformed:<rewrite> Don't know what to do with match=>\"".Stringify($pattern)."\""); }}

sub compile_match1 {
  my($self,$document,$patternbox)=@_;
  # Create a temporary document
  my $capdocument = LaTeXML::Document->new($document->getModel);
  my $capture = $capdocument->openElement('_Capture_', font=>LaTeXML::Font->new());
  $capdocument->absorb($patternbox);
#####  $capdocument->getModel->applyRewrites($capdocument,$capdocument->getDocument->documentElement,$self);
  my @nodes= ($$self{mode} eq 'math'
	      ? $capdocument->findnodes("//ltx:XMath/*",$capture)
	      : $capture->childNodes);
  my $frag = $capdocument->getDocument->createDocumentFragment;
  map($frag->appendChild($_), @nodes);
  # Convert the captured nodes to an XPath that would match them.
  my $xpath = domToXPath($capdocument,$frag);
  # For math, restrict to NOT operate on presentation branch of XMDual.
  # The semantics should already be associated with it, through the XMDual itself.
  # This assumes that any arguments in the presentation branch are by reference (XMRef)
  # to the same args in the content branch --- thus the args will still be matched.
  $xpath .= "[not(ancestor-or-self::*[parent::ltx:XMDual and not(following-sibling::*)])]"
    if $$self{math};

  print STDERR "Converting \"".ToString($patternbox)."\"\n  => xpath= \"$xpath\"\n" if $LaTeXML::Rewrite::DEBUG;
  [$xpath,scalar(@nodes)]; }

sub XXXcompile_replacement {
  my($self,$document,$pattern)=@_;
  if(!ref $pattern){
    $self->compile_replacement1(digest_rewrite(($$self{math} ? '$'.$pattern.'$' : $pattern))); }
  elsif($pattern->isaBox){
    $self->compile_replacement1($pattern); }
  else {
    $self->compile_replacement1(digest_rewrite($pattern)); 
}}

sub XXXcompile_replacement1 {
  my($self,$patternbox)=@_;
  $patternbox = $patternbox->getBody if $$self{math};
  sub { $_[0]->absorb($patternbox); }}


# Reworked to do digestion at replacement time.
sub compile_replacement {
  my($self,$document,$pattern)=@_;

  if((ref $pattern) && $pattern->isaBox){
    $pattern = $pattern->getBody if $$self{math};
    sub { $_[0]->absorb($pattern); }}
  else {
    $pattern = Tokenize($$self{math} ? '$'.$pattern.'$' : $pattern) unless ref $pattern;
    sub {
      my $stomach = $STATE->getStomach;
      $stomach->bgroup;
      $STATE->assignValue(font=>LaTeXML::Font->new(), 'local');
      $STATE->assignValue(mathfont=>LaTeXML::MathFont->new(), 'local');
      my $box = $stomach->digest($pattern,0);
      $stomach->egroup;
      $box = $box->getBody if $$self{math};
      $_[0]->absorb($box); }
}}

sub compile_regexp {
  my($self,$pattern)=@_;
  my $code =  "sub { \$_[0] =~ s${pattern}g; }";
  my $fcn = eval $code;
  Error(":malformed:<rewrite> Failed to compile regexp pattern \"$pattern\" into \"$code\": $!") if $@;
  $fcn; }

#**********************************************************************

sub digest_rewrite {
  my($string)=@_;
  my $stomach = $STATE->getStomach;
  $stomach->bgroup;
  $STATE->assignValue(font=>LaTeXML::Font->new(), 'local');  # Use empty font, so eventual insertion merges.
  $STATE->assignValue(mathfont=>LaTeXML::MathFont->new(), 'local');
  my $box = $stomach->digest((ref $string ? $string : Tokenize($string)),0);
  $stomach->egroup;
  $box; }

#**********************************************************************
sub domToXPath {
  my($document,$node)=@_;
  "descendant-or-self::". domToXPath_rec($document,$node); }

# May need some work here;
our %EXCLUDED_MATCH_ATTRIBUTES=(scriptpos=>1);

sub domToXPath_rec {
  my($document,$node,@extra_predicates)=@_;
  my $type = $node->nodeType;
  if($type == XML_DOCUMENT_FRAG_NODE){
    my @nodes = $node->childNodes;
    domToXPath_rec($document,shift(@nodes) , domToXPath_seq($document,'following-sibling',@nodes), @extra_predicates); }
  elsif($type == XML_ELEMENT_NODE){
    my $qname = $document->getNodeQName($node);
    return '*[true()]' if $qname eq '_WildCard_';
    my @predicates =();
    # Order the predicates so as to put most quickly restrictive first.
    if($node->hasAttributes){
      foreach my $attribute (grep($_->nodeType == XML_ATTRIBUTE_NODE, $node->attributes)){
	my $key = $attribute->nodeName;
	next if ($key =~ /^_/) || $EXCLUDED_MATCH_ATTRIBUTES{$key};
	push(@predicates, "\@".$key."='".$attribute->getValue."'"); }}
    if($node->hasChildNodes){
      my @children = $node->childNodes;
      if(! grep($_->nodeType != XML_TEXT_NODE,@children)){ # All are text nodes:
	push(@predicates, "text()='".$node->textContent."'"); }
      elsif(! grep($_->nodeType != XML_ELEMENT_NODE,@children)){
	push(@predicates,domToXPath_seq($document,'child',@children)); }
      else {
	Fatal(":misdefined:<rewrite> Cannot generate XPath for mixed content on ".$node->toString); }}
###    if($document->getModel->canHaveAttribute($qname,'font')){
###      if(my $font = $node->getAttribute('_font')){
###	push(@predicates,"\@_font and match-font('".$font."',\@_font)"); }}
    if($document->getModel->canHaveAttribute($qname,'font')){
      if(my $font = $node->getAttribute('_font')){
	my $pred = LaTeXML::Font::font_match_xpaths($font);
##	print STDERR "Font $font => $pred\n";
	push(@predicates,$pred); }}

    $qname."[".join(' and ',grep($_,@predicates,@extra_predicates))."]"; }

  elsif($type == XML_TEXT_NODE){
###    "text()='".$node->textContent."'"; }}
    "*[text()='".$node->textContent."']"; }}

# $axis would be child or following-sibling
sub domToXPath_seq {
  my($document,$axis,@nodes)=@_;
  if(@nodes){
    $axis."::*[position()=1 and self::"
      .   domToXPath_rec($document,shift(@nodes),domToXPath_seq($document,'following-sibling',@nodes)).']'; }
  else { (); }}

#**********************************************************************
1;


__END__

=pod 

=head1 NAME

C<LaTeXML::Rewrite> - rewrite rules for modifying the XML document.

=head1 DESCRIPTION

C<LaTeXML::Rewrite> implements rewrite rules for modifying the XML document.

=head2 Methods

=over 4

=item C<< $rule->rewrite($document,$node); >>

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
