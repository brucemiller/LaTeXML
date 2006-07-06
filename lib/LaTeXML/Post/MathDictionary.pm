# /=====================================================================\ #
# |  LaTeXML::Post::MathDictionary                                      | #
# | Dictionary of Math `names' to semantic properties                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
# ================================================================================
# LaTeXML::Post::MathDictionary
#  A Mapping of math token names
# to properties such as
#     role
#     signature (?) : the grammar rules that should apply to argments when used the token is applied
#       but also/eventually type signature ?

# ================================================================================
package LaTeXML::Post::MathDictionary;
use strict;
use LaTeXML::Util::Pathname;
use LaTeXML::Post::MathPath;
use XML::LibXML;
use Exporter;
our @EXPORTER= (qw(&Declare));

# ================================================================================

our %ROLEMAP = ();

sub new {
  my($class)=@_;
  bless {map=>{%ROLEMAP}}, $class; }


# Hmm, a heirarchy of dictionaries?
#  Default dictionary is from the stuff at end.
#  document specific declarations add a layer
#  some declarations are specific to sections of the doc.

# Either we can ask for a dictionary that applies to a certain
# node, combining the relevant portions based on node ancestry,
# and constructing a `new' dictionary.
# Then we get definitions from that  specific dictionary.
#
# OR we always use the big dictionary, and ask for the meaning
# that would apply to a given $node.  Then we've got to walk up
# the ancestry, until we find a meaning.

# The latter seems time inefficent, the former space inefficient.

# In the former case, we've got to distinguish 2 kinds of object:
#  dictionary_factory and dictionary.

# Hmm...

#   Dictionary: list of hashes associating data with name.
#     go down list returning first found data 
#   DictionaryTree(?):
#    [ factory ? warehouse, aggregator, 
#     hash (on ID) of hashes (name=>meaning)
#     construct a dictionary for a given node based on ancestry.

sub getDocumentDictionary {
  my($doc,$pathname)=@_;
  
  my $dict = LaTeXML::Post::MathDictionary->new(); 
  $dict->loadDocumentDictionary($doc,$pathname);
  $dict; }

sub getNodeDictionary {
  my($self,$doc)=@_;
  $self; }

# ================================================================================
sub loadDocumentDictionary {
  my($dict,$doc,$pathname)=@_;
  my($dir,$name,$ext)=pathname_split($pathname);
  if(my $docdictpath = pathname_find($name,paths=>[$dir], types=>['dict'])){
#    print STDERR "loading dictionary: $docdictpath\n";
    local $LaTeXML::DOCUMENT = $doc;
    if(!defined(do $docdictpath)){
      warn "Failed to process dictionary $docdictpath: $!$@"; }}
}

# ================================================================================
sub Declare {
  my($pattern,%options)=@_;
  my $xpath = constructMathPath($pattern, undeclared=>0,
				label=>$options{label}, refnum=>$options{refnum}, font=>$options{font});
  my $role  = $options{role};
  my $name = $options{name};
  my $content = $options{content};
  foreach my $math ($LaTeXML::DOCUMENT->findnodes($xpath)){
    next if $math->getAttribute('role'); # Already declared
    $math->setAttribute('role',$role) if defined $role;
    $math->setAttribute('name',$name) if defined $name;
    if(defined $content){
      map($math->removeChild($_),grep($_ ->nodeType == XML_TEXT_NODE, $math->childNodes));
      $math->appendText($content); }
  }
}
# ================================================================================

# Given the name for a token, return the part_of_speech (if any)
# Typically signifies a terminal for the grammar.
sub getRole {
  my($self,$name)=@_;
  if(defined $name){
#    if(($name =~ /^(\+|\-)?(\d*)(\.(\d*))?$/) && ((length $2) || (length($4||'')))){
#      'NUMBER'; }
#    else {
      $ROLEMAP{$name}; }}
#}

# Given the name for a token, return the signature (if any)
# This is a list of the grammar rules that should apply to the
# arguments when this token is applied.
sub signature {
  my($self,$name)=@_;

}

# ================================================================================

sub DefRole {
  my($name,$role)=@_;
  $ROLEMAP{$name}=$role; }

# ================================================================================
1;
