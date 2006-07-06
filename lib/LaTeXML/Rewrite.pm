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
use XML::LibXML;

sub new {
  my($class,$mode,@specs)=@_;
  my @clauses = ();
  while(@specs){
    my($op,$pattern) = (shift(@specs),shift(@specs));
   push(@clauses,['uncompiled',$op,$pattern]); }
  bless {mode=>$mode, math=>($mode eq 'math'), clauses=>[@clauses]}, $class; }

sub clauses { @{$_[0]->{clauses}}; }

sub rewrite {
  my($self,$document,$node)=@_;
    $self->applyClause($document,$node,0,$self->clauses); }

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
    $self->compileClause($clause); }
  my($ignore,$op,$pattern)=@$clause;
  if($op eq 'select'){
    my($xpath,$nnodes)=@$pattern;
    print STDERR "Rewrite selecting \"$xpath\"\n" if $LaTeXML::Rewrite::DEBUG;
    foreach my $node ($MODEL->getXPath->findnodes($xpath,$tree)){
      next unless $node->ownerDocument->isSameNode($tree->ownerDocument); # If still attached to original document!
      $self->applyClause($document,$node,$nnodes,@more_clauses); }}
  elsif($op eq 'test'){
    my $nnodes = &$pattern($document,$tree);
    print STDERR "Rewrite test at ".$tree->toString.": ".($nnodes ? $nnodes." to replace" : "failed")."\n" 
      if $LaTeXML::Rewrite::DEBUG;
    $self->applyClause($document,$tree,$nnodes,@more_clauses) if $nnodes; }
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
    $MODEL->applyRewrites($document,$insertion,$self);
    # Now remove the insertion and replace with rewritten nodes and replace the following siblings.
    @inserted = $insertion->childNodes;
    $parent->removeChild($insertion);
    map( $parent->appendChild($_), @inserted, @following);
  }
  elsif($op eq 'action'){
    print STDERR "Rewrite action at ".$tree->toString." using $pattern\n" if $LaTeXML::Rewrite::DEBUG;
    &$pattern($tree); }
  elsif($op eq 'attributes'){
    map( $tree->setAttribute($_,$$pattern{$_}), keys %$pattern); }
  elsif($op eq 'regexp'){
    foreach my $text ($MODEL->getXPath->findnodes('descendant-or-self::text()',$tree)){
      my $string = $text->textContent;
      if(&$pattern($string)){
	$text->setData($string); }}}
  else {
    Error("Unknown directive \"$op\" in Compiled Rewrite spec"); }
}

#**********************************************************************
sub compileClause {
  my($self,$clause)=@_;
  my($ignore,$op,$pattern)= @$clause;
  if   ($op eq 'scope'){
    $op='select';
    if($pattern =~ /^label:(.*)$/){
      $pattern=["descendant-or-self::*[\@label='$1']",1]; }
    elsif($pattern =~ /^(.*):(.*)$/){
      $pattern=["descendant-or-self::*[local-name()='$1' and \@refnum='$2']",1]; }
    else {
      Error("Unrecognized scope pattern in Rewrite clause: \"$pattern\""); }}
  elsif($op eq 'xpath'){
    $op='select'; $pattern=[$pattern,1]; }
  elsif($op eq 'match'){
    if(ref $pattern eq 'CODE'){
      $op='test'; }
    elsif(!ref $pattern){	# Assume is TeX
      # Digest the TeX
      my $box = digest_rewrite(($$self{math} ? '$'.$pattern.'$' : $pattern));
      # Create a temporary document
      my $document = LaTeXML::Document->new();
      my $capture = $document->openElement('_Capture_', font=>LaTeXML::Font->new());
      $document->absorb($box);
      $MODEL->applyRewrites($document,$document->getDocument->documentElement,$self);
      my @nodes= ($$self{mode} eq 'math'
		  ? $MODEL->getXPath->findnodes("//ltxml:XMath/*",$capture)
		  : $capture->childNodes);
      my $frag = $document->getDocument->createDocumentFragment;
      map($frag->appendChild($_), @nodes);
      # Convert the captured nodes to an XPath that would match them.
      my $xpath = domToXPath($frag);
      print STDERR "Converting \"$pattern\"\n  => xpath= \"$xpath\"\n" if $LaTeXML::Rewrite::DEBUG;
      # Finally update the clause to match using that xpath expression.
      $op = 'select'; $pattern=[$xpath,scalar(@nodes)]; }}
  elsif($op eq 'replace'){
    if(ref $pattern eq 'CODE'){}
    elsif(!ref $pattern){	# Assume is TeX; A Constructor pattern could also make sense!
      my $box = digest_rewrite(($$self{math} ? '$'.$pattern.'$' : $pattern));
      $box = $box->getBody if $$self{math};
      $pattern = sub { $_[0]->absorb($box); }}}
  elsif($op eq 'regexp'){
    my $code =  "sub { \$_[0] =~ s${pattern}g; }";
    my $fcn = eval $code;
    if($@){ Error("Failed to compile regexp pattern \"$pattern\" into \"$code\": $!"); }
    else {
      $pattern = $fcn; }}
  $$clause[0]='compiled'; $$clause[1]=$op; $$clause[2]=$pattern; }

