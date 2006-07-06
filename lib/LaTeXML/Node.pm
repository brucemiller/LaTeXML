# /=====================================================================\ #
# |  LaTeXML::Node                                                      | #
# | Intermediate XML representation                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#**********************************************************************
# NOTE: Annoying features of the current arrangment:
#   * Making new nodes (of which class) is spread around too much.
#   * the provision for "insert in current node" vs. insert here
#     isn't _quite_ right (but getting close).
#**********************************************************************

package LaTeXML::Node;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
use XML::LibXML;
our @ISA = qw(LaTeXML::Object);

# Note that attributes beginning with "_" are hidden from the XML.
sub new {
  my($class,$tag,%attributes)=@_;
  foreach my $attr (keys %attributes){ # Clean out undefined attributes.
    delete $attributes{$attr} unless defined $attributes{$attr}; }
  bless {tag=>$tag, attributes=>{%attributes},  content=>[]}, $class; }

sub isaNode { 1; }
sub getNodeName   { $_[0]->{tag}; }
sub getParentNode { $_[0]->{parent}; }
# Get a node attribute: $node->getAttribute('foo');
sub getAttribute { $_[0]->{attributes}{$_[1]}; }
sub getAttributes{ $_[0]->{attributes}; }

# Set a node attribute; clears it, if undef.
sub setAttribute {
  my($self,$attr,$value)=@_;
  if(defined $value){
    # (sanitizing the characters happens on output)
    $$self{attributes}{$attr} = $value; }
  else {
    delete $$self{attributes}{$attr}; }}

sub removeAttribute {
  my($self,$attr)=@_;
  delete $$self{attributes}{$attr}; }

