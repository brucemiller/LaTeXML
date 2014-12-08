# /=====================================================================\ #
# |  LaTeXML::Core::Document                                            | #
# | Constructs the Document from digested material                      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::Document;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Core::List;
use LaTeXML::Common::Error;
use LaTeXML::Common::XML;
use LaTeXML::Util::Radix;
use Unicode::Normalize;
use base qw(LaTeXML::Common::Object);

#**********************************************************************
# These two element names are `leaks' of the document structure into
# the Core of LaTeXML... In principle, we should be more abstract!

our $FONT_ELEMENT_NAME = "ltx:text";
our $MATH_TOKEN_NAME   = "ltx:XMTok";
#**********************************************************************

# [could conceivable make more sense to let the Stomach create the Document?]

# Mystery attributes:
#    font :
#       Probably should keep font ONLY in extra properties,
#        THEN once complete, compute the relative font at each node that accepts
#       a font attribute, and add the attribute.
#   locator : a box

sub new {
  my ($class, $model) = @_;
  my $doc = XML::LibXML::Document->new("1.0", "UTF-8");
  # We'll set the DocType when the 1st Element gets added.
  return bless { document => $doc, node => $doc, model => $model,
    idstore => {}, labelstore => {},
    node_fonts => {}, node_boxes => {}, node_properties => {},
    pending => [], progress => 0 }, $class; }

#**********************************************************************
# Basic Accessors

# This will be a node of type XML_DOCUMENT_NODE
sub getDocument { my ($self) = @_; return $$self{document}; }
sub getModel    { my ($self) = @_; return $$self{model}; }

# Get the node representing the current insertion point.
# The node will have nodeType of
#   XML_DOCUMENT_NODE if the document is empty, so far.
#   XML_ELEMENT_NODE  for normal elements.
#   XML_TEXT_NODE     if the last insertion was text
# The other node types will not appear here.
sub getNode { my ($self) = @_; return $$self{node}; }

sub setNode {
  my ($self, $node) = @_;
  my $type = $node->nodeType;
  if ($type == XML_DOCUMENT_FRAG_NODE) {    # Whoops
    my @n = $node->childNodes;
    if (@n > 1) {
      Error('unexpected', 'multiple-nodes', $self,
        "Cannot set insertion point to a DOCUMENT_FRAG_NODE", Stringify($node)); }
    elsif (@n < 1) {
      Error('unexpected', 'empty-nodes', $self,
        "Cannot set insertion point to an empty DOCUMENT_FRAG_NODE"); }
    $node = $n[0]; }
  $$self{node} = $node;
  return; }

sub getLocator {
  my ($self, @args) = @_;
  if (my $box = $self->getNodeBox($$self{node})) {
    return $box->getLocator(@args); }
  else {
    return 'EOF?'; } }    # well?

# Get the element at (or containing) the current insertion point.
sub getElement {
  my ($self) = @_;
  my $node = $$self{node};
  $node = $node->parentNode if $node->getType == XML_TEXT_NODE;
  return ($node->getType == XML_DOCUMENT_NODE ? undef : $node); }

# Get the child elements of the given $node
sub getChildElements {
  my ($self, $node) = @_;
  return grep { $_->nodeType == XML_ELEMENT_NODE } $node->childNodes; }

# Get the last element node (if any) in $node
sub getLastChildElement {
  my ($self, $node) = @_;
  if ($node->hasChildNodes) {
    my $n = $node->lastChild;
    while ($n && $n->nodeType != XML_ELEMENT_NODE) {
      $n = $node->previousSibling; }
    return $n; } }

# get the first element node (if any) in $node
sub getFirstChildElement {
  my ($self, $node) = @_;
  if ($node->hasChildNodes) {
    my $n = $node->firstChild;
    while ($n && $n->nodeType != XML_ELEMENT_NODE) {
      $n = $n->nextSibling; }
    return $n; }
  return; }

# Find the nodes according to the given $xpath expression,
# the xpath is relative to $node (if given), otherwise to the document node.
sub findnodes {
  my ($self, $xpath, $node) = @_;
  return $$self{model}->getXPath->findnodes($xpath, ($node || $$self{document})); }

# Like findnodes, but only returns the first matched node
sub findnode {
  my ($self, $xpath, $node) = @_;
  my @nodes = $$self{model}->getXPath->findnodes($xpath, ($node || $$self{document}));
  return (@nodes ? $nodes[0] : undef); }

# Get the node's qualified name in standard form
# Ie. using the registered prefix for that namespace.
# NOTE: Reconsider how _Capture_ & _WildCard_ should be integrated!?!
# NOTE: Should Deprecate! (use model)
sub getNodeQName {
  my ($self, $node) = @_;
  return $$self{model}->getNodeQName($node); }

#**********************************************************************
# Extensions of Model.

sub canContain {
  my ($self, $tag, $child) = @_;
  my $model = $$self{model};
  $tag   = $model->getNodeQName($tag)   if ref $tag;      # In case tag is a node.
  $child = $model->getNodeQName($child) if ref $child;    # In case child is a node.
  return $model->canContain($tag, $child); }

# Can an element with (qualified name) $tag contain a $childtag element indirectly?
# That is, by openning some number of autoOpen'able tags?
# And if so, return the tag to open.
sub canContainIndirect {
  my ($self, $tag, $child) = @_;
  my $model = $$self{model};
  $tag = $model->getNodeQName($tag) if ref $tag;          # In case tag is a node.
  $child = $model->getNodeQName($child) if ref $child;    # In case child is a node.
        # $imodel{$tag}{$child} => $intermediate || $child
  my $imodel = $STATE->lookupValue('INDIRECT_MODEL');
  if (!$imodel) {
    $imodel = $self->computeIndirectModel();
    $STATE->assignValue(INDIRECT_MODEL => $imodel, 'global'); }
  return $$imodel{$tag}{$child}; }

# The indirect model includes all elements allowed as direct children,
# and all descendents of a node that can be inserted after autoOpen'ing intermediate elements.
# This model therefor includes information from the Schema, as well as
# autoOpen information that may be introduced in binding files.
# [Thus it should NOT be modifying the Model object, which may cover several documents in Daemon]
sub computeIndirectModel {
  my ($self) = @_;
  my $model  = $$self{model};
  my $imodel = {};
  # Determine any indirect paths to each descendent via an `autoOpen-able' tag.
  foreach my $tag ($model->getTags) {
    local %::DESC = ();
    computeIndirectModel_aux($model, $tag, '');
    $$imodel{$tag} = {%::DESC}; }
  # PATCHUP
  if ($$model{permissive}) {    # !!! Alarm!!!
    $$imodel{'#Document'}{'#PCDATA'} = 'ltx:p'; }
  return $imodel; }

sub computeIndirectModel_aux {
  my ($model, $tag, $start) = @_;
  my $x;
  foreach my $kid ($model->getTagContents($tag)) {
    next if $::DESC{$kid};      # already seen
    $::DESC{$kid} = $start if $start;
    if (($kid ne '#PCDATA') && ($x = $STATE->lookupMapping('TAG_PROPERTIES', $kid)) && $$x{autoOpen}) {
      computeIndirectModel_aux($model, $kid, $start || $kid); }
  }
  return; }

sub canContainSomehow {
  my ($self, $tag, $child) = @_;
  my $model = $$self{model};
  $tag   = $model->getNodeQName($tag)   if ref $tag;      # In case tag is a node.
  $child = $model->getNodeQName($child) if ref $child;    # In case child is a node.
  return $model->canContain($tag, $child) || $self->canContainIndirect($tag, $child); }

sub canHaveAttribute {
  my ($self, $tag, $attrib) = @_;
  my $model = $$self{model};
  $tag = $model->getNodeQName($tag) if ref $tag;          # In case tag is a node.
  return $model->canHaveAttribute($tag, $attrib); }

sub canAutoOpen {
  my ($self, $tag) = @_;
  if (my $props = $STATE->lookupMapping('TAG_PROPERTIES', $tag)) {
    return $$props{autoClose}; } }

# Dirty little secrets:
#  You can generically allow an element to autoClose using Tag.
# OR you can indicate a specific node can autoClose, or forbid it, using
# the _autoclose or _noautoclose attributes!
sub canAutoClose {
  my ($self, $node) = @_;
  my $t     = $node->nodeType;
  my $model = $$self{model};
  my $props;
  return ($t == XML_TEXT_NODE) || ($t == XML_COMMENT_NODE)    # text or comments auto close
    || (($t == XML_ELEMENT_NODE)                              # otherwise must be element
    && !$node->getAttribute('_noautoclose')                   # without _noautoclose
    && ($node->getAttribute('_autoclose')                     # and either with _autoclose
                                                              # OR it has autoClose set on tag properties
      || (($props = $STATE->lookupMapping('TAG_PROPERTIES', $self->getNodeQName($node)))
        && $$props{autoClose})));
}

# get the actions that should be performed on afterOpen or afterClose
sub getTagActionList {
  my ($self, $tag, $when) = @_;
  $tag = $$self{model}->getNodeQName($tag) if ref $tag;       # In case tag is a node.
  my ($p, $n) = (undef, $tag);
  if ($tag =~ /^([^:]+):(.+)$/) {
    ($p, $n) = ($1, $2); }
  my $when0   = $when . ':early';
  my $when1   = $when . ':late';
  my $taghash = $STATE->lookupMapping('TAG_PROPERTIES', $tag) || {};
  my $nshash  = ((defined $p) && $STATE->lookupMapping('TAG_PROPERTIES', $p . ':*')) || {};
  my $allhash = $STATE->lookupMapping('TAG_PROPERTIES', '*') || {};
  my $v;
  return (
    (($v = $$taghash{$when0}) ? @$v : ()),
    (($v = $$nshash{$when0})  ? @$v : ()),
    (($v = $$allhash{$when0}) ? @$v : ()),
    (($v = $$taghash{$when})  ? @$v : ()),
    (($v = $$nshash{$when})   ? @$v : ()),
    (($v = $$allhash{$when})  ? @$v : ()),
    (($v = $$taghash{$when1}) ? @$v : ()),
    (($v = $$nshash{$when1})  ? @$v : ()),
    (($v = $$allhash{$when1}) ? @$v : ()),
    ); }