#**********************************************************************

sub digest_rewrite {
  my($string)=@_;
  $STOMACH->bgroup;
  $STATE->assign('value',font=>LaTeXML::Font->new(), 'local');  # Use empty font, so eventual insertion merges.
  $STATE->assign('value',mathfont=>LaTeXML::MathFont->new(), 'local');
  my $box = $STOMACH->digest(TokenizeInternal($string),0);
  $STOMACH->egroup;
  $box; }

#**********************************************************************
sub domToXPath {
  my($node)=@_;
  "descendant-or-self::". domToXPath_rec($node); }

sub domToXPath_rec {
  my($node,@extra_predicates)=@_;
  my $type = $node->nodeType;
  if($type == XML_DOCUMENT_FRAG_NODE){
    my @nodes = $node->childNodes;
    domToXPath_rec(shift(@nodes) , domToXPath_seq('following-sibling',@nodes), @extra_predicates); }
  elsif($type == XML_ELEMENT_NODE){
    my $ns = $node->namespaceURI;
    my $tag = $node->localname;
    return '*[true()]' if $tag eq '_WildCard_';
    my $name = ($ns ? $MODEL->getNamespacePrefix($ns).':'.$tag : $tag);
    my @predicates =();
    # Order the predicates so as to put most quickly restrictive first.
    if($node->hasAttributes){
      foreach my $attribute (grep($_->nodeType == XML_ATTRIBUTE_NODE, $node->attributes)){
	my $key = $attribute->nodeName;
	next if $key =~ /^_/;
	push(@predicates, "\@".$key."='".$attribute->getValue."'"); }}
    if($node->hasChildNodes){
      my @children = $node->childNodes;
      if(! grep($_->nodeType != XML_TEXT_NODE,@children)){ # All are text nodes:
	push(@predicates, "text()='".$node->textContent."'"); }
      elsif(! grep($_->nodeType != XML_ELEMENT_NODE,@children)){
	push(@predicates,domToXPath_seq('child',@children)); }
      else {
	Fatal("Cannot generate XPath for mixed content on ".$node->toString); }}
    if($MODEL->canHaveAttribute($tag,'font')){
      push(@predicates,"match-font('".$node->getAttribute('_font')."',\@_font)"); }

    $name."[".join(' and ',grep($_,@predicates,@extra_predicates))."]"; }
  elsif($type == XML_TEXT_NODE){
    "text()='".$node->textContent."'"; }}

# $axis would be child or following-sibling
sub domToXPath_seq {
  my($axis,@nodes)=@_;
  if(@nodes){
    $axis."::*[position()=1 and self::"
      .   domToXPath_rec(shift(@nodes),domToXPath_seq('following-sibling',@nodes)).']'; }
  else { (); }}

#**********************************************************************
1;
