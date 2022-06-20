# -*- mode: Perl -*-
# /=====================================================================\ #
# |  lxRDFa                                                             | #
# | LaTeXML support for RDFa                                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Package::Pool;
use strict;
use warnings;
use LaTeXML::Package;

=pod

=head1 NAME

lxRDFa - RDF markup for latexml style and documents

=head1 SYNOPSIS

This package is designed for L<LaTeXML|http://dlmf.nist.gov/LaTeXML/>.
If you don't have that installed, then this package is completely useless.

This provides Resource Description Framework (RDF) markup for LaTeXML documents.

=for comment something more should be said.

=begin sty

% /=====================================================================\ %
% |  lxRDFa.sty                                                         | %
% | RDF markup for latexml documents                                    | %
% |=====================================================================| %
% | Part of LaTeXML:                                                    | %
% |  Public domain software, produced as part of work done by the       | %
% |  United States Government & not subject to copyright in the US.     | %
% |---------------------------------------------------------------------| %
% | Bruce Miller <bruce.miller@nist.gov>                        %_%     | %
% | http://dlmf.nist.gov/LaTeXML/                              (o o)    | %
% \=========================================================ooo==U==ooo=/ %
\NeedsTeXFormat{LaTeX2e}[1999/12/01]
\ProvidesPackage{latexml}[2022/06/13 v0.8.6]

=end sty

=head2 Usage

This package does literally nothing in TeX.  Everything we say here will apply
to the XML produced by LaTeXML.

The sole package option is C<labels>X<labels (package option)>.  It causes all occurrences of
C<<< \label{<I<ref>>} >>> to also call
C<< \lxRDFa{property=dcterms:alternative,content=I<ref>} >>.
We will discuss the usage of this macro momentarily.

=cut

DeclareOption('labels', sub {
    Let(T_CS('\lxRDF@original@label'),           T_CS('\label'));
    Let(T_CS('\lxRDF@original@longtable@label'), T_CS('\@longtable@label'));
    DefMacro('\label Semiverbatim', '\lxRDF@original@label{#1}\lxRDFa{property=dcterms:alternative,content=#1}');
    DefMacro('\@longtable@label Semiverbatim',
      '\lxRDF@original@longtable@label{#1}\lxRDFa{property=dcterms:alternative,content=#1}');
});
ProcessOptions();

=begin sty

\DeclareOption{labels}{}
\ProcessOptions

=end sty

C<<< \lxRDFaPrefix{<I<prefix>>}{<I<initialurl>>} >>>X<\lxRDFaPrefix (package command)>
associates a prefix with the given (partial) URI for use in RDFa Compact URI's.
These associations are global, not attached to the current node.
If prefix is empty, this defines the vocabulary(?)

=cut

DefPrimitive('\lxRDFaPrefix{}{}', sub {
    my ($stomach, $prefix, $url) = @_;
    $prefix = ToString(Expand($prefix));
    $url    = CleanURL(ToString(Expand($url)));
    if ($prefix) {
      AssignMapping('RDFa_prefixes', $prefix => $url); }
    else {
      AssignValue('RDFa_vocabulary' => $url, 'global'); }
    return; });

=begin sty

\DeclareRobustCommand{\lxRDFaPrefix}[2]{}

=end sty

=head3 Adding RDF Attributes to arbitrary LaTeXML Markup

C<<< \lxRDFa[<I<xpath>>]{<I<keywordpairs>>} >>>X<\lxRDFa (package command)>
adds any RDF attributes to a node. If xpath is given, the RDF attributes are added
to the node indicated by the xpath expression, otherwise to the current node.
You are responsible for how the attributes relate to those
in both parent and children nodes, such as establishment
of default subject or objects, chaining and so forth.

C<<< \lxRDF[<I<content>>]{<I<keyvals>>} >>>X<\lxRDF (package command)>
adds an ltx:rdf element to the document.
If content is given, it provides the content of the element,
otherwise an invisible metadata container is created.
In either case, with the given RDF attributes.
This can appear anywhere in the document, including in the preamble.

We'll start our preparations with keywords for RDF attributes.

=over 4

=item about

Establishes the subject for predicates appearing on the current
element or descendants.E<10>
about can be SafeCURIE, CURIE or IRI;E<10>
Or, if the keyword is of the form C<<< \ref{<I<label>>} >>> or C<<< #<I<id>> >>>,
it actually sets the aboutlabelref or aboutidref attribute (resp).
These will be resolved back to a IRI for about during postprocessing.
Note, however, that otherwise, the about need not be an explicit reference
to a part of the document; it can be 'virtual'.

