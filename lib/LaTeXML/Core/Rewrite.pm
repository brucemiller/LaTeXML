# /=====================================================================\ #
# |  LaTeXML::Core::Rewrite                                             | #
# | Rewrite Rules that modify the Constructed Document                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Rewrite;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Common::XML;

sub new {
  my ($class, $mode, @specs) = @_;
  my @clauses = ();
  while (@specs) {
    my ($op, $pattern) = (shift(@specs), shift(@specs));
    push(@clauses, ['uncompiled', $op, $pattern]); }
  return bless {
    mode => $mode, math => ($mode eq 'math'), clauses => [@clauses], labels => {}
  }, $class; }

sub clauses {
  my ($self) = @_;
  return @{ $$self{clauses} }; }

DebuggableFeature('rewrite', 'Debug rewritting operations (LaTeXML::Core::Rewrite)');

sub rewrite {
  my ($self, $document, $node) = @_;
  foreach my $node ($document->findnodes('//*[@labels]')) {
    my $labels = $node->getAttribute('labels');
    if (my $id = $node->getAttribute('xml:id')) {
      foreach my $label (split(/ /, $labels)) {
        $$self{labels}{$label} = $id; } }
    else {
      Error('malformed', 'label', $node, "Node has labels but no xml:id"); } }
  Debug(('=' x 40)) if $LaTeXML::DEBUG{rewrite};
  $self->applyClause($document, $node, 0, $self->clauses);
  return; }

