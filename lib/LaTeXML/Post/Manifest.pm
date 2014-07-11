# /=====================================================================\ #
# |  LaTeXML::Post::Manifest                                            | #
# | Abstract clsas for Manifest creation                                | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::Manifest;
use strict;
use warnings;

use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

# Options:
#   format: which specification we're creating a manifest for
#   siteDirectory: the directory we're analyzing
sub new {
  my ($class, %options) = @_;
  my $self;

  if ($options{format}) {
    # Abstract class constructor, we need to instantiate a specific manifest processor
    my $format = ucfirst(lc(delete $options{format}));
    local $@ = '';
    my $eval_return = eval { require "LaTeXML/Post/Manifest/$format.pm"; 1; };
    if ($eval_return && (!$@)) {
      $self = eval {
        "LaTeXML::Post::Manifest::$format"->new(%options);
      };
      if (!$self) {
        Warn('misdefined', 'Manifest', undef,
	     "Manifest post-processor '$format' could not be instanciated; Skipping", $@);
        $self = $class->SUPER::new(%options); } }
    else {
      Warn('missing', 'Manifest', undef,
	   "No Manifest post-processor found for format $format; Skipping", $@);
      $self = $class->SUPER::new(%options); } }
  else {
    # Called from a concrete manifest class
    $self                 = $class->SUPER::new(%options);
    $$self{siteDirectory} = $options{siteDirectory};
    $$self{db}            = $options{db}; }

  return $self; }

1;

