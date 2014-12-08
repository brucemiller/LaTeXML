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
use warnings;
use LaTeXML::Common::XML;
use LaTeXML::Post::MathML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::MathProcessor);
use base qw(Exporter);
our @EXPORT = (
  qw( &DefOpenMath ),
  qw( &om_expr ),
);

my $omURI      = "http://www.openmath.org/OpenMath";    # CONSTANT
my $omMimeType = 'application/openmath+xml';            # CONSTANT

sub preprocess {
  my ($self, $doc, @nodes) = @_;
  $$self{hackplane1} = 0 unless $$self{hackplane1};
  $$self{plane1} = 1 if $$self{hackplane1} || !defined $$self{plane1};
  $doc->adjust_latexml_doctype('OpenMath');             # Add OpenMath if LaTeXML dtd.
  $doc->addNamespace($omURI, 'om');
  return; }

sub outerWrapper {
  my ($self, $doc, $xmath, $om) = @_;
  my $wrapped = ['om:OMOBJ', {}, $om];
  if (my $id = $xmath->getAttribute('fragid')) {        # Associate id's, but DONT crossref
    $wrapped = $self->associateID($wrapped, $id, 1); }
  return $wrapped; }

sub convertNode {
  my ($self, $doc, $xmath) = @_;
  my ($item, @rest) = element_nodes($xmath);
  return { processor => $self,
    encoding => 'OpenMath', mimetype => $omMimeType,
    xml => (!$item || @rest ? om_unparsed($item, @rest) : om_expr($item)) }; }

sub combineParallel {
  my ($self, $doc, $xmath, $primary, @secondaries) = @_;
  my $id   = $xmath->getAttribute('fragid');
  my @attr = ();
  foreach my $secondary (@secondaries) {
    my $mimetype = $$secondary{mimetype} || 'unknown';
    if ($mimetype eq $omMimeType) {    # Another OpenMath object?
      push(@attr,
        ['om:OMS', { cd => "Alternate", name => $mimetype }],
        $$secondary{xml}); }
    elsif (my $xml = $$secondary{xml}) {    # Or some other XML object?
                                            # ORRRR should this be in other order?
      push(@attr,
        ['om:OMS', { cd => "Alternate", name => $mimetype }],
        ['om:OMFOREIGN', {}, $$secondary{processor}->outerWrapper($doc, $xmath, $xml)]); }
    # What do do with src?
##    elsif (my $src = $$secondary{src}) {         # something referred to by a file? Image, maybe?
##      push(@wsecondaries, ['m:annotation', { encoding => $mimetype, src => $src }]); }
    elsif (my $string = $$secondary{string}) {    # simple string data?
      push(@attr,
        ['om:OMS', { cd => "Alternate", name => $mimetype }],
        ['om:OMSTR', {}, $string]); }
    # anything else ignore?
  }
  # Throw in a TeX encoding, for good measure. Should be own processor?
  my $math = $xmath->parentNode;
  if (my $tex = $math && isElementNode($math) && $math->getAttribute('tex')) {
    push(@attr,
      ['om:OMS', { cd => 'Alternate', name => 'TeX' }],
      ['om:OMFOREIGN', {}, $tex]); }              # Should this simply be OMSTR ???
  return { processor => $self,
    mimetype => $omMimeType,
    xml => ['om:OMATTR', {}, @attr, $$primary{xml}] }; }

sub getQName {
  my ($node) = @_;
  return $LaTeXML::Post::DOCUMENT->getQName($node); }

sub rawIDSuffix {
  return '.om'; }

# ================================================================================

# DANGER!!! Ths accumulate all the DefMathML declarations.
# They're fixed after the module has been loaded, so are Daemon Safe,
# but probably should be going into (post) STATE, so that they are extensible.
our $OMTable = {};

sub DefOpenMath {
  my ($key, $sub) = @_;
  $$OMTable{$key} = $sub;
  return; }

sub om_expr {
  my ($node) = @_;
  # Get the real node, first.
  $node = $LaTeXML::Post::DOCUMENT->realizeXMNode($node);
  my $result = om_expr_aux($node);
  # map any ID here, as well, BUT, since we follow split/scan, use the fragid, not xml:id!
  if (my $id = $node->getAttribute('fragid')) {
    $result = $LaTeXML::Post::MATHPROCESSOR->associateID($result, $id); }
  return $result; }

