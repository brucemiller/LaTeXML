# /=====================================================================\ #
# |  LaTeXML::DOM                                                       | #
# | Document Object Model                                               | #
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
# NOTE: No special handling of namespaces
#**********************************************************************

package LaTeXML::DOM::Node;
use strict;
use LaTeXML::Global;
# Profiling hack so new doesn't get seen as BEGIN!
sub dummy {()} dummy();

sub new {
  my($class,$tag,%attributes)=@_;
  bless {tag=>$tag, attributes=>{%attributes},  content=>[]}, $class; }

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

# Find the nearest setting of $key on $node or ancestors.
sub findAttribute {
  my($node,$key)=@_;
  while(defined $node && !$$node{attributes}{$key}){
    $node = $$node{parent}; }
  $$node{attributes}{$key}; }

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

#----------------------------------------------------------------------
# Construction methods

sub canContain        { MODEL->canContain($_[0]->{tag},$_[1]); }
sub canContainIndirect{ MODEL->canContainIndirect($_[0]->{tag},$_[1]); }
sub canAutoClose      { MODEL->canAutoClose($_[0]->{tag}); }
sub canHaveAttribute  { MODEL ->canHaveAttribute($_[0]->{tag},$_[1]); }

# Can we close $self, and any parents, upto closing a node with tag $tag?
sub canClose {
  my($self,$tag)=@_;
  ($$self{tag} eq $tag) || ($self->canAutoClose && $self->getParentNode->canClose($tag)); }

# Public interface:
# Close this node and return the parent that would be open assuming this one were.
sub close {
  my($self, $tag)=@_;
  if($$self{tag} eq $tag){	# This is the node to close.
    Message("Close ".$self->header) if Debugging('DOM');
    $$self{parent}; }		#  the parent would be the current node.
  elsif($self->canAutoClose){ # Auto Close this node
    Message("Auto close ".$self->header." for </$tag>") if Debugging('DOM');
    $$self{parent}->close($tag); } # & Recurse to parent which might be $tag.
  else {
    Error("Cannot close </$tag> while ".$self->header." is open."); }}

