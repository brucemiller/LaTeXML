# /=====================================================================\ #
# |  LaTeXML::BibTeX                                                    | #
# | Make an bibliography from cited entries                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::BibTeX;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Common::Error;
use Encode;
use LaTeXML::BibTeX::BibStyle;
use LaTeXML::BibTeX::Bibliography;
use LaTeXML::BibTeX::Runtime;
use LaTeXML::BibTeX::Runtime::Buffer;
use LaTeXML::BibTeX::Runtime::Utils;

use Module::Load;

# options: searchpaths
sub new {
  my ($class, %options) = @_;
  return bless {%options}, $class; }

sub loadStyle {
  my ($self, $stylename) = @_;
  my $stage = "Reading bst file";
  ProgressSpinup($stage);
  $$self{style} = LaTeXML::BibTeX::BibStyle->new($stylename, $$self{searchpaths});
  ProgressSpindown($stage);
  return $$self{style}; }

sub loadBibliographies {
  my ($self, @bibfiles) = @_;
  my @bibs = ();
  foreach my $bibfile (@bibfiles) {
    my $stage = "Parsing $bibfile";
    ProgressSpinup($stage);
    # find the bibfile, or error out and try the next one
    my $bibpath = pathname_find($bibfile, paths => $$self{searchpaths}, types => ['bib'])
      || pathname_kpsewhich("$bibfile.bib");
    if (!defined($bibpath)) {
      Error('missing_file', $bibfile, undef, "Can't find Bibliography file $bibfile");
      next; }
    # open the bibfile, or cause a fatal error
    my $bib = LaTeXML::BibTeX::Bibliography->new($bibfile, $bibpath);
    return unless $bib;
    push(@bibs, $bib);
    ProgressSpindown($stage); }
  $$self{bibliographies} = [@bibs];
  return $$self{bibliographies}; }

#======================================================================
# given an appropriate context, emulate what BibTeX does and produce a bbl string
# returns a pair ($buffer, $runtime)
sub run {
  my ($self, $cites) = @_;
  # create a string to write things into
  my $bblbuffer = "";
  open(my $ofh, '>', \$bblbuffer);
##  binmode($ofh, ":utf8");
  #======================================================================
  # prepare the code to be run
  my $macro    = 'lxBibitemFrom';                                          # huh?
  my $btbuffer = LaTeXML::BibTeX::Runtime::Buffer->new($ofh, 0, $macro);
  # Create a configuration that optionally wraps things inside a macro
  my $runtime = LaTeXML::BibTeX::Runtime->new(undef, $btbuffer, $$self{bibliographies}, [@$cites]);
  #======================================================================
  # and run the code
  my $stage = "Running BibTeX";
  ProgressSpinup($stage);
  my $ok = 0;
  eval {
    $runtime->initContext;
    $runtime->run($$self{style}->getProgram);
    $ok = 1; };
  Error('bibtex', 'runtime', undef, $@) unless $ok;
  $btbuffer->finalize;
  ProgressSpindown($stage);
  return unless $ok;
  # prepend the bbl preamble
  my $bblPreamble = $self->buildBBLPreamble($runtime);
  $bblbuffer = $bblPreamble . $bblbuffer if defined($bblPreamble);
  return $bblbuffer, $runtime; }

# build the preamble
# NOTE: Hmmmmmm....
sub buildBBLPreamble {
  my ($self, $runtime) = @_;
  my $buffer  = '\makeatletter';
  my $entries = $runtime->getEntries;
  my ($field);
  foreach my $entry (@$entries) {
    # begin the hook
    $buffer .= '\expandafter\def\csname lx@bibentry@taghook@' . $entry->getKey . '\endcsname{';
    # key, bibtype
    $buffer .= '\lx@tag@intags[key]{' . $entry->getKey . '}';
    $buffer .= '\lx@tag@intags[bibtype]{' . $entry->getType . '}';
    # author
    $field = $entry->getPlainField('author');
    $buffer .= '\lx@tag@intags[authors]{' . $field . '}' if defined($field);
    # editor
    $field = $entry->getPlainField('editor');
    $buffer .= '\lx@tag@intags[editors]{' . $field . '}' if defined($field);
    # title
    $field = $entry->getPlainField('title');
    $buffer .= '\lx@tag@intags[title]{' . $field . '}' if defined($field);
    # year
    $field = $entry->getPlainField('year');
    $buffer .= '\lx@tag@intags[year]{' . $field . '}' if defined($field);
    # close the hook
    $buffer .= '}';
  }
  $buffer .= '\makeatother';
  return $buffer; }
#======================================================================
1;