sub getLabelID {
  my ($self, $label) = @_;
  if (my $id = $$self{labels}{ LaTeXML::Package::CleanLabel($label) }) {
    return $id; }
  else {
    Error('misdefined', '<rewrite>', undef, "No id for label $label in Rewrite");
    return; } }

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
  my ($self, $document, $tree, $nmatched, $clause, @more_clauses) = @_;
  if (!$clause) {
    markSeen($tree, $nmatched);
    return; }
  return unless $clause;
  if ($$clause[0] eq 'uncompiled') {
    $self->compileClause($document, $clause); }
  my ($ignore, $op, $pattern) = @$clause;
  if ($op eq 'trace') {
    local $LaTeXML::DEBUG{rewrite} = 1;
    $self->applyClause($document, $tree, $nmatched, @more_clauses); }
  elsif ($op eq 'ignore') {
    $self->applyClause($document, $tree, $nmatched, @more_clauses); }
  elsif ($op eq 'select') {
    my ($xpath, $nnodes, @wilds) = @$pattern;
    my @matches = $document->findnodes($xpath, $tree);
    Debug("Rewrite selecting \"$xpath\" => " . scalar(@matches) . " matches")
      if $LaTeXML::DEBUG{rewrite};
    foreach my $node (@matches) {
      next unless $node->ownerDocument->isSameNode($tree->ownerDocument); # If still attached to original document!
      next if $node->getAttribute('_matched');
      my @w = markWildcards($node, @wilds);
      $self->applyClause($document, $node, $nnodes, @more_clauses);
      unmarkWildcards($node, @w); } }
  elsif ($op eq 'multi_select') {
    foreach my $subpattern (@$pattern) {
      my ($xpath, $nnodes, @wilds) = @$subpattern;
      my @matches = $document->findnodes($xpath, $tree);
      Debug("Rewrite selecting \"$xpath\" => " . scalar(@matches) . " matches")
        if $LaTeXML::DEBUG{rewrite};
      foreach my $node (@matches) {
        next unless $node->ownerDocument->isSameNode($tree->ownerDocument); # If still attached to original document!
        my @w = markWildcards($node, @wilds);
        $self->applyClause($document, $node, $nnodes, @more_clauses);
        unmarkWildcards($node, @w); } } }
  elsif ($op eq 'test') {
    my $nnodes = &$pattern($document, $tree);
    Debug("Rewrite test at " . $tree->toString . ": " . ($nnodes ? $nnodes . " to replace" : "failed"))
      if $LaTeXML::DEBUG{rewrite};
    $self->applyClause($document, $tree, $nnodes, @more_clauses) if $nnodes; }
  elsif ($op eq 'replace') {
    Debug("Rewrite replace at " . $tree->toString . " using $pattern")
      if $LaTeXML::DEBUG{rewrite};
    my $parent = $tree->parentNode;
    # Remove & separate nodes to be replaced, and sibling nodes following them.
    my @following = ();    # Collect the matching and following nodes
    while (my $sib = $parent->lastChild) {
      $parent->removeChild($sib);
      unshift(@following, $sib);
      last if $tree->isSameNode($sib); }
    my @replaced = map { shift(@following) } 1 .. $nmatched;    # Remove the nodes to be replaced
    map { $document->unRecordNodeIDs($_) } @replaced;
    # Carry out the operation, inserting whatever nodes.
    $document->setNode($parent);
    my $point = $parent->lastChild;
    &$pattern($document, @replaced);                            # Carry out the insertion.

    # Now collect the newly inserted nodes for any needed patching
    my @inserted = ();                                          # Collect the newly added nodes.
    if ($point) {
      my @sibs = $parent->childNodes;
      while (my $sib = pop(@sibs)) {
        last if $$sib == $$point;
        unshift(@inserted, $sib); } }
    else {
      @inserted = $parent->childNodes; }

    # Now make any adjustments to the new nodes
    map { $document->recordNodeIDs($_) } @inserted;
    my $font = $document->getNodeFont($tree);   # the font of the matched node
    foreach my $ins (@inserted) {               # Copy the non-semantic parts of font to the replacement
      $document->mergeNodeFontRec($ins => $font); }
    # Now, replace the following nodes.
    map { $parent->appendChild($_) } @following; }
  elsif ($op eq 'action') {
    Debug("Rewrite action at " . $tree->toString . " using $pattern")
      if $LaTeXML::DEBUG{rewrite};
    &$pattern($tree); }
  elsif ($op eq 'attributes') {
    my @nodes = ();
    my $n     = $tree;
    for (my $i = 0 ; $n && ($i < $nmatched) ; $i++) {
      push(@nodes, $n);
      $n = $n->nextSibling; }
    if ($tree->hasAttribute('_has_wildcards')) {
      setAttributes_wild($document, $pattern, @nodes); }
    else {
      setAttributes_encapsulate($document, $pattern, @nodes); }

    Debug("Rewrite attributes (deep $nmatched) " . join(',', sort keys %$pattern) . " for " . Stringify($tree))
      if $LaTeXML::DEBUG{rewrite};
    $self->applyClause($document, $tree, $nmatched, @more_clauses); }
  elsif ($op eq 'regexp') {
    my @matches = $document->findnodes('descendant-or-self::text()', $tree);
    Debug("Rewrite regexp => " . scalar(@matches) . " matches")
      if $LaTeXML::DEBUG{rewrite};
    foreach my $text (@matches) {
      my $string = $text->textContent;
      if (&$pattern($string)) {
        $text->setData($string); } } }
  else {
    Error('misdefined', '<rewrite>', undef, "Unknown directive '$op' in Compiled Rewrite spec"); }
  return; }

# Set attributes for an encapsulated tree (ie. a decorated symbol as symbol itself)
sub setAttributes_encapsulate {
  my ($document, $attributes, @nodes) = @_;
  return unless grep { !$_->getAttribute('_matched'); } @nodes;
  my $node = $nodes[0];
  if (!$$attributes{_nowrap} && (scalar(@nodes) > 1)) {
    $node = $document->wrapNodes('ltx:XMWrap', @nodes); }
  map { $node->setAttribute($_, $$attributes{$_}) } keys %$attributes;    #}
  return; }