=cut

DefKeyVal('RDFa', about => 'Semiverbatim');

=item resource

Specifies the object of the a @property on the same element,
AND specifies the subject for any predicates on descendant elements (chaining)E<10>
resource can be SafeCURIE, CURIE or IRI;E<10>
Or, if C<<< \ref{<I<label>>} >>> or C<<< #<I<id>> >>>, specifies resourcelabelref or
resourceidref attribute.

=cut

DefKeyVal('RDFa', resource => 'Semiverbatim');

=item typeof

if @resource is on the same element, it forms a new triple
indicating the type. Otherwise, it creates an anonymous resource
(blank node or bnode) with that typeE<10>
typeof can be a space separated list of: Term, CURIE or Abs. IRI

=cut

DefKeyVal('RDFa', typeof => 'Semiverbatim');    # space sep list of: Term, CURIE or Abs. IRI

=item property

specifies predicate(s) and asserts that the current subject is related to object

=over 4

=item * subject is @about on same element, or @resource/@typeof on ancestor,
or document root;

=item * object is @resource, @href, @content, @typeof on same element,
or the text content

=back

resource can be a space separated list of: Term, CURIE or Abs. IRI.

=cut

DefKeyVal('RDFa', property => 'Semiverbatim');

=item rel

Exactly the same as @property, except that

=over 4

=item * can form multiple triples,

=item * the objects being nearest @resource, @href on same or descendant

=back

rel can be a space separated list of: Term, CURIE or Abs. IRI.

=cut

DefKeyVal('RDFa', rel => 'Semiverbatim');

=item rev

Exactly the same as @rel, except that subject and object are reversed.E<10>
rev can be a space separated list of: Term, CURIE or Abs. IRI

=cut

DefKeyVal('RDFa', rev => 'Semiverbatim');

=item content

specifies the object as a plain string in place of the element's content().E<10>
content is a CDATA

=cut

DefKeyVal('RDFa', content => 'Semiverbatim');    # CDATA

=item datatype

specifies the datatype of the content/content()E<10>
datatype is a Term, CURIE or Abs. IRI

=cut

DefKeyVal('RDFa', datatype => 'Semiverbatim');   # Term, CURIE or Abs. IRI

=item href

specifies the object of a predicate.
It is similar to @resource but does not chain to indicate subject
@labelref, @idref and @href, and thus C<< <ltx:ref> >>, can thus participate
in RDFa by indicating the object of a predicate.

=item src

also indicates the object of a predicate.
@src doesn't appear directly in LaTeXML's schema,
but C<< <ltx:graphics @source> >> does, and is mapped to C<< <img src..> >> in html.
Should @source then act as an object?

=back

Decipher the RDF Keywords into a hash of RDF attributes,
accounting for C<<< \ref{<I<label>>} >>> or C<<< #<I<id>> >>> in the about and resource
keywords

=cut