sub firstChild { $_[0]{content}->[0]; }
sub lastChild  { $_[0]{content}->[$#{$_[0]{content}}]; }
sub childNodes { @{$_[0]{content}}; }

sub removeChild {
  my($self,$node)=@_;
  $$self{content} = [grep(! ($_ eq $node), @{$$self{content}})]; }

# different API than standard replaceChild
sub replace {
  my($self,$node,@replacements)=@_;
  my @kids = @{$$self{content}};
  my $p = 0;
  while(($p <= $#kids) && ($kids[$p] ne $node)){ $p++; }
  if($p > $#kids){ push(@kids,@replacements); }
  else { splice(@kids,$p,1,@replacements); }
  $$self{content} = [@kids]; }

# Insert the child node into $self.
# If pos is defined, insert it into that position (eg. 0 is at beginning),
# else append.
sub insert {
  my($self,$child,$pos)=@_;
  $$child{parent}  = $self; 
  # Note the childs effective font, either declared or the declared font of $self.
  $$child{attributes}{_font} = $$child{attributes}{font} || $$self{attributes}{_font};
  $$child{document}= $$self{document};
  if(!defined $pos){
    push(@{$$self{content}},$child); }
  elsif($pos == 0){
    unshift(@{$$self{content}},$child); }
  else {
    my @k=@{$$self{content}};
    $$self{content}=[@k[0..$pos-1],$child,@k[$pos..$#k]]; }
  $child; }

#----------------------------------------------------------------------
# Various forms of output
sub sanitize {
  my($string)=@_;
  $string =~ s/&/&amp;/g;
  $string =~ s/\'/&apos;/g;
  $string =~ s/</&lt;/g;
  $string =~ s/>/&gt;/g;
  $string; }

# ONLY for testing (?) or not....
# Needed, since attributes can now be objects
# But, it is probably only needed for things that will be moved
# to postprocessing anyway!
sub getAttribute_string {
  my($self,$key)=@_;
  my $value = $$self{attributes}{$key};
  if(!defined $value){ $value; }
  elsif((ref $value) && $value->isa('LaTeXML::Font')){
    # Special case Font: make it relative to font inherited from parent.
    # We assume some parent has a Font in the same attribute.
    if(defined $self->getParentNode) {
      $value = $value->relativeTo($self->getParentNode->getAttribute('_font')); }
    else {
      $value = $value->stringify; }
    ($value ? $value :undef); }
  else {
    $value = $value->toString if ref $value;
    # Damn, comments are a pain ....
    $value =~ s/%.*?\n//gs;
    $value =~ s/\n//gs; 
    $value; }}

sub serializeAttributes {
  my($self)=@_;
  my $string='';
  foreach my $key (sort keys %{$$self{attributes}}){
    next if $key =~ /^_/;
    my $value = $self->getAttribute_string($key);
    $string .=' ' if $string;
#    $string.= $key."=\"".sanitize($value)."\"" if defined $value; }
    $string.= $key."=\"".$value."\"" if defined $value; }
  $string; }

sub stringify {
  my($self)=@_;
  "Node[".$$self{tag}.' '.$self->serializeAttributes."]"; }

sub textContent { join('',map($_->textContent,@{$_[0]{content}})); }

# Locator should be some sort of Box.
sub setLocator { $_[0]->{attributes}{_locator} = $_[1]; }
sub getLocator { 
  my($self)=@_;
  my $box = $$self{attributes}{_locator};
  (defined $box ?  "from ".$box->toString.' '.$box->getLocator : 'Unknown'); }

sub toXML {
  my($self,$doc,$parent)=@_;
  # If parent, add directly, so namespaces are managed better.
  my $ns = $$self{attributes}{_namespace};
  my $node = (defined $ns 
	      ? (defined $parent 
		 ? $parent->addNewChild($ns,$$self{tag})
		 : $doc->createElementNS($ns,$$self{tag}))
	      : (defined $parent 
		 ? $parent->addChild($doc->createElement($$self{tag}))
		 : $doc->createElement($$self{tag})));
  foreach my $key (sort keys %{$$self{attributes}}){
    next if $key =~ /^_/;
    my $value = $self->getAttribute_string($key);
    $node->setAttribute($key=>$value) if defined $value; }
  foreach my $child (@{$$self{content}}){
    map($node->appendChild($_), $child->toXML($doc,$node)); }
  ($parent ? () : ($node)); }	# if parent, already installed!

#**********************************************************************
# LaTeXML::TextNode;
#**********************************************************************
package LaTeXML::TextNode;
use LaTeXML::Global;
use strict;
use Unicode::Normalize;
use XML::LibXML;
our @ISA = qw(LaTeXML::Node);

# Presumably all attributes are hidden ones...
sub new {
  my($class,$text,%attributes)=@_;
  $text = "&amp;" if $text eq '&';
  bless {tag=>'#PCDATA', attributes=>{%attributes}, content=>[], text=>$text}, $class;  }

sub appendText {
  my($self,$text)=@_;
  $text = "&amp;" if $text eq '&';
  $$self{text} .= $text; }

sub textContent { $_[0]{text}; }

sub stringify {
  "TextNode[".$_[0]->{text}."]"; }

sub toXML {
  my($self,$doc,$parent)=@_;
  $doc->createTextNode(NFC($$self{text})); }

#**********************************************************************
# LaTeXML::CommentNode;
#**********************************************************************
package LaTeXML::CommentNode;
use strict;
use XML::LibXML;
our @ISA = qw(LaTeXML::Node);

sub new {
  my($class,$text,%attributes)=@_;
  bless {tag=>'_Comment_', attributes=>{%attributes}, content=>[], text=>$text}, $class; }

sub appendComment {
  my($self,$comment)=@_;
  $$self{text} .= $comment;
  $self; }

sub textContent { ""; }

sub stringify {
  "CommentNode[".$_[0]->{text}."]"; }

sub toXML {
  my($self,$doc,$parent)=@_;
  my $string = $$self{text};
  chomp($string);
  $string =~ s/\-\-+/__/g;
  ($doc->createComment(' '.$string.' '),
   # Just a hack to make comparison's easier.
   # Strictly, there probably shouldn't be a newline here, anyway...
   $doc->createTextNode("\n")); }

#**********************************************************************
# LaTeXML::ProcessingInstruction;
#**********************************************************************
package LaTeXML::ProcessingInstruction;
use strict;
use XML::LibXML;
our @ISA = qw(LaTeXML::Node);

sub new {
  my($class,$op,%attrib)=@_;
  bless {tag=>'_ProcessingInstruction_', op=>$op, 
	 attributes=>{%attrib}, content=>[]}, $class; }

sub textContent { ""; }

sub stringify {
  my($self)=@_;
  "ProcessingInstruction[".$$self{op}." ".$self->serializeAttributes."]"; }

sub toXML {
  my($self,$doc,$parent)=@_;
  $doc->createProcessingInstruction($$self{op},$self->serializeAttributes); }

#**********************************************************************
# LaTeXML::Document;
#**********************************************************************
package LaTeXML::Document;
use LaTeXML::Global;
use strict;
use XML::LibXML;
use XML::LibXML::Common qw(:libxml);

our @ISA = qw(LaTeXML::Node);

sub new {
  my($class,%attributes)=@_;
  bless {tag=>'_Document_', attributes=>{%attributes}, content=>[]}, $class; }

sub toXML {
  my($self)=@_;
  my $doc = XML::LibXML::Document->new('1.0','UTF-8');
  my @content = @{$$self{content}};
  my @roots = grep(ref $_ eq 'LaTeXML::Node', @content);
  Error("Document is Empty! ") if scalar(@roots)==0;
  Error("Document must have exactly 1 root element; it has ".
	join(', ',map(Stringify($_),@roots)))
    if (scalar(@roots) > 1);
  $doc->createInternalSubset($roots[0]->getNodeName,
			     $self->getAttribute('publicID'),$self->getAttribute('systemID'))
    if(@roots);
  foreach my $node (@content){
    foreach my $item ($node->toXML($doc,undef)){
      if($item->nodeType == XML_ELEMENT_NODE){
	$doc->setDocumentElement($item); }
      else {
	$doc->appendChild($item); }}}

  $doc; }
  
#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Node, LaTeXML::TextNode, LaTeXML::CommentNode, LaTeXML::ProcessingInstruction, LaTeXML::Document

=head2 DESCRIPTION

These classes form the intermediate represention of an XML Document during construction by the
L<LaTeXML::Intestine>; after the document tree is completed, it is converted to an
L<XML::LibXML::Document> via the C<toXML> method.  In most, or all, cases, it should be
unnecessary to create any of these objects, or to modify them; that can usually be left
to the Intestines.  It may be useful to inspect them, however.

C<LaTeXML::Node> represents elements, C<LaTeXML::TextNode> represents text nodes,
C<LaTeXML::CommentNode> represents comments, C<LaTeXML::ProcessingInstruction> represents
processing instructions and C<LaTeXML::Document> represents the top-level document.

=head2 Common Methods

=over 4

=item C<< $tag = $node->getNodeName; >>

Get the tag name of C<$node>.  For text, comments, processing instructions and documents, this yields
C<#PCDATA>, C<_Comment_> and C<_ProcessingInstruction_> and C<_Document_>, respectively.

=item C<< $parent = $node->getParentNode; >>

Return the parent node of C<$node>.

=item C<< $string = $node->textContent(); >>

Return the text content of C<$node>.

=item C<< $box = $node->getLocator(); >>

Return the box responsible for creating this C<$node>, if known.
If a box is returned, its C<getLocator> method can be used to determine the
point in the source file that created it.

=item C<< $xmlnode = $node->toXML($doc,$parent); >>

Convert the C<$node> to the appropriate L<XML::LibXML> representation.
C<$doc> is the L<XML::LibXML::Document> being constructed. C<$parent> is the
L<XML::LibXML::Node> for the parent of this node; it is undef for the root element
of the document.

=back

=head2 C<Node> Methods

=over 4

=item C<< $value = $node->getAttribute($key); >>

Get the value of the C<$key> attribute of C<$node>.
Generally this should be a string, but at least L<LaTeXML::Font> objects
may remain in object form until conversion (in order to get the inheritance right).

=item C<< $hash = $node->getAttributes; >>

Get a hash of all the attribitues of C<$node>.

=item C<< $node->setAttribute($key,$value); >>

Set the attribute C<$key> of C<$node> to C<$value>. If C<$value> is undef,
the attribute will be removed.

=item C<< $node->removeAttribute($key); >>

Remove the attribute C<$key> from C<$node>.

=item C<< $string = $node->getAttribute_string($key); >>

Get the attribute C<$key> of C<$node>, returning a string. This does any
necessary resolution (eg. for fonts) and stringification.

=item C<< $string = $node->serializeAttributes(); >>

Return a string representing the attribute-value pairs for C<$node>.

=item C<< $childnode = $node->firstChild; >>

Return the first child node of C<$node>, if any.

=item C<< $childnode = $node->lastChild; >>

Return the last child node of C<$node>, if any.

=item C<< $node->removeChild($childnode); >>

Remove C<$childnode> from C<$node>.

=item C<< $node->replace($childnode,@replacements); >>

Replace C<$childnode> in C<$node> by the nodes in C<@replacements>.

=item C<< $node->insert($childnode,$pos); >>

Insert C<$childnode> into C<$node> at the given position C<$pos>.
If C<$pos> is undefined, C<$childnode> will be appended to C<$node>.

=back

=head2 C<TextNode> Methods

=over 4

=item C<< $node = LaTeXML::TextNode->new($text,%attributes); >>

Create a text node with the given C<$text>.  Generally should not be needed.

=item C<< $node->appendText($string); >>

Append C<$string> to the text contained in C<$node>.

=back

=head2 C<CommentNode> Methods

=over 4

=item C<< $node = LaTeXML::CommentNode->new($text,%attributes); >>

Create a comment node with the given C<$text>.  Generally should not be needed.

=item C<< $node->appendComment($string); >>

Append C<$string> to the comment text contained in C<$node>.

=back

=head2 C<ProcessingInstruction> Methods

=over 4

=item C<< $node = LaTeXML::ProcessingInstruction->new($op,%attributes); >>

Create a processing instruction node with the given operator C<$op>
and C<%attributes>.  Thus,
C<< LaTeXML::ProcessingInstruction->new('foo',bar=>'baz') >>
would create  C<<  <?foo bar="baz"?> >>.
Generally should not be needed.

=back

=head2 C<Document> Methods

=over 4

=item C<< $node = LaTeXML::Document->new(%attributes); >>

Create a text node with the given C<$text>.  Generally should not be needed.
Relevant attributes include:
   publicID : the public identifier of the document type.
   systemID : the system identifier of the document type.
   _font    : the initial font for the document. used to determine where font changes
          are required during insertion of text.

=back

=cut