# Set attributes for a subtree w/wildcards
# Presumably only on tokens which are not in the wildcard?
sub setAttributes_wild {
  my ($document, $attributes, @nodes) = @_;
  my $node = $nodes[0];
  return unless grep { !$_->getAttribute('_matched'); } @nodes;
  if ($$attributes{_nowrap}    # No wrapping requested, or already is an XMDual
    || ((scalar(@nodes) == 1) && ($document->getNodeQName($nodes[0]) eq 'ltx:XMDual'))) {
    my ($nonwild) = grep { !$_->getAttribute('_wildcard'); } @nodes;
    if ($nonwild) {
      map { $nonwild->setAttribute($_ => $$attributes{$_}); } keys %$attributes; } }
  else {
    # Do this slightly clunky, in order to keep the SAME xml @nodes in the result
    my $wrapper = $document->wrapNodes('ltx:XMWrap', @nodes);
    my @wildids = set_wildcard_ids($document, $wrapper);
    $node = $document->wrapNodes('ltx:XMDual', $wrapper);
    $node->setAttribute(role => $$attributes{role}) if defined $$attributes{role};
    $node->removeChild($wrapper);
    my $app = $document->openElementAt($node, 'ltx:XMApp');
    my $op  = $document->openElementAt($app, 'ltx:XMTok',
      map { ($_ eq 'role' ? () : ($_ => $$attributes{$_})); } keys %$attributes);
    foreach my $rid (@wildids) {
      $document->openElementAt($app, 'ltx:XMRef', idref => $rid); }
    $node->appendChild($wrapper); }
  return; }

sub set_wildcard_ids {
  my ($document, $node) = @_;
  if (($node->nodeType != XML_ELEMENT_NODE)
    || $node->getAttribute('_matched')) {
    return (); }
  elsif ($node->hasAttribute('_wildcard')) {
    my $id = $node->getAttribute('xml:id');
    if (!$id) {
      LaTeXML::Package::GenerateID($document, $node, undef, '');
      $id = $node->getAttribute('xml:id'); }
    return ($id); }
  else {
    return map { set_wildcard_ids($document, $_); } $node->childNodes; } }

sub markSeen {
  my ($node, $nsibs) = @_;
  for (my $i = 0 ; $node && ($i < $nsibs) ; $i++) {
    markSeen_rec($node);
    $node = $node->nextSibling; }
  return; }

sub markSeen_rec {
  my ($node) = @_;
  return if $node->getAttribute('_wildcard');    # Not even children?
  $node->setAttribute('_matched' => 1);
  foreach my $child ($node->childNodes) {
    if ($child->nodeType == XML_ELEMENT_NODE) {
      markSeen_rec($child); } }
  return; }

sub markWildcards {
  my ($node, @wilds) = @_;
  $node->setAttribute(_has_wildcards => 1) if @wilds;
  my @n = ();
  foreach my $wild (@wilds) {
    my $n     = $node;
    my $start = 1;
    foreach my $i (@$wild) {
      last unless $n;
      $n     = ($start ? nth_sibling($n, $i) : nth_child($n, $i));
      $start = 0; }
    if ($n && ($n->nodeType == XML_ELEMENT_NODE)) {
      $n->setAttribute('_wildcard' => 1);
      push(@n, $n); } }
  return @n; }

sub unmarkWildcards {
  my (@nodes) = @_;
  foreach my $n (@nodes) {
    if ($n && ($n->nodeType == XML_ELEMENT_NODE)) {
      $n->removeAttribute('_has_wildcards');
      $n->removeAttribute('_wildcard'); } }
  return; }

sub nth_sibling {
  my ($node, $n) = @_;
  my $nn = $node;
  while ($nn && ($n > 1)) { $nn = $nn->nextSibling; $n--; }
  return $nn; }

sub nth_child {
  my ($node, $n) = @_;
  my @c = $node->childNodes;
  return $c[$n - 1]; }
