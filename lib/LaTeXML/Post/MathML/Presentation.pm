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
use LaTeXML::MathParser qw(p_getAttribute p_setAttribute p_removeAttribute p_element_nodes);
use LaTeXML::Common::XML;

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

sub associateNodeHook {
# technical note: $sourcenode and $currentnode are LibXML elements, while $node is that OR the arrayref triple form
  my ($self, $node, $sourcenode, $noxref, $currentnode) = @_;
  # TODO: Shouldn't we have a single getQName shared for the entire latexml codebase
  #       (same for the p_* methods from MathParser)
  #  in LaTeXML::Common or LaTeXML::Util ?
  my $name = getQName($node);
  if ($name =~ /^m:(?:mi|mo|mn)$/) {
    if (my $href = $sourcenode->getAttribute('href')) {
      p_setAttribute($node, 'href', $href); }
    if (my $title = $sourcenode->getAttribute('title')) {
      p_setAttribute($node, 'title', $title); } }
  $self->addAccessibilityAnnotations($node, $sourcenode, $currentnode) if $$self{a11y};
  return; }

# Experiment: set accessibility attributes on the resulting presentation tree,
# if the XMath source has a claim to the semantics via a "meaning" attribute.
sub addAccessibilityAnnotations {
  my ($self, $node, $sourcenode, $currentnode) = @_;
  # 1. Filter and bookkeep which nodes are to be treated.
  my $current_node_name = getQName($currentnode);
  return if $current_node_name eq 'ltx:XMath';
  return if $currentnode->getAttribute('_a11y');
  $currentnode->setAttribute('_a11y', 'done');
  my $source_node_name = getQName($sourcenode);
  my $container;
# skip non-material dual presentation, which points to content nodes but should *not* carry annotations itself
  if ($$currentnode != $$sourcenode) {
    return if ($source_node_name ne 'ltx:XMDual') or ($sourcenode->getAttribute('_a11y'));
    $sourcenode->setAttribute('_a11y', 'done'); }
  elsif ($container = $LaTeXML::Post::DOCUMENT->findnode('ancestor::ltx:XMDual[1]', $currentnode)) {
# also skip any embellishments in duals that are not semantic, a bit tricky since we need to check parent xmapps
    my $content_node = $container->firstChild;
    my %xmrefs       = map { my $ref = $_->getAttribute('idref'); $ref ? ($ref => 1) : () }
      $LaTeXML::Post::DOCUMENT->findnodes("//ltx:XMRef[\@idref]", $content_node);
    return unless %xmrefs;    # certainly not usable if no refs.
    my $ancestor = $currentnode;
    while ($$ancestor != $$container && !$xmrefs{ $ancestor->getAttribute('xml:id') || '' }) {
      $ancestor = $ancestor->parentNode; }
    return if $$ancestor == $$container; }
  # 1--end. We reach here only with semantic nodes in hand (or the logic has a Bug).

  # 2. Bookkeep the semantic information.
  my ($meaning, $arg);
  if (my $src_meaning = $sourcenode->getAttribute('meaning')) {
    $meaning = $src_meaning; }
  elsif ($source_node_name eq 'ltx:XMApp') {
    my $op = ($$node[0] eq 'm:mrow') ? '#op' : p_getAttribute($sourcenode->firstChild, 'meaning');
    if ($op) {    # annotate only if we knew a 'meaning' attribute, for the special markup scenarios
      $meaning = "$op(" . join(",", map { "#$_" } 1 .. scalar(element_nodes($sourcenode)) - 1) . ')'; }
    else {
      # otherwise, take the liberty to delete all data-arg of direct children
      for my $pmml_child (@$node[2 .. scalar(@$node) - 1]) {
        p_removeAttribute($pmml_child, 'data-arg'); } } }
  elsif ($source_node_name eq 'ltx:XMDual') {
    $meaning = dual_content_to_semantic_attr($sourcenode->firstChild); }

# 3. Bookkeep "arg" information
# (careful, can be arbitrary deep in a dual content tree)
# also, not so easy to disentangle - a node nested deeply inside a dual may be _either_ referenced in the dual (primary)
# _or_ a classic direct child of an intermediate XMApp. So we test until we find an $arg:
  $container = $container || $LaTeXML::Post::DOCUMENT->findnode('ancestor::ltx:XMDual[1]', $sourcenode);
  if ($container) {
    my $id = $sourcenode->getAttribute('xml:id');
    $arg = $id && dual_content_idref_to_data_attr($container->firstChild, $id); }
  if (!$arg && (getQName($sourcenode->parentNode) eq 'ltx:XMApp')) {    # normal apply case
        # note we can only do this simple check because we filtered out all embellishments in step 1.
    my $position = $LaTeXML::Post::DOCUMENT->findvalue("count(preceding-sibling::*)", $sourcenode);
    $arg = $position || 'op'; }

  p_setAttribute($node, 'data-semantic', $meaning) if $meaning;
  p_setAttribute($node, 'data-arg',      $arg)     if $arg;
  return; }

# Given the first (content) child of an ltx:XMDual, compute its corresponding a11y "semantic" attribute
sub dual_content_to_semantic_attr {
  my ($node, $prefix) = @_;
  my $name = getQName($node);
  if ($name eq 'ltx:XMTok') {
    return $node->getAttribute('meaning') || $node->getAttribute('name') || 'unknown'; }
  elsif ($name eq 'ltx:XMApp') {
    my @arg_nodes   = element_nodes($node);
    my $op_node     = shift @arg_nodes;
    my $op          = ($op_node && $op_node->getAttribute('meaning')) || '#op';
    my @arg_strings = ();
    my $index       = 0;
    for my $arg_node (@arg_nodes) {
      $index++;
      if (getQName($arg_node) eq 'ltx:XMApp') {
        push @arg_strings, dual_content_to_semantic_attr($arg_node, $prefix ? ($prefix . "_$index") : $index); }
      else {
        push @arg_strings, '#' . ($prefix ? ($prefix . "_$index") : $index); } } # will we need level suffixes?
    return $op . '(' . join(",", @arg_strings) . ')'; }
  else {
    print STDERR "Warning:unknown XMDual content child '$name' will default data-semantic attribute to 'unknown'\n";
    return 'unknown'; } }

# Given the first (content) child of an ltx:XMDual, and an idref value, compute the corresponding "arg" attribute for that XMRef
sub dual_content_idref_to_data_attr {
  my ($content_node, $idref) = @_;
  my ($ref_node) = $LaTeXML::Post::DOCUMENT->findnodes(
    "//ltx:XMRef[\@idref=\"" . $idref . "\"][1]", $content_node);
  my $path     = '';
  my $ancestor = $ref_node;
  while ($$ancestor != $$content_node) {
    my $position = $LaTeXML::Post::DOCUMENT->findvalue("count(preceding-sibling::*)", $ancestor);
    $path     = $path ? ($position . '_' . $path) : $position;
    $ancestor = $ancestor->parentNode; }
  return $path || 'op'; }

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
