# /=====================================================================\ #
# |  LaTeXML::Post::MathML::Presentation                                | #
# | MathML generator for LaTeXML                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::MathML::Presentation;
use strict;
use warnings;
use base qw(LaTeXML::Post::MathML);
use LaTeXML::Post::MathML qw(getQName);
use LaTeXML::Common::XML qw(isElementNode);

sub preprocess {
  my ($self, $doc, @maths) = @_;
  $self->SUPER::preprocess($doc, @maths);
  if ($$self{linelength}) {    # If we're doing linebreaking...
    $self->preprocess_linebreaking($doc, @maths); }
  return; }

# This would be the non-linebreaking version
sub convertNode_simple {
  my ($self, $doc, $xmath, $style) = @_;
  return $self->pmml_top($xmath, $style); }

# Convert a node and compute it's linebroken layout
sub convertNode_linebreak {
  my ($self, $doc, $xmath, $style) = @_;
  my $breaker = $$self{linebreaker};
  if (!$breaker) {
    require LaTeXML::Post::MathML::Linebreaker;
    $breaker = $$self{linebreaker} = LaTeXML::Post::MathML::Linebreaker->new(); }

  my $pmml   = $self->convertNode_simple($doc, $xmath, $style);
  my $layout = $breaker->bestFitToWidth($xmath, $pmml, $$self{linelength}, 1);
  if ($$layout{hasbreak}) {    # YES it did linebreak!
    $pmml = $breaker->applyLayout($pmml, $layout); }
  return ($pmml, $$layout{hasbreak}); }

sub convertNode {
  my ($self, $doc, $xmath) = @_;
  my $style = (($xmath->parentNode->getAttribute('mode') || 'inline') eq 'display'
    ? 'display' : 'text');
  my $id = $xmath->parentNode->getAttribute('xml:id');
  # If this node has already been pre-converted

  my $pmml;
  if ($pmml = $id && $$doc{converted_pmml_cache}{$id}) { }
  # A straight displayed Math will have been handled by preprocess_linebreaking (below),
  # and, if it needed line-breaking, will have generated a MathFork/MathBranch.
  # Other math, in the non-semantic side of a MathFork, may want to line break here as well.
  # It presumably will NOT be display style(?)
  # NEXT better strategy will be to scan columns of MathBranches to establish desired line length?
  elsif ($$self{linelength}    # If line breaking
    && ($doc->findnodes('ancestor::ltx:MathBranch', $xmath))    # In formatted side of MathFork?
          # But ONLY if last column!! (until we can adapt LineBreaker!)
    && !$doc->findnodes('parent::ltx:Math/parent::ltx:td/following-sibling::ltx:td', $xmath)) {
    my ($pmmlb, $broke) = $self->convertNode_linebreak($doc, $xmath, $style);
    $pmml = $pmmlb; }
  else {
    $pmml = $self->convertNode_simple($doc, $xmath, $style); }
  return { processor => $self, xml => $pmml, mimetype => 'application/mathml-presentation+xml' }; }

sub rawIDSuffix {
  return '.pmml'; }

use Data::Dumper;