#**********************************************************************
sub compileClause {
  my ($self,   $document, $clause)  = @_;
  my ($ignore, $op,       $pattern) = @$clause;
  my ($oop, $opattern) = ($op, $pattern);
  if ($op eq 'label') {
    if (ref $pattern eq 'ARRAY') {
      #      $op='multi_select'; $pattern = [map(["descendant-or-self::*[\@label='$_']",1], @$pattern)]; }

      $op = 'multi_select'; $pattern = [map { ["descendant-or-self::*[\@xml:id='$_']", 1] }
          map { $self->getLabelID($_) } @$pattern]; }
    else {
      #      $op='select'; $pattern=["descendant-or-self::*[\@label='$pattern']",1]; }}
      $op      = 'select';
      $pattern = ["descendant-or-self::*[\@xml:id='" . $self->getLabelID($pattern) . "']", 1]; } }
  elsif ($op eq 'scope') {
    $op = 'select';
    if ($pattern =~ /^label:(.*)$/) {
      #      $pattern=["descendant-or-self::*[\@label='$1']",1]; }
      $pattern = ["descendant-or-self::*[\@xml:id='" . $self->getLabelID($1) . "']", 1]; }
    elsif ($pattern =~ /^id:(.*)$/) {
      $pattern = ["descendant-or-self::*[\@xml:id='$1']", 1]; }
### Is this pattern ever used? <elementname>:<refnum> expects attribute!!!
###    elsif ($pattern =~ /^(.*):(.*)$/) {
###      $pattern = ["descendant-or-self::*[local-name()='$1' and \@refnum='$2']", 1]; }
    else {
      Error('misdefined', '<rewrite>', undef,
        "Unrecognized scope pattern in Rewrite clause: \"$pattern\"; Ignoring it.");
      $op = 'ignore'; $pattern = []; } }
  elsif ($op eq 'xpath') {
    $op = 'select'; $pattern = [$pattern, 1]; }
  elsif ($op eq 'match') {
    if (ref $pattern eq 'CODE') {
      $op = 'test'; }
    elsif (ref $pattern eq 'ARRAY') {    # Multiple patterns!
      $op      = 'multi_select';
      $pattern = [map { $self->compile_match($document, $_) } @$pattern]; }
    else {
      $op = 'select'; $pattern = $self->compile_match($document, $pattern); } }
  elsif ($op eq 'replace') {
    if (ref $pattern eq 'CODE') { }
    else {
      $pattern = $self->compile_replacement($document, $pattern); } }
  elsif ($op eq 'regexp') {
    $pattern = $self->compile_regexp($pattern); }
  Debug("Compiled clause $oop=>" . ToString($opattern) . "  ==> $op=>" . ToString($pattern))
    if $LaTeXML::DEBUG{rewrite};
  $$clause[0] = 'compiled'; $$clause[1] = $op; $$clause[2] = $pattern;
  return; }

#**********************************************************************
sub compile_match {
  my ($self, $document, $pattern) = @_;
###  if (!ref $pattern) {
###    return $self->compile_match1($document,
###      digest_rewrite(($$self{math} ? '$' . $pattern . '$' : $pattern))); }
###  els
  if ($pattern->isaBox) {
    return $self->compile_match1($document, $pattern); }
  elsif (ref $pattern) {    # Is tokens????
    return $self->compile_match1($document, digest_rewrite($pattern)); }
  else {
    Error('misdefined', '<rewrite>', undef,
      "Don't know what to do with match=>\"" . Stringify($pattern) . "\"");
    return; } }

sub compile_match1 {
  my ($self, $document, $patternbox) = @_;
  # Create a temporary document
  my $capdocument = LaTeXML::Core::Document->new($document->getModel);
  my $capture     = $capdocument->openElement('_Capture_', font => LaTeXML::Common::Font->new());
  $capdocument->absorb($patternbox);
  my @nodes = ($$self{mode} eq 'math'
    ? $capdocument->findnodes("//ltx:XMath/*", $capture)
    : $capture->childNodes);
  my $frag = $capdocument->getDocument->createDocumentFragment;
  map { $frag->appendChild($_) } @nodes;
  # Convert the captured nodes to an XPath that would match them.
  my ($xpath, $nnodes, @wilds) = domToXPath($capdocument, $frag);
  # The branches of an XMDual can contain "decorations", nodes that are ONLY visible
  # from either presentation or content, but not both.
  # [See LaTeXML::Core::Document->markXMNodeVisibility]
  # These decorations should NOT have rewrite rules applied
  $xpath .= '[@_pvis and @_cvis]' if $$self{math};

  if ($LaTeXML::DEBUG{rewrite}) {
    Debug("Converting \"" . ToString($patternbox) . "\"\n  $nnodes nodes\n  => xpath= \"$xpath\"");
    foreach my $w (@wilds) {
      Debug('with wildcard \@' . join(',', @$w)); } }
  return [$xpath, $nnodes, @wilds]; }

