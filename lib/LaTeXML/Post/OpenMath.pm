# /=====================================================================\ #
# |  LaTeXML::Post::OpenMath                                            | #
# | OpenMath generator for LaTeXML                                      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# ================================================================================
# TODO
#     Scheme for mapping from LaTeXML's "meaning" => cd+name
# Unfortunately, OpenMath's naming scheme is unweildy, unless you are
# completely immersed in the OpenMath world. It is also incomplete in
# the sense that it doesn't cover nearly enough symbols that LaTeXML encounters.
# And, of course, many of those symbols are ambiguous!
#
# So, I think LaTeXML's naming scheme is a worthwhile one to pursue,
# but we DO need to provide a rich but customizable mapping, starting with stuff like:
#    equals => arith1:eq
# ================================================================================
package LaTeXML::Post::OpenMath;
use strict;
use LaTeXML::Common::XML;
use base qw(LaTeXML::Post);

our $omURI = "http://www.openmath.org/OpenMath";

sub process {
  my($self,$doc)=@_;
  if(my @maths = $self->find_math_nodes($doc)){
    $self->Progress($doc,"Converting ".scalar(@maths)." formulae");
#    $doc->addNamespace($omURI,'om');
    foreach my $math (@maths){
      $self->processNode($doc,$math); }
    $doc->adjust_latexml_doctype('OpenMath'); } # Add OpenMath if LaTeXML dtd.
  $doc; }

sub setParallel {
  my($self,@moreprocessors)=@_;
  $$self{parallel}=1;
  $$self{math_processors} = [@moreprocessors]; }


sub find_math_nodes { $_[1]->findnodes('//ltx:Math'); }

sub getQName {
  $LaTeXML::Post::DOCUMENT->getQName(@_); }

# $self->processNode($doc,$mathnode) is the top-level conversion
# It converts the XMath within $mathnode, and adds it to the $mathnode,
sub processNode {
  my($self,$doc,$math)=@_;
  my $mode = $math->getAttribute('mode')||'inline';
  my $xmath = $doc->findnode('ltx:XMath',$math);
  my $style = ($mode eq 'display' ? 'display' : 'text');
  if($$self{parallel}){
    $doc->addNodes($math,$self->translateParallel($doc,$xmath,$style,'ltx:Math')); }
  else {
    $doc->addNodes($math,$self->translateNode($doc,$xmath,$style,'ltx:Math')); }}

sub translateNode {
  my($self,$doc,$xmath,$style,$embedding)=@_;
  $doc->addNamespace($omURI,'om');
  my @trans = Expr($xmath);
  # Wrap unless already embedding within MathML.
  ($embedding =~ /^om:/ ? @trans : ['om:OMOBJ',{},@trans]); }

sub getEncodingName { 'OpenMath'; }

sub translateParallel {
  my($self,$doc,$xmath,$style,$embedding)=@_;
  $doc->addNamespace($omURI,'om');
  my @trans = ['om:OMATTR',{},
	       map( (['om:OMS',{cd=>"Alternate", name=>$_->getEncodingName}],
		     ['om:OMFOREIGN',{},$_->translateNode($doc,$xmath,$style,'om:OMATTR')]),
		    @{$$self{math_processors}}),
	       $self->translateNode($doc,$xmath,$style,'om:OMATTR') ];
  # Wrap unless already embedding within MathML.
  ($embedding =~ /^om:/ ? @trans : ['om:OMOBJ',{},@trans]); }

# ================================================================================
our $OMTable={};

sub DefOpenMath {
  my($key,$sub) =@_;
  $$OMTable{$key} = $sub; }

