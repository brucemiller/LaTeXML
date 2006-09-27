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
use Time::HiRes;

sub new {
  my($class,%options)=@_;
  my $self = bless {%options}, $class; 
  $$self{verbosity} = 0 unless defined $$self{verbosity};
  $self; }

sub getNamespace            { $_[0]->{namespace} || "http://dlmf.nist.gov/LaTeXML"; }

#======================================================================
# abstract:
# sub process($doc) => $doc,...


sub ProcessChain {
  my($doc,@postprocessors)=@_;
  my @docs = ($doc);
  foreach my $processor (@postprocessors){
    my $t0 = [Time::HiRes::gettimeofday];
    @docs = map($processor->process($_),@docs);
    my $elapsed = Time::HiRes::tv_interval($t0,[Time::HiRes::gettimeofday]);
    $processor->Progress(sprintf(" %.2f sec",$elapsed));
  }
  @docs; }

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

#**********************************************************************


#**********************************************************************
package LaTeXML::Post::Document;
use strict;
use XML::LibXML;
use XML::LibXML::XPathContext;
use LaTeXML::Util::Pathname;
use DB_File;

our $NSURI = "http://dlmf.nist.gov/LaTeXML";
our $XPATH = XML::LibXML::XPathContext->new();
$XPATH->registerNs(ltx=>$NSURI);

sub new {
  my($class,$xmldoc,%options)=@_;
  my %data = ();
  if(ref $class){		# Cloning!
    map($data{$_}=$$class{$_}, keys %$class);
    $class = ref $class; }
  map($data{$_}=$options{$_}, keys %options);
  if((defined $data{destination}) && (!defined $data{destinationDirectory})){
    my($vol,$dir,$name)=File::Spec->splitpath($data{destination});
    $data{destinationDirectory} = $dir || '.'; }
  $data{document}=$xmldoc;
  $data{idcache} = undef;
  $data{namespaces}={ltx=>$NSURI} unless $data{namespaces};
  bless {%data}, $class; }

sub newFromFile {
  my($class,$source,%options)=@_;
  if(!$options{sourceDirectory}){
    my($vol,$dir,$name) = File::Spec->splitpath($source);
    $options{sourceDirectory} = $dir || '.'; }
  $class->new(createParser(%options)->parse_file($source),
	      %options); }

sub newFromString {
  my($class,$string,%options)=@_;
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  $class->new(createParser(%options)->parse_string($string),
	      %options); }

sub newFromSTDIN {
  my($class,%options)=@_;
  my $string;
  { local $/ = undef; $string = <>; }
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  $class->new(createParser(%options)->parse_string($string),
	      %options); }

sub newFromNode {
  my($class,$node,%options)=@_;
  my $doc = $class->new_document($node);
  $class->new($doc,%options); }

sub createParser {
  my(%options)=@_;
  # Read in the XML, unless it already is a Doc.
  my $XMLParser = XML::LibXML->new();
  if($options{validate}){ # First, load the LaTeXML catalog in case it's needed...
    map(XML::LibXML->load_catalog($_),
	pathname_find('catalog',installation_subdir=>'dtd'));
    $XMLParser->load_ext_dtd(1);  # DO load dtd.
    $XMLParser->validation(1); }
  else {
    $XMLParser->load_ext_dtd(0);
    $XMLParser->validation(0); }
  $XMLParser->keep_blanks(0);	# This allows formatting the output.
  $XMLParser; }


sub getDocument             { $_[0]->{document}; }
sub getDocumentElement      { $_[0]->{document}->documentElement; }
sub getSourceDirectory      { $_[0]->{sourceDirectory} || '.'; }
sub getDestination          { $_[0]->{destination}; }
sub getURL                  { $_[0]->{url}; }
sub getDestinationDirectory { $_[0]->{destinationDirectory}; }
sub toString                { $_[0]->{document}->toString(1); }

sub getDestinationExtension {
  my($self)=@_;
  ($$self{destination} =~ /\.([^\.\/]*)$/ ? $1 : undef); }

sub findnodes {
  my($self,$path,$node)=@_;
  $XPATH->findnodes($path,$node || $$self{document}); }

# Similar but returns only 1st node
sub findnode {
  my($self,$path,$node)=@_;
  my($first)=$XPATH->findnodes($path,$node || $$self{document});
  $first; }

sub addNamespace{
  my($self,$nsuri,$prefix)=@_;
  $$self{namespaces}{$prefix}=$nsuri;
  $self->getDocumentElement->setNamespace($nsuri,$prefix,0); }

#======================================================================
# Add nodes to $node in the document $self.
# This takes a convenient recursive reprsentation for xml:
# data = string |  [$tagname, {attr=>value,..}, @children...]
# The $tagname should have a namespace prefix whose URI has been
# registered with addNamespace.

sub addNodes {
  my($self,$node,@data)=@_;
  foreach my $child (@data){
    if(ref $child eq 'ARRAY'){
      my($tag,$attributes,@children)=@$child;
      my($prefix,$localname)= $tag =~ /^(.*):(.*)$/;
      my $nsuri = $$self{namespaces}{$prefix};
      warn "No namespace on $tag" unless $nsuri;
      my $new = $node->addNewChild($nsuri,$localname);
      $node->appendChild($new);
      if($attributes){
	foreach my $key (keys %$attributes){
	  $new->setAttribute($key, $$attributes{$key}) if defined $$attributes{$key}; }}
      $self->addNodes($new,@children); }
    elsif((ref $child) =~ /^XML::LibXML::/){
      my $type = $child->nodeType;
      if($type == XML_ELEMENT_NODE){
	my $newnode = $node->addNewChild($child->namespaceURI,$child->localname);
	copy_attributes($newnode,$child);
	$self->addNodes($newnode,$child->childNodes); }
      elsif($type == XML_DOCUMENT_FRAG_NODE){
	$self->addNodes($node,$child->childNodes); }
      elsif($type == XML_TEXT_NODE){
	$node->appendTextNode($child->textContent); }
    }
    elsif(ref $child){
      warn "Dont know how to add $child to $node; ignoring"; }
    elsif(defined $child){
      $node->appendTextNode($child); }}}