# Reworked to do digestion at replacement time.
sub compile_replacement {
  my ($self, $document, $pattern) = @_;

  if ((ref $pattern) && $pattern->isaBox) {
    $pattern = $pattern->getBody if $$self{math};
    return sub { $_[0]->absorb($pattern); } }
  else {
    return sub {
      my $stomach = $STATE->getStomach;
      $stomach->bgroup;
      $STATE->assignValue(font     => LaTeXML::Common::Font->new(), 'local');
      $STATE->assignValue(mathfont => LaTeXML::Common::Font->new(), 'local');
      my $box = $stomach->digest($pattern, 0);
      $stomach->egroup;
      $box = $box->getBody if $$self{math};
      $_[0]->absorb($box); }
} }

sub compile_regexp {
  my ($self, $pattern) = @_;
  my $code = "sub { \$_[0] =~ s${pattern}g; }";
  ## no critic
  my $fcn = eval $code;
  ## use critic
  Error('misdefined', '<rewrite>', undef,
    "Failed to compile regexp pattern \"$pattern\" into \"$code\": $!") if $@;
  return $fcn; }

#**********************************************************************

sub digest_rewrite {
  my ($string) = @_;
  my $stomach = $STATE->getStomach;
  $stomach->bgroup;
  $STATE->assignValue(font => LaTeXML::Common::Font->new(), 'local'); # Use empty font, so eventual insertion merges.
  $STATE->assignValue(mathfont => LaTeXML::Common::Font->new(), 'local');
  my $box = $stomach->digest($string, 0);
  $stomach->egroup;
  return $box; }

#**********************************************************************
sub domToXPath {
  my ($document, $node) = @_;
  my ($xpath, $nnodes, $nwilds, @wilds)
    = domToXPath_rec($document, $node, 'descendant-or-self', undef);
  return ($xpath, $nnodes, @wilds); }

# May need some work here;
my %EXCLUDED_MATCH_ATTRIBUTES = (scriptpos => 1, 'xml:id' => 1, fontsize => 1);    # [CONSTANT]