# Is it clear that we should just getAttribute('role'),
# instead of the getOperatorRole like in MML?
sub om_expr_aux {
  my ($node) = @_;
  return OMError("Missing Subexpression") unless $node;
  my $tag = getQName($node);
  if (($tag eq 'ltx:XMWrap') || ($tag eq 'ltx:XMArg')) {    # Unparsed
    my ($item, @rest) = element_nodes($node);
    return (!$item || @rest ? om_unparsed($item, @rest) : om_expr($item)); }
  elsif ($tag eq 'ltx:XMDual') {
    my ($content, $presentation) = element_nodes($node);
    return om_expr($content); }
  elsif ($tag eq 'ltx:XMApp') {
    my ($op, @args) = element_nodes($node);
    return OMError("Missing Operator") unless $op;
    my $sub = lookupConverter('Apply', $op->getAttribute('role'), $op->getAttribute('meaning'));
    return &$sub($op, @args); }
  elsif ($tag eq 'ltx:XMTok') {
    my $sub = lookupConverter('Token', $node->getAttribute('role'), $node->getAttribute('meaning'));
    return &$sub($node); }
  elsif ($tag eq 'ltx:XMHint') {
    return (); }
  else {
    return ['om:OMSTR', {}, $node->textContent]; } }

sub om_unparsed {
  my (@nodes) = @_;
  if (!@nodes) {
    return ['om:OME', {},
      ['om:OMS', { name => 'unexpected', cd => 'moreerrors' }],
      ['om:OMSTR', {}, "Missing Subexpression"]]; }
  else {
    my @om = ();
    foreach my $node (@nodes) {
      $node = $LaTeXML::Post::DOCUMENT->realizeXMNode($node);
      my $tag = getQName($node);
      if ($tag eq 'ltx:XMHint') { }
      elsif (($tag eq 'ltx:XMTok') && (($node->getAttribute('role') || 'UNKNOWN') eq 'UNKNOWN')) {
        push(@om, ['om:OMS', { cd => 'unknown', name => $node->textContent }]); }
      else {
        push(@om, om_expr_aux($node)); } }
    return ['om:OME', {}, ['om:OMS', { cd => 'ambiguous', name => 'fragments' }], @om]; } }

sub lookupConverter {
  my ($mode, $role, $name) = @_;
  $name = '?' unless $name;
  $role = '?' unless $role;
  return $$OMTable{"$mode:$role:$name"} || $$OMTable{"$mode:?:$name"}
    || $$OMTable{"$mode:$role:?"} || $$OMTable{"$mode:?:?"}; }

# ================================================================================
# Helpers
sub OMError {
  my ($msg) = @_;
  return ['om:OME', {},
    ['om:OMS', { name => 'unexpected', cd => 'moreerrors' }],
    ['om:OMS', {}, $msg]]; }
# ================================================================================
# Tokens

# Note: In general, there needs to be a lot more support/analysis.
# Here, we simply assume that the token is a variable if there's no CD!!!
# See comments above about meaning.
# With the gradual refinement of meaning, in the lack of a mapping,
# we'll just presume that the cd defaults to latexml...
DefOpenMath('Token:?:?', sub {
    my ($token) = @_;
    if (my $meaning = $token->getAttribute('meaning')) {
      my $cd = $token->getAttribute('omcd') || 'latexml';
      return ['om:OMS', { name => $meaning, cd => $cd }]; }
    else {
      my ($name, %mmlattr) = LaTeXML::Post::MathML::stylizeContent($token, 1);
      if (my $mv = $mmlattr{mathvariant}) {
        $name = $mv . "-" . $name; }
      return ['om:OMV', { name => $name }]; } });

# NOTE: Presence of '.' distinguishes float from int !?!?
DefOpenMath('Token:NUMBER:?', sub {
    my ($node) = @_;
    my $value = $node->getAttribute('meaning');    # name attribute (may) holds actual value.
    $value = $node->textContent unless defined $value;
    if ($value =~ /\./) {
      return ['om:OMF', { dec => $value }]; }
    else {
      return ['om:OMI', {}, $value]; } });

DefOpenMath('Token:SUPERSCRIPTOP:?', sub {
    return ['om:OMS', { name => 'superscript', cd => 'ambiguous' }]; });
DefOpenMath('Token:SUBSCRIPTOP:?', sub {
    return ['om:OMS', { name => 'subscript', cd => 'ambiguous' }]; });

DefOpenMath("Token:?:\x{2062}", sub {
    return ['om:OMS', { name => 'times', cd => 'arith1' }]; });

# ================================================================================
# Applications.

# Generic

DefOpenMath('Apply:?:?', sub {
    my ($op, @args) = @_;
    return ['om:OMA', {}, map { om_expr($_) } $op, @args]; });

# NOTE: No support for OMATTR here...

# NOTE: Sketch of what OMBIND support might look like.
# Currently, no such construct is created in LaTeXML...
DefOpenMath('Apply:LambdaBinding:?', sub {
    my ($op, $expr, @vars) = @_;
    return ['om:OMBIND', {},
      ['om:OMS', { name => "lambda", cd => 'fns1' },
        ['om:OMBVAR', {}, map { om_expr($_) } @vars],    # Presumably, these yield OMV
        om_expr($expr)]]; });

# ================================================================================
1;