sub new_document {
  my($self,$root)=@_;
  my $doc = XML::LibXML::Document->new("1.0","UTF-8");
  my($public_id,$system_id);
  if(my $dtd = $$self{document}->internalSubset){
    if($dtd->toString
       =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')([^\2]*)\2\s+(\"|\')([^\4]*)\4>$/){
      ($public_id,$system_id)=($3,$5); }}
  if(ref $root eq 'ARRAY'){
    my($tag,$attributes,@children)=@$root;
    my($prefix,$localname)= $tag =~ /^(.*):(.*)$/;
    $doc->createInternalSubset($localname,$public_id,$system_id) if $public_id;
    my $nsuri = $$self{namespaces}{$prefix};
    my $node = $doc->createElementNS($nsuri,$localname);
    $doc->setDocumentElement($node);
    map( $node->setAttribute($_=>$$attributes{$_}),keys %$attributes) if $attributes;
    $self->addNodes($node,@children); }
  elsif(ref $root eq 'XML::LibXML::Element'){
    my $localname = $root->localname;
    $doc->createInternalSubset($localname,$public_id,$system_id) if $public_id;
    my $node = $doc->createElementNS($root->namespaceURI,$localname);
    $doc->setDocumentElement($node);
    copy_attributes($node,$root);
    $self->addNodes($node,$root->childNodes); }
  else {
    die "Dont know how to use $root as document element"; }
# With some trepidation, I'm leaving this off.
# All the xml utilities on the web end give problems finding a way to install
# a catalog for the DTD's!!!
#  $doc->createInternalSubset($doc->documentElement->nodeName,$PUBLICID,$SYSTEMID);
  $doc; }

sub copy_attributes {
  my($newnode,$oldnode)=@_;
  foreach my $child ($oldnode->attributes){
    my $type = $child->nodeType;
    if($type == XML_ATTRIBUTE_NODE){
      if(my $ns = $child->namespaceURI){
	$newnode->setAttributeNS($ns,$child->localname,$child->getValue); }
      else {
	$newnode->setAttribute($child->localname,$child->getValue); }}
    elsif($type == XML_NAMESPACE_DECL){}
    else {
      warn "Dont know how to add $child to $newnode; ignoring"; }}}

#======================================================================
# Support for ID's

sub findNodeByID {
  my($self,$id)=@_;
  if(!$$self{idcache}){
    $$self{idcache}={};
    foreach my $node ($self->findnodes("//*[\@id]")){
      $$self{idcache}{$node->getAttribute('id')} = $node; }}
  $$self{idcache}{$id}; }

sub realizeXMNode {
  my($self,$node)=@_;
  (($node->localname eq 'XMRef') && ($node->getNamespaceURI eq $NSURI)
   ? $node=$self->findNodeByID($node->getAttribute('idref'))
   : $node); }

#======================================================================
# adjust_latexml_doctype($doc,"Foo","Bar") =>
# <!DOCTYPE document PUBLIC "-//NIST LaTeXML//LaTeXML article + Foo + Bar"
#                 "http://dlmf.nist.gov/LaTeXML/LaTeXML-Foo-Bar.dtd">
sub adjust_latexml_doctype {
  my($self,@additions)=@_;
  my $doc = $$self{document};
  if(my $dtd = $doc->internalSubset){
    if($dtd->toString
       =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')-\/\/NIST LaTeXML\/\/LaTeXML\s+([^\"]*)\2\s+(\"|\')([^\"]*)\4>$/){
      my($root,$parts,$system)=($1,$3,$5);
      my($type,@addns)=split(/ \+ /,$parts);
      my %addns = ();
      map($addns{$_}=1,@addns,@additions);
      @addns = sort keys %addns;
      my $publicid = join(' + ',"-//NIST LaTeXML//LaTeXML $type",@addns);
      my $systemid = join('-',"http://dlmf.nist.gov/LaTeXML/LaTeXML",@addns).".dtd";
      $doc->removeInternalSubset;	# Apparently we've got to remove it first.
      $doc->createInternalSubset($root,$publicid,$systemid); }}}

#======================================================================
# Cache support: storage of data from previous run.
# ?

# cacheFile as parameter ????

sub cacheLookup {
  my($self,$key)=@_;
  $self->openCache;
  $$self{cache}{$key}; }

sub cacheStore {
  my($self,$key,$value)=@_;
  $self->openCache;
  $$self{cache}{$key} = $value; }

sub openCache {
  my($self)=@_;
  if(!$$self{cache}){
    $$self{cache}={};
    my $dbfile = pathname_make(dir=>$self->getDestinationDirectory,
			       name=>'LaTeXML', type=>'cache');
    tie %{$$self{cache}}, 'DB_File', $dbfile,  O_RDWR|O_CREAT
      or return $self->Error("Couldn't create DB cache for ".$self->getSource.": $!");
  }}

sub closeCache {
  my($self)=@_;
  if($$self{cache}){
      untie %{$$self{cache}};
      $$self{cache}=undef; }}

1;

__END__

=head1 LaTeXML::Post

LaTeXML::Post is the driver for various postprocessing operations.
It has a complicated set of options that I'll document shortly.

=cut
#**********************************************************************