sub RDFAttributes {
  my ($keyvals) = @_;
  $keyvals = $keyvals->beDigested($STATE->getStomach);
  my $hash = GetKeyVals($keyvals);
  my $x;
  foreach my $key (qw(about resource)) {
    if (my $value = $$hash{$key}) {
      if ((ref $value eq 'LaTeXML::Core::Whatsit')
        && ($value->getDefinition->getCSName eq '\ref')) {
        $$hash{ $key . 'labelref' } = CleanLabel($value->getArg(2));
        delete $$hash{$key}; }
      elsif (($x = ToString($value)) && ($x =~ /^#(.+)$/)) {
        $$hash{ $key . 'idref' } = CleanID($1);
        delete $$hash{$key}; }
      else {
        $$hash{$key} = CleanURL($value); } } }    # at least clean it.
  return $hash; }

=for comment
It ought to be wrong to put resource (or resourceXXref) attributes on an ltx:ref...
Given the RDF Keywords, and content (if any) check/complete the RDF triple.
Presumably an anonymous subject or object isn't sufficient?

=cut

sub RDFTriple {
  my ($keyvals, $content) = @_;
  my $attr = RDFAttributes($keyvals);
  if (!($$attr{about} || $$attr{aboutlabelref} || $$attr{aboutidref})) {
    $$attr{about} = ''; }    # Silently make the triple about the entire document
  if (!($$attr{property} || $$attr{rel} || $$attr{rev})) {
    Warn('expected', 'property', $keyvals,
      "Expected 'property' or 'rel' or 'rev' in RDF attributes"); }
  if (!($$attr{content} || $$attr{resource} || $$attr{resourcelabelref} || $$attr{resourceidref}
      || ($content && scalar($content->unlist)))) {
    Warn('expected', 'resource', $keyvals,
      "Expected 'resource' or 'content' in RDF attributes"); }
  return $attr; }

=for comment We can finally define the commands.

=cut

DefConstructor('\lxRDFa OptionalSemiverbatim RequiredKeyVals:RDFa', sub {
    my ($document, $xpath, $kv) = @_;
    my ($save, @nodes);
    $xpath = ToString($xpath);
    if ($xpath) {
      $save  = $document->getNode;
      @nodes = $document->findnodes(ToString($xpath), $save);
      Warn('expected', 'node', $document,
        "No node matched xpath $xpath for RDFa properties") unless scalar(@nodes); }
    else {
      $save  = $document->floatToAttribute('property');    # pic arbitrary rdf attribute
      @nodes = ($document->getElement);
      Warn('expected', 'node', $document,
        "No node matched accepts RDFa properties") unless scalar(@nodes); }
    my $attr = RDFAttributes($kv);
    foreach my $node (@nodes) {
      foreach my $k (sort keys %$attr) {
        # use direct method ($doc method doesn't skips about="", which we need!)
        $node->setAttribute($k => ToString($$attr{$k})); } }
    $document->setNode($save); });

=begin comment

This version of \lxRDF is for use in the preamble.
It is complicated because \@add@frontmatter provides us no way to
do the extra processing of the RDF Keywords.

=end comment

=cut

DefPrimitive('\lxRDF@preamble[]RequiredKeyVals:RDFa', sub {
    my ($stomach, $content, $kv) = @_;
    # Since this gets digested in the preamble...
    my $inpreamble = LookupValue('inPreamble');
    AssignValue(inPreamble => 0);
    my $attr = RDFTriple($kv);    # require complete triple, here.
    push(@{ LookupValue('frontmatter')->{'ltx:rdf'} },
      ['ltx:rdf', { map { ($_ => ToString($$attr{$_})) } keys %$attr },
        ($content ? (Digest(Tokens(T_BEGIN, $content, T_END))) : ())]);
    AssignValue(inPreamble => $inpreamble);
    return; });

=for comment This version of \lxRDF is for use in the document body.

=cut

DefConstructor('\lxRDF@body[] RequiredKeyVals:RDFa', sub {
    # "^<ltx:rdf %&RDFTriple(#2,#1)>#1</ltx:rdf>",
    my ($document, $content, $kv) = @_;
    if (my $savenode = $document->floatToElement('ltx:rdf')) {
      my $rdf = $document->openElement('ltx:rdf');
      # a bit of trouble to add empty elements!
      my $attr = RDFTriple($kv, $content);
      foreach my $k (keys %$attr) {
        # use direct method ($doc method doesn't skips about="", which we need!)
        $rdf->setAttribute($k => ToString($$attr{$k})); }
      $document->absorb($content) if $content;
      $document->closeElement('ltx:rdf');
      $document->setNode($savenode); } },
  alias => '\lxRDF');

=for comment Start with \lxRDF bound to the preamble form, which saves the rdf as frontmatter

=cut

Let('\lxRDF', '\lxRDF@preamble');

=for comment When the document's begun, switch to the inline version.

=cut

PushValue('@at@begin@document', (T_CS('\let'), T_CS('\lxRDF'), T_CS('\lxRDF@body')));

=begin sty

\DeclareRobustCommand{\lxRDFa}[2][]{}
\DeclareRobustCommand{\lxRDF}[2][]{}

=end sty

C<<< \lxRDFAnnotate{<I<keyvals>>}{<I<text>>} >>>X<\lxRDFAnnotate (package command)>
creates a visible text node with the given RDF attributes.
This node inherits whatever RDF context exists at that point,
such as the current subject, chaining or whatever.
Thus, you may want to give an explicit about.

=cut

DefConstructor('\lxRDFAnnotate RequiredKeyVals:RDFa {}',
  "<ltx:text %&RDFAttributes(#1,#2)>#2</ltx:text>");

=begin sty

\DeclareRobustCommand{\lxRDFAnnotate}[2]{#2}

=end sty

=begin comment

These aren't included in the binding.

Other shorthands might be useful, like
DefMacro('\lxRDFResource[]{}{}','\@lxRDF{about={#1},predicate={#2},resource={#3}}');
DefMacro('\lxRDFProperty[]{}{}','\@lxRDF{about={#1},predicate={#2},content={#3}}');
or maybe leave to other applications, till I get some feedback ?

Another useful thing might be the ability to attribute
the current node, the previous node, the parent node...?

=end comment

=cut

1;