sub associateNodeHook {
  # technical note: $sourcenode is a LibXML element, while $node is that OR the arrayref triple form
  my ($self, $node, $sourcenode) = @_;
  # if (ref $node eq 'ARRAY') {
  #   print STDERR "node: ", Dumper($node), "\nxmath: ", $sourcenode->toString(1), "\n"; }
  # else {
  #   print STDERR "node: ", $node->toString(1), "\nxmath: ", $sourcenode->toString(1), "\n"; }

  # TODO: Shouldn't we have a single getQName shared for the entire latexml codebase
  #  in LaTeXML::Common or LaTeXML::Util ?
  my $name = getQName($node);
  if ($name =~ /^m:(?:mi|mo|mn)$/) {
    if (my $href = $sourcenode->getAttribute('href')) {
      if (ref $node eq 'ARRAY') {
        $$node[1]{href} = $href; }
      else {
        $node->setAttribute('href', $href); } }
    if (my $title = $sourcenode->getAttribute('title')) {
      if (ref $node eq 'ARRAY') {
        $$node[1]{title} = $title; }
      else {
        $node->setAttribute('title', $title); } } }
  # Experiment: set accessibility attributes on the resulting presentation tree,
  # if the XMath source has a claim to the semantics via a "meaning" attribute.
  # Part I: Top-down. Recover the meaning of a subtree as an accessible annotation
  my $meaning;
  my $source_name          = getQName($sourcenode);
  my $src_parent           = $sourcenode->parentNode;
  my $src_parent_name      = getQName($src_parent);
  my $src_grandparent      = $src_parent->parentNode;
  my $src_grandparent_name = getQName($src_grandparent);
  # tokens are simplest - if we know of a meaning, use that for accessibility
  if ($source_name eq 'ltx:XMTok') {
    if (my $token_meaning = $sourcenode->getAttribute('meaning')) {
      if ($src_grandparent_name eq 'ltx:XMDual') {
        # often an XMDual contains the participating tokens of a transfix notation
        # and those tokens carry the same meaning as the top-level dual operation.
        # in those cases, don't tag the tokens, only tag the top-level dual node
        my $dual_meaning = $src_grandparent->firstChild->firstChild->getAttribute('meaning');
        $meaning = $token_meaning if ($token_meaning ne $dual_meaning); }
      else {    # just copy the meaning in the usual case
        $meaning = $token_meaning; } } }
  elsif ($source_name eq 'ltx:XMApp') {
    my @src_children = $sourcenode->childNodes;
    my $arg_count    = scalar(@src_children) - 1;
    # Implied operator case with special presentation element, rather than an mrow
    # (e.g. in \sqrt{} we don't have an operator token, but a wrapping msqrt)
    if ($name ne 'm:mrow') {
      # attempt annotating only if we understand the operator,
      # otherwise leave the default behavior to handle this element
      if (my $op_literal = $src_children[0]->getAttribute('meaning')) {
        $meaning = $op_literal . '(' . join(",", map { '@' . $_ } (1 .. $arg_count)) . ')'; } }
    else {
      # Directly translate the content tree in the attribute, all constitutents can be cross-annotated:
      $meaning = '@op(' . join(",", map { '@' . $_ } (1 .. $arg_count)) . ')'; } }
  elsif ($source_name eq 'ltx:XMDual') {
    # duals always have a literal head applied to a list of referenced arguments
    my $content_child = $sourcenode->firstChild;
    my $op_literal    = $content_child->firstChild->getAttribute('meaning');
    my @arg_nodes     = $content_child->childNodes;
    my $arg_count     = scalar(@arg_nodes) - 1;
    $meaning = $op_literal . '(' . join(",", map { '@' . $_ } (1 .. $arg_count)) . ')'; }
  # if we found some meaning, attach it as an accessible attribute
  if ($meaning) {
    if (ref $node eq 'ARRAY') {
      $$node[1]{semantic} = $meaning; }
    else {
      $node->setAttribute('semantic', $meaning); } }

  # Part II: Bottom-up. Also check if argument of higher parent notation, mark if so.
  my $arg;
  if ($src_parent_name eq 'ltx:XMApp' && $src_grandparent_name ne 'ltx:XMDual') {
    # Handle applications, but not inside duals - those should be handled when entering the dual
    my $op_node = $src_parent->firstChild;
    if ($op_node->getAttribute('meaning')) {    # only annotated applications we understand
      my $index        = 0;
      my $prev_sibling = $sourcenode;
      while ($prev_sibling = $prev_sibling->previousSibling) {
        $index++ if isElementNode($prev_sibling); }
      if ($index == 0) {
        $arg = 'op'; }
      else {
        $arg = $index; } } }
  elsif ($src_parent_name eq 'ltx:XMWrap' && $src_grandparent_name eq 'ltx:XMDual' &&
    # in which case, associated with the XMRef for this argument, if any.
    (my $fragid = $sourcenode->getAttribute('fragid'))) {
    my $content_child = $src_grandparent->firstChild;
    my @arg_nodes     = grep { isElementNode($_) } $content_child->childNodes;
    my $index         = 0;
    while (my $arg_node = shift @arg_nodes) {
      if ((getQName($arg_node) eq 'ltx:XMRef') && $arg_node->getAttribute('idref') eq $fragid) {
        # Found!
        $arg = $index; last; }
      $index += 1;
  } }
# if we found an indication that this node is an argument of a higher-up content tree, attach the annotation
  if ($arg) {
    if (ref $node eq 'ARRAY') {
      $$node[1]{arg} = $arg; }
    else {
      $node->setAttribute('arg', $arg); } }
  return; }