# Is it clear that we should just getAttribute('role'),
# instead of the getOperatorRole like in MML?
sub Expr {
  my($node)=@_;
  return OMError("Missing Subexpression") unless $node;
  my $tag = getQName($node);
  if($tag eq 'ltx:XMath'){
    my($item,@rest)=  element_nodes($node);
    print STDERR "Warning! got extra nodes for content!\n" if @rest;
    Expr($item); }
  elsif($tag eq 'ltx:XMDual'){
    my($content,$presentation) = element_nodes($node);
    Expr($content); }
  elsif($tag eq 'ltx:XMWrap'){
    # Note... Error?
##    Row(grep($_,map(Expr($_),element_nodes($node)))); 
    (); }
  elsif($tag eq 'ltx:XMApp'){
    my($op,@args) = element_nodes($node);
    return OMError("Missing Operator") unless $op;
    my $sub = lookupConverter('Apply',$op->getAttribute('role'),$op->getAttribute('meaning'));
    &$sub($op,@args); }
  elsif($tag eq 'ltx:XMTok'){
    my $sub = lookupConverter('Token',$node->getAttribute('role'),$node->getAttribute('meaning'));
    &$sub($node); }
  elsif($tag eq 'ltx:XMHint'){
    (); }
  else {
    ['om:OMSTR',{},$node->textContent]; }}

sub lookupConverter {
  my($mode,$role,$name)=@_;
  $name = '?' unless $name;
  $role = '?' unless $role;
  $$OMTable{"$mode:$role:$name"} || $$OMTable{"$mode:?:$name"}
    || $$OMTable{"$mode:$role:?"} || $$OMTable{"$mode:?:?"}; }

# ================================================================================
# Helpers
sub OMError {
  my($msg)=@_;
  ['om:OME',{},
   ['om:OMS',{name=>'unexpected', cd=>'moreerrors'}],
   ['om:OMS',{},$msg]]; }
# ================================================================================
# Tokens

# Note: In general, there needs to be a lot more support/analysis.
# Here, we simply assume that the token is a variable if there's no CD!!!
# See comments above about meaning.
# With the gradual refinement of meaning, in the lack of a mapping,
# we'll just presume that the cd defaults to latexml...
DefOpenMath('Token:?:?',    sub { 
  my($token)=@_;
  if(my $meaning = $token->getAttribute('meaning')){
    my $cd = $token->getAttribute('omcd') || 'latexml';
    ['om:OMS',{name=>$meaning, cd=>$cd}]; }
  else {
    my $name = $token->getAttribute('name') || $token->textContent;
    ['om:OMV',{name=>$name}]; }});

# NOTE: Presence of '.' distinguishes float from int !?!?
DefOpenMath('Token:NUMBER:?',sub {
  my($node)=@_;
  my $value = $node->getAttribute('meaning'); # name attribute (may) holds actual value.
  $value = $node->textContent unless defined $value;
  if($value =~ /\./){
    ['om:OMF',{dec=>$value}]; }
  else {
    ['om:OMI',{},$value]; }});

DefOpenMath('Token:SUPERSCRIPTOP:?',sub {
   ['om:OMS',{name=>'superscript',cd=>'ambiguous'}];});
DefOpenMath('Token:SUBSCRIPTOP:?',sub {
   ['om:OMS',{name=>'subscript',cd=>'ambiguous'}];});

DefOpenMath("Token:?:\x{2062}", sub {
  ['om:OMS',{name=>'times', cd=>'arith1'}]; });

# ================================================================================
# Applications.

# Generic

DefOpenMath('Apply:?:?', sub {
  my($op,@args)=@_;
  ['om:OMA',{},map(Expr($_),$op,@args)]; });

# NOTE: No support for OMATTR here...

# NOTE: Sketch of what OMBIND support might look like.
# Currently, no such construct is created in LaTeXML...
DefOpenMath('Apply:LambdaBinding:?', sub {
  my($op,$expr,@vars)=@_;
  ['om:OMBIND',{},
   ['om:OMS',{name=>"lambda", cd=>'fns1'},
    ['om:OMBVAR',{},map(Expr($_),@vars)], # Presumably, these yield OMV
    Expr($expr)]]; });

# ================================================================================
1;
