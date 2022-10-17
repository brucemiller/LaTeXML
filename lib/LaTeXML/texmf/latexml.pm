# -*- mode: Perl -*-
# /=====================================================================\ #
# |  latexml.ltxml                                                      | #
# | Style file for latexml documents                                    | #
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
no warnings 'redefine';    # ????

=pod

=head1 NAME

latexml - package commands for TeX to HTML conversion

=head1 SYNOPSIS

This package is designed for L<LaTeXML|http://dlmf.nist.gov/LaTeXML/>.
If you don't have that installed, then this package is (mostly) useless.

At the highest level, package developers should create a binding file
<I<packagename>>.sty.ltxml that implements the commands to turn TeX into the
appropriate XML.  If you aren't writing your own package but need a few
definitions, you can create <I<basefile>>.latexml (which will be
automatically loaded) or <I<preloadfile>>.ltxml
(which will be loaded when you use pass LaTeXML the option
C<< --preload=<preloadfile> >>.
See L<http://dlmf.nist.gov/LaTeXML/manual/usage/usage.conversion.html#SS0.SSS0.Px3>
for more information, and
L<http://dlmf.nist.gov/LaTeXML/manual/customization/> for what goes into these
files.

The LaTeXML package aims to avoid the previous paragraph by providing common
commands that arise when aiming for XML output.  Consequently,
most package options and commands have no actual effect in TeX, and only
in XML.  There are four broad categories of functions:

=over 4

=item * controlling various conversion options

=item * presentation customization

=item * semantic enhancement macros

=item * exposing internal functionality

=back

=begin sty

% /=====================================================================\ %
% |  latexml.sty                                                        | %
% | Style file for latexml documents                                    | %
% |=====================================================================| %
% | Part of LaTeXML:                                                    | %
% |  Public domain software, produced as part of work done by the       | %
% |  United States Government & not subject to copyright in the US.     | %
% |---------------------------------------------------------------------| %
% | Bruce Miller <bruce.miller@nist.gov>                        %_%     | %
% | http://dlmf.nist.gov/LaTeXML/                              (o o)    | %
% \=========================================================ooo==U==ooo=/ %

=end sty

=head2 Usage

The first thing we do is define the boolean C<latexml>X<latexml (package boolean)>.  This allows you to type
C<\iflatexml XML output \else PDF output\fi>X<\iflatexml (package command)>
or use the related commands with packages designed to interact with TeX booleans.

At the moment, this construction also allows you to bypass any commands that may
give LaTeXML problems.  It is the eventual goal to mostly remove this necessity.

=cut

DefConditional('\iflatexml', sub { 1; });

=for sty
\newif\iflatexml\latexmlfalse

=head3 Package Options

=over 4

=item noids(default), ids X<noids (package option)>X<ids (package option)>

assign XML ids to every element

=item noprofiling(default), profiling X<noprofiling (package option)>X<profiling (package option)>

collect some primitive profiling info

=item nomathparserspeculate(default), mathparserspeculate X<nomathparserspeculate (package opoption)> X<mathparserspeculate (package option)>

math parser speculates on possible notations

=item nocomments, comments(default) X<nocomments (package option)>X<comments (package option)>

convert TeX comments to XML comments, comments every 25th source line

=item noguesstabularheaders(default), guesstabularheaders X<noguesstabularheaders (package option)>X<guesstabularheaders (package option)>

attempt to determine the headers of a tabular environment

=item nobibtex, bibtex(default) X<nobibtex (package option)>X<bibtex (package option)>

'nobibtex' is intended to be used for arXiv-like build harnesses, where there
are explicit instructions to only use ".bbl" and that bibtex will not be run.

=item mathlexemesX<mathlexemes (package option)>

Lexeme serialization for math formulas

=for comment "If the string is longer than 40 characters", then Pod::LaTeX splits the item and bolds the second half
=for comment The first set of items are already bold, this just provides some consistency in the source

=item B<rawstyles, localrawstyles, norawstyles(default),>

B<rawclasses, localrawclasses, norawclasses(default)>X<rawstyles (package option)>X<localrawstyles (package option)>X<norawstyles (package option)>X<rawclasses (package option)>X<localrawclasses (package option)>X<norawclasses (package option)>

Finer control over which (if any) raw .sty/.cls files to include

=back

In Perl, the options are passed up the chain.  In TeX, the options do nothing.

=cut

DeclareOption('ids',                   sub { AssignValue('GENERATE_IDS'         => 1, 'global'); });
DeclareOption('noids',                 sub { AssignValue('GENERATE_IDS'         => 0, 'global'); });
DeclareOption('comments',              sub { AssignValue('INCLUDE_COMMENTS'     => 1, 'global'); });
DeclareOption('nocomments',            sub { AssignValue('INCLUDE_COMMENTS'     => 0, 'global'); });
DeclareOption('profiling',             sub { AssignValue('PROFILING'            => 1, 'global'); });
DeclareOption('noprofiling',           sub { AssignValue('PROFILING'            => 0, 'global'); });
DeclareOption('mathparserspeculate',   sub { AssignValue('MATHPARSER_SPECULATE' => 1, 'global'); });
DeclareOption('nomathparserspeculate', sub { AssignValue('MATHPARSER_SPECULATE' => 0, 'global'); });
DeclareOption('guesstabularheaders',   sub { AssignValue(GUESS_TABULAR_HEADERS  => 1, 'global'); });
DeclareOption('noguesstabularheaders', sub { AssignValue(GUESS_TABULAR_HEADERS  => 0, 'global'); });
DeclareOption('bibtex',                sub { AssignValue('NO_BIBTEX'            => 0, 'global'); });
DeclareOption('nobibtex',              sub { AssignValue('NO_BIBTEX'            => 1, 'global'); });
DeclareOption('mathlexemes',           sub { AssignValue('LEXEMATIZE_MATH'      => 1, 'global'); });
DeclareOption('rawstyles',             sub { AssignValue('INCLUDE_STYLES'       => 1, 'global'); });
DeclareOption('localrawstyles', sub { AssignValue('INCLUDE_STYLES'  => 'searchpaths', 'global'); });
DeclareOption('norawstyles',    sub { AssignValue('INCLUDE_STYLES'  => 0,             'global'); });
DeclareOption('rawclasses',     sub { AssignValue('INCLUDE_CLASSES' => 1,             'global'); });
DeclareOption('localrawclasses', sub { AssignValue('INCLUDE_CLASSES' => 'searchpaths', 'global'); });
DeclareOption('norawclasses',    sub { AssignValue('INCLUDE_CLASSES' => 0, 'global'); });

=for comment Tim doesn't know what's going on here

=cut

DefConstructor('\lx@save@parameter{}{}', sub {
    $_[0]->insertPI('latexml', ToString($_[1]) => $_[2]); });
DefKeyVal('LTXML', 'dpi', 'Number', '', code => sub {
    $STATE->assignValue(DPI => ToString($_[1]));
    AtBeginDocument(Tokens(T_CS('\lx@save@parameter'), T_OTHER('DPI'), T_BEGIN, $_[1], T_END)); });
DefKeyVal('LTXML', 'magnify', 'Number', '', code => sub {
    AtBeginDocument(Tokens(T_CS('\lx@save@parameter'), T_OTHER('magnifiy'), T_BEGIN, $_[1], T_END)); });
DefKeyVal('LTXML', 'upsample', 'Number', '', code => sub {
    AtBeginDocument(Tokens(T_CS('\lx@save@parameter'), T_OTHER('upsample'), T_BEGIN, $_[1], T_END)); });
DefKeyVal('LTXML', 'zoomout', 'Number', '', code => sub {
    AtBeginDocument(Tokens(T_CS('\lx@save@parameter'), T_OTHER('zoomout'), T_BEGIN, $_[1], T_END)); });
DefKeyVal('LTXML', 'tokenlimit', 'Number', '', code => sub {
    $LaTeXML::TOKEN_LIMIT = int(ToString($_[1]));
    return; });
DefKeyVal('LTXML', 'iflimit', 'Number', '', code => sub {
    $LaTeXML::IF_LIMIT = int(ToString($_[1]));
    return; });
DefKeyVal('LTXML', 'absorblimit', 'Number', '', code => sub {
    $LaTeXML::ABSORB_LIMIT = int(ToString($_[1]));
    return; });
DefKeyVal('LTXML', 'pushbacklimit', 'Number', '', code => sub {
    $LaTeXML::PUSHBACK_LIMIT = int(ToString($_[1]));
    return; });

ProcessOptions(inorder => 1, keysets => ['LTXML']);

=for comment TeX will ignore unknown options, so that binding can evolve more easily.

=begin sty

\DeclareOption{ids}{}
\DeclareOption{noids}{}
\DeclareOption{comments}{}
\DeclareOption{nocomments}{}
\DeclareOption{profiling}{}
\DeclareOption{noprofiling}{}
\DeclareOption{mathparserspeculate}{}
\DeclareOption{nomathparserspeculate}{}
\DeclareOption{guesstabularheaders}{}
\DeclareOption{noguesstabularheaders}{}
\DeclareOption*{\PackageWarning{latexml}{option  \CurrentOption\space ignored}}
\ProcessOptions

=end sty

=head3 URL

We provide a shorthand to present a URL with text.
The format is: C<<< \URL[<I<alternative text>>]{<I<url>>} >>>X<\URL (package command)>.  In XML, this will
become a traditional hyperlink.  In TeX, the url is made into a footnote if the
alternative text is supplied.  Note that the order of the arguments is reversed
from hyperref's C<<< \href{<I<url>>}{<I<alternative text>>} >>>.

=for comment Does this really belong here? Or should this be disableable?

=cut

DefConstructor('\URL[] Verbatim', "<ltx:ref href='#href'>?#1(#1)(#href)</ltx:ref>",
  properties => sub { (href => CleanURL($_[2])); });

=begin sty

\RequirePackage{url}
\def\URL{\@ifnextchar[{\@URL}{\@@URL}}%]
\def\@@URL{\begingroup\Url}
\def\@URL[#1]{#1\begingroup\def\UrlLeft##1\UrlRight{\footnote{\texttt{##1}}}\Url}

=end sty

=head3 Semantic Enhancment macros

We have several web related macros: C<\XML>, C<\SGML>, C<\HTML>, C<\XHTML>, C<\XSLT>, C<\CSS>,
C<\MathML>, C<\OpenMath>, and C<\LaTeXML>
X<\XML (package command)>X<\SGML (package command)>X<\HTML (package command)>
X<\XHTML (package command)>X<\XSLT (package command)>X<\CSS (package command)>
X<\MathML (package command)>X<\OpenMath (package command)>X<\LaTeXML (package command)>

In TeX, these only have a font transformation (and not even that for OpenMath).
In XML, these are given links to the authoritative resources.

LaTeXML implements its logo similar to the other web standard links.
In TeX, the logo is more complicated, because we want to mirror LaTeX.
If we left the X alone, we'd be able to do C<\LaTeX{\scshape ml}>.

=begin comment

NOTE: Figure out where this should go.
At least should define various `semantic enhancement' macros that
authors using latexml might want.
We need to be careful not to step on the toes of other packages (naming scheme),
nor assume too much about what semantics that authors might want.
NOTE: Are we stepping on toes by including these here?

=end comment

=cut

DefMacro('\XML',      '\URL[\texttt{XML}]{http://www.w3.org/XML/}');
DefMacro('\SGML',     '\URL[\texttt{HTML}]{http://www.w3.org/MarkUp/SGML/}');
DefMacro('\HTML',     '\URL[\texttt{HTML}]{http://www.w3.org/html/}');
DefMacro('\XHTML',    '\URL[\texttt{XHTML}]{http://www.w3.org/TR/xhtml11/}');
DefMacro('\XSLT',     '\URL[\texttt{XSLT}]{http://www.w3.org/Style/XSL/}');
DefMacro('\CSS',      '\URL[\texttt{CSS}]{http://www.w3.org/Style/CSS/}');
DefMacro('\MathML',   '\URL[\texttt{MathML}]{http://www.w3.org/Math/}');
DefMacro('\OpenMath', '\URL[\texttt{OpenMath}]{http://www.openmath.org/}');
#DefMacro('\BibTeX','BibTeX');

DefMacro('\LaTeXML',      '\URL[\LaTeXML@logo]{http://dlmf.nist.gov/LaTeXML/}');
DefMacro('\LaTeXML@logo', '\lx@LaTeXML@{\lx@LaTeXML@XML}');
DefConstructor('\lx@LaTeXML@{}',
  "<ltx:text class='ltx_LaTeXML_logo'>"
    . "<ltx:text cssstyle='letter-spacing:-0.2em; margin-right:0.1em'>"
    . "L"
    . "<ltx:text fontsize='70%' yoffset='2.2pt'>A</ltx:text>"
    . "T"
    . "<ltx:text yoffset='-0.4ex'>E</ltx:text></ltx:text>"
    . "#1</ltx:text>",
  sizer => sub { (Dimension('3.8em'), Dimension('1.6ex'), Dimension('0.4ex')); });
DefConstructor('\lx@LaTeXML@XML', "xml",    # "<ltx:text xoffset='-0.15em'>xml</ltx:text>",
  bounded => 1, font => { shape => 'smallcaps' });

=begin sty

\providecommand{\XML}{\textsc{xml}}%
\providecommand{\SGML}{\textsc{sgml}}%
\providecommand{\HTML}{\textsc{html}}%
\providecommand{\XHTML}{\textsc{xhtml}}%
\providecommand{\XSLT}{\textsc{xslt}}%
\providecommand{\CSS}{\textsc{css}}%
\providecommand{\MathML}{\textsc{MathML}}%
\providecommand{\OpenMath}{OpenMath}%

\DeclareRobustCommand{\LaTeXML}{L\kern-.36em%
        {\sbox\z@ T%
         \vbox to\ht\z@{\hbox{\check@mathfonts
                              \fontsize\sf@size\z@
                              \math@fontsfalse\selectfont
                              A}%
                        \vss}%
        }%
        \kern-.15em%
%        T\kern-.1667em\lower.5ex\hbox{E}\kern-.125em\relax
%        {\tt XML}}
        T\kern-.1667em\lower.4ex\hbox{E}\kern-0.05em\relax
        {\scshape xml}}%

=end sty

We define C<\LaTeXMLversion>X<\LaTeXMLversion (package command)>,  C<\LaTeXMLrevision>X<\LaTeXMLrevision (package command)>, and C<\LaTeXMLfullversion>X<\LaTeXMLfullversion (package command)> to combine those two.  We can't quite make this happen in TeX.

=for comment Maybe we could do this in TeX if we get into the weeds of Pod::Simple

=cut

DefMacro('\LaTeXMLversion',  sub { ExplodeText($LaTeXML::VERSION); });
DefMacro('\LaTeXMLrevision', sub { ExplodeText($LaTeXML::Version::REVISION); });
DefMacro('\LaTeXMLfullversion',
'\LaTeXML (\LaTeXMLversion\expandafter\ifx\expandafter.\LaTeXMLrevision.\else; rev.~\LaTeXMLrevision\fi)');

=begin sty

\providecommand{\LaTeXMLversion}{}
\providecommand{\LaTeXMLrevision}{}
\providecommand{\LaTeXMLfullversion}{\LaTeXML}

=end sty

=head3 Id Related Commands

We next define several ID related commands.  C<<< \lxDocumentID{<I<id>>} >>>X<\lxDocumentID (package command)> sets the
document ID in XML (and does nothing in TeX).
C<<< \LXMID{<I<label>>}{<I<expression>>} >>>X<\LXMID (package command)> typesets the expression, and creates a
command referring to it, so that C<<< \LXMRef{<I<label>>} >>>X<\LXMRef (package command)> will typeset it again.

=cut

DefMacro('\lxDocumentID{}', '\def\thedocument@ID{#1}');
DefMacro('\LXMID{}{}',      '\lx@xmarg{#1}{#2}');
DefMacro('\LXMRef{}',       '\lx@xmref{#1}');

=begin sty

\providecommand{\lxDocumentID}[1]{}%
\def\LXMID#1#2{\expandafter\gdef\csname xmarg#1\endcsname{#2}\csname xmarg#1\endcsname}
\def\LXMRef#1{\csname xmarg#1\endcsname}

=end sty

=head3 Class Related Features

Next come two related class commands.E<10>
C<<< \lxAddClass{<I<classname>>} >>>X<\lxAddClass (package command)> will add
the given class to the current XML structure it's inside;
nothing happens in TeX.
C<<< \lxWithClass{<I<classname>>}{<I<code>>} >>>X<\lxWithClass (package command)> will put the result of the code into a
div with the given class; TeX will just return the second argument.

=cut

Let('\lxAddClass', '\@ADDCLASS');
DefConstructor('\lxAddClass Semiverbatim', sub {
    $_[0]->addClass($_[0]->getElement, ToString($_[1])); });
DefConstructor('\lxWithClass Semiverbatim {}', sub {
    my ($document, $class, $box) = @_;
    my $context = $document->getElement;    # Where we originally start inserting.
    my @nodes   = ();
    if (isTextNode($document->getNode)) {
      push(@nodes, $document->openElement('ltx:text')); }
    push(@nodes, $document->absorb($box));
    @nodes = $document->filterChildren($document->filterDeletions(@nodes));
    $document->closeToNode($context);
    $document->addClass($nodes[0], ToString($class)) if @nodes; });

=begin sty

\providecommand{\lxAddClass}[1]{}%
\providecommand{\lxWithClass}[2]{#2}%

=end sty

We next define a simplified hyperlink.  C<<< \lxRef{<I<label>>}{<I<text>>} >>>X<\lxRef (package command)> will, in
XML, make a link pointing to that label.  In TeX, this is ignored and simply
prints the text.

=cut

DefConstructor('\lxRef Semiverbatim {}',
  "<ltx:ref labelref='#label'>#2</ltx:ref>",
  properties => sub { (label => CleanLabel($_[1])); });

=for sty
\def\lxRef#1#2{#2}

=head3 CSS and Javascript

If you want to add a script or style file, one way is to pass the appropriate option
to C<latexmlpost> using C<<< latexmlpost --javascript=<I<file>> >>> or
C<<< latexmlpost --css=<I<file>> >>>, respectively.  But if you're going to be
using the same file every time, then it is easier to add
C<<< \lxRequireResource[options]{<I<file>>} >>>X<\lxRequireResource (package command)>.
C<options> can include the type or mime-type (if LaTeXML is misidentifying it based on the suffix),
or something like C<media=(max-width:1000pt)> for a css file.

=cut

DefPrimitive('\lxRequireResource OptionalKeyVals {}', sub {
    my ($stomach, $kv, $path) = @_;
    RequireResource(ToString($path), ($kv ? $kv->getHash : ())); });

=for sty
\providecommand{\lxRequireResource}[2][]{}

=head3 lxKeywords

C<<< \lxKeywords{<I<keywords>>} >>>X<\lxKeywords (package command)> will add the keywords to the meta information of
the document.

=cut

DefMacro('\lxKeywords{}',
  '\@add@frontmatter{ltx:keywords}[name={keywords}]{#1}');

=for sty
\def\lxKeywords#1{}

=head3 Page Customization

We now define several ways to customize the output XML, none of which have an
effect in TeX.  C<\lxContextTOC>X<\lxContextTOC (package command)> will create a contextual table of contents,
focusing on the current part/chapter/section.

=cut

DefConstructor('\lxContextTOC',
  "<ltx:TOC format='context'/>");

=for sty
\def\lxContextTOC{}%

The environments C<lxNavbar>X<lxNavbar (package environment)>, C<lxHeader>X<lxHeader (package environment)>, and C<lxFooter>X<lxFooter (package environment)> should
be placed in the preamble, and typeset their contents in the corresponding part of
every page.  For example, the LaTeXML manual has

 \begin{lxNavbar}
 \lxRef{top}{\includegraphics{../graphics/latexml}}\\
 \includegraphics{../graphics/mascot}\\
 \lxContextTOC
 \end{lxNavbar}

just before C<\begin{document}>.  This creates the navigation panel
on the left hand side of every page.
In TeX, the entire environment is ignored, which the C<comment> package
allows us to easily do.

=for comment
Of course, it would be more interesting to supply a "template"
for header and footer that would show where the next link goes,
rather than predict what the next link will be! (after splitting!)
Repeated header/footers should give multiple header/footer lines ?
or do they just arrange the lines within it?

=cut

AssignValue('navigation' => [], 'global');

sub insertNavigation {
  my ($document) = @_;
  if (my @items = @{ LookupValue('navigation') }) {
    $document->appendTree($document->getDocument->documentElement,
      ['ltx:navigation', {}, @items]); }
  return; }
Tag('ltx:document', 'afterClose' => \&insertNavigation);
DefEnvironment('{lxNavbar}', sub { },
  beforeDigest    => sub { AssignValue(inPreamble => 0); },
  beforeConstruct => sub {
    my ($document, $whatsit) = @_;
    PushValue('navigation',
      ['ltx:inline-para', { class => 'ltx_page_navbar' }, $whatsit->getBody]);
    return; });
DefEnvironment('{lxHeader}', sub { },
  beforeDigest    => sub { AssignValue(inPreamble => 0); },
  beforeConstruct => sub {
    my ($document, $whatsit) = @_;
    PushValue('navigation',
      ['ltx:inline-para', { class => 'ltx_page_header' }, $whatsit->getBody]);
    return; });
DefEnvironment('{lxFooter}', sub { },
  beforeDigest    => sub { AssignValue(inPreamble => 0); },
  beforeConstruct => sub {
    my ($document, $whatsit) = @_;
    PushValue('navigation',
      ['ltx:inline-para', { class => 'ltx_page_footer' }, $whatsit->getBody]);
    return; });

=begin sty

\RequirePackage{comment}
\excludecomment{lxNavbar}
\excludecomment{lxHeader}
\excludecomment{lxFooter}

=end sty

=head3 Table Beautification

When it comes to tables, XML (especially HTML) provides more
semantics than TeX: the tags C<< <thead> >>, C<< <tfoot> >>, and C<< <th> >>
don't have corresponding counterparts in general TeX.
To remedy that, we preface the rows of the head with
C<\lxBeginTableHead>X<\lxBeginTableHead (package command)> and place C<\lxEndTableHead>X<\lxEndTableHead (package command)> after
the C<\\> at the end of the header row.
Similarly, the foot rows are surrounded with C<\lxBeginTableFoot>X<\lxBeginTableFoot (package command)> and
C<\lxEndTableFoot>X<\lxEndTableFoot (package command)>.

Mimicking C<< <th> >> depends on whether we're looking at a column header or a row
header. To mark an individual cell as a column header, add
C<\lxTableColumnHead>X<\lxTableColumnHead (package command)> to the entry.  To mark an individual cell as
a row header, add C<\lxTableRowHead>X<\lxTableRowHead (package command)>.  If you want to mark an
individual cell as both a column and row header, you can use both, although it
could be argued that that entry should be in the title or caption of the table,
and not in the table itself.

If you want to mark an entire column as row headers,
C<\usepackage{array}>
and then put in the column specification:
C<< >{\lxTableRowHead} >>.
If you want to mark an entire row as column headers, then they should be in the
C<< <thead> >> of two paragraphs ago.  Obviously, these six commands can do nothing in TeX.

=for comment
This really calls for styling, but why should we get into that game?
There are many other packages for that.

=cut

DefMacroI('\lxBeginTableHead', undef, '\@tabular@begin@heading');
DefMacroI('\lxEndTableHead',   undef, '\@tabular@end@heading');
DefMacroI('\lxBeginTableFoot', undef, '\@tabular@begin@heading');
DefMacroI('\lxEndTableFoot',   undef, '\@tabular@end@heading');
DefMacroI('\lxTableColumnHead', undef, sub {
    if (my $alignment = LookupValue('Alignment')) {
      $alignment->currentColumn->{thead}{column} = 1; }
    return; });
DefMacroI('\lxTableRowHead', undef, sub {
    if (my $alignment = LookupValue('Alignment')) {
      $alignment->currentColumn->{thead}{row} = 1; }
    return; });

=begin sty

\def\lxBeginTableHead{}
\def\lxEndTableHead{}
\def\lxBeginTableFoot{}
\def\lxEndTableFoot{}
\def\lxTableColumnHead{}
\def\lxTableRowHead{}

=end sty

=head3 Declarative information for Mathematics

LaTeXML can't always determine the type of math that a symbol should be.
Therefore, you can use C<<< \lxFcn{<I<funcname>>} >>>X<\lxFcn (package command)>, C<<< \lxID{<I<identifier>>} >>>X<\lxID (package command)>,
and C<<< \lxPunct{<I<punctuation mark>>} >>>X<\lxPunct (package command)> to denote a symbol as a function,
identifier, or punctuation, respectively.  These commands aren't needed by TeX,
so they just echo back their contents.

We also provide a more general form: eg. C<\lxTweakMath{role=POSTFIX}{@}>X<\lxTweakMath (package command)> is the
same as C<\lx@math@tweak>.

=cut

DefConstructor('\lxFcn{}', "<ltx:XMWrap role='FUNCTION'>#1</ltx:XMWrap>",
  requireMath => 1, reversion => '#1', alias => '');
DefConstructor('\lxID{}', "<ltx:XMWrap role='ID'>#1</ltx:XMWrap>",
  requireMath => 1, reversion => '#1', alias => '');
DefConstructor('\lxPunct{}', "<ltx:XMWrap role='PUNCT'>#1</ltx:XMWrap>",
  requireMath => 1, reversion => '#1', alias => '');
DefConstructor('\lxMathTweak RequiredKeyVals {}',
  "<ltx:XMWrap %&GetKeyVals(#1)>#2</ltx:XMWrap>",
  afterDigest => sub {
    my ($stomach, $whatsit) = @_;
    my ($kv,      $body)    = $whatsit->getArgs;
    $whatsit->setProperties($kv->getPairs);
    $whatsit->setFont($body->getFont);
    return; },
  reversion => '#2');

=begin sty

\providecommand{\lxFcn}[1]{#1}
\providecommand{\lxID}[1]{#1}
\providecommand{\lxPunct}[1]{#1}
\providecommand{\lxMathTweak}[2]{#2}

=end sty

=head3 lxDefMath

We define a math function such that the TeX output is what you might
expect, while providing the semantic hooks for generating useful XML.E<10>
C<<< \lxDefMath{<I<\cs>>}[<I<nargs>>][<I<optargs>>]{<I<presentation>>}[<I<declarations>>] >>>X<\lxDefMath (package command)>.E<10>
In TeX, this is equivalent to:E<10>
C<<< \providecommand{<I<\cs>>}[<I<nargs>>][<I<optargs>>]{<I<presentation>>} >>>,E<10>
throwing away the final optional arguments.  In LaTeXML, [<I<declarations>>]
is assumed to have the formE<10>
C<<< [name=<I<name>>,meaning=<I<meaning>>,role=<I<role>>,cd=<l<cd>>] >>>.E<10>
Any that are found help define the semantics of the object.

This is a prime example of where LaTeXML's syntax makes things much easier than
in TeX.  Eventually, C<\lxDefMath> becomes a C<\providecommand>.

=for comment Tim doesn't know what "cd" is in the above

=cut

DefPrimitive('\lxDefMath{}[Number][]{} OptionalKeyVals:XMath', sub {
    my ($stomach, $cs, $nargs, $opt, $presentation, $params) = @_;
    my ($name, $meaning, $cd, $role, $alias, $scope) =
      $params && map { $_ && ToString($_) } map { $params->getValue($_) }
      qw(name meaning cd role alias scope);
    my $needsid = $params && ($params->getValue('tag') || $params->getValue('description'));
    my $id      = ($needsid ? next_declaration_id() : undef);
    DefMathI($cs, convertLaTeXArgs($nargs, $opt), $presentation,
      name  => $name,  meaning => $meaning, omcd      => $cd, role => $role, alias => $alias,
      scope => $scope, decl_id => $id,      revert_as => 'context');
    if ($needsid) {    # Also provide for decl_id hook for definition links.
      return Digest(Invocation('\@lxDefMathDeclare', $id, $params)); }
    else {
      return; }
});
DefConstructor('\@lxDefMathDeclare{} RequiredKeyVals:XMath', sub {
    my ($document, $id, $kv, %props) = @_;
    my $save = $document->floatToElement('ltx:declare');
    $document->openElement('ltx:declare', 'xml:id' => $id);
    if ($props{term} || $props{short}) {
      $document->openElement('ltx:tags');
      $document->insertElement('ltx:tag', $props{term},  role => 'term')  if $props{term};
      $document->insertElement('ltx:tag', $props{short}, role => 'short') if $props{short};
      $document->closeElement('ltx:tags'); }
    if (my $description = $props{description}) {
      $document->insertElement('ltx:text', $description); }
    $document->closeElement('ltx:declare');
    $document->setNode($save); },
  mode        => 'text',
  afterDigest => sub { my ($stomach, $whatsit) = @_;
    my ($id, $kv) = $whatsit->getArgs;
    normalizeDeclareKeys($kv, $whatsit);
    return; },
  properties => { alignmentSkippable => 1 },
  reversion  => '');

=begin comment

We're interested in getting some useful phrases for several contexts:
  Notations lists:  $term$ : description
  [where layout may require substituting some markup for the :, so we'll want to split them]
  tooltips: short (name), probably text preferred.
And we want to synthesize these out of two keyvals: tag,description.
If both are given tag is shortname, description is long form, possibly separating out the term
If only 1 given, and matches the math term: record it, and use remainder for name & description
Else use the given for name, description, with no term

=end comment

=cut

sub normalizeDeclareKeys {
  my ($kv, $whatsit) = @_;
  my $tag         = $kv->getValue('tag');
  my $description = $kv->getValue('description');
  my ($term, $short, $desc);
  if (my $stuff = $description || $tag) {
    ($term, $desc) = splitDeclareTag($stuff); }
  $short = ($description ? $tag || $desc : undef);
  $desc  = $desc || $description || $tag;
  $whatsit->setProperties(term => $term, short => $short, description => $desc);
  return; }

# Temporary(?) Hack for DLMF: Split an \lxDeclare tag of the form tag={math: description}
sub splitDeclareTag {
  my ($tag) = @_;
  my @boxes = $tag->unlist;
  my @tag   = ();
  # Or should we collect initial math box?
  while (@boxes && ($boxes[0]->getString ne ':')) {
    push(@tag, shift(@boxes)); }
  if (@boxes) {
    shift(@boxes);
    return (List(@tag), List(@boxes)); }
  else {
    return; } }

=begin sty

\providecommand{\lxDefMath}{\lx@defmath}%
\def\lx@defmath#1{%
  \@ifnextchar[{\lx@defmath@a{#1}}{\lx@defmath@a{#1}[0]}}%
\def\lx@defmath@a#1[#2]{%
  \@ifnextchar[{\lx@defmath@opt{#1}[#2]}{\lx@defmath@noopt{#1}[#2]}}%
\def\lx@defmath@opt#1[#2][#3]#4{%
  \providecommand{#1}[#2][#3]{#4}%
  \@ifnextchar[{\lx@@skipopt}{}}%
\def\lx@defmath@noopt#1[#2]#3{%
  \providecommand{#1}[#2]{#3}%
  \@ifnextchar[{\lx@@skipopt}{}}%
\def\lx@@skipopt[#1]{}%

=end sty

=head3 lxDeclare, lxRefDeclaration

C<<< \lxDeclare[<I<declarations>>]{<I<match>>} >>>X<\lxDeclare (package command)> and C<<< \lxRefDeclaration{<I<label>>} >>>X<\lxRefDeclaration (package command)>
allow the following keyword options:

=over 4

=item scope=<I<scope>>

Specifies the scope of the declaration,
i.e., to what portion of the document the declarations apply.
You can specify one of the counters associated with sections, equations, et.c.
If unspecified, the declaration is scoped to the current unit.
Note that this applies to equations, as well.

=item label=<I<label>>

assigns a label to the declaration so that it can be
reused at another point in the document (with C<\lxRefDeclaration>), particularly
when that point is not otherwise within the scope of the original declaration.

=back

To effect the declaration:

=over 4

=item role=<I<role>>

Assigns a grammatical role to the matched item for parsing.

=item name=<I<name>>

Assigns a name to the matched item.

=item meaning=<I<meaning>>

Assigns a semantic name to the matched item.

=back

Alternatively, use

=over 4

=item replace

provides a replacement for the matched expression, rather than adding attributes.

=back

In TeX, C<<< \lxDeclare[<I<declarations>>]{<I<match>>} >>> and
C<<< \lxRefDeclaration{<I<label>>} >>> do nothing, throwing away their arguments.

=begin comment

Should we provide some examples?
I'm concerned about the order of applying these filters.
even though it seems right so far.

Potential keywords/operations needed(?)

=end comment

=over 4

=item nodef

inhibits the marking of the current point as the `definition'
of the expression. (a ref declaration would normally not be a def anyway)

=back

=begin comment

Could this be better documented?  Tim doesn't understand what it's doing.

It would be good to incorporate Scoping into this macro.
As defined, it obeys TeX's usual grouping scope.
However, scoping by 'module' (M.Kohlhase's approach) and/or
'document' scoping could be useful.

In module scoping, the definition is only available within a
module environment that defines it, AND in other module envs
that 'use' it.

In document scoping, the definition would only be available within
the current sectional unit.  I'm not sure the best way to achieve this 
within latex, itself, but have ideas about LaTeXML...
But, perhaps it is only the declarative aspects that are important to
LaTeXML....

=end comment

=cut

DefKeyVal('Declare', 'nowrap',  '{}', 1);
DefKeyVal('Declare', 'trace',   '{}', 1);
DefKeyVal('Declare', 'replace', 'UndigestedKey');
our $declare_keys = { scope => 1, role => 1, tag => 1, description => 1, name => 1, meaning => 1,
  trace => 1, nowrap => 1, replace => 1, label => 1 };
# Most is same as above; merge into one!!!!!
DefConstructor('\lxDeclare OptionalMatch:* OptionalKeyVals:Declare {}', sub {
    my ($document, $flag, $kv, $pattern, %props) = @_;
    if (my $id = $props{id}) {
      my $save = $document->floatToElement('ltx:declare');
      $document->openElement('ltx:declare', 'xml:id' => $id);
      if ($props{term} || $props{short}) {
        $document->openElement('ltx:tags');
        $document->insertElement('ltx:tag', $props{term},  role => 'term')  if $props{term};
        $document->insertElement('ltx:tag', $props{short}, role => 'short') if $props{short};
        $document->closeElement('ltx:tags'); }
      if (my $description = $props{description}) {
        $document->insertElement('ltx:text', $description); }
      $document->closeElement('ltx:declare');
      $document->setNode($save); } },
  mode         => 'text',
  beforeDigest => sub { reenterTextMode(); neutralizeFont(); },
  afterDigest  => sub { my ($stomach, $whatsit) = @_;
    my ($star, $kv, $pattern) = $whatsit->getArgs;
    return unless $kv;
    CheckOptions("\\lxDeclare keys", $declare_keys, %{ $kv->getKeyVals });
    foreach my $key (qw(role tag name meaning replace)) {
      if (my $value = $kv->getValue($key)) {
        Warn('unexpected', $key, $stomach,
          "Repeated $key: " . join('; ', map { Stringify($_) } @$value))
          if ref $value eq 'ARRAY'; } }
    my $id = ($kv->getValue('tag') || $kv->getValue('description') ? next_declaration_id() : undef);
    if ($id && LookupValue('InPreamble')) {
      Warn('unexpected', 'tag', $stomach,
        "Declaration with tag cannot appear in preamble"
          . Stringify($whatsit)); }
    # Temporary(?) Hack: If no description, bui tag is of form <math>: text
    # make description = tag, and tag be only the shorter text part
    $whatsit->setProperties(scope => getDeclarationScope($kv),
      role    => ToString($kv->getValue('role')),
      name    => ToString($kv->getValue('name')),
      meaning => ToString($kv->getValue('meaning')),
      trace   => defined $kv->getValue('trace'),
      nowrap  => defined $kv->getValue('nowrap'),
      id      => $id,
      match   => $pattern,
      replace => $kv->getValue('replace'));
    normalizeDeclareKeys($kv, $whatsit);
    if (my $label = ToString($kv->getValue('label'))) {
      PushValue("Declaration_$label", $whatsit); }
    return; },
  afterConstruct => sub { my ($document, $whatsit) = @_;
    my $scope = $whatsit->getProperty('scope');
    createDeclarationRewrite($document, $scope, $whatsit); },
  properties => { alignmentSkippable => 1 },
  reversion  => '');
DefConstructor('\lxRefDeclaration OptionalKeyVals:Declare {}', '',
  afterDigest => sub { my ($stomach, $whatsit) = @_;
    my ($keys, $labels) = $whatsit->getArgs;
    $whatsit->setProperties(scope => getDeclarationScope($keys),
      labels => [split(',', ToString($labels))]); },
  afterConstruct => sub { my ($document, $whatsit) = @_;
    my $scope = $whatsit->getProperty('scope');
    foreach my $label (@{ $whatsit->getProperty('labels') }) {
      if (my $declaration = LookupValue("Declaration_$label")) {
        map { createDeclarationRewrite($document, $scope, $_) } @$declaration; }
      else {
        Warn('unexpected', $label, $document,
          "No Declaration with label=$label was found"); } } },
  properties => { alignmentSkippable => 1 },
  reversion  => '');
NewCounter('@XMDECL', 'section', idprefix => 'XMD');

sub next_declaration_id {
  StepCounter('@XMDECL');
  DefMacroI(T_CS('\@@XMDECL@ID'), undef,
    Tokens(Explode(LookupValue('\c@@XMDECL')->valueOf)),
    scope => 'global');
  return ToString(Expand(T_CS('\the@XMDECL@ID'))); }

sub getDeclarationScope {
  my ($keys) = @_;
  # Sort out the scope.
  my $scope = $keys && $keys->getValue('scope');
  $scope = ($scope ? ToString($scope) : LookupValue('current_counter'));
  if ($scope && LookupValue("\\c\@$scope")) {    # Scope is some counter.
    $scope = "id:" . ToString(Digest(Expand(T_CS("\\the$scope\@ID")))); }
  return $scope; }

sub createDeclarationRewrite {
  my ($document, $scope, $whatsit) = @_;
  my %props = $whatsit->getProperties;
  my ($id, $match, $nowrap, $role, $name, $meaning, $ref, $trace, $replace)
    = map { $props{$_} } qw(id match nowrap role name meaning ref trace replace);
  # Put this rule IN FRONT of other rules!
  UnshiftValue('DOCUMENT_REWRITE_RULES',
    LaTeXML::Core::Rewrite->new('math',
      ($trace ? (trace => $trace) : ()),
      ($scope ? (scope => $scope) : ()),
      ($match ? (match => $match) : ()),
      ($replace
        ? (replace => $replace)
        : attributes => { ($role ? (role => $role) : ()),
          ($name    ? (name    => $name)    : ()),
          ($meaning ? (meaning => $meaning) : ()),
          ($id      ? (decl_id => $id)      : ()),
          ($nowrap  ? (_nowrap => $nowrap)  : ()),
        }),
    ));
  return; }

=begin sty

\newcommand{\lxDeclare}[2][]{\@bsphack\@esphack}%
\newcommand{\lxRefDeclaration}[2][]{\@bsphack\@esphack}%

=end sty

=cut

1;