#================================================================================
# Presentation MathML with Line breaking
# Not at all sure how this will integrate with Parallel markup...

# Any displayed formula is a candidate for line-breaking.
# If it is not already in a MathFork, and needs line-breaking,
# then we ought to wrap in a MathFork, so as to preserve the
# slightly "semantically meaningful" form.
# If we're mangling the document structure in this way,
# it needs to be done before the main scan-all-math's loop,
# since it moves the maths around.
# However, since we also have to check whether it NEEDS line breaking beforehand,
# we might as well linebreak & store that line-broken result alongside.
# [it will get stored WITHOUT an XMath expression, though, so we won't be asked to redo it]
# convertNode will be called later on the main fork (unbroken).
# Also, other subexpressions inside MathFork/MathBranch that were created by
# the usual means (bindings for eqnarray, or whatever) will still need to
# be converted (convertNode).
# And in fact they also should be line-broken -- we just don't know the width!!
sub preprocess_linebreaking {
  my ($self, $doc, @maths) = @_;

  # Rewrap every displayed ltx:Math in an ltx:MathFork (if it isn't ALREADY in a MathFork).
  # This is so that we can preserve the "more semantic" non-linebroken form as the main branch.
  foreach my $math (@maths) {
    my $mode = $math->getAttribute('mode') || 'inline';
    next unless $mode eq 'display';    # SKIP if not in display mode?
    my $style = ($mode eq 'display' ? 'display' : 'text');
    # If already has in a MathBranch, we can't really know if, or how wide, to line break!?!?!
    next if $doc->findnodes('ancestor::ltx:MathFork', $math);    # SKIP if already in a branch?
          # Now let's do the layout & see if it actually needs line breaks!
          # next if $math isn't really so wide ..
    my $id    = $math->getAttribute('xml:id');
    my $xmath = $doc->findnode('ltx:XMath', $math);
    my ($pmml, $broke) = $self->convertNode_linebreak($doc, $xmath, $style);
    if ($broke) {    # YES it did linebreak!
          # Replace the Math node with a MathFork that contains the Math node.
          # And a MathBranch that ONLY contains the line-broken pmml.
          # That branch won't get other parallel markup,
          # but the main, more semantic(?) one, will and will get the unbroken pmml (?), as well.
      my $p = $math->parentNode;
      $id = $id . ".mbr" if $id;
      $doc->replaceNode($math, ['ltx:MathFork', {}, $math,
          ['ltx:MathBranch', {},
            ['ltx:Math', { 'xml:id' => $id },
              $self->outerWrapper($doc, $xmath, $pmml)]]]);
      # Now,RE-mark, since the insertion removed internal attributes!
      $doc->markXMNodeVisibility; }
    # cache the converted pmml?
    # But note that applyLayout MAY have MODIFIED the orignal $pmml, so it may have linebreaks!
    # but then, it will have a modified id, as well!!! (.mbr appended)
    if ($id) {
      $$doc{converted_pmml_cache}{$id} = $pmml; }
  }
  return; }

#================================================================================
1;
