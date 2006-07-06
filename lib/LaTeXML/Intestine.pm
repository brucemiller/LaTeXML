# /=====================================================================\ #
# |  LaTeXML::Intestine                                                 | #
# | Constructs the DOM from digested material                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Intestine;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
use LaTeXML::DOM;
our @ISA = qw(LaTeXML::Object);
#**********************************************************************

# [could conceivable make more sense to let the Stomach create the Intestine?]

sub new {
  my($class, $stomach)=@_;
  bless {model=>$stomach->getModel, 
#	 initialFont=>$stomach->getFont, 
	 initialFont=>$stomach->getValue('default@textfont'),
	 stomach=>$stomach,
	 progress=>0},$class; }

#**********************************************************************
# Accessors
sub getModel { $_[0]->{model}; }

sub getRootNode { $_[0]->{root}; }
sub getNode     { $_[0]->{node}; }
sub setNode     { $_[0]->{node} = $_[1]; }

sub getContext {
  my($self,$short)=@_;
  my $node = $$self{node};
  my $box = $LaTeXML::BOX;
  my $msg = "During DOM construction ";
  $msg .= "for ".$box->toString." from ".$box->getSourceLocator if $box;
  $msg .= "\n" unless $short;
  $node = undef if $short && $box; # ignore node if want short & have box
  $msg .= $node->getContext($short) if $node;
  $msg; }

#**********************************************************************
# Allow lookup of values from Stomach.
# Only will work for values globally set during digestion.

sub getValue { $_[0]->{stomach}->getValue($_[1]); }
sub setValue { $_[0]->{stomach}->setValue($_[1],$_[2],1); }

#**********************************************************************
# Given a digested document, process it, constructing a DOM tree.
sub buildDOM {
  my($self,$doc)=@_;
  NoteProgress("\n(Building");
  local $LaTeXML::INTESTINE = $self;
  local $LaTeXML::STOMACH   = $$self{stomach}; # Can still access FINAL state
  local $LaTeXML::MODEL     = $$self{model};
  $$self{model}->loadDocType([$$self{stomach}->getSearchPaths]);
  $$self{node} = $$self{root} = LaTeXML::DOM::Document->new();
  $$self{node}->setAttribute('font',$$self{initialFont});
  $self->absorb($doc);
  NoteProgress(")");
  $$self{root}; }

sub absorb {
  my($self,$box)=@_;
  if(defined $box){
    local $LaTeXML::BOX = $box;
    $box->beAbsorbed($self); }}

#**********************************************************************
# Handlers for various construction operations.
# General naming: 'open' opens a node at current pos and sets it to current,
# 'close' closes current node(s), inserts opens & closes, ie. w/o moving current

# Tricky: if there's a font switch, we may want to open or close nodes.
# We'll want to close nodes if we can minimize the number of font switches.
sub openText {
  my($self,$text,$font)=@_;
  my $n = $$self{node};
  my ($closeable,$bestdiff,$closeto,$lastcloseto,$f)=(1,99999,$n,$n);
  while(defined $n){
    $closeable &&= $n->canAutoClose;
    if(defined (my $f = $n->getAttribute('font'))){
      my $d = $font->distance($f);
      if($d < $bestdiff){
	$bestdiff = $d;
	$closeto = $lastcloseto; 
	last if ($d == 0); }
      last unless $closeable;
      $lastcloseto = $n->getParentNode; }
    $n = $n->getParentNode; }

  # Maybe close some nodes.
  while($$self{node} != $closeto){
    $$self{node} = $$self{node}->getParentNode; } # Hmm... this avoids the daemons!
  # Maybe open a new node.
  if($bestdiff > 0){
    # NOTE: We've embedded the element name here!!! Arghh!!!
    $self->openElement('textstyle',font=>$font); }
  # Finally, insert the darned text.
  $$self{node} = $$self{node}->insertText($text); }

sub insertMathToken {
  my($self,$string,$font)=@_;
  $self->openElement('XMTok', font=>$font);
  $self->getNode->insertText($string);
  $self->closeElement('XMTok'); }

sub openElement {
  my($self,$tag,%attributes)=@_;
  NoteProgress('.') if ($$self{progress}++ % 25)==0;
  $$self{node} = $$self{node}->open($tag,%attributes); 
  # Probably here is the place we can set the `origin' of the node, 
  # or whatever that evolves into....
  if(defined(my $post=$$self{model}->getTagProperty($tag,'afterOpen'))){
    &$post($$self{node},$LaTeXML::BOX); }
  $$self{node}; }