#**********************************************************************
# This is a diagnostic tool that MIGHT help locate XML::LibXML bugs;
# It simply walks through the document tree. Use it before and after
# places where some sort of data corruption might have taken place.
sub doctest {
  my ($self, $when, $severe) = @_;
  local $LaTeXML::NNODES = 0;
  print STDERR "\nSTART DOC TEST $when....." . ($severe ? "\n" : '');
  if (my $root = $self->getDocument->documentElement) {
    $self->doctest_rec(undef, $root, $severe); }
  print STDERR "...(" . $LaTeXML::NNODES . " nodes)....DONE\n";
  return; }

sub doctest_rec {
  my ($self, $parent, $node, $severe) = @_;
  # Check consistency of document, parent & type, before proceeding
  $self->doctest_head($parent, $node, $severe);
  my $type = $node->nodeType;
  if ($type == XML_ELEMENT_NODE) {
    print STDERR "ELEMENT "
      . join(' ', "<" . $$self{model}->getNodeQName($node),
      (map { $_->nodeName . '="' . $_->getValue . '"' } $node->attributes)) . ">\n"
      if $severe;
    $self->doctest_children($node, $severe); }
  elsif ($type == XML_ATTRIBUTE_NODE) {
    print STDERR "ATTRIBUTE " . $node->nodeName . "=>" . $node->getValue . "\n" if $severe; }
  elsif ($type == XML_TEXT_NODE) {
    print STDERR "TEXT " . $node->textContent . "\n" if $severe; }
  elsif ($type == XML_CDATA_SECTION_NODE) {
    print STDERR "CDATA " . $node->textContent . "\n" if $severe; }
  #  elsif($type == XML_ENTITY_REF_NODE){}
  #  elsif($type == XML_ENTITY_NODE){}
  elsif ($type == XML_PI_NODE) {
    print STDERR "PI " . $node->localname . " " . $node->getData . "\n" if $severe; }
  elsif ($type == XML_COMMENT_NODE) {
    print STDERR "COMMENT " . $node->textContent . "\n" if $severe; }
  #  elsif($type == XML_DOCUMENT_NODE){}
  #  elsif($type == XML_DOCUMENT_TYPE_NODE){
  elsif ($type == XML_DOCUMENT_FRAG_NODE) {
    print STDERR "DOCUMENT_FRAG \n" if $severe;
    $self->doctest_children($node, $severe); }
  #  elsif($type == XML_NOTATION_NODE){}
  #  elsif($type == XML_HTML_DOCUMENT_NODE){}
  #  elsif($type == XML_DTD_NODE){}
  else {
    print STDERR "OTHER $type\n" if $severe; }
  return; }

sub doctest_head {
  my ($self, $parent, $node, $severe) = @_;
  # Check consistency of document, parent & type, before proceeding
  print STDERR "  NODE $$node [" if $severe;    # BEFORE checking nodeType!
  print STDERR "d" if $severe;
  if (!$node->ownerDocument->isSameNode($self->getDocument)) {
    print STDERR "!" if $severe; }
  print STDERR "p" if $severe;
  if ($parent && !$node->parentNode->isSameNode($parent)) {
    print STDERR "!" if $severe; }
  print STDERR "t" if $severe;
  my $type = $node->nodeType;
  print STDERR "] " if $severe;
  return; }

sub doctest_children {
  my ($self, $node, $severe) = @_;
  print STDERR "[fc" if $severe;
  my $c = $node->firstChild;
  while ($c) {
    print STDERR "]\n" if $severe;
    $self->doctest_rec($node, $c, $severe);
    print STDERR "[nc" if $severe;
    $c = $c->nextSibling; }
  print STDERR "]done\n" if $severe;
  return; }

#**********************************************************************
# This should be called before returning the final XML::LibXML::Document to the
# outside world.  It resolves the fonts for each node relative to it's ancestors.
# It removes the `helper' attributes that store fonts, source box, etc.
sub finalize {
  my ($self) = @_;
  $self->pruneXMDuals;
  if (my $root = $self->getDocument->documentElement) {
    local $LaTeXML::FONT = $self->getNodeFont($root);
    $self->finalize_rec($root);
    set_RDFa_prefixes($self->getDocument, $STATE->lookupValue('RDFa_prefixes')); }
  return $$self{document}; }

