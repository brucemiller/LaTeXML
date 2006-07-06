# /=====================================================================\ #
# |  LaTeXML::Post                                                      | #
# | PostProcessing driver                                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post;
use strict;
use XML::LibXML;
use File::Spec;

#**********************************************************************
sub new {
  my($class)=@_;
  bless { },$class; }

sub process {
  my($self,$doc,%options)=@_;

  $options{namespaceURI} = "http://dlmf.nist.gov/LaTeXML";

  foreach my $processor (@{$options{processors}}){
    $processor->init(%options); 
    local $LaTeXML::Post::PROCESSOR = $processor;
    local $LaTeXML::Post::DOCUMENT = $doc;
    $doc = $processor->process($doc); 
    $processor->closeCache;		# If opened.
  }

  # Normalize namespaces.
  $doc = normalizeNS($doc) unless ($options{format}||'') eq 'html';
  $doc; }

sub createParser {
    my($self,%options)=@_;
    # Read in the XML, unless it already is a Doc.
    my $XMLParser = XML::LibXML->new();
    if($options{validate}){ # First, load the LaTeXML catalog in case it's needed...
	foreach my $dir (@INC){	# Load catalog (all, 1st only ???)
	    next unless -f "$dir/LaTeXML/dtd/catalog";
	    XML::LibXML->load_catalog("$dir/LaTeXML/dtd/catalog");
	    last; }
	$XMLParser->load_ext_dtd(1);  # DO load dtd.
	$XMLParser->validation(1); }
    else {
	$XMLParser->load_ext_dtd(0);
	$XMLParser->validation(0); }
    $XMLParser->keep_blanks(0);	# This allows formatting the output.
    $XMLParser; }


sub readDocument {
  my($self,$source,%options)=@_;
  my $parser = $self->createParser(%options);
  $parser->parse_file($source); }

sub readDocumentFromString {
  my($self,$string,%options)=@_;
  my $parser = $self->createParser(%options);
  $parser->parse_string($string); }

# Should these also be "postprocessors" ?
sub toString {
  my($self,$doc,$format)=@_;
  (($format||'xml') eq 'html' ? $doc->toStringHTML : $doc->toString(1)); }

sub writeDocument {
  my($self,$doc,$destination,$format)=@_;
  my $string = $self->toString($doc,$format);
  open(OUT,">:utf8",$destination) or return die("Couldn't write $destination: $!");
  print OUT $string;
  close(OUT); }

# Returns a new document with namespaces normalized.
# Should ultimately be incorporated in libxml2
# (and of course, done correctly), and bound in XML::LibXML
sub normalizeNS {
  my($doc)=@_;
return $doc;
  my $XMLParser = XML::LibXML->new();
  # KLUDGE: The only namespace cleanup available right now
  # in libxml2 is during parsing!! So, we write to string & reparse!
  # (C14N is a bit too extreme for our purposes)
  # Obviously inefficent (but amazingly fast!)
  $XMLParser->clean_namespaces(1);
  $XMLParser->parse_string($doc->toString);
}

# adjust_latexml_doctype($doc,"Foo","Bar") =>
# <!DOCTYPE document PUBLIC "-//NIST LaTeXML//LaTeXML article + Foo + Bar"
#                 "http://dlmf.nist.gov/LaTeXML/LaTeXML-Foo-Bar.dtd">
sub adjust_latexml_doctype {
  my($self,$doc,@additions)=@_;
  if(my $dtd = $doc->internalSubset){
    if($dtd->toString =~/^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')([^\"]*)\2\s+(\"|\')([^\"]*)\4>$/){
      my($root,$public,$system)=($1,$3,$5);
      if($public =~ m|^-//NIST LaTeXML|){
	my $publicid = join(' + ',"-//NIST LaTeXML//LaTeXML article",@additions);
	my $systemid = join('-',"http://dlmf.nist.gov/LaTeXML/LaTeXML",@additions).".dtd";
	$doc->removeInternalSubset;	# Apparently we've got to remove it first.
	$doc->createInternalSubset($root,$publicid,$systemid); }}}}

#**********************************************************************
package LaTeXML::Post::Processor;
use strict;
use LaTeXML::Util::Pathname;
use DB_File;

sub new {
  my($class,%options)=@_;
  bless {%options}, $class; }

sub init {
  my($self,%options)=@_;
  $self->closeCache;
  $$self{options}              = {%options};
  $$self{verbosity}            = $options{verbosity} || 0;
  $$self{format}               = $options{format} || 'xml';
  $$self{sourceDirectory}      = $options{sourceDirectory};
  $$self{destinationDirectory} = $options{destinationDirectory};
  $$self{searchPaths}          = $options{searchPaths} || [$$self{sourceDirectory}];
}

sub getSourceDirectory      { $_[0]->{sourceDirectory}; }
sub getDestinationDirectory { $_[0]->{destinationDirectory}; }
sub getSearchPaths          { $_[0]->{searchPaths}; }
sub getNamespace            { $_[0]->{namespace} || "http://dlmf.nist.gov/LaTeXML"; }