sub closeElement {
  my($self,$tag)=@_;
  $$self{node} = $$self{node}->close($tag); 
  if(defined(my $post=$$self{model}->getTagProperty($tag,'afterClose'))){
    # Hopefully, the node we want to process is now the last child of the
    # current node that has the correct type?
    my @nodes = grep($_->getNodeName eq $tag, $$self{node}->childNodes);
    my $node = $nodes[$#nodes];
    &$post($node,$LaTeXML::BOX); }
  $$self{node}; }

sub openComment {
  my($self,$text)=@_;
  $$self{node} = $$self{node}->insertComment($text); }

sub insertPI      { 
  my($self,$op,%attrib)=@_;
  $$self{node}->insert(LaTeXML::DOM::ProcessingInstruction->new($op,%attrib));}

# Shorthand
sub insertElement {
  my($self,$tag,$content,%attrib)=@_;
  $self->openElement($tag,%attrib);
  $self->absorb($content);
  $self->closeElement($tag); }

#**********************************************************************
# Higher level: Interpret a Constructor pattern.
# It looks like XML!
# Must be called from within ->absorb, so that $BOX is bound to Whatsit.
# Binds $_ to the constructor being parsed.
#our $VALUE_RE = "(\\#|\\%)";
our $VALUE_RE = "(\\#)";
our $COND_RE  = "\\?$VALUE_RE";
our $QNAME_RE = "([\\w\\-_]+)";	# Eventually allow prefixes?
our $TEXT_RE  = "([^\\#<\\?]+|.)";

sub interpretConstructor {
  my($self,$constructor)=@_;
  local $_ = $constructor;
  my $floats = s/^\^\s*//;	# Grab float marker.
  my $savenode = undef;
  while($_){
    if(/^$COND_RE/o){
      apply_conditional(); }
    # Processing instruction: <?name a=v ...?>
    elsif(s|^\s*<\?$QNAME_RE||o){
      $self->insertPI($1,parse_avpairs());
      Error("Missing \"?>\" in constructor at \"$_\"") unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif(s|^\s*<$QNAME_RE||o){
      my $tag = $1;
      # Floating elements: temporarily move to a parent that accepts this element.
      if($floats && !defined $savenode){
	for(my $n=$self->getNode; defined $n; $n = $n->getParentNode){
	  if($n->canContain($tag)){
	    $savenode = $self->getNode; $self->setNode($n); last; }}}
      $self->openElement($tag,parse_avpairs());
      $self->closeElement($tag) if s|^/||; # Empty element.
      Error("Missing \">\" in constructor at \"$_\"") unless s|^>||; }
    # Close tag: </name>
    elsif(s|^\s*</$QNAME_RE\s*>||o){
      $self->closeElement($1); }
    # Substitutable value: argument, property...
    elsif(/^$VALUE_RE/o){ 
      $self->absorb(parse_value()); }
    # Attribute: a=v; assigns in current node? [May conflict with random text!?!]
    elsif(s|^$QNAME_RE\s*=\s*||o){
      my ($n,$key) = ($self->getNode,$1);
      while($floats && defined $n && ! $n->canHaveAttribute($key)){
	$n = $n->getParentNode; }
      Error("No open node can accept attribute $key") unless defined $n; 
      $n->setAttribute($key,parse_string()); }
    # Else random text
    elsif(s/^$TEXT_RE//o){	# Else, just some text.
      $self->openText($1,$LaTeXML::BOX->getFont); }
  }
  $self->setNode($savenode) if defined $savenode; # Restore original node, if we floated
}

# process a conditional in a constructor
# Conditionals are of the form ?value(...)(...),
# standing for IF-ELSE; the ELSE clause is optional.
# It does NOT handled nested conditionals!!!
sub apply_conditional {
  if(s/^\?//){
    my $bool = parse_value();
    s/^\((.*?)\)(\((.*?)\))?/ ($bool ? $1 : $3)||''; /e
      or Error("Unbalanced conditional in \"$_\"");
  }}

# Parse a substitutable value from the constructor (in $_)
# Recognizes the #1, %prop, possibly followed by {foo}, for KeyVals,
# Future enhancements? array ref, &foo(xxx) for function calls, ...
sub parse_value {
  my $value;
  if   (s/^\#(\d+)//     ){ $value = $LaTeXML::BOX->getArg($1); }
  elsif(s/^\#([\w\-_]+)//){ $value = $LaTeXML::BOX->getProperty($1); }
  # &foo(...) ? Function (but not &foo; !!!)
  if(s/^\{$QNAME_RE\}//o && defined $value){
    Error("{} accessor applied to non-KeyVals arg in constructor")
      unless (ref $value eq 'LaTeXML::KeyVals');
    $value = $value->getValue($1); }
  # Array??? 
  $value; }

# Parse a delimited string from the constructor (in $_), 
# for example, an attribute value.  Can contain substitutions (above),
# the result is a string.
# NOTE: UNLESS there is ONLY one substituted value, then return the value object.
# This is (hopefully) temporary to handle font objects as attributes.
# The DOM holds the font objects, rather than strings,
# to resolve relative fonts on output.
sub parse_string {
  my @values=();
  if(s/^\s*([\'\"])//){
    my $quote = $1;
    while($_ && !s/^$quote//){
      if   ( /^$COND_RE/o              ){ apply_conditional(); }
      elsif( /^$VALUE_RE/o             ){ push(@values,parse_value()); }
      elsif(s/^(.[^\#<\?\!$quote]*)//){ push(@values,$1); }}}
  if(!@values){ undef; }
  elsif(@values==1){ $values[0]; }
  else { join('',map( (ref $_ ? $_->toString : $_), @values)); }}

# Parse a set of attribute value pairs from a constructor pattern, 
# substituting argument and property values from the whatsit.
sub parse_avpairs {
  my %attr=();		# Check substitutions for attributes.
  s|^\s*||;
  while($_){
    if(/^$COND_RE/o){
      apply_conditional(); }
    elsif(s|^$QNAME_RE\s*=\s*||o){
      my ($key,$value) = ($1,parse_string());
      $attr{$key}=$value if defined $value; }
    else { last; }
    s|^\s*||; }
  %attr; }

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Intestine

=head2 DESCRIPTION

LaTeXML::Intestine carries out the construction of the document tree (represented by
a LaTeXML::DOM::Document) by traversing the digested LaTeXML::List coming from the
LaTeXML::Stomach.  

=head2 Top-Level Method

=over 4

=item C<< $doc = $intestine->buildDOM($list); >>

Build and return a DOM from the digested $list.
This is done by invoking the absorb method of the digested objects, passing
the intestine as argument.

=back

=head2 Accessing the Intestine's state

=over 4

=item C<< $model = $intestine->getModel; >>

Returns the current LaTeXML::Model being used.

=item C<< $doc = $intestine->getRootNode; >>

Returns the root node (LaTeXML::DOM::Document) of the document being constructed.

=item C<< $node = $intestine->getNode; >>

Returns the node at the current insertion point during construction.  This node
is considered still to be `open'; any insertions will go into it (if possible).

=item C<< $string = $intestine->getContext; >>

Returns a string describing the current position in the constructed tree, for
error messages.

=back

=head2 Methods useful for Document Construction

=over 4

=item C<< $intestine->openText($text,$font); >>

Open a node for text in font $font, performing any required automatic opening
and closing of intermedate nodes (including those needed for font changes) 
and inserting the string $text into it.

=item C<< $intestine->insertMathToken($string,$font); >>

Insert a math token (XMTok) containing the string $string in the given font.

=item C<< $intestine->openElement($tag,%attributes); >>

Open an element, named $tag and with the given attributes.
This will be inserted into the current node while  performing 
any required automatic opening and closing of intermedate nodes.
The new element becomes the current node.
An error is signalled if there is no allowed way to insert such an element into
the current node.

=item C<< $intestine->closeElement($tag); >>

Close the closest open element named $tag including any intermedate nodes that
may be automatically closed.  If that is not possible, signal an error.
The closed node's parent becomes the current node.

=item C<< $intestine->openComment($text); >>

Insert a comment with the given $text into the current node.

=item C<< $intestine->insertPI($op,%attributes); >>

Insert a ProcessingInstruction into the current node.

=item C<< $intestine->insertElement($tag,$content,%attributes); >>

This is a shorthand for creating an element $tag (with given attributes),
absorbing $content from within that new node, and then closing it.

=cut