sub finalize_rec {
  my ($self, $node) = @_;
  my $model               = $$self{model};
  my $qname               = $model->getNodeQName($node);
  my $declared_font       = $LaTeXML::FONT;
  my $desired_font        = $LaTeXML::FONT;
  my %pending_declaration = ();
  if (my $comment = $node->getAttribute('_pre_comment')) {
    $node->parentNode->insertBefore(XML::LibXML::Comment->new($comment), $node); }
  if (my $comment = $node->getAttribute('_comment')) {
    $node->parentNode->insertAfter(XML::LibXML::Comment->new($comment), $node); }

  if (my $font_attr = $node->getAttribute('_font')) {
    $desired_font        = $$self{node_fonts}{$font_attr};
    %pending_declaration = $desired_font->relativeTo($declared_font);
    if (($node->hasChildNodes || $node->getAttribute('_force_font'))
      && scalar(keys %pending_declaration)) {
      foreach my $attr (keys %pending_declaration) {
        if ($model->canHaveAttribute($qname, $attr)) {
          $self->setAttribute($node, $attr => $pending_declaration{$attr}{value});
          # Merge to set the font currently in effect
          $declared_font = $declared_font->merge(%{ $pending_declaration{$attr}{properties} });
          delete $pending_declaration{$attr}; } }
    } }
  local $LaTeXML::FONT = $declared_font;
  foreach my $child ($node->childNodes) {
    my $type = $child->nodeType;
    if ($type == XML_ELEMENT_NODE) {
      my $was_forcefont = $child->getAttribute('_force_font');
      $self->finalize_rec($child);
      # Also check if child is  $FONT_ELEMENT_NAME  AND has no attributes
      # AND providing $node can contain that child's content, we'll collapse it.
      if (($model->getNodeQName($child) eq $FONT_ELEMENT_NAME)
        && !$was_forcefont && !$child->hasAttributes) {
        my @grandchildren = $child->childNodes;
        if (!grep { !$self->canContain($qname, $_) } @grandchildren) {
          $self->replaceNode($child, @grandchildren); } }
    }
    # On the other hand, if the font declaration has NOT been effected,
    # We'll need to put an extra wrapper around the text!
    elsif ($type == XML_TEXT_NODE) {
      if ($self->canContain($qname, $FONT_ELEMENT_NAME)
        && scalar(keys %pending_declaration)) {
        # Too late to do wrapNodes?
        my $text = $self->wrapNodes($FONT_ELEMENT_NAME, $child);
        foreach my $attr (keys %pending_declaration) {
          $self->setAttribute($text, $attr => $pending_declaration{$attr}{value}); }
        $self->finalize_rec($text);    # Now have to clean up the new node!
      }
    } }

  # Attributes that begin with (the semi-legal) "_" are for Bookkeeping.
  # Remove them now.
  foreach my $attr ($node->attributes) {
    my $n = $attr->nodeName;
    $node->removeAttribute($n) if $n =~ /^_/; }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Document construction at the Current Insertion Point.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#**********************************************************************
# absorb the given $box into the DOM (called from constructors).
# This will return a list of whatever nodes were created.
# Note that this may include nodes that are children of other nodes in the list
# or nodes that are no longer in the document.
# Also, note that when a text nodes is appended to, the complete text node is in the list,
# not just the portion that was added.
# [Note that recording the nodes being constructed isn't all that costly,
# but filtering them for parent/child relations IS, particularly since it usually isn't needed]
#
# A $box that is a Box, or List, or Whatsit, is responsible for carrying out
# its own insertion, but it should ultimately call methods of Document
# that will record the nodes that were created.
# $box can also be a plain string which will be inserted according to whatever
# font, mode, etc, are in %props.
sub absorb {
  my ($self, $box, %props) = @_;
  # Nothing? Skip it
  if (!defined $box) {
    return; }
  # A Proper Box or List or Whatsit? It will handle it.
  elsif (ref $box) {
    local $LaTeXML::BOX = $box;
    # [ATTEMPT to] only record if we're running in NON-VOID context.
    # [but wantarray seems defined MUCH more than I would have expected!?]
    if ($LaTeXML::RECORDING_CONSTRUCTION || defined wantarray) {
      my @n = ();
      { local $LaTeXML::RECORDING_CONSTRUCTION = 1;
        local @LaTeXML::CONSTRUCTED_NODES = ();
        $box->beAbsorbed($self);
        @n = @LaTeXML::CONSTRUCTED_NODES; }    # These were created just now
      map { $self->recordConstructedNode($_) } @n;    # record these for OUTER caller!
      return @n; }                                    # but return only the most recent set.
    else {
      return $box->beAbsorbed($self); } }
  # Else, plain string in text mode.
  elsif (!$props{isMath}) {
    return $self->openText($box, $props{font} || ($LaTeXML::BOX && $LaTeXML::BOX->getFont)); }
  # Or plain string in math mode.
  # Note text nodes can ONLY appear in <XMTok> or <text>!!!
  # Have we already opened an XMTok? Then insert into it.
  elsif ($$self{model}->getNodeQName($$self{node}) eq $MATH_TOKEN_NAME) {
    return $self->openMathText_internal($box); }
  # Else create the XMTok now.
  else {
    # Odd case: constructors that work in math & text can insert raw strings in Math mode.
    return $self->insertMathToken($box, font => $props{font}); } }

# Note that a box has been absorbed creating $node;
# This does book keeping so that we can return the sequence of nodes
# that were added by absorbing material.
sub recordConstructedNode {
  my ($self, $node) = @_;
  if ((defined $LaTeXML::RECORDING_CONSTRUCTION)    # If we're recording!
    && (!@LaTeXML::CONSTRUCTED_NODES                # and this node isn't already recorded
      || !$node->isSameNode($LaTeXML::CONSTRUCTED_NODES[-1]))) {
    push(@LaTeXML::CONSTRUCTED_NODES, $node); }
  return; }

sub filterDeletions {
  my ($self, @nodes) = @_;
  my $doc = $$self{document};
  # This test seems to successfully determine inclusion,
  # without requiring the (dangerous? & dubious?) unbindNode to be used.
  return grep { isDescendantOrSelf($_, $doc) } @nodes; }

# Given a list of nodes such as from ->absorb,
# filter out all the nodes that are children of other nodes in the list.
sub filterChildren {
  my ($self, @node) = @_;
  #  return @node;
  #  return ();
  return () unless @node;
  my @n = (shift(@node));
  foreach my $n (@node) {
    push(@n, $n) unless grep { isDescendantOrSelf($n, $_); } @n; }
  return @n; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Shorthand for open,absorb,close, but returns the new node.
sub insertElement {
  my ($self, $qname, $content, %attrib) = @_;
  my $node = $self->openElement($qname, %attrib);
  if (ref $content eq 'ARRAY') {
    map { $self->absorb($_) } @$content; }
  elsif (defined $content) {
    $self->absorb($content); }
  # In obscure situations, $node may have already gotten closed?
  # close it if it is still open.
  my $c = $$self{node};
  while ($c && ($c->nodeType != XML_DOCUMENT_NODE) && !$c->isSameNode($node)) {
    $c = $c->parentNode; }
  if ($c->isSameNode($node)) {
    $self->closeElement($qname); }
  return $node; }

sub insertMathToken {
  my ($self, $string, %attributes) = @_;
  $attributes{role} = 'UNKNOWN' unless $attributes{role};
  my $node = $self->openElement($MATH_TOKEN_NAME, %attributes);
  my $box  = $attributes{_box} || $LaTeXML::BOX;
  my $font = $attributes{font} || $box->getFont;
  $self->setNodeFont($node, $font);
  $self->setNodeBox($node, $box);
  $self->openMathText_internal($string) if defined $string;
  $self->closeNode_internal($node);    # Should be safe.
  return $node; }

# Insert a new comment, or append to previous comment.
# Does NOT move the current insertion point to the Comment,
# but may move up past a text node.
sub insertComment {
  my ($self, $text) = @_;
  chomp($text);
  $text =~ s/\-\-+/__/g;
  $self->closeText_internal;    # Close any open text node.
  my $comment;
  if ($$self{node}->nodeType == XML_DOCUMENT_NODE) {
    push(@{ $$self{pending} }, $comment = $$self{document}->createComment(' ' . $text . ' ')); }
  elsif (($comment = $$self{node}->lastChild) && ($comment->nodeType == XML_COMMENT_NODE)) {
    $comment->setData($comment->data . "\n     " . $text); }
  else {
    $comment = $$self{node}->appendChild($$self{document}->createComment(' ' . $text . ' ')); }
  return $comment; }

# Insert a ProcessingInstruction of the form <?op attr=value ...?>
# Does NOT move the current insertion point to the PI,
# but may move up past a text node.
sub insertPI {
  my ($self, $op, %attrib) = @_;
  # We'll just put these on the document itself.
  # Put these in an attractive order, main "operator" first
  my @keys = ((map { ($attrib{$_} ? ($_) : ()) } qw(class package options)),
    (grep { $_ !~ /^(?:class|package|options)$/ } sort keys %attrib));
  my $data = join(' ', map { $_ . "=\"" . ToString($attrib{$_}) . "\"" } @keys);
  my $pi = $$self{document}->createProcessingInstruction($op, $data);
  $self->closeText_internal;    # Close any open text node
  if ($$self{node}->nodeType == XML_DOCUMENT_NODE) {
    push(@{ $$self{pending} }, $pi); }
  else {
    $$self{document}->insertBefore($pi, $$self{document}->documentElement); }
  return $pi; }

#**********************************************************************
# Middle level, mostly public, API.
# Handlers for various construction operations.
# General naming: 'open' opens a node at current pos and sets it to current,
# 'close' closes current node(s), inserts opens & closes, ie. w/o moving current

# Tricky: Insert some text in a particular font.
# We need to find the current effective -- being the closest  _declared_ font,
# (ie. it will appear in the elements attributes).  We may also want
# to open/close some elements in such a way as to minimize the font switchiness.
# I guess we should only open/close "text" elements, though.
# [Actually, we'd like the user to _declare_ what element to use....
#  I don't like having "text" built in here!
#  AND, we've assumed that "font" names the relevant attribute!!!]

sub openText {
  my ($self, $text, $font) = @_;
  my $node = $$self{node};
  my $t    = $node->nodeType;
  return if $text =~ /^\s+$/ &&
    (($t == XML_DOCUMENT_NODE)    # Ignore initial whitespace
    || (($t == XML_ELEMENT_NODE) && !$self->canContain($node, '#PCDATA')));
  return if $font->getFamily eq 'nullfont';
  print STDERR "Insert text \"$text\" /" . Stringify($font) . " at " . Stringify($node) . "\n"
    if $LaTeXML::Core::Document::DEBUG;

  if (($t != XML_DOCUMENT_NODE)    # If not at document begin
    && !(($t == XML_TEXT_NODE) &&    # And not appending text in same font.
      ($font->distance($self->getNodeFont($node->parentNode)) == 0))) {
    # then we'll need to do some open/close to get fonts matched.
    $node = $self->closeText_internal;    # Close text node, if any.
    my ($bestdiff, $closeto) = (99999, $node);
    my $n = $node;
    while ($n->nodeType != XML_DOCUMENT_NODE) {
      my $d = $font->distance($self->getNodeFont($n));
     #print STDERR "Font Compare: ".Stringify($n)." w/font=".Stringify($self->getNodeFont($n))." ==>$d\n";

      if ($d < $bestdiff) {
        $bestdiff = $d;
        $closeto  = $n;
        last if ($d == 0); }
      last if ($$self{model}->getNodeQName($n) ne $FONT_ELEMENT_NAME) || $n->getAttribute('_noautoclose');
      $n = $n->parentNode; }
    $self->closeToNode($closeto) if $closeto ne $node;    # Move to best starting point for this text.
    $self->openElement($FONT_ELEMENT_NAME, font => $font, _fontswitch => 1) if $bestdiff > 0; # Open if needed.
  }
  # Finally, insert the darned text.
  my $tnode = $self->openText_internal($text);
  $self->recordConstructedNode($tnode);
  return $tnode; }

# Mystery:
#  How to deal with font declarations?
#  font vs _font; either must redirect to Font object until they are relativized, at end.
#  When relativizing, should it depend on font attribute on element and/or DTD allowed attribute?
sub openElement {
  my ($self, $qname, %attributes) = @_;
  NoteProgress('.') if ($$self{progress}++ % 25) == 0;
  print STDERR "Open element $qname at " . Stringify($$self{node}) . "\n" if $LaTeXML::Core::Document::DEBUG;
  my $point = $self->find_insertion_point($qname);
  $attributes{_box} = $LaTeXML::BOX unless $attributes{_box};
  my $newnode = $self->openElementAt($point, $qname,
    _font => $attributes{font} || $attributes{_box}->getFont,
    %attributes);
  $self->setNode($newnode);
  return $newnode; }

# Note: This closes the deepest open node of a given type.
# This can cause problems with auto-opened nodes, esp. ones for fontswitches!
# Since this is an "explicit request", we're currently skipping over those nodes,
# ie. we're automatically closing them, even if they're the same type as we're asking to close!!!
# This is kinda risky! Maybe we should try to request closing of specific nodes.
sub closeElement {
  my ($self, $qname) = @_;
  print STDERR "Close element $qname at " . Stringify($$self{node}) . "\n" if $LaTeXML::Core::Document::DEBUG;
  $self->closeText_internal();
  my ($node, @cant_close) = ($$self{node});
  while ($node->nodeType != XML_DOCUMENT_NODE) {
    my $t = $$self{model}->getNodeQName($node);
    # autoclose until node of same name BUT also close nodes opened' for font switches!
    last if ($t eq $qname) && !(($t eq $FONT_ELEMENT_NAME) && $node->getAttribute('_fontswitch'));
    push(@cant_close, $node) unless $self->canAutoClose($node);
    $node = $node->parentNode; }
  if ($node->nodeType == XML_DOCUMENT_NODE) {    # Didn't find $qname at all!!
    Error('malformed', $qname, $self,
      "Attempt to close " . ($qname eq '#PCDATA' ? $qname : '</' . $qname . '>') . ", which isn't open",
      "Currently in " . $self->getInsertionContext);
    return; }
  else {                                         # Found node.
                                                 # Intervening non-auto-closeable nodes!!
    Error('malformed', $qname, $self,
      "Closing " . ($qname eq '#PCDATA' ? $qname : '</' . $qname . '>')
        . " whose open descendents do not auto-close",
      "Descendents are " . join(', ', map { Stringify($_) } @cant_close))
      if @cant_close;
    # So, now close up to the desired node.
    $self->closeNode_internal($node);
    return $node; } }

# Check whether it is possible to open $qname at this point,
# possibly by autoOpen'ing & autoClosing other tags.
sub isOpenable {
  my ($self, $qname) = @_;
  my $node = $$self{node};
  while ($node) {
    return 1 if $self->canContainSomehow($node, $qname);
    return 0 unless $self->canAutoClose($node);    # could close, then check if parent can contain
    $node = $node->parentNode; }
  return 0; }

# Check whether it is possible to close each element in @tags,
# any intervening nodes must be autocloseable.
# returning the last node that would be closed if it is possible,
# otherwise undef.
sub isCloseable {
  my ($self, @tags) = @_;
  my $node = $$self{node};
  $node = $node->parentNode if $node->nodeType == XML_TEXT_NODE;
  while (my $qname = shift(@tags)) {
    while (1) {
      return if $node->nodeType == XML_DOCUMENT_NODE;
      my $this_qname = $$self{model}->getNodeQName($node);
      last if $this_qname eq $qname;
      return unless $self->canAutoClose($node);
      $node = $node->parentNode; }
    $node = $node->parentNode if @tags; }
  return $node; }

# Close $qname, if it is closeable.
sub maybeCloseElement {
  my ($self, $qname) = @_;
  if (my $node = $self->isCloseable($qname)) {
    $self->closeNode_internal($node);
    return $node; } }

# This closes all nodes until $node becomes the current point.
sub closeToNode {
  my ($self, $node, $ifopen) = @_;
  my $model = $$self{model};
  my ($t, @cant_close) = ();
  my $n = $$self{node};
  my $lastopen;
  # go up the tree from current node, till we find $node
  while ((($t = $n->getType) != XML_DOCUMENT_NODE) && !$n->isSameNode($node)) {
    push(@cant_close, $n) unless $self->canAutoClose($n);
    $lastopen = $n;
    $n        = $n->parentNode; }
  if ($t == XML_DOCUMENT_NODE) {    # Didn't find $node at all!!
    Error('malformed', $model->getNodeQName($node), $self,
      "Attempt to close " . Stringify($node) . ", which isn't open",
      "Currently in " . $self->getInsertionContext) unless $ifopen;
    return; }
  else {                            # Found node.
    Error('malformed', $model->getNodeQName($node), $self,
      "Closing " . Stringify($node) . " whose open descendents do not auto-close",
      "Descendents are " . join(', ', map { Stringify($_) } @cant_close))
      if @cant_close;               # But found has intervening non-auto-closeable nodes!!
    $self->closeNode_internal($lastopen) if $lastopen; }
  return; }

# This closes all nodes until $node is closed.
sub closeNode {
  my ($self, $node) = @_;
  my $model = $$self{model};
  my ($t, @cant_close) = ();
  my $n = $$self{node};
  while ((($t = $n->getType) != XML_DOCUMENT_NODE) && !$n->isSameNode($node)) {
    push(@cant_close, $n) unless $self->canAutoClose($n);
    $n = $n->parentNode; }
  if ($t == XML_DOCUMENT_NODE) {    # Didn't find $qname at all!!
    Error('malformed', $model->getNodeQName($node), $self,
      "Attempt to close " . Stringify($node) . ", which isn't open",
      "Currently in " . $self->getInsertionContext); }
  else {                            # Found node.
                                    # Intervening non-auto-closeable nodes!!
    Error('malformed', $model->getNodeQName($node), $self,
      "Closing " . Stringify($node) . " whose open descendents do not auto-close",
      "Descendents are " . join(', ', map { Stringify($_) } @cant_close))
      if @cant_close;
    $self->closeNode_internal($node); }
  return; }

# Add the given attribute to the nearest node that is allowed to have it.
sub addAttribute {
  my ($self, $key, $value) = @_;
  return unless defined $value;
  my $node = $$self{node};
  $node = $node->parentNode if $node->nodeType == XML_TEXT_NODE;
  while (($node->nodeType != XML_DOCUMENT_NODE) && !$$self{model}->canHaveAttribute($node, $key)) {
    $node = $node->parentNode; }
  if ($node->nodeType == XML_DOCUMENT_NODE) {
    Error('malformed', $key, $self,
      "Attribute $key not allowed in this node or ancestors"); }
  else {
    $self->setAttribute($node, $key, $value); }
  return; }

#**********************************************************************
# Low level internal interface

# Return a string indicating the path to the current insertion point in the document.
# if $levels is defined, show only that many levels
sub getInsertionContext {
  my ($self, $levels) = @_;
  my $node = $$self{node};
  my $type = $node->nodeType;
  if (($type != XML_TEXT_NODE) && ($type != XML_ELEMENT_NODE) && ($type != XML_DOCUMENT_NODE)) {
    Error('internal', 'context', $self,
      "Insertion point is not an element, document or text: ", Stringify($node));
    return; }
  my $path = Stringify($node);
  while ($node = $node->parentNode) {
    if ((defined $levels) && (--$levels <= 0)) { $path = '...' . $path; last; }
    $path = Stringify($node) . $path; }
  return $path; }

# Find the node where an element with qualified name $qname can be inserted.
# This will move up the tree (closing auto-closable elements),
# or down (inserting auto-openable elements), as needed.
sub find_insertion_point {
  my ($self, $qname) = @_;
  $self->closeText_internal;    # Close any current text node.
  my $cur_qname = $$self{model}->getNodeQName($$self{node});
  my $inter;
  # If $qname is allowed at the current point, we're done.
  if ($self->canContain($cur_qname, $qname)) {
    return $$self{node}; }
  # Else, if we can create an intermediate node that accepts $qname, we'll do that.
  elsif (($inter = $self->canContainIndirect($cur_qname, $qname))
    && ($inter ne $qname) && ($inter ne $cur_qname)) {
    $self->openElement($inter, font => $self->getNodeFont($$self{node}));
    return $self->find_insertion_point($qname); }    # And retry insertion (should work now).
  else {                                             # Now we're getting more desparate...
        # Check if we can auto close some nodes, and _then_ insert the $qname.
    my ($node, $closeto) = ($$self{node});
    while (($node->nodeType != XML_DOCUMENT_NODE) && $self->canAutoClose($node)) {
      my $parent = $node->parentNode;
      if ($self->canContainSomehow($parent, $qname)) {
        $closeto = $node; last; }
      $node = $parent; }
    if ($closeto) {
      $self->closeNode_internal($closeto);             # Close the auto closeable nodes.
      return $self->find_insertion_point($qname); }    # Then retry, possibly w/auto open's
    else {                                             # Didn't find a legit place.
      Error('malformed', $qname, $self,
        ($qname eq '#PCDATA' ? $qname : '<' . $qname . '>') . " isn't allowed here",
        "Currently in " . $self->getInsertionContext);
      return $$self{node}; } } }                       # But we'll do it anyway, unless Error => Fatal.

sub getInsertionCandidates {
  my ($node) = @_;
  my @nodes = ();
  # Check the current element FIRST, then build list of candidates.
  my $first = $node;
  $first = $first->parentNode if $first && $first->getType == XML_TEXT_NODE;
  my $isCapture = $first && ($first->localname || '') eq '_Capture_';
  push(@nodes, $first) if $first && $first->getType != XML_DOCUMENT_NODE && !$isCapture;
  $node = $node->lastChild if $node && $node->hasChildNodes;
  while ($node && ($node->nodeType != XML_DOCUMENT_NODE)) {
    my $n = $node;
    while ($n) {
      if (($n->localname || '') eq '_Capture_') {
        push(@nodes, element_nodes($n)); }
      else {
        push(@nodes, $n); }
      $n = $n->previousSibling; }
    $node = $node->parentNode; }
  push(@nodes, $first) if $isCapture;
  return @nodes; }

# The following two "floatTo" operations find an appropriate point
# within the document tree preceding the current insertion point.
# They return undef (& issue a warning) if such a point cannot be found.
# Otherwise, they move the current insertion point to the appropriate node,
# and return the previous insertion point.
# After you make whatever changes (insertions or whatever) to the tree,
# you should do
#   $document->setNode($savenode)
# to reset the insertion point to where it had been.

# Find a node in the document that can contain an element $qname
sub floatToElement {
  my ($self, $qname) = @_;
  my @candidates = getInsertionCandidates($$self{node});
  while (@candidates && !$self->canContain($candidates[0], $qname)) {
    shift(@candidates); }
  if (my $n = shift(@candidates)) {
    my $savenode = $$self{node};
    $self->setNode($n);
    print STDERR "Floating from " . Stringify($savenode) . " to " . Stringify($n) . " for $qname\n"
      if ($$savenode ne $$n) && $LaTeXML::Core::Document::DEBUG;
    return $savenode; }
  else {
    Warn('malformed', $qname, $self, "No open node can contain element '$qname'",
      $self->getInsertionContext())
      unless $self->canContainSomehow($$self{node}, $qname);
    return; } }

# Find a node in the document that can accept the attribute $key
sub floatToAttribute {
  my ($self, $key) = @_;
  my @candidates = getInsertionCandidates($$self{node});
  while (@candidates && !$self->canHaveAttribute($candidates[0], $key)) {
    shift(@candidates); }
  if (my $n = shift(@candidates)) {
    my $savenode = $$self{node};
    $self->setNode($n);
    return $savenode; }
  else {
    Warn('malformed', $key, $self, "No open node can get attribute '$key'",
      $self->getInsertionContext());
    return; } }

sub openText_internal {
  my ($self, $text) = @_;
  my $qname;
  if ($$self{node}->nodeType == XML_TEXT_NODE) {    # current node already is a text node.
    print STDERR "Appending text \"$text\" to " . Stringify($$self{node}) . "\n" if $LaTeXML::Core::Document::DEBUG;
    $$self{node}->appendData($text); }
  elsif (($text =~ /\S/)                            # If non space
    || $self->canContain($$self{node}, '#PCDATA')) {    # or text allowed here
    my $point = $self->find_insertion_point('#PCDATA');
    my $node  = $$self{document}->createTextNode($text);
    print STDERR "Inserting text node for \"$text\" into " . Stringify($point) . "\n"
      if $LaTeXML::Core::Document::DEBUG;
    $point->appendChild($node);
    $self->setNode($node); }
  return $$self{node}; }                                # return the text node (current)

# Question: Why do I have math ligatures handled within openMathText_internal,
# but text ligatures handled within closeText_internal ???

sub openMathText_internal {
  my ($self, $string) = @_;
  # And if there's already text???
  my $node = $$self{node};
  my $font = $self->getNodeFont($node);
  $node->appendText($string);
  ##print STDERR "Trying Math Ligatures at \"$string\"\n";
  $self->applyMathLigatures($node);
  return $node; }

# New stategy (but inefficient): apply ligatures until one succeeds,
# then remove it, and repeat until ALL (remaining) fail.
sub applyMathLigatures {
  my ($self, $node) = @_;
  if (my $ligatures = $STATE->lookupValue('MATH_LIGATURES')) {
    my @ligatures = @$ligatures;
    while (@ligatures) {
      my $matched = 0;
      foreach my $ligature (@ligatures) {
        if ($self->applyMathLigature($node, $ligature)) {
          @ligatures = grep { $_ ne $ligature } @ligatures;
          $matched = 1;
          last; } }
      return unless $matched; } }
  return; }

# Apply ligature operation to $node, presumed the last insertion into it's parent(?)
sub applyMathLigature {
  my ($self, $node, $ligature) = @_;
  my @sibs = $node->parentNode->childNodes;
  my ($nmatched, $newstring, %attr) = &{ $$ligature{matcher} }($self, @sibs);
  if ($nmatched) {
    my @boxes = ($self->getNodeBox($node));
    $node->firstChild->setData($newstring);
    for (my $i = 0 ; $i < $nmatched - 1 ; $i++) {
      my $remove = $node->previousSibling;
      unshift(@boxes, $self->getNodeBox($remove));
      $self->removeNode($remove); }
## This fragment replaces the node's box by the composite boxes it replaces
## HOWEVER, this gets things out of sync because parent lists of boxes still
## have the old ones.  Unless we could recursively replace all of them, we'd better skip it(??)
    if (scalar(@boxes) > 1) {
      $self->setNodeBox($node, List(@boxes, mode => 'math')); }
    foreach my $key (sort keys %attr) {
      my $value = $attr{$key};
      if (defined $value) {
        $node->setAttribute($key => $value); }
      else {
        $node->removeAttribute($key); } }
    return 1; }
  else {
    return; } }

# Closing a text node is a good time to apply regexps (aka. Ligatures)
sub closeText_internal {
  my ($self) = @_;
  my $node = $$self{node};
  if ($node->nodeType == XML_TEXT_NODE) {    # Current node is text?
    my $parent  = $node->parentNode;
    my $font    = $self->getNodeFont($parent);
    my $string  = $node->data;
    my $ostring = $string;
    my $fonttest;
    if (my $ligatures = $STATE->lookupValue('TEXT_LIGATURES')) {
      foreach my $ligature (@$ligatures) {
        next if ($fonttest = $$ligature{fontTest}) && !&$fonttest($font);
        $string = &{ $$ligature{code} }($string); } }
    $node->setData($string) unless $string eq $ostring;
    $self->setNode($parent);                 # Now, effectively Closed
    return $parent; }
  else {
    return $node; } }

# Close $node, and any current nodes below it.
# No checking! Use this when you've already verified that $node can be closed.
# and, of course, $node must be current or some ancestor of it!!!
sub closeNode_internal {
  my ($self, $node) = @_;
  my $closeto = $node->parentNode;            # Grab now in case afterClose screws the structure.
  my $n       = $self->closeText_internal;    # Close any open text node.
  while ($n->nodeType == XML_ELEMENT_NODE) {
    $self->closeElementAt($n);
    $self->autoCollapseChildren($n);
    last if $node->isSameNode($n);
    $n = $n->parentNode; }
  $self->setNode($closeto);
  #  $self->autoCollapseChildren($node);
  return $$self{node}; }

# Avoid redundant nesting of font switching elements:
# If we're closing a node that can take font switches and it contains
# a single FONT_ELEMENT_NAME node; pull it up.
sub autoCollapseChildren {
  my ($self, $node) = @_;
  my $model = $$self{model};
  my $qname = $model->getNodeQName($node);
  my @c;
  if ((scalar(@c = $node->childNodes) == 1)    # with single child
    && ($model->getNodeQName($c[0]) eq $FONT_ELEMENT_NAME)
    # AND, $node can have all the attributes that the child has (but at least 'font')
    && !(grep { !$model->canHaveAttribute($qname, $_) }
      ('font', grep { /^[^_]/ } map { $_->nodeName } $c[0]->attributes))
    # BUT, it isn't being forced somehow
    && !$c[0]->hasAttribute('_force_font')) {
    my $c = $c[0];
    $self->setNodeFont($node, $self->getNodeFont($c));
    $self->removeNode($c);
    foreach my $gc ($c->childNodes) {
      $node->appendChild($gc); }
    # Merge the attributes from the child onto $node
    foreach my $attr ($c->attributes()) {
      if ($attr->nodeType == XML_ATTRIBUTE_NODE) {
        my $key = $attr->nodeName;
        my $val = $attr->getValue;
        # Special case attributes
        if ($key eq 'xml:id') {    # Use the replacement id
          if (!$node->hasAttribute($key)) {
            $self->recordID($val, $node);
            $node->setAttribute($key, $val); } }
        elsif ($key eq 'class') {    # combine $class
          if (my $class = $node->getAttribute($key)) {
            $node->setAttribute($key, $class . ' ' . $val); }
          else {
            $node->setAttribute($key, $val); } }
        # xoffset, yoffset, pad-width, pad-height should sum up, if present on both.
        elsif ($key =~ /^(xoffset|yoffset|pad-height|pad-width)$/) {
          if (my $val2 = $node->getAttribute($key)) {
            my $v1 = $val =~ /^([\+\-\d\.]*)pt$/  && $1;
            my $v2 = $val2 =~ /^([\+\-\d\.]*)pt$/ && $1;
            $node->setAttribute($key => ($v1 + $v2) . 'pt'); }
          else {
            $node->setAttribute($key => $val); } }
        # Remaining attributes should prefer the inner (child's) values, if any
        # (font, size, color, framed)
        # (width,height, depth, align, vattach, float)
        elsif (my $ns = $attr->namespaceURI) {
          $node->setAttributeNS($ns, $attr->name, $val); }
        else {
          $node->setAttribute($attr->localname, $val); } } }
  }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Document surgery (?)
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# The following carry out DOM modification but NOT relative to any current
# insertion point (eg $$self{node}), but rather relative to nodes specified
# in the arguments.

# Set any allowed attribute on a node, decoding the prefix, if any.
# Also records, and checks, any id attributes.
# [xml:id and namespaced attributes are always allowed]
sub setAttribute {
  my ($self, $node, $key, $value) = @_;
  $value = $value->toAttribute if ref $value;
  if ((defined $value) && ($value ne '')) {    # Skip if `empty'; but 0 is OK!
    if ($key eq 'xml:id') {                    # If it's an ID attribute
      $value = $self->recordID($value, $node);    # Do id book keeping
      $node->setAttributeNS($LaTeXML::Common::XML::XML_NS, 'id', $value); }    # and bypass all ns stuff
    elsif ($key !~ /:/) {    # No colon; no namespace (the common case!)
                             # Ignore attributes not allowed by the model,
                             # but accept "internal" attributes.
      my $model = $$self{model};
      my $qname = $model->getNodeQName($node);
      if ($model->canHaveAttribute($qname, $key) || $key =~ /^_/) {
        $node->setAttribute($key => $value); } }
    else {                   # Accept any namespaced attributes
      my ($ns, $name) = $$self{model}->decodeQName($key);
      if ($ns) {             # If namespaced attribute (must have prefix!
        my $prefix = $node->lookupNamespacePrefix($ns);    # namespace already declared?
        if (!$prefix) {                                    # if namespace not already declared
          $prefix = $$self{model}->getDocumentNamespacePrefix($ns, 1);    # get the prefix to use
          $self->getDocument->documentElement->setNamespace($ns, $prefix, 0); }    # and declare it
        if ($prefix eq '#default') {    # Probably shouldn't happen...?
          $node->setAttribute($name => $value); }
        else {
          $node->setAttributeNS($ns, "$prefix:$name" => $value); } }
      else {
        $node->setAttribute($name => $value); } } }    # redundant case...
  return; }

#**********************************************************************
# Association of nodes and ids (xml:id)

sub recordID {
  my ($self, $id, $node) = @_;
  if (my $prev = $$self{idstore}{$id}) {    # Whoops! Already assigned!!!
                                            # Can we recover?
    my $badid = $id;
    $id = $self->modifyID($id);
    Info('malformed', 'id', $node, "Duplicated attribute xml:id",
      "Using id='$id' on " . Stringify($node), "id='$badid' already set on " . Stringify($prev)); }
  $$self{idstore}{$id} = $node;
  return $id; }

sub unRecordID {
  my ($self, $id) = @_;
  delete $$self{idstore}{$id};
  return; }

# These are used to record or unrecord, in bulk, all the ids within a node (tree).
sub recordNodeIDs {
  my ($self, $node) = @_;
  foreach my $idnode ($self->findnodes('descendent-or-self::*[@xml:id]', $node)) {
    if (my $id = $idnode->getAttribute('xml:id')) {
      $self->recordID($id, $idnode); } }
  return; }

sub unRecordNodeIDs {
  my ($self, $node) = @_;
  foreach my $idnode ($self->findnodes('descendant-or-self::*[@xml:id]', $node)) {
    if (my $id = $idnode->getAttribute('xml:id')) {
      $self->unRecordID($id); } }
  return; }

# Get a new, related, but unique id
# Sneaky option: try $LaTeXML::Core::Document::ID_SUFFIX as a suffix for id, first.
sub modifyID {
  my ($self, $id) = @_;
  if (my $prev = $$self{idstore}{$id}) {    # Whoops! Already assigned!!!
                                            # Can we recover?
    my $badid = $id;
    if (!$LaTeXML::Core::Document::ID_SUFFIX
      || $$self{idstore}{ $id = $badid . $LaTeXML::Core::Document::ID_SUFFIX }) {
      foreach my $s1 (1 .. 26 * 26 * 26) {    # Gotta give up, eventually; is 3 letters enough?
        return $id unless $$self{idstore}{ $id = $badid . radix_alpha($s1) }; }
      Fatal('malformed', 'id', $self, "Automatic incrementing of ID counters failed",
        "Last alternative for '$id' is '$badid'"); } }
  return $id; }

sub lookupID {
  my ($self, $id) = @_;
  return $$self{idstore}{$id}; }

#======================================================================
# Odd bit:
# In an XMDual, in each branch (content, presentation) there will be atoms
# that correspond to the input (one will be real, the other an XMRef to the first).
# But also there will be additional "decoration" (delimiters, punctuation, etc on the presentation
# side; other symbols, bindings, whatever, on the content side).
# These decorations should NOT be subject to rewrite rules,
# and in cross-linked parallel markup, they should be attributed to the
# upper containing object's ID, rather than left dangling.
#
# To determine this, we mark all math nodes as to whether they are "visible" from
# presentation, content or both (the default top-level being both).
# Decorations are the nodes that are visible to only one mode.
# Note that nodes that are not visible at all CAN occur (& do currently when the parser
# creates XMDuals), pruneXMDuals (below) gets rid of them.

# NOTE: This should ultimately be in a base Document class,
# since it is also needed before conversion to parallel markup!
sub markXMNodeVisibility {
  my ($self) = @_;
  my @xmath = $self->findnodes('//ltx:XMath/*');
  foreach my $math (@xmath) {
    foreach my $node ($self->findnodes('descendant-or-self::*[@_pvis or @_cvis]', $math)) {
      $node->removeAttribute('_pvis');
      $node->removeAttribute('_cvis'); } }
  foreach my $math (@xmath) {
    $self->markXMNodeVisibility_aux($math, 1, 1); }
  return; }

sub markXMNodeVisibility_aux {
  my ($self, $node, $cvis, $pvis) = @_;
  my $qname = $self->getNodeQName($node);
  return if (!$cvis || $node->getAttribute('_cvis')) && (!$pvis || $node->getAttribute('_pvis'));
  # Special case: for XMArg used to wrap "formal" arguments on the content side,
  # mark them as visible as presentation as well.
  $pvis = 1 if $cvis && ($qname eq 'ltx:XMArg');
  $node->setAttribute('_cvis' => 1) if $cvis;
  $node->setAttribute('_pvis' => 1) if $pvis;
  if ($qname eq 'ltx:XMDual') {
    my ($c, $p) = element_nodes($node);
    $self->markXMNodeVisibility_aux($c, 1, 0) if $cvis;
    $self->markXMNodeVisibility_aux($p, 0, 1) if $pvis; }
  elsif ($qname eq 'ltx:XMRef') {
    #    $self->markXMNodeVisibility_aux($self->realizeXMNode($node),$cvis,$pvis); }
    my $id = $node->getAttribute('idref');
    if (!$id) {
      Warn('expected', 'id', $self, "Missing id on ltx:XMRef");
      return; }
    my $reffed = $self->lookupID($id);
    if (!$reffed) {
      Warn('expected', 'node', $self, "No node found with id=$id (referred to from ltx:XMRef)");
      return; }
    $self->markXMNodeVisibility_aux($reffed, $cvis, $pvis); }
  else {
    foreach my $child (element_nodes($node)) {
      $self->markXMNodeVisibility_aux($child, $cvis, $pvis); } }
  return; }

# Reduce any ltx:XMDual's to just the visible branch, if the other is not visible
# (according to markXMNodeVisibility)
# If we could be 100% sure that the marking had stayed consistent (after various doc surgery)
# we could avoid re-marking, but we'd better be sure before removing nodes!
sub pruneXMDuals {
  my ($self) = @_;
  # RE-mark visibility!
  $self->markXMNodeVisibility;
  # will reversing keep from problems removing nodes from trees that already have been removed?
  foreach my $dual (reverse $self->findnodes('descendant-or-self::ltx:XMDual')) {
    my ($content, $presentation) = element_nodes($dual);
    if (!$self->findnode('descendant-or-self::*[@_pvis or @_cvis]', $content)) {    # content never seen
      $self->replaceTree($presentation, $dual); }
    elsif (!$self->findnode('descendant-or-self::*[@_pvis or @_cvis]', $presentation)) {    # pres.
      $self->replaceTree($content, $dual); }
  }
  return; }

#**********************************************************************
# Record the Box that created this node.
sub setNodeBox {
  my ($self, $node, $box) = @_;
  return unless $box;
  my $boxid = "$box";
  $$self{node_boxes}{$boxid} = $box;
  return $node->setAttribute(_box => $boxid); }

sub getNodeBox {
  my ($self, $node) = @_;
  my $t = $node->nodeType;
  return if $t != XML_ELEMENT_NODE;
  if (my $boxid = $node->getAttribute('_box')) {
    return $$self{node_boxes}{$boxid}; } }

sub setNodeFont {
  my ($self, $node, $font) = @_;
  return unless ref $font;    # ?
  my $fontid = $font->toString;
  $$self{node_fonts}{$fontid} = $font;
  if ($node->nodeType == XML_ELEMENT_NODE) {
    $node->setAttribute(_font => $fontid); }
  else {
    Warn('malformed', 'font', $node, "Can't set font on this node"); }
  return; }

sub getNodeFont {
  my ($self, $node) = @_;
  my $t = $node->nodeType;
  return (($t == XML_ELEMENT_NODE) && $$self{node_fonts}{ $node->getAttribute('_font') })
    || LaTeXML::Common::Font->textDefault(); }

sub decodeFont {
  my ($self, $fontid) = @_;
  return $$self{node_fonts}{$fontid} || LaTeXML::Common::Font->textDefault(); }

# Remove a node from the document (from it's parent)
sub removeNode {
  my ($self, $node) = @_;
  if ($node) {
    my $chopped = $$self{node}->isSameNode($node);    # Note if we're removing insertion point
    if ($node->nodeType == XML_ELEMENT_NODE) {        # If an element, do ID bookkeeping.
      if (my $id = $node->getAttribute('xml:id')) {
        $self->unRecordID($id); }
      $chopped ||= grep { $self->removeNode_aux($_) } $node->childNodes; }
    my $parent = $node->parentNode;
    if ($chopped) {                                   # Don't remove insertion point!
      $self->setNode($parent); }
    $parent->removeChild($node);
  }
  return $node; }

sub removeNode_aux {
  my ($self, $node) = @_;
  my $chopped = $$self{node}->isSameNode($node);
  if ($node->nodeType == XML_ELEMENT_NODE) {          # If an element, do ID bookkeeping.
    if (my $id = $node->getAttribute('xml:id')) {
      $self->unRecordID($id); }
    $chopped ||= grep { $self->removeNode_aux($_) } $node->childNodes; }
  return $chopped; }

#**********************************************************************
# Inserting new nodes at random points into the document,
# typically, later in the process or during some kind of rearrangement.

# This is a somewhat strange situation; There are commands and environments
# that do some interesting thing to their contents. This include things like
# center, flushleft, or rotate, or ...
# Naively one is tempted to create a containing block with appropriate type & attributes.
# However, since these things can be allowed in so many places by LaTeX, that
# one has a difficult time creating a sensible document model.
# The purpose of transformingBlock is to set the contents (possibly creating a
# consistent <p> around them, if called for), and returning the list of newly
# created nodes. These nodes can then have appropriate attributes added as needed
# for each specific case.

# Since this situation can occur in both LaTeX and AmSTeX type documents,
# we'll put it in the TeX pool so it can be reused.

# Tricky bit for creating nodes late in the game,
######
### See createElementAt
# This opens a new element at the _specified_ point, rather than the current insertion point.
# This is useful during document rearrangement or augmentation that may be needed later
# in the process.
sub openElementAt {
  my ($self, $point, $qname, %attributes) = @_;
  my ($ns, $tag) = $$self{model}->decodeQName($qname);
  my $newnode;
  my $font = $attributes{_font} || $attributes{font};
  my $box = $attributes{_box};
  $box = $$self{node_boxes}{$box} if $box && !ref $box;    # may already be the string key
         # If this will be the document root node, things are slightly more involved.
  if ($point->nodeType == XML_DOCUMENT_NODE) {    # First node! (?)
    $$self{model}->addSchemaDeclaration($self, $tag);
    map { $$self{document}->appendChild($_) } @{ $$self{pending} };    # Add saved comments, PI's
    $newnode = $$self{document}->createElement($tag);
    $self->recordConstructedNode($newnode);
    $$self{document}->setDocumentElement($newnode);
    if ($ns) {
  # Here, we're creating the initial, document element, which will hold ALL of the namespace declarations.
  # If there is a default namespace (no prefix), that will also be declared, and applied here.
  # However, if there is ALSO a prefix associated with that namespace, we have to declare it FIRST
  # due to the (apparently) buggy way that XML::LibXML works with namespaces in setAttributeNS.
      my $prefix = $$self{model}->getDocumentNamespacePrefix($ns);
      my $attprefix = $$self{model}->getDocumentNamespacePrefix($ns, 1, 1);
      if (!$prefix && $attprefix) {
        $newnode->setNamespace($ns, $attprefix, 0); }
      $newnode->setNamespace($ns, $prefix, 1); } }
  else {
    $font = $self->getNodeFont($point) unless $font;
    $box  = $self->getNodeBox($point)  unless $box;
    $newnode = $self->openElement_internal($point, $ns, $tag); }

  foreach my $key (sort keys %attributes) {
    next if $key eq 'font';       # !!!
    next if $key eq 'locator';    # !!!
    $self->setAttribute($newnode, $key, $attributes{$key}); }
  $self->setNodeFont($newnode, $font) if $font;
  $self->setNodeBox($newnode, $box) if $box;
  print STDERR "Inserting " . Stringify($newnode) . " into " . Stringify($point) . "\n" if $LaTeXML::Core::Document::DEBUG;

  # Run afterOpen operations
  $self->afterOpen($newnode);

  return $newnode; }

sub openElement_internal {
  my ($self, $point, $ns, $tag) = @_;
  my $newnode;
  if ($ns) {
    if (!defined $point->lookupNamespacePrefix($ns)) {    # namespace not already declared?
      $self->getDocument->documentElement
        ->setNamespace($ns, $$self{model}->getDocumentNamespacePrefix($ns), 0); }
    $newnode = $point->addNewChild($ns, $tag); }
  else {
    $newnode = $point->appendChild($$self{document}->createElement($tag)); }
  $self->recordConstructedNode($newnode);
  return $newnode; }

# Whenever a node has been created using openElementAt,
# closeElementAt ought to be used to close it, when you're finished inserting into $node.
# Basically, this just runs any afterClose operations.
sub closeElementAt {
  my ($self, $node) = @_;
  return $self->afterClose($node); }

sub afterOpen {
  my ($self, $node) = @_;
  # Set current point to this node, just in case the afterOpen's use it.
  my $savenode = $$self{node};
  $self->setNode($node);
  my $box = $self->getNodeBox($node);
  map { &$_($self, $node, $box) } $self->getTagActionList($node, 'afterOpen');
  $self->setNode($savenode);
  return $node; }

sub afterClose {
  my ($self, $node) = @_;
  # Should we set point to this node? (or to last child, or something ??
  my $savenode = $$self{node};
  my $box      = $self->getNodeBox($node);
  map { &$_($self, $node, $box) } $self->getTagActionList($node, 'afterClose');
  $self->setNode($savenode);
  return $node; }

#**********************************************************************
# Appending clones of nodes

# Inserting clones of nodes into the document.
# Nodes that exist in some other part of the document (or some other document)
# will need to be cloned so that they can be part of the new document;
# otherwise, they would be removed from thier previous document.
# Also, we want to have a clean namespace node structure
# (otherwise, libxml2 has a tendency to introduce annoying "default" namespace prefix declarations)
# And, finally, we need to modify any id's present in the old nodes,
# since otherwise they may be duplicated.

# Should have variants here for prepend, insert before, insert after.... ???
sub appendClone {
  my ($self, $node, @newchildren) = @_;
  # Expand any document fragments
  @newchildren = map { ($_->nodeType == XML_DOCUMENT_FRAG_NODE ? $_->childNodes : $_) } @newchildren;
  # Now find all xml:id's in the newchildren and record replacement id's for them
  local %LaTeXML::Core::Document::IDMAP = ();
  # Find all id's defined in the copy and change the id.
  foreach my $child (@newchildren) {
    foreach my $idnode ($self->findnodes('.//@xml:id', $child)) {
      my $id = $idnode->getValue;
      $LaTeXML::Core::Document::IDMAP{$id} = $self->modifyID($id); } }
  # Now do the cloning (actually copying) and insertion.
  $self->appendClone_aux($node, @newchildren);
  return $node; }

sub appendClone_aux {
  my ($self, $node, @newchildren) = @_;
  foreach my $child (@newchildren) {
    my $type = $child->nodeType;
    if ($type == XML_ELEMENT_NODE) {
      my $new = $self->openElement_internal($node, $child->namespaceURI, $child->localname);
      foreach my $attr ($child->attributes) {
        if ($attr->nodeType == XML_ATTRIBUTE_NODE) {
          my $key = $attr->nodeName;
          if ($key eq 'xml:id') {    # Use the replacement id
            my $newid = $LaTeXML::Core::Document::IDMAP{ $attr->getValue };
            $new->setAttribute($key, $newid);
            $self->recordID($newid, $new); }
          elsif ($key eq 'idref') {    # Refer to the replacement id if it was replaced
            my $id = $attr->getValue;
            $new->setAttribute($key, $LaTeXML::Core::Document::IDMAP{$id} || $id); }
          elsif (my $ns = $attr->namespaceURI) {
            $new->setAttributeNS($ns, $attr->name, $attr->getValue); }
          else {
            $new->setAttribute($attr->localname, $attr->getValue); } }
      }
      $self->afterOpen($new);
      $self->appendClone_aux($new, $child->childNodes);
      $self->afterClose($new); }
    elsif ($type == XML_TEXT_NODE) {
      $node->appendTextNode($child->textContent); } }
  return $node; }

#**********************************************************************
# Wrapping & Unwrapping nodes by another element.

# Wrap @nodes with an element named $qname, making the new element replace the first $node,
# and all @nodes becomes the child of the new node.
# [this makes most sense if @nodes are a sequence of siblings]
# Returns undef if $qname isn't allowed in the parent, or if @nodes aren't allowed in $qname,
# otherwise, returns the newly created $qname.
sub wrapNodes {
  my ($self, $qname, @nodes) = @_;
  return unless @nodes;
  my $model  = $$self{model};
  my $parent = $nodes[0]->parentNode;
  my ($ns, $tag) = $model->decodeQName($qname);
  my $new = $self->openElement_internal($parent, $ns, $tag);
  $self->afterOpen($new);
  $parent->replaceChild($new, $nodes[0]);

  if (my $font = $self->getNodeFont($parent)) {
    $self->setNodeFont($new, $font); }
  if (my $box = $self->getNodeBox($parent)) {
    $self->setNodeBox($new, $box); }
  foreach my $node (@nodes) {
    $new->appendChild($node); }
  $self->afterClose($new);
  return $new; }

# Unwrap the children of $node, by replacing $node by its children.
sub unwrapNodes {
  my ($self, $node) = @_;
  return $self->replaceNode($node, $node->childNodes); }

# Replace $node by @nodes (presumably descendants of some kind?)
sub replaceNode {
  my ($self, $node, @nodes) = @_;
  my $parent = $node->parentNode;
  my $c0;
  while (my $c1 = shift(@nodes)) {
    if ($c0) { $parent->insertAfter($c1, $c0); }
    else     { $parent->replaceChild($c1, $node); }
    $c0 = $c1; }
  $self->removeNode($node);
  return $node; }

# initially since $node->setNodeName was broken in XML::LibXML 1.58
# but this can provide for more options & correctness?
sub renameNode {
  my ($self, $node, $newname) = @_;
  my $model = $$self{model};
  my ($ns, $tag) = $model->decodeQName($newname);
  my $parent = $node->parentNode;
  my $new = $self->openElement_internal($parent, $ns, $tag);
  my $id;
  # Move to the position AFTER $node
  $parent->insertAfter($new, $node);
  # Copy ALL attributes from $node to $newnode
  foreach my $attr ($node->attributes) {
    my $key   = $attr->getName;
    my $value = $node->getAttribute($key);
    $id = $value if $key eq 'xml:id';    # Save to register after removal of old node.
    $new->setAttribute($key, $value); }
  # AND move all content from $node to $newnode
  foreach my $child ($node->childNodes) {
    $new->appendChild($child); }
  ## THEN call afterOpen... ?
  # It would normally be called before children added,
  # but how can we know if we're duplicated auto-added stuff?
  $self->afterOpen($new);
  $self->afterClose($new);
  # Finally, remove the old node
  $self->removeNode($node);
  # and FINALLY, we can register the new node under the id.
  $self->recordID($id, $new) if $id;
  return $new; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Finally, another set of surgery methods
# These take an array representation of the XML Tree to append
#   [tagname,{attributes..}, children]
# THESE SHOULD BE PART OF A COMMON BASE CLASS; DUPLICATED IN Post::Document
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sub replaceTree {
  my ($self, $new, $old) = @_;
  my $parent    = $old->parentNode;
  my @following = ();                 # Collect the matching and following nodes
  while (my $sib = $parent->lastChild) {
    last if $sib->isSameNode($old);
    $parent->removeChild($sib);       # We're putting these back, in a moment!
    unshift(@following, $sib); }
  $self->removeNode($old);
  $self->appendTree($parent, $new);
  my $inserted = $parent->lastChild;
  map { $parent->appendChild($_) } @following;    # No need for clone
  return $inserted; }

sub appendTree {
  my ($self, $node, @data) = @_;
  foreach my $child (@data) {
    if (ref $child eq 'ARRAY') {
      my ($tag, $attributes, @children) = @$child;
      my $new = $self->openElementAt($node, $tag, ($attributes ? %$attributes : ()));
      $self->appendTree($new, @children); }
    elsif ((ref $child) =~ /^XML::LibXML::/) {
      my $type = $child->nodeType;
      if ($type == XML_ELEMENT_NODE) {
        my $tag = $self->getNodeQName($child);
        my %attributes = map { $_->nodeType == XML_ATTRIBUTE_NODE ? ($_->nodeName => $_->getValue) : () }
          $child->attributes;
        my $new = $self->openElementAt($node, $tag, %attributes);
        $self->appendTree($new, $child->childNodes); }
      elsif ($type == XML_DOCUMENT_FRAG_NODE) {
        $self->appendTree($node, $child->childNodes); }
      elsif ($type == XML_TEXT_NODE) {
        $node->appendTextNode($child->textContent); }
    }
    elsif ((ref $child) && $child->isaBox) {
      my $savenode = $self->getNode;
      $self->setNode($node);
      $self->absorb($child);
      $self->setNode($savenode); }
    elsif (ref $child) {
      Warn('malformed', $child, $node, "Dont know how to add '$child' to document; ignoring"); }
    elsif (defined $child) {
      $node->appendTextNode($child); } }
  return; }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Document> - represents an XML document under construction.

=head1 DESCRIPTION

A C<LaTeXML::Core::Document> represents an XML document being constructed by LaTeXML,
and also provides the methods for constructing it.  
It extends L<LaTeXML::Common::Object>.

LaTeXML will have digested the source material resulting in a L<LaTeXML::Core::List> (from a L<LaTeXML::Core::Stomach>)
of  L<LaTeXML::Core::Box>s, L<LaTeXML::Core::Whatsit>s and sublists.  At this stage, a document is created
and it is responsible for `absorbing' the digested material.
Generally, the L<LaTeXML::Core::Box>s and L<LaTeXML::Core::List>s create text nodes,
whereas the L<LaTeXML::Core::Whatsit>s create C<XML> document fragments, elements
and attributes according to the defining L<LaTeXML::Core::Definition::Constructor>.

Most document construction occurs at a I<current insertion point> where material will
be added, and which moves along with the inserted material.
The L<LaTeXML::Common::Model>, derived from various declarations and document type,
is consulted to determine whether an insertion is allowed and when elements may need
to be automatically opened or closed in order to carry out a given insertion.
For example, a C<subsection> element will typically be closed automatically when it
is attempted to open a C<section> element.

In the methods described here, the term C<$qname> is used for XML qualified names.
These are tag names with a namespace prefix.  The prefix should be one
registered with the current Model, for use within the code.  This prefix is
not necessarily the same as the one used in any DTD, but should be mapped
to the a Namespace URI that was registered for the DTD.

The arguments named C<$node> are an XML::LibXML node.

The methods here are grouped into three sections covering basic access to the 
document, insertion methods at the current insertion point,
and less commonly used, lower-level, document manipulation methods.

=head2 Accessors

=over 4

=item C<< $doc = $document->getDocument; >>

Returns the C<XML::LibXML::Document> currently being constructed.

=item C<< $doc = $document->getModel; >>

Returns the C<LaTeXML::Common::Model> that represents the document model used for this document.

=item C<< $node = $document->getNode; >>

Returns the node at the I<current insertion point> during construction.  This node
is considered still to be `open'; any insertions will go into it (if possible).
The node will be an C<XML::LibXML::Element>, C<XML::LibXML::Text>
or, initially, C<XML::LibXML::Document>.

=item C<< $node = $document->getElement; >>

Returns the closest ancestor to the current insertion point that is an Element.

=item C<< $node = $document->getChildElement($node); >>

Returns a list of the child elements, if any, of the C<$node>.

=item C<< @nodes = $document->getLastChildElement($node); >>

Returns the last child element of the C<$node>, if it has one, else undef.

=item C<< $node = $document->getFirstChildElement($node); >>

Returns the first child element of the C<$node>, if it has one, else undef.

=item C<< @nodes = $document->findnodes($xpath,$node); >>

Returns a list of nodes matching the given C<$xpath> expression.
The I<context node> for C<$xpath> is C<$node>, if given,
otherwise it is the document element.

=item C<< $node = $document->findnode($xpath,$node); >>

Returns the first node matching the given C<$xpath> expression.
The I<context node> for C<$xpath> is C<$node>, if given,
otherwise it is the document element.

=item C<< $node = $document->getNodeQName($node); >>

Returns the qualified name (localname with namespace prefix)
of the given C<$node>.  The namespace prefix mapping is the
code mapping of the current document model.

=item C<< $boolean = $document->canContain($tag,$child); >>

Returns whether an element C<$tag> can contain a child C<$child>.
C<$tag> and C<$child> can be nodes, qualified names of nodes
(prefix:localname), or one of a set of special symbols
C<#PCDATA>, C<#Comment>, C<#Document> or C<#ProcessingInstruction>.

=item C<< $boolean = $document->canContainIndirect($tag,$child); >>

Returns whether an element C<$tag> can contain a child C<$child>
either directly, or after automatically opening one or more autoOpen-able
elements.

=item C<< $boolean = $document->canContainSomehow($tag,$child); >>

Returns whether an element C<$tag> can contain a child C<$child>
either directly, or after automatically opening one or more autoOpen-able
elements.

=item C<< $boolean = $document->canHaveAttribute($tag,$attrib); >>

Returns whether an element C<$tag> can have an attribute named C<$attrib>.

=item C<< $boolean = $document->canAutoOpen($tag); >>

Returns whether an element C<$tag> is able to be automatically opened.

=item C<< $boolean = $document->canAutoClose($node); >>

Returns whether the node C<$node> can be automatically closed.

=back

=head2 Construction Methods

These methods are the most common ones used for construction of documents.
They generally operate by creating new material at the I<current insertion point>.
That point initially is just the document itself, but it moves along to
follow any new insertions.  These methods also adapt to the document model so as to
automatically open or close elements, when it is required for the pending insertion
and allowed by the document model (See L<Tag>).

=over 4

=item C<< $xmldoc = $document->finalize; >>

This method finalizes the document by cleaning up various temporary
attributes, and returns the L<XML::LibXML::Document> that was constructed.


=item C<< @nodes = $document->absorb($digested); >>

Absorb the C<$digested> object into the document at the current insertion point
according to its type.  Various of the the other methods are invoked as needed,
and document nodes may be automatically opened or closed according to the document
model.

This method returns the nodes that were constructed.
Note that the nodes may include children of other nodes,
and nodes that may already have been removed from the document
(See filterChildren and filterDeleted).
Also, text insertions are often merged with existing text nodes;
in such cases, the whole text node is included in the result.

=item C<< $document->insertElement($qname,$content,%attributes); >>

This is a shorthand for creating an element C<$qname> (with given attributes),
absorbing C<$content> from within that new node, and then closing it.
The C<$content> must be digested material, either a single box, or
an array of boxes, which will be absorbed into the element.
This method returns the newly created node,
although it will no longer be the current insertion point.

=item C<< $document->insertMathToken($string,%attributes); >>

Insert a math token (XMTok) containing the string C<$string> with the given attributes.
Useful attributes would be name, role, font.
Returns the newly inserted node.

=item C<< $document->insertComment($text); >>

Insert, and return, a comment with the given C<$text> into the current node.

=item C<< $document->insertPI($op,%attributes); >>

Insert, and return,  a ProcessingInstruction into the current node.

=item C<< $document->openText($text,$font); >>

Open a text node in font C<$font>, performing any required automatic opening
and closing of intermedate nodes (including those needed for font changes)
and inserting the string C<$text> into it.

=item C<< $document->openElement($qname,%attributes); >>

Open an element, named C<$qname> and with the given attributes.
This will be inserted into the current node while  performing 
any required automatic opening and closing of intermedate nodes.
The new element is returned, and also becomes the current insertion point.
An error (fatal if in C<Strict> mode) is signalled if there is no allowed way
to insert such an element into the current node.

=item C<< $document->closeElement($qname); >>

Close the closest open element named C<$qname> including any intermedate nodes that
may be automatically closed.  If that is not possible, signal an error.
The closed node's parent becomes the current node.
This method returns the closed node.

=item C<< $node = $document->isOpenable($qname); >>

Check whether it is possible to open a C<$qname> element
at the current insertion point.

=item C<< $node = $document->isCloseable($qname); >>

Check whether it is possible to close a C<$qname> element,
returning the node that would be closed if possible,
otherwise undef.

=item C<< $document->maybeCloseElement($qname); >>

Close a C<$qname> element, if it is possible to do so,
returns the closed node if it was found, else undef.

=item C<< $document->addAttribute($key=>$value); >>

Add the given attribute to the node nearest to the current insertion point
that is allowed to have it. This does not change the current insertion point.

=item C<< $document->closeToNode($node); >>

This method closes all children of C<$node> until C<$node>
becomes the insertion point. Note that it closes any
open nodes, not only autoCloseable ones.

=back

=head3 Internal Insertion Methods

These are described as an aide to understanding the code;
they rarely, if ever, should be used outside this module.

=over 4

=item C<< $document->setNode($node); >>

Sets the I<current insertion point> to be  C<$node>.
This should be rarely used, if at all; The construction methods of document
generally maintain the notion of insertion point automatically.
This may be useful to allow insertion into a different part of the document,
but you probably want to set the insertion point back to the previous
node, afterwards.

=item C<< $string = $document->getInsertionContext($levels); >>

For debugging, return a string showing the context of the current insertion point;
that is, the string of the nodes leading up to it.
if C<$levels> is defined, show only that many nodes.

=item C<< $node = $document->find_insertion_point($qname); >>

This internal method is used to find the appropriate point,
relative to the current insertion point, that an element with
the specified C<$qname> can be inserted.  That position may
require automatic opening or closing of elements, according
to what is allowed by the document model.

=item C<< @nodes = getInsertionCandidates($node); >>

Returns a list of elements where an arbitrary insertion might take place.
Roughly this is a list starting with C<$node>,
followed by its parent and the parents siblings (in reverse order), 
followed by the grandparent and siblings (in reverse order).

=item C<< $node = $document->floatToElement($qname); >>

Finds the nearest element at or preceding the current insertion point
(see C<getInsertionCandidates>), that can accept an element C<$qname>;
it moves the insertion point to that point, and returns the previous insertion point.
Generally, after doing whatever you need at the new insertion point,
you should call C<< $document->setNode($node); >> to
restore the insertion point.
If no such point is found, the insertion point is left unchanged,
and undef is returned.

=item C<< $node = $document->floatToAttribute($key); >>

This method works the same as C<floatToElement>, but find
the nearest element that can accept the attribute C<$key>.

=item C<< $node = $document->openText_internal($text); >>

This is an internal method,  used by C<openText>, that assumes the insertion point has
been appropriately adjusted.)

=item C<< $node = $document->openMathText_internal($text); >>

This internal method appends C<$text> to the current insertion point,
which is assumed to be a math node.  It checks for math ligatures and
carries out any combinations called for.

=item C<< $node = $document->closeText_internal(); >>

This internal method closes the current node, which should be a text node.
It carries out any text ligatures on the content.

=item C<< $node = $document->closeNode_internal($node); >>

This internal method closes any open text or element nodes starting
at the current insertion point, up to and including C<$node>.
Afterwards, the parent of C<$node> will be the current insertion point.
It condenses the tree to avoid redundant font switching elements.

=item C<< $document->afterOpen($node); >>

Carries out any afterOpen operations that have been recorded (using C<Tag>)
for the element name of C<$node>.

=item C<< $document->afterClose($node); >>

Carries out any afterClose operations that have been recorded (using C<Tag>)
for the element name of C<$node>.

=back

=head2 Document Modification

The following methods are used to perform various sorts of modification
and rearrangements of the document, after the normal flow of insertion
has taken place.  These may be needed after an environment (or perhaps the whole document)
has been completed and one needs to analyze what it contains to decide
on the appropriate representation.

=over 4

=item C<< $document->setAttribute($node,$key,$value); >>

Sets the attribute C<$key> to C<$value> on C<$node>.
This method is prefered over the direct LibXML one, since it
takes care of decoding namespaces (if C<$key> is a qname),
and also manages recording of xml:id's.

=item C<< $document->recordID($id,$node); >>

Records the association of the given C<$node> with the C<$id>,
which should be the C<xml:id> attribute of the C<$node>.
Usually this association will be maintained by the methods
that create nodes or set attributes.

=item C<< $document->unRecordID($id); >>

Removes the node associated with the given C<$id>, if any.
This might be needed if a node is deleted.

=item C<< $document->modifyID($id); >>

Adjusts C<$id>, if needed, so that it is unique.
It does this by appending a letter and incrementing until it
finds an id that is not yet associated with a node.

=item C<< $node = $document->lookupID($id); >>

Returns the node, if any, that is associated with the given C<$id>.

=item C<< $document->setNodeBox($node,$box); >>

Records the C<$box> (being a Box, Whatsit or List), that
was (presumably) responsible for the creation of the element C<$node>.
This information is useful for determining source locations,
original TeX strings, and so forth.

=item C<< $box = $document->getNodeBox($node); >>

Returns the C<$box> that was responsible for creating the element C<$node>.

=item C<< $document->setNodeFont($node,$font); >>

Records the font object that encodes the font that should be
used to display any text within the element C<$node>.

=item C<< $font = $document->getNodeFont($node); >>

Returns the font object associated with the element C<$node>.

=item C<< $node = $document->openElementAt($point,$qname,%attributes); >>

Opens a new child element in C<$point> with the qualified name C<$qname>
and with the given attributes.  This method is not affected by, nor does
it affect, the current insertion point.  It does manage namespaces,
xml:id's and associating a box, font and locator with the new element,
as well as running any C<afterOpen> operations.

=item C<< $node = $document->closeElementAt($node); >>

Closes C<$node>.  This method is not affected by, nor does
it affect, the current insertion point.
However, it does run any C<afterClose> operations, so any element
that was created using the lower-level C<openElementAt> should
be closed using this method.

=item C<< $node = $document->appendClone($node,@newchildren); >>

Appends clones of C<@newchildren> to C<$node>.
This method modifies any ids found within C<@newchildren>
(using C<modifyID>), and fixes up any references to those ids
within the clones so that they refer to the modified id.

=item C<< $node = $document->wrapNodes($qname,@nodes); >>

This method wraps the C<@nodes> by a new element with qualified name C<$qname>,
that new node replaces the first of C<@node>.
The remaining nodes in C<@nodes> must be following siblings of the first one.

NOTE: Does this need multiple nodes?
If so, perhaps some kind of movenodes helper?
Otherwise, what about attributes?

=item C<< $node = $document->unwrapNodes($node); >>

Unwrap the children of C<$node>, by replacing C<$node> by its children.

=item C<< $node = $document->replaceNode($node,@nodes); >>

Replace C<$node> by C<@nodes>; presumably they are some sort of descendant nodes.

=item C<< $node = $document->renameNode($node,$newname); >>

Rename C<$node> to the tagname C<$newname>; equivalently replace C<$node> by
a new node with name C<$newname> and copy the attributes and contents.
It is assumed that C<$newname> can contain those attributes and contents.

=item C<< @nodes = $document->filterDeletions(@nodes); >>

This function is useful with C<$doc->absorb($box)>,
when you want to filter out any nodes that have been deleted and
no longer appear in the document.

=item C<< @nodes = $document->filterChildren(@nodes); >>

This function is useful with C<$doc->absorb($box)>,
when you want to filter out any nodes that are children of other nodes in C<@nodes>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

