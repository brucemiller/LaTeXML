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
use LaTeXML::BibTeX::Bibliography;
use LaTeXML::BibTeX::Runtime;
use LaTeXML::BibTeX::Runtime::Buffer;
use LaTeXML::BibTeX::Runtime::Utils;

use Time::HiRes qw(time);

use Module::Load;

# options: searchpaths
sub new {
  my ($class, %options) = @_;
  return bless {%options}, $class; }

#======================================================================
# given an appropriate context, emulate what BibTeX does and produce a bbl string
# returns a pair ($buffer, $runtime)
sub emulateBibTeX {
  my ($self, $doc, $style, $files, $cites) = @_;
  my $program = $style->getProgram;
##  my ($reader, $bibpath, @bibreaders);
  my @bibs;
  # create a reader for each bib file
  # NOTE: Don't really need new bibliography objects each time, do we????
  # (even separate from question of "evaluating" them?)
  foreach my $bibfile (@$files) {
    # find the bibfile, or error out and try the next one
    my $bibpath = pathname_find($bibfile, paths => $$self{searchpaths}, types => ['bib'])
      || pathname_kpsewhich("$bibfile.bib");
    if (!defined($bibpath)) {
      Error('missing_file', $bibfile, undef, "Can't find Bibliography file $bibfile");
      next; }
    # open the bibfile, or cause a fatal error
    my $bib = LaTeXML::BibTeX::Bibliography->new($bibfile, $bibpath);
    if (!defined($bib)) {
      Fatal('missing_file', $bibfile, undef, "Unable to open Bibliography file $bibpath");
      return; }
    push(@bibs, $bib); }
  # create a string to write things into
  my $bblbuffer = "";
  open(my $ofh, '>', \$bblbuffer);
##  binmode($ofh, ":utf8");
  #======================================================================
  # prepare the code to be run
  my $macro    = 'lxBibitemFrom';                                          # huh?
  my $btbuffer = LaTeXML::BibTeX::Runtime::Buffer->new($ofh, 0, $macro);
  # Create a configuration that optionally wraps things inside a macro
  my $runtime = LaTeXML::BibTeX::Runtime->new(undef, $btbuffer, [@bibs], [@$cites]);
  #======================================================================
  # and run the code
  my $stage = "Running BibTeX";
  ProgressSpinup($stage);
  my $ok = 0;
  eval {
    $runtime->initContext;
    $runtime->run($program);
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
