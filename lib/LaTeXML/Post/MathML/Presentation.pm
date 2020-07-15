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
  # technical note: $sourcenode is a LibXML element, while $node is that OR the arrayref triple form
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
  $self->addAccessibilityAnnotations($node, $currentnode);
  return; }

# Experiment: set accessibility attributes on the resulting presentation tree,
# if the XMath source has a claim to the semantics via a "meaning" attribute.
sub addAccessibilityAnnotations {
  # Part I: Top-down. Recover the meaning of a subtree as an accessible annotation
  my ($self, $node, $currentnode) = @_;
  my $current_node_name = getQName($currentnode);
  return if $current_node_name eq 'ltx:XMath';
# a number of redundant annotations are caused by reusing the same content node for on-the-fly content,
# e.g. we end up creating a new invisible-apply XMTok, and then associate its node
# with the $currentnode of its parent <XMApp>f(x)</XMApp>, now as <XMApp>f<XMTok>invisible-apply</XMTok>(x)</XMApp>
# that second call should just immediately terminate, there is nothing to add in such cases.
  return if $currentnode->getAttribute('_a11y');
  $currentnode->setAttribute('_a11y', 'done');
  # --- TOP PRIORITY: run an exclusion check for pieces that are presentation-only fluff for duals
  my @dual_pres_ancestry = $LaTeXML::Post::DOCUMENT->findnodes("ancestor-or-self::*[preceding-sibling::*][parent::ltx:XMDual]", $currentnode);
  my $dual_pres_node = $dual_pres_ancestry[-1]; #  Weirdly ->findnode() is finding the highest ancestor, rather than the tightest ancestor? This [-1] seems to do it.
  if ($dual_pres_node && !$dual_pres_node->isSameNode($currentnode)) { # 1) they have a dual ancestor, but are not the main presentation node
    my $check_node = $currentnode;
    my $id         = $currentnode->getAttribute('xml:id');
    while (!$id && !$check_node->isSameNode($dual_pres_node)) {
      $id         = $check_node->getAttribute('xml:id');
      $check_node = $check_node->parentNode; }
    # if no id is found, they are not referenced by the dual
    return unless $id; }
  # ---
  # In the remaining cases, process the node, check if it has meaningful annotations to add
  my ($meaning, $arg);
  if ($dual_pres_node && $dual_pres_node->isSameNode($currentnode)) {    # top-level pres of dual
    my $dual_content_node = $dual_pres_node->previousSibling;
    my $dual_content_name = getQName($dual_content_node);
    if ($dual_content_name eq 'ltx:XMRef') {    # single subtree of the presentation, point to it
      $meaning = '#1'; }
    elsif ($dual_content_name eq 'ltx:XMTok') {
      $meaning = $dual_content_node->getAttribute('meaning'); }
    elsif ($dual_content_name eq 'ltx:XMApp') {
      my $op_node   = $dual_content_node->firstChild;
      my $op        = ($op_node && $op_node->getAttribute('meaning')) || '#op';
      my @arg_nodes = element_nodes($dual_content_node);
      my $arg_count = scalar(@arg_nodes) - 1;
      $meaning = $op . '(' . join(",", map { '#' . $_ } (1 .. $arg_count)) . ')'; }
# Note that the carrier ltx:XMDual is never passed in associateNode, but often requires an "arg". Recurse:
    $self->addAccessibilityAnnotations($node, $dual_pres_node->parentNode); }
  # tokens are simplest - if we know of a meaning, use that for accessibility
  elsif ($current_node_name eq 'ltx:XMTok') {
    # stylistic choice - avoid tagging numbers, even though we could, too obvious
    my $role = $currentnode->getAttribute('role') || '';
    $meaning = ($role ne 'NUMBER') && $currentnode->getAttribute('meaning'); }
  elsif ($current_node_name eq 'ltx:XMApp') {
    my @current_children   = element_nodes($currentnode);
    my $current_op_meaning = $current_children[0]->getAttribute('meaning') || '';
    my $arg_count          = scalar(@current_children) - 1;
    # Ok, so we need to disentangle the case where the operator XMTok is preserved in pmml,
    # and the case where it isn't. E.g. in \sqrt{x} we get a msqrt wrapper, but no dedicated token
    # so we need to mark the literal "square-root" in msqrt
    my $op;
    my $name = getQName($node);
    if ($name ne 'm:mrow') {    # not an mrow, prefer the literal semantic
      $op = $current_op_meaning; }
    else {    # mrow, prefer #op, except for whitelisted exception cases (which ones??)
      $op = ($current_op_meaning eq 'multirelation') ? $current_op_meaning : '#op'; }
    if ($op) {    # Set the meaning, if we found a satisfying $op:
      $meaning = "$op(" . join(",", map { '#' . $_ } (1 .. $arg_count)) . ")"; }
    else {        # if there is no op, we should undo argument annotations pointing at the application,
      for my $arg_node (p_element_nodes($node)) {
        if ((p_getAttribute($arg_node, '_a11y') || '') ne 'ref') {
          p_removeAttribute($arg_node, 'data-arg'); } } } }

  # if we found some meaning, attach it as an accessible attribute
  p_setAttribute($node, 'data-semantic', $meaning) if $meaning;

  # Part II: Bottom-up. Also check if argument of higher parent notation, mark if so.
  # II.1 id-carrying nodes always point to their referrees.
  if ($dual_pres_node && (my $id = $currentnode->getAttribute('xml:id'))) {
    # We already found the dual
    my $dual_content_node = $dual_pres_node->previousSibling;
    my @content_args = getQName($dual_content_node) eq 'ltx:XMApp' ? element_nodes($dual_content_node) : ($dual_content_node);
    my $arg_count = scalar(@content_args);
    # if no compound-apply, no need for top-level dual annotation, leave it to the descendants
    my $index = 0;
    while (my $c_arg = shift @content_args) {
      if ($id eq ($c_arg->getAttribute('idref') || '')) {
        p_setAttribute($node, '_a11y', 'ref');    # mark as used in ref
        $arg = $index || ($arg_count >= 2 ? 'op' : '1');
        last;
      } else {    # note that if we never find the 'idref', arg is never set
        $index++; } } }
  # II.2. applications children are directly pointing to their parents
  #   also fallback in the dual case, if the XMApp had an id but wasn't an arg
  if (!$arg && (getQName($currentnode->parentNode) eq 'ltx:XMApp')) {
    my $index        = 0;
    my $prev_sibling = $currentnode;
    while ($prev_sibling = $prev_sibling->previousSibling) {
      $index++; }
    $arg = $index ? $index : 'op'; }
  p_setAttribute($node, 'data-arg', $arg) if $arg;
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