sub domToXPath_rec {
  my ($document, $node, $axis, $pos) = @_;
  my $type = (ref $node eq 'XML::LibXML::NodeList' ? 999 : $node->nodeType);
  if (($type == 999) || ($type == XML_DOCUMENT_FRAG_NODE)) {
    my @nodes = ($type == 999 ? $node->get_nodelist() : $node->childNodes);
    my ($xpath, $nnodes, @wilds) = domToXPath_seq($document, $axis, $pos, @nodes);
    return ($xpath, $nnodes, 0, @wilds); }
  elsif ($type == XML_ELEMENT_NODE) {
    my $qname      = $document->getNodeQName($node);
    my @children   = $node->childNodes;
    my @predicates = ();
    my @wilds      = ();
    if ($qname eq '_WildCard_') {
      my $tomatch = $node->childNodes;    # or all children!
      if ($tomatch) {
        my ($xpath, $nnodes, $nwilds, @wilds) = domToXPath_rec($document, $tomatch, $axis, $pos);
        my $n = (scalar(@children) || 1);
        return ($xpath, $n, $n); }
      else {
        return ($axis . '::*', 1, 1); } }
    # Also, an XMRef pointing to a wildcard is a wildcard!
    # (or pointing to an XMArg|XMWrap of a wildcard!)
    elsif ($qname eq 'ltx:XMRef') {
      my $id = $node->getAttribute('idref');
      my $r  = $id && $document->lookupID($id);
      my $rq = $r  && $document->getNodeQName($r);    # eq '_WildCard_')
      if ($rq && ($rq =~ /ltx:(?:XMArg|XMWrap)$/)) {
        my @rc = $r->childNodes;
        if ((scalar(@rc) == 1)) {
          $r  = $r->firstChild;
          $rq = $document->getNodeQName($r); } }
      if ($rq && ($rq eq '_WildCard_')) {
        return ($axis . '::*', 1, 1); } }
    # Also treat XMArg or XMWrap with single wildcard child as a wildcard (w/o children)
    elsif (($qname =~ /ltx:(?:XMArg|XMWrap)$/)
      && (scalar(@children) == 1) && ($document->getNodeQName($children[0]) eq '_WildCard_')) {
      my $tomatch = $children[0]->childNodes;
      if ($tomatch) {
        my ($xpath, $nnodes, $nwilds, @wilds) = domToXPath_rec($document, $tomatch, 'child', 1);
        return ($axis . '::' . $qname . '[' .
            join(' and ', ($pos ? ('position()=' . $pos) : undef), $xpath) . ']',
          1, 1); }
      else {
        return ($axis . '::*', 1, 1); } }
    # Order the predicates so as to put most quickly restrictive first.
    if ($node->hasAttributes) {
      foreach my $attribute (grep { $_->nodeType == XML_ATTRIBUTE_NODE } $node->attributes) {
        my $key = $attribute->nodeName;
        next if ($key =~ /^_/) || $EXCLUDED_MATCH_ATTRIBUTES{$key};
        push(@predicates, "\@" . $key . "='" . $attribute->getValue . "'"); } }
    if (@children) {
      if (!grep { $_->nodeType != XML_TEXT_NODE } @children) {    # All are text nodes:
        push(@predicates, "text()=" . quoteXPathLiteral($node->textContent)); }
      elsif (!grep { $_->nodeType != XML_ELEMENT_NODE } @children) {
        my ($xp, $n, @w) = domToXPath_seq($document, 'child', 1, @children);
        push(@predicates, $xp);
        push(@wilds,      @w); }
      else {
        Fatal('misdefined', '<rewrite>', $node,
          "Can't generate XPath for mixed content"); } }
    if ($document->canHaveAttribute($qname, 'font')) {
      if (my $font = $node->getAttribute('_font')) {
        my $pred = LaTeXML::Common::Font::font_match_xpaths($font);
        push(@predicates, $pred); } }

    if ($pos) {
      unshift(@predicates, 'self::' . $qname);
      $qname = '*';
      unshift(@predicates, 'position()=' . $pos); }
    my $preds = join(' and ', grep { $_ } @predicates);
    return ($axis . '::' . $qname . ($preds ? "[" . $preds . "]" : ''), 1, 0, @wilds);
  }

  elsif ($type == XML_TEXT_NODE) {
    return ("*[text()=" . quoteXPathLiteral($node->textContent) . "]", 1, 0); } }

# Return quoted string, but note: XPath doesn't provide sensible way to slashify ' or "
sub quoteXPathLiteral {
  my ($string) = @_;
  if    ($string !~ /'/) { return "'" . $string . "'"; }
  elsif ($string !~ /"/) { return '"' . $string . '"'; }
  else { return 'concat(' . join(',"\'",', map { "'" . $_ . "'"; } split(/'/, $string)) . ')'; } }

sub domToXPath_seq {
  my ($document, $axis, $pos, @nodes) = @_;
  my $i         = 1;
  my @sibxpaths = ();
  my @wilds     = ();
  my ($xpath, $n, $nwilds, @w0) = domToXPath_rec($document, shift(@nodes), $axis, $pos);
  if ($nwilds) {
    for (my $j = 0 ; $j < $nwilds ; $j++) {
      push(@wilds, [$i]); $i++; } }
  else {
    push(@wilds, (map { [1, @$_]; } @w0));
    $i++; }
  foreach my $sib (@nodes) {
    my ($xp, $nn, $nw, @w) = domToXPath_rec($document, $sib, 'following-sibling', $i - 1);
    push(@sibxpaths, $xp);
    if ($nw) {
      for (my $j = 0 ; $j < $nw ; $j++) {
        push(@wilds, [$i]); $i++; } }
    else {
      push(@wilds, (map { [$i, @$_]; } @w));
      $i++; } }
  return ($xpath . (scalar(@sibxpaths) ? join('', map { '[' . $_ . ']'; } @sibxpaths) : ''),
    $i - 1, @wilds); }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Rewrite> - rewrite rules for modifying the XML document.

=head1 DESCRIPTION

C<LaTeXML::Core::Rewrite> implements rewrite rules for modifying the XML document.
See L<LaTeXML::Package> for declarations which create the rewrite rules.
Further documentation needed.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