# Insert a child node, return the child as the current node, assuming this one were.
sub insert {
  my($self,$child,$pos)=@_;
  my $via;
  if(!((ref $child) =~ /LaTeXML::DOM::/)){
    Error("Insertion of Bad Child!! $child"); }
  my $ctag = $$child{tag};
  if($self->canContain($ctag)){
    Message("Inserting ".$child->header." in ".$self->header) if Debugging('DOM');
    $$child{parent}  = $self; 
    $$child{document}= $$self{document};
    if(!defined $pos){
      push(@{$$self{content}},$child); }
    elsif($pos == 0){
      unshift(@{$$self{content}},$child); }
    else {
      my @k=@{$$self{content}};
      $$self{content}=[@k[0..$pos-1],$child,@k[$pos..$#k]]; }
    $child; }
  elsif(defined($via=$self->canContainIndirect($ctag))){ # Can be subchild if $via is between
    Message("Creating intermediate <$via> to insert ".$child->header." in ".$self->header)
      if Debugging('DOM');
    $self->open($via)->insert($child); } # So, create $via & insert child there.
  else {			# Now we're getting more desparate...
    # Check if we can auto close some nodes, and _then_ insert the child.
    my ($n,$ok) = ($self,0);
    while($n->canAutoClose && defined ($n=$$n{parent}) &&
	  ! ($ok = ($n->canContain($ctag) || $n->canContainIndirect($ctag)))){}
    if(defined $n && $ok){		# It will work.
      Message("Closing ".$self->header." to insert ".$child->header) if Debugging('DOM');
      $self->close($$self{tag})->insert($child); } # So, close self, insert child in result.
    else {			# Nope, don't know what to do with child.
      my $extra = ($$child{tag} eq '#PCDATA' ? " ($$child{text})" : '');
      Error("Cannot insert <$$child{tag}>$extra into <$$self{tag}>"
	    .($self->canAutoClose ? " or parent(s)" :'')); }}}

# Public interface:
# Open a new node with given tag and attributes, and insert it into the document.
sub open {
  my($self,$tag, %attributes)=@_;
  foreach my $attr (keys %attributes){
    delete $attributes{$attr} unless defined $attributes{$attr}; }
  my $child = LaTeXML::DOM::Node->new($tag, %attributes);
  Message("Open ".$child->header) if Debugging('DOM');
  $self->insert($child);
}

sub insertText {
  my($self,$text)=@_;
  if(($text =~/^\s+$/) && ! $self->canContain('#PCDATA')){  # Ignore stray whitespace
    $self }
  else {
    $self->insert(LaTeXML::DOM::Text->new($text)); }}

sub insertComment {
  my($self,$comment)=@_;
  $self->insert(LaTeXML::DOM::Comment->new($comment)); }

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
  elsif((ref $value eq 'LaTeXML::Font')||(ref $value eq 'LaTeXML::MathFont')){
    # Special case Font: make it relative to font inherited from parent.
    # We assume some parent has a Font in the same attribute.
    if(defined $self->getParentNode) {
      $value = $value->relativeTo($self->getParentNode->findAttribute($key)); }
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
    my $value = $self->getAttribute_string($key);
    $string.=' '.$key."='".sanitize($value)."'" if defined $value; }
  $string; }

sub header {
  my($self)=@_;
  "<".$$self{tag}.$self->serializeAttributes.">"; }

sub serialize {
  my($self,$out,$depth)=@_;
  $depth=0 unless $depth;
  my $tag = $$self{tag};
  my $kids= $$self{content};
  my $fattr = $self->serializeAttributes;
  my $indent = ($self->canContain('#PCDATA') ? '' : "\n".('  'x($depth-1)));
  if(@$kids){
    print $out "<$tag$fattr>";
    foreach my $kid (@$kids){
      print $out $indent."  " if $indent;
      $kid->serialize($out,$depth+1); }
    print $out $indent if $indent;
    print $out "</$tag>"; }
  else {
    print $out "<$tag$fattr/>"; }
}

sub toString {
  my($self,$depth)=@_;
  $depth=0 unless $depth;
  my $tag = $$self{tag};
  my $kids= $$self{content};
  my $fattr = $self->serializeAttributes;
  my $indent = ($self->canContain('#PCDATA') ? '' : "\n".('  'x($depth-1)));
  my $string = '';
  if(@$kids){
    $string .= "<$tag$fattr>";
    foreach my $kid (@$kids){
      $string .= $indent."  " if $indent;
      $string .= $kid->toString($depth+1); }
    $string .= $indent if $indent;
    $string .= "</$tag>"; }
  else {
    $string .= "<$tag$fattr/>"; }
  $string; }

sub textContent { join('',map($_->textContent,@{$_[0]{content}})); }

sub getContext {
  my($self,$short)=@_;
  my $node = $self;
  my @stack = ($node);
  if(!$short){
    while(defined($node = $$node{parent})) { push(@stack,$node); }}
  my ($string,$prefix,$line) = ('','  ','');
  while(@stack){
    $node = pop(@stack);
    $string .= "\n" if $string;
    $line = $prefix . $node->header
      .(@stack && ($stack[$#stack] ne $$node{content}->[0]) ? "..." : '');
    $string .= $line;
    $prefix .= '  '; }
  if(!$short){
    $string .= "\n".(' 'x length($line))."^ XML Insertion point"; }
  $string; }

#**********************************************************************
# LaTeXML::DOM::Text;
#**********************************************************************
package LaTeXML::DOM::Text;
use LaTeXML::Global;
use strict;
use Unicode::Normalize;
our @ISA = qw(LaTeXML::DOM::Node);

sub new {
  my($class,$text)=@_;
  $text = "&amp;" if $text eq '&';
  bless {tag=>'#PCDATA', attributes=>{}, content=>[], text=>$text}, $class;  }

sub insertText {
  my($self,$text)=@_;
  $text = "&amp;" if $text eq '&';
  Message("Inserting \"$text\" in <#PCDATA>") if Debugging('DOM');
  $$self{text} .= $text;
  $self; }

sub serialize {
  my($self,$out,$depth)=@_;
  my $string = $$self{text};
  $string =~ s/&/&amp;/g;
  $string =~ s/</&lt;/g;
  $string =~ s/>/&gt;/g;
  print $out NFC($string); }

sub toString {
  my($self,$depth)=@_;
  my $string = $$self{text};
  $string =~ s/&/&amp;/g;
  $string =~ s/</&lt;/g;
  $string =~ s/>/&gt;/g;
  NFC($string); }

sub textContent { $_[0]{text}; }

#**********************************************************************
# LaTeXML::DOM::Comment;
#**********************************************************************
package LaTeXML::DOM::Comment;
use strict;
our @ISA = qw(LaTeXML::DOM::Node);

sub new {
  my($class,$text)=@_;
  bless {tag=>'_Comment_', attributes=>{}, content=>[], text=>$text}, $class; }

sub insertComment {
  my($self,$comment)=@_;
  $$self{text} .= $comment;
  $self; }

sub serialize {
  my($self,$out,$depth)=@_;
  my $string = $$self{text};
  chomp($string);
  $string =~ s/\-\-+/__/g;
  print $out "<!-- $string -->\n"; }

sub toString {
  my($self,$depth)=@_;
  my $string = $$self{text};
  chomp($string);
  $string =~ s/\-\-+/__/g;
  "<!-- $string -->\n"; }

sub textContent { ""; }

#**********************************************************************
# LaTeXML::DOM::ProcessingInstruction;
#**********************************************************************
package LaTeXML::DOM::ProcessingInstruction;
use strict;
our @ISA = qw(LaTeXML::DOM::Node);

sub new {
  my($class,$op,%attrib)=@_;
  bless {tag=>'_ProcessingInstruction_', op=>$op, 
	 attributes=>{%attrib}, content=>[]}, $class; }

sub serialize {
  my($self,$out,$depth)=@_;
  print $out "<?$$self{op}".$self->serializeAttributes."?>\n"; }

sub toString {
  my($self,$depth)=@_;
  "<?$$self{op}".$self->serializeAttributes."?>\n"; }

sub textContent { ""; }

#**********************************************************************
# LaTeXML::DOM::Document;
#**********************************************************************
package LaTeXML::DOM::Document;
use LaTeXML::Global;
use strict;
our @ISA = qw(LaTeXML::DOM::Node);

sub new {
  my($class,%options)=@_;
  bless {tag=>'_Document_',  attributes=>{}, content=>[], 
	 model=>MODEL, %options}, $class; }

sub serialize {
  my($self,$out,$depth)=@_;
  my @content = @{$$self{content}};
  my @roots = grep(ref $_ eq 'LaTeXML::DOM::Node', @content);
  local $LaTeXML::MODEL = $$self{model};
  Error("Document must have exactly 1 root element; it has ".scalar(@roots))  
    if (scalar(@roots) != 1);
  print $out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print $out "<!DOCTYPE ".($roots[0]->getNodeName||'')
    ." PUBLIC \"".(MODEL->getPublicID||'')."\" \"".(MODEL->getSystemID||'')."\">\n";
  my $ns = MODEL->getDefaultNamespace;;
  $roots[0]->setAttribute('xmlns',$ns) if $ns;
  $depth=0 unless $depth;
  foreach my $node (@{$$self{content}}){
    $node->serialize($out,$depth+1); }
  print $out "\n"; }

sub toString {
  my($self,$depth)=@_;
  my @content = @{$$self{content}};
  my @roots = grep(ref $_ eq 'LaTeXML::DOM::Node', @content);
  local $LaTeXML::MODEL = $$self{model};
  Error("Document must have exactly 1 root element; it has ".scalar(@roots))  
    if (scalar(@roots) != 1);
  my $string = '';
  $string .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  $string .= "<!DOCTYPE ".$roots[0]->getNodeName
    ." PUBLIC \"".MODEL->getPublicID."\" \"".MODEL->getSystemID."\">\n";
  my $ns = MODEL->getDefaultNamespace;;
  $roots[0]->setAttribute('xmlns',$ns) if $ns;
  $depth=0 unless $depth;
  foreach my $node (@{$$self{content}}){
    $string .= $node->toString($depth+1); }
  $string .= "\n"; 
  $string; }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::DOM::Node, LaTeXML::DOM::Text, LaTeXML::DOM::Comment, LaTeXML::DOM::ProcessingInstruction, LaTeXML::DOM::Document

=head2 DESCRIPTION

These packages represent XML Document nodes.  I am still undecided
about the exact distribution of labor between LaTeXML::Intestine, LaTeXML::Model and these
packages.  One possiblilty would be to keep this module relatively simple and clean,
possibly even abandoning it for, say, XML::LibXML.  Thus, other than to say that
I've attempted to use the `standard' DOM methods to create and manipulate these nodes,
I won't document this package further for now.

=cut