sub getOption { $_[0]->{options}->{$_[1]}; }

#======================================================================
sub Error {
  my($self,$msg)=@_;
  die "".(ref $self)." Error: $msg"; }

sub Warn {
  my($self,$msg)=@_;
  warn "".(ref $self)." Warning: $msg" if $$self{verbosity}>-1; }

sub Progress {
  my($self,$msg)=@_;
  print STDERR "".(ref $self).": $msg\n" if $$self{verbosity}>0; }

sub ProgressDetailed {
  my($self,$msg)=@_;
  print STDERR "".(ref $self).": $msg\n" if $$self{verbosity}>1; }

#======================================================================
# I/O support
sub addSearchPath {
  my($self,$path)=@_;
  $path = pathname_absolute($path,$$self{sourceDirectory})
    unless pathname_is_absolute($path);
  push(@{$$self{searchPaths}}, $path); }

# Find a file in, or relative to, the source directory or any additional search paths.
sub findFile {
  my($self,$name,$types)=@_;
  pathname_find($name,paths=>$$self{searchPaths},types=>$types); }

# Copy a source file, presumably relative to the source document's directory,
# to a corresponding sub-directory in the destination directory.
# Return the path to the copy, relative to the destination.
sub copyFile {
  my($self,$source)=@_;
  my ($reldir,$name,$type) = pathname_split(pathname_relative($source,$$self{sourceDirectory}));
  my $destdir = pathname_concat($$self{destinationDirectory},$reldir);
  pathname_mkdir($destdir) 
    or return $self->Error("Could not create relative directory $destdir: $!");
  my $dest = pathname_make(dir=>$destdir,name=>$name,type=>$type);
  pathname_copy($source, $dest) or warn("Couldn't copy $source to $dest: $!");
  pathname_make(dir=>$reldir,name=>$name,type=>$type); }

#======================================================================
# Support for ID's

# NOTE: This needs to be worked on.
#  If you use xml:id, the ID spec (supported by libxml2, at least partly)
# will allow xpath id('$id') to quickly look it up, even w/o loading the DTD.
# HOWEVER, if you change the node the id is on, it isn't recognized by libxml!!!
# Currently (probably) the only place we'd need that is in MathParse, which
# soon will be moved to latexml, proper, so afterwards, probably xpath's id() 
# will be sufficient.

our $nsXML = "http://www.w3.org/XML/1998/namespace";

sub cacheIDs {
  my($self,$doc)=@_;
  $$self{idcache}={};
  foreach my $node ($doc->findnodes("//*[\@id]")){
#    $$self{idcache}{$node->getAttributeNS($nsXML,'id')} = $node; }}
    $$self{idcache}{$node->getAttribute('id')} = $node; }}

sub updateID {
  my($self,$node)=@_;
#  $$self{idcache}{$node->getAttributeNS($nsXML,'id')} = $node; }
  $$self{idcache}{$node->getAttribute('id')} = $node; }

sub findNodeByID {
  my($self,$doc,$id)=@_;

##  my $cnode =   $$self{idcache}{$id};
##  my ($idnode) = $doc->findnodes("id('$id')");
##print STDERR "ID=$id cached => ".($cnode ? $cnode->toString : "not found")."\n id() =>".($idnode ? $idnode->toString : "not found")."\n";


#  [$doc->findnodes("//*[\@id='$id']")]->[0]; }
  $$self{idcache}{$id}; 
#  my($node)=$doc->findnodes("id('$id')");
#  $node; }
}

sub realizeXMNode {
  my($self,$doc,$node)=@_;
  ($node->nodeName eq 'XMRef' 
   ? $node=$self->findNodeByID($doc,$node->getAttribute('idref'))
   : $node); }

#======================================================================
# Cache support: storage of data from previous run.
# ?

sub cacheLookup {
  my($self,$key)=@_;
  $self->openCache;
  my $skey = (ref $self).":".$key;
  $$self{cache}{$skey}; }

sub cacheStore {
  my($self,$key,$value)=@_;
  $self->openCache;
  my $skey = (ref $self).":".$key;
  $$self{cache}{$skey} = $value; }

sub openCache {
  my($self)=@_;
  if(!$$self{cache}){
    $$self{cache}={};
    my $dbfile = pathname_make(dir=>$self->getDestinationDirectory, name=>'LaTeXML', type=>'cache');
    tie %{$$self{cache}}, 'DB_File', $dbfile,  O_RDWR|O_CREAT
      or return $self->Error("Couldn't create DB cache for ".$self->getSource.": $!");
  }}

sub closeCache {
  my($self)=@_;
  if($$self{cache}){
      untie %{$$self{cache}};
      $$self{cache}=undef; }}

#**********************************************************************
1;

__END__

=head1 LaTeXML::Post

LaTeXML::Post is the driver for various postprocessing operations.
It has a complicated set of options that I'll document shortly.

=cut
#**********************************************************************

