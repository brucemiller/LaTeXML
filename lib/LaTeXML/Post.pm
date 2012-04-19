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
use Encode;
use LaTeXML::Util::Pathname;

sub new {
  my($class,%options)=@_;
  my $self = bless {%options}, $class; 
  $$self{verbosity} = 0 unless defined $$self{verbosity};
  $$self{resourceDirectory} = $options{resourceDirectory};
  $$self{resourcePrefix}    = $options{resourcePrefix};
  $self; }

sub getNamespace            { $_[0]->{namespace} || "http://dlmf.nist.gov/LaTeXML"; }

#======================================================================
# abstract:
sub process {
  my($self,$doc)=@_;
  $self->Error("This post-processor does not implement ->process(\$doc);!");
  $doc; }

#======================================================================
sub ProcessChain {
  my($doc,@postprocessors)=@_;
  my @docs = ($doc);
  foreach my $processor (@postprocessors){
    local $LaTeXML::Post::PROCESSOR = $processor;
    my $t0 = [Time::HiRes::gettimeofday];
    my @newdocs = ();
    foreach my $doc (@docs){
      local $LaTeXML::Post::DOCUMENT = $doc;
      push(@newdocs, $processor->process($doc)); }
    @docs = @newdocs;
    my $elapsed = Time::HiRes::tv_interval($t0,[Time::HiRes::gettimeofday]);
## not portable enough...
##    my $mem =  `ps -p $$ -o size=`; chomp($mem);
##    $processor->Progress($doc,sprintf(" %.2f sec; $mem KB",$elapsed));
    $processor->Progress($doc,sprintf(" %.2f sec",$elapsed));
  }
  @docs; }

#======================================================================
sub Error {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  die "".(ref $self).($dest ? "[".$dest."]" : '')." Error: $msg"; }

sub Warn {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  print STDERR "".(ref $self).($dest ? "[".$dest."]" : '').": Warning: $msg\n" if $$self{verbosity}>-1; }

sub Progress {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  print STDERR "".(ref $self).($dest ? "[".$dest."]" : '').": $msg\n" if $$self{verbosity}>0; }

sub ProgressDetailed {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  print STDERR "".(ref $self).($dest ? "[".$dest."]" : '').": $msg\n" if $$self{verbosity}>1; }

#======================================================================
# Some postprocessors will want to create a bunch of "resource"s,
# such as generated or transformed image files, or other data files.
# These should return a pathname, relative to the document's destination,
# for storing a resource associated with $node.
# Will use the Post option resourceDirectory
sub desiredResourcePathname {
  my($self,$doc,$node,$source,$type)=@_;
  undef; }

sub generateResourcePathname {
  my($self,$doc,$node,$source,$type)=@_;
  my $subdir = $$self{resourceDirectory} || '';
  my $prefix = $$self{resourcePrefix} || "x";
  my $counter = join('_', "_max",$subdir,$prefix,"counter_");
  my $n = $doc->cacheLookup($counter) || 0;
  my $name = $prefix . ++$n;
  $doc->cacheStore($counter,$n); 
  pathname_make(dir=>$subdir, name=>$name, type=>$type); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Post::MathProcessor;
use strict;
use base qw(LaTeXML::Post);
use LaTeXML::Common::XML;

# This is an abstract class; A complete MathProcessor will need to define:
#    $self->convertNode($doc,$xmath,$style)
#        to generate the converted math node
#    $self->combineParallel($doc,$math,$primary,@secondaries)
#        to combine the $primary (the result of $self's conversion of $math)
#        with the results of other math processors to create the
#        parallel markup appropriate for this processor's markup.
#    $self->getEncodingName returns a mime type to describe the markup type
#    $self->rawIDSuffix returns a short string to append to id's for nodes
#        using this markup.

# Top level processing finds and converts all math nodes.
# Invokes preprocess on each before doing the conversion in case
# analysis is needed.
sub process {
  my($self,$doc)=@_;
  if(my @maths = $self->find_math_nodes($doc)){
    $self->Progress($doc,"Converting ".scalar(@maths)." formulae");
    local $LaTeXML::Post::MATHPROCESSOR = $self;
    $self->preprocess($doc,@maths);
    if($$self{parallel}){
      foreach my $proc (@{$$self{secondary_processors}}){
	local $LaTeXML::Post::MATHPROCESSOR = $proc;
	$proc->preprocess($doc,@maths); }}
    # Re-Fetch the math nodes, in case preprocessing has messed them up.
    @maths = $self->find_math_nodes($doc);

##    foreach my $math (@maths){
    ## Do in reverse, since (in LaTeXML) we allow math nested within text within math.
    ## So, we want to converted any nested expressions first, so they get carried along
    ## with the outer ones.
    foreach my $math (reverse(@maths)){
      # If parent is MathBranch, which branch number is it?
      # (note: the MathBranch will be in a ltx:MathFork, with a ltx:Math being 1st child)
      my @preceding = $doc->findnodes("parent::ltx:MathBranch/preceding-sibling::*",$math);
      local $LaTeXML::Post::MathProcessor::FORK = scalar(@preceding);
      $self->processNode($doc,$math); }}

  # Experimentally, cross reference ??? (or clearer name?)
  if($$self{parallel}){
    # There could be various strategies when there are more than 2 parallel conversions,
    # eg a cycle or something....
    # Here, we simply take the first two processors that know how to addCrossref
    # and connect their nodes to each other.
    my ($proc1,$proc2,@ignore)
      = grep($_->can('addCrossref'),  $self,@{$$self{secondary_processors}});
    if($proc1 && $proc2){
      $proc1->addCrossrefs($doc,$proc2);
      $proc2->addCrossrefs($doc,$proc1); }}

  $doc; }

# Make THIS MathProcessor the primary branch (of whatever parallel markup it supports),
# and make all of the @moreprocessors be secondary ones.
sub setParallel {
  my($self,@moreprocessors)=@_;
  $$self{parallel}=1;
  map($$_{is_secondary}=1, @moreprocessors); # Mark the others as secondary
  $$self{secondary_processors} = [@moreprocessors]; }

sub find_math_nodes {  $_[1]->findnodes('//ltx:Math'); }

# Optional; if you want to do anything before translation
sub preprocess {
  my($self,$doc,@nodes)=@_;
}

# $self->processNode($doc,$mathnode) is the top-level conversion
# It converts the XMath within $mathnode, and adds it to the $mathnode,
# This invokes $self->convertNode($doc,$xmath,$style) to get the conversion.
sub processNode {
  my($self,$doc,$math)=@_;
  my $mode = $math->getAttribute('mode')||'inline';
  my $xmath = $doc->findnode('ltx:XMath',$math);
  return unless $xmath;		# Nothing to convert if there's no XMath ... !
  my $style = ($mode eq 'display' ? 'display' : 'text');
  local $LaTeXML::Post::MATHPROCESSOR = $self;
  my @markup=();
  if($$self{parallel}){
    # THIS should probably should
    # 1. collect the conversions,
    # 2. apply outerWrapper (when namespaces differ from primary)
    # 3. invoke combineParallel
    my $primary = $self->convertNode($doc,$xmath,$style);
    my $nsprefix = ( (ref $primary eq 'ARRAY') && ($$primary[0]=~/^(\w*):/) && $1) || 'ltx';
    my @secondaries = ();
    foreach my $proc (@{$$self{secondary_processors}}){
      local $LaTeXML::Post::MATHPROCESSOR = $proc;
      my $secondary = $proc->convertNode($doc,$xmath,$style);
      if((ref $secondary eq 'ARRAY') && ($$secondary[0]=~/^(\w*):/) && ($1 ne $nsprefix)){
	$secondary = $proc->outerWrapper($doc,$math,$secondary); }
      push(@secondaries, [$proc,$secondary]); }
    @markup = $self->combineParallel($doc,$math, $primary,@secondaries); }
  else {
    @markup = ($self->convertNode($doc,$xmath,$style)); }
  # we now REMOVE the ltx:XMath from the ltx:Math
  # (if there's an XMath PostProcessing module, it will add it back, with appropriate id's
  $doc->removeNodes($xmath);
  # Then, we add all the conversion results to ltx:Math
  $doc->addNodes($math, $self->outerWrapper($doc,$math, @markup)); }

# NOTE: Sort out how parallel & outerWrapper should work.
# It probably ought to be that if the conversion is being embedded in
# something from another namespace, it needs the wrapper.
# ie. when mixing parallel markups, NOT just at the top level, although certainly there too.
#
# This probably should be doing the m:math or om:OMA wrapper?
sub outerWrapper {
  my($self,$doc,$mathnode,@conversions)=@_;
  @conversions; }

# This should proably be from the core of the current ->processNode
# $style is either display or inline
sub convertNode {
  my($self,$doc,$node,$style)=@_;
  $self->Error("Conversion has not been defined for this MathProcessor"); }

# This should be implemented by potential Primaries
# Maybe the caller of this should check the namespaces, and call wrapper if needed?
sub combineParallel {
  my($self,$doc,$mathnode, $primary, @secondaries)=@_;
  $self->Error("Combining Parallel markup has not been defined for this MathProcessor"); }

# When converting an XMath node (with an id) to some other format,
# we will generate an id for the new node.
# This method returns a suffix to be added to the XMath id.
# The suffix comes from:
#  * When the node is in the n-th MathBranch of a MathFork, it gets ".fork<n>"
#  * When the format is not the primary format, it gets a suffix based on type (eg. ".pmml")
sub IDSuffix {
  my($self)=@_;
####  ($LaTeXML::Post::MathProcessor::FORK ? ".fork".$LaTeXML::Post::MathProcessor::FORK : '') .
     ($$self{is_secondary} ? $_[0]->rawIDSuffix : ''); }
  
sub rawIDSuffix { ''; }

# This should note the use of the given id (if any),
# and return an id for the new converted node
sub convertID {
  my($self, $id)=@_;
  if(defined $id){
    my $previous_ids = $$self{convertedIDs}{$id};
    my $suffix='';
    if($previous_ids){
      $suffix = chr(ord('a')-1+scalar(@$previous_ids)); }
    else {
      $previous_ids = []; }
    my $converted_id = $id . $LaTeXML::Post::MATHPROCESSOR->IDSuffix . $suffix;
    $$self{convertedIDs}{$id} = [@$previous_ids,$converted_id];
    $converted_id; }}

# Add backref linkages (eg. xref) onto the nodes that $self created (converted from XMath)
# to reference those that $otherprocessor created.
sub addCrossrefs {
  my($self,$doc,$otherprocessor)=@_;
  my $selfs_map = $$self{convertedIDs};
  my $others_map = $$otherprocessor{convertedIDs};
  foreach my $xid (keys %$selfs_map){ # For each XMath id that $self converted
    if(my $other_ids = $$others_map{$xid}){ # Did $other also convert those ids?
      if(my $xref_id = $other_ids && $$other_ids[0]){ # get (first) id $other created from $xid.
	foreach my $id (@{$$selfs_map{$xid}}){ # look at each node $self created from $xid
	  if(my $node=$doc->findNodeByID($id)){ # If we find a node,
	    $self->addCrossref($node,$xref_id); }}}}}} # add a crossref from it to $others's node

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

package LaTeXML::Post::Document;
use strict;
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use DB_File;
use Unicode::Normalize;

our $NSURI = "http://dlmf.nist.gov/LaTeXML";
our $XPATH = LaTeXML::Common::XML::XPath->new(ltx=>$NSURI);

# Useful options:
#   destination = the ultimate destination file for this document to be written.
#   destinationDirectory = the directory it will be stored in (derived from $destination)
#   siteDirectory = the root directory of where the entire site will be contained
#   namespaces = a hash of namespace prefix => namespace uri
#   namespaceURIs = reverse hash of above.
#   nocache = a boolean, disables storing of permanent LaTeXML.cache
#     the cache is used to remember things like image conversions from previous runs.
#   searchpaths = array of paths to search for other resources
sub new {
  my($class,$xmldoc,%options)=@_;
  my %data = ();
  if(ref $class){		# Cloning!
    map($data{$_}=$$class{$_}, keys %$class);
    $class = ref $class; }
  map($data{$_}=$options{$_}, keys %options); # These override.
  if((defined $options{destination}) && (!defined $options{destinationDirectory})){
    my($vol,$dir,$name)=File::Spec->splitpath($data{destination});
    $data{destinationDirectory} = $dir || '.'; }
  # Check consistency of siteDirectory (providing there's a destinationDirectory)
  if($data{destinationDirectory}){
    if($data{siteDirectory}){
      (bless {},$class)->Error("The destination directory ($data{destinationDirectory})"
		   ." must be within the siteDirectory ($data{siteDirectory})")
	unless pathname_is_contained($data{destinationDirectory},$data{siteDirectory}); }
    else {
      $data{siteDirectory} = $data{destinationDirectory}; }}

  $data{document}=$xmldoc;
  $data{namespaces}={ltx=>$NSURI} unless $data{namespaces};
  $data{namespaceURIs}={$NSURI=>'ltx'} unless $data{namespaceURIs};

  # Fetch any additional namespaces
  foreach my $ns ($xmldoc->documentElement->getNamespaces){
      my($prefix,$uri)=($ns->getLocalName,$ns->getData);
      if($prefix){
	  $data{namespaces}{$prefix}=$uri unless $data{namespaces}{$prefix};
	  $data{namespaceURIs}{$uri}=$prefix unless $data{namespaceURIs}{$uri}; }}

  # Extract data from latexml's ProcessingInstructions
  # I'd like to provide structured access to the PI's for those modules that need them,
  # but it isn't quite clear what that api should be.
  $data{processingInstructions}=
    [map($_->textContent,$XPATH->findnodes('.//processing-instruction("latexml")',$xmldoc))];

  # Combine specified paths with any from the PI's
  my @paths = ();
  @paths = @{$data{searchpaths}} if $data{searchpaths};
  foreach my $pi (@{$data{processingInstructions}}){
    if($pi =~ /^\s*searchpaths\s*=\s*([\"\'])(.*?)\1\s*$/){
      push(@paths,split(',',$2)); }}
  push(@paths,pathname_absolute($data{sourceDirectory})) if $data{sourceDirectory};
  $data{searchpaths} = [@paths];

  my $self = bless {%data}, $class; 
  $$self{idcache} = {};
  foreach my $node ($self->findnodes("//*[\@xml:id]")){
###print STDERR "INIT $$self{destination} ID=".$node->getAttribute('xml:id')."\n";
    $$self{idcache}{$node->getAttribute('xml:id')} = $node; }
  # Possibly disable permanent cache?
  $$self{cache} = {} if $data{nocache};
  $self; }

sub Error {
  my($self,$msg)=@_;
  die "".(ref $self)." Error: $msg"; }

sub newFromFile {
  my($class,$source,%options)=@_;
  $options{source} = $source;
  if(!$options{sourceDirectory}){
    my($vol,$dir,$name) = File::Spec->splitpath($source);
    $options{sourceDirectory} = $dir || '.'; }
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseFile($source),%options);
  $doc->validate if $$doc{validate};
  $doc; }

sub newFromString {
  my($class,$string,%options)=@_;
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseString($string),%options);
  $doc->validate if $$doc{validate};
  $doc; }

sub newFromSTDIN {
  my($class,%options)=@_;
  my $string;
  { local $/ = undef; $string = <>; }
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  my $doc = $class->new(LaTeXML::Common::XML::Parser()->parseString($string),%options);
  $doc->validate if $$doc{validate};
  $doc; }

sub getDocument             { $_[0]->{document}; }
sub getDocumentElement      { $_[0]->{document}->documentElement; }
sub getSource               { $_[0]->{source}; }
sub getSourceDirectory      { $_[0]->{sourceDirectory} || '.'; }
sub getSearchPaths          { @{$_[0]->{searchpaths}}; }
sub getDestination          { $_[0]->{destination}; }
sub getDestinationDirectory { $_[0]->{destinationDirectory}; }
sub getSiteDirectory        { $_[0]->{siteDirectory}; }

# Given an absolute pathname in the document destination directory,
# return the corresponding pathname relative to the site directory (they maybe different!).
sub siteRelativePathname {
  my($self,$pathname)=@_;
  (defined $pathname ? pathname_relative($pathname, $$self{siteDirectory}) : undef); }

sub siteRelativeDestination {
  my($self)=@_;
  (defined $$self{destination}
   ? pathname_relative($$self{destination},$$self{siteDirectory})
   : undef); }

# Given an absolute pathname to some Resource in the document source directory (eg. an image),
# return the corresponding pathname relative to the site directory(!)
# (presumably that resource file will be copied to the corresponding place in the destination.)
# The idea is that it should have the same relative path from the target file
# as it did to the source file.
# Returns undef if such a path cannot be constructed, such as when the resource
# is not contained within a directory that corresponds to the site directory.
sub siteRelativeResource {
  my($self,$pathname)=@_;
  # source file relative to the document's source
  my $relsrc = pathname_relative($pathname, $$self{sourceDirectory});
  # absolute path where that file ought to go in the destination directory.
  my $dest = pathname_absolute($relsrc,$$self{destinationDirectory});
  # Now check whether it is relative to the site, and return the relative path, if so.
  pathname_is_contained($dest,$$self{siteDirectory}); }

sub getParentDocument { $_[0]->{parentDocument}; }
sub getAncestorDocument { 
  my($self)=@_;
  my($doc,$d) = $self;
  while($d = $$doc{parentDocument}){
    $doc = $d; }
  $doc; }

sub toString {
  my($self)=@_;
  $$self{document}->toString(1); }

sub getDestinationExtension {
  my($self)=@_;
  ($$self{destination} =~ /\.([^\.\/]*)$/ ? $1 : undef); }

sub checkDestination {
  my($self,$reldest)=@_;
  my $dest = pathname_concat($self->getDestinationDirectory,$reldest);
  if(my $destdir = pathname_directory($dest)){
    pathname_mkdir($destdir)
      or return $self->Error("Could not create directory $destdir for $reldest: $!"); }
  $dest; }

#======================================================================
sub validate {
  my($self)=@_;
  # First, load the LaTeXML catalog in case it's needed...
  map(XML::LibXML->load_catalog($_),
      pathname_findall('catalog',installation_subdir=>'schema'));
  # Check for a RelaxNGSchema PI
  my $schema;
  foreach my $pi (@{$$self{processingInstructions}}){
    if($pi =~ /^\s*RelaxNGSchema\s*=\s*([\"\'])(.*?)\1\s*$/){
      $schema = $2; }}
  if($schema){			# Validate using rng
    $schema .= ".rng" unless $schema =~ /\.rng$/;
#    print STDERR "Validating using schema $schema\n";
    my $rng;
    eval { $rng = XML::LibXML::RelaxNG->new(location=>$schema); };
    if($@){			# Failed to load schema from catalog
      my $schemapath = pathname_find($schema,paths=>[$self->getSearchPaths]);
      eval { $rng = XML::LibXML::RelaxNG->new(location=>$schemapath); };
    }
    die "Failed to load RelaxNG schema $schema:\n$@" unless $rng;
    eval { $rng->validate($$self{document}); };
    if($@){
#      die "Error during RelaxNG validation  (".$schema."):\n".substr($@,0,200); }}
      die "Error during RelaxNG validation  (".$schema."):\n".$@
	."\nEither fix the source document, or use the --novalidate option\n"; }}
  elsif(my $decldtd = $$self{document}->internalSubset){ # Else look for DTD Declaration
#    print STDERR "Validating using DTD ".$decldtd->publicId." at ".$decldtd->systemId."\n";
    my $dtd = XML::LibXML::Dtd->new($decldtd->publicId,$decldtd->systemId);
    if(!$dtd){
      die "Failed to load DTD ".$decldtd->publicId." at ".$decldtd->systemId; }
    eval { $$self{document}->validate($dtd); };
    if($@){
      die "Error during DTD validation  (".$decldtd->systemId."):\n$@"
	."\nEither fix the source document, or use the --novalidate option\n"; }}
  else {			# Nothing found to validate with
    warn "No Schema or DTD found for this document";  }
}

#======================================================================
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
  if(!$$self{namespaces}{$prefix} || ($$self{namespaces}{$prefix} ne $nsuri)
    || (($self->getDocumentElement->lookupNamespacePrefix($nsuri)||'') ne $prefix)){
    $$self{namespaces}{$prefix}=$nsuri;
    $$self{namespaceURIs}{$nsuri}=$prefix;
    $XPATH->registerNS($prefix=>$nsuri);
    $self->getDocumentElement->setNamespace($nsuri,$prefix,0); }}

sub getQName {
  my($self,$node)=@_;
  my $nsuri = $node->namespaceURI;
  if(!$nsuri){			# No namespace at all???
    if($node->nodeType == XML_ELEMENT_NODE){
      $node->localname; }
    else {
      undef; }}
  elsif(my $prefix = $$self{namespaceURIs}{$nsuri}){
    $prefix.":".$node->localname; }
  else {
    warn "Missing namespace prefix for $nsuri";
    $node->localname; }}
#======================================================================
# ADD nodes to $node in the document $self.
# This takes a convenient recursive reprsentation for xml:
# data = string |  [$tagname, {attr=>value,..}, @children...]
# The $tagname should have a namespace prefix whose URI has been
# registered with addNamespace.

# Note that we're currently ignoring duplicated ids.
# these should only happen from rearrangement and copying of document fragments
# with embedded bits of math in them, which have those XMTok/XMRef pairs.
# If those are the cases, we should end up finding the original id'd item, anyway, right?
#
# NOTE that only XML::LibXML's addNewChild deals cleanly with namespaces
# and since there is only an "add" (ie. append) version (not prepend, insert after, etc)
# we have to orient everything towards appending.
# In particular, see the perversity in the following few methods.
sub addNodes {
  my($self,$node,@data)=@_;
  foreach my $child (@data){
    if(ref $child eq 'ARRAY'){
      my($tag,$attributes,@children)=@$child;
      my($prefix,$localname)= $tag =~ /^(.*):(.*)$/;
      my $nsuri = $prefix && $$self{namespaces}{$prefix};
      warn "No namespace on $tag" unless $nsuri;
      my $new = $node->addNewChild($nsuri,$localname);
      if($attributes){
	foreach my $key (keys %$attributes){
	  next unless defined $$attributes{$key};
	  my($attrprefix,$attrname)= $key =~ /^(.*):(.*)$/;
	  my $value = $$attributes{$key};
	  if($key eq 'xml:id'){	# Ignore duplicated IDs!!!
	    if(!defined $$self{idcache}{$value}){
	      $$self{idcache}{$value} = $new;
###print STDERR "REGISTER[a] $$self{destination} ID=".$value."\n";
	      $new->setAttribute($key, $value); }
	    else { print STDERR "Duplicated[a]  $$self{destination} id $value\n"; }}
	  elsif($attrprefix && ($attrprefix ne 'xml')){
	    my $attrnsuri = $attrprefix && $$self{namespaces}{$attrprefix};
	    $new->setAttributeNS($attrnsuri,$key, $$attributes{$key}); }
	  else {
	    $new->setAttribute($key, $$attributes{$key}); }}}
      $self->addNodes($new,@children); }
    elsif((ref $child) =~ /^XML::LibXML::/){
      my $type = $child->nodeType;
      if($type == XML_ELEMENT_NODE){
	my $new = $node->addNewChild($child->namespaceURI,$child->localname);
	foreach my $attr ($child->attributes){
	  my $atype = $attr->nodeType;
	  if($atype == XML_ATTRIBUTE_NODE){
	    my $key = $attr->nodeName;
	    if($key eq 'xml:id'){
	      my $value = $attr->getValue;
	      my $old;
	      if((!defined ($old=$$self{idcache}{$value})) # if xml:id is new
		 || $old->isSameNode($child)){		   # OR it's really this node...(replace)
###print STDERR "REGISTER[b] $$self{destination} ID=".$value."\n";
		$$self{idcache}{$value} = $new;
		$new->setAttribute($key, $value); }
	      else {
		print STDERR "Duplicated[b] $$self{destination} id $value\n"; }}
	    elsif(my $ns = $attr->namespaceURI){
	      $new->setAttributeNS($ns,$attr->name,$attr->getValue); }
	    else {
	      $new->setAttribute( $attr->localname,$attr->getValue); }}
	}
	$self->addNodes($new, $child->childNodes); }
      elsif($type == XML_DOCUMENT_FRAG_NODE){
	$self->addNodes($node,$child->childNodes); }
      elsif($type == XML_TEXT_NODE){
	$node->appendTextNode($child->textContent); }
    }
    elsif(ref $child){
      warn "Dont know how to add $child to $node; ignoring"; }
    elsif(defined $child){
      $node->appendTextNode($child); }}}

# Remove @nodes from the document
sub removeNodes {
  my($self,@nodes)=@_;
  foreach my $node (@nodes){
    foreach my $idd ($self->findnodes("descendant-or-self::*[\@xml:id]",$node)){
      my $id = $idd->getAttribute('xml:id');
      if($$self{idcache}{$id}){
###print STDERR "DELETE $$self{destination} ID=".$id."\n";
	delete $$self{idcache}{$id}; }}
    $node->unlinkNode; }}

# Replace $node by @replacements in the document
sub replaceNode {
  my($self,$node,@replacements)=@_;
  my ($parent,$following) = ($node->parentNode, undef);
  # Note that since we can only append new stuff, we've got to remove the following first.
  my @save=();
  while(($following = $parent->lastChild) && ($$following != $$node)){ # Remove & Save following siblings.
    unshift(@save,$parent->removeChild($following)); }
  $self->removeNodes($node);
  $self->addNodes($parent,@replacements);
  map($parent->appendChild($_),@save); } # Put these back.

# Put @nodes at the beginning of $node.
sub prependNodes {
  my($self,$node,@nodes)=@_;
  my @save=();
  # Note that since we can only append new stuff, we've got to remove the following first.
  while(my $last = $node->lastChild){ # Remove, but save, all children
    unshift(@save,$node->removeChild($last)); }
  $self->addNodes($node,@nodes);	 # Now, add the new nodes.
  map($node->appendChild($_),@save); } # Put these back.

# Clone a node, but adjusting it so that it has unique id's.
# $document->cloneNode($node) or ->cloneNode($node,$idsuffix)
# This clones the node and adjusts any xml:id's within it to be unique.
# Any idref's to those ids will be changed to the new id values.
# If $idsuffix is supplied, the ids will have that suffix appended to the ids.
# Then each $id is checked to see whether it is unique; If needed,
# one or more letters are appended, until a new id is found.
my @letters = (qw(a b c d e f g h i j k l m n o p q r s t u v w x y z));
sub cloneNode {
  my($self,$node,$idsuffix)=@_;
  return $node unless ref $node;
  my $copy = $node->cloneNode(1);
  # Find all id's defined in the copy and change the id.
  my %idmap=();
  foreach my $n ($self->findnodes('descendant-or-self::*[@xml:id]',$copy)){
    my $id = $n->getAttribute('xml:id');
    my $suffix = (defined $idsuffix ? $idsuffix : '');
    if($$self{idcache}{$id.$suffix}){ # new id already in use?
      FOUND:{
	  foreach my $l (@letters){
	    if(! $$self{idcache}{$id.$suffix.$l}){
	      $suffix .= $l; last FOUND; }}
	  foreach my $l1 (@letters){
	    foreach my $l2 (@letters){
	      if(! $$self{idcache}{$id.$suffix.$l1.$l2}){
		$suffix .= $l1.$l2; last FOUND; }}}}}
    my $newid = $id.$suffix;
    if($$self{idcache}{$newid}){ # id already in use.
      print STDERR "Exhausted id suffixes in cloneNode at id=$id\n"; }
    else {
      $idmap{$id}=$newid;
      $$self{idcache}{$newid}=$n;
      $n->setAttribute('xml:id'=>$newid);
      if(my $fragid = $n->getAttribute('fragid')){ # GACK!!
	$n->setAttribute(fragid=>$fragid.$suffix); }}}
  # Now, replace all REFERENCES to those modified ids.
  foreach my $n ($self->findnodes('descendant-or-self::*[@idref]',$copy)){
    if(my $id = $idmap{$n->getAttribute('idref')}){
      $n->setAttribute(idref=>$id); }} # use id or fragid?
  $copy; }

#======================================================================

sub newDocument {
  my($self,$root,%options)=@_;
  my $xmldoc = XML::LibXML::Document->new("1.0","UTF-8");
  my($public_id,$system_id);
  if(my $dtd = $$self{document}->internalSubset){
    if($dtd->toString
       =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')([^\2]*)\2\s+(\"|\')([^\4]*)\4>$/){
      ($public_id,$system_id)=($3,$5); }}
  my $parent_id;
  if(ref $root eq 'ARRAY'){
    my($tag,$attributes,@children)=@$root;
    my($prefix,$localname)= $tag =~ /^(.*):(.*)$/;
    $xmldoc->createInternalSubset($localname,$public_id,$system_id) if $public_id;
    my $nsuri = $$self{namespaces}{$prefix};
    my $node = $xmldoc->createElementNS($nsuri,$localname);
    $xmldoc->setDocumentElement($node);
    map( $node->setAttribute($_=>$$attributes{$_}),keys %$attributes) if $attributes;
    $self->addNodes($node,@children); }
  elsif(ref $root eq 'XML::LibXML::Element'){
    $parent_id = $self->findnode('ancestor::*[@id]',$root);
    $parent_id = $parent_id->getAttribute('id') if $parent_id;
    my $localname = $root->localname;
    $xmldoc->createInternalSubset($localname,$public_id,$system_id) if $public_id;
    # Make a copy of $root be the new element node, carefully w.r.t. namespaces.
    # Seems that only importNode (not adopt) works correctly,
    # PROVIDED we also set the namespace.
    my $node = $xmldoc->importNode($root);
    $xmldoc->setDocumentElement($node); 
    $xmldoc->documentElement->setNamespace($root->namespaceURI,$root->prefix,1); }
  else {
    die "Dont know how to use $root as document element"; }

  my $root_id = $self->getDocumentElement->getAttribute('xml:id');
  my $doc = $self->new($xmldoc,
		       ($parent_id ? (parent_id=>$parent_id) : ()),
		       ($root_id   ? (split_from_id=>$root_id) : ()),
		       %options); 

  # Copy any processing instructions.
  foreach my $pi ($self->findnodes(".//processing-instruction('latexml')")){
    $doc->getDocument->appendChild($pi->cloneNode); }
  # If new document has no date, try to add one
  $doc->addDate($self);

  # Finally, return the new document.
  $doc; }

our @MonthNames=(qw( January February March April May June
		     July August September October November December));
sub addDate {
  my($self,$fromdoc)=@_;
  if(!$self->findnodes('ltx:date',$self->getDocumentElement)){
    my @dates;
    #  $fromdoc's document has some, so copy them.
    if($fromdoc && (@dates = $fromdoc->findnodes('ltx:date',$fromdoc->getDocumentElement))){
      $self->addNodes($self->getDocumentElement,@dates); }
    else {
      my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time());
      $self->addNodes($self->getDocumentElement,
		      ['ltx:date',{role=>'creation'},
		       $MonthNames[$mon]." ".$mday.", ".(1900+$year)]); }}}

#======================================================================
# Given a list of nodes (or node constructors [tag,attr,content...])
# conjoin given a conjunction like ',' or a pair like [',', ' and ']
sub conjoin {
  my($self,$conjunction,@nodes)=@_;
  my ($comma,$and) = ($conjunction,$conjunction);
  ($comma,$and)=@$conjunction if ref $conjunction;
  my $n = scalar(@nodes);
  if($n < 2){ return @nodes; }
  else {
    my @foo=();
    push(@foo,shift(@nodes));
    while($nodes[1]){
      push(@foo, $comma,shift(@nodes)); }
    push(@foo,$and,shift(@nodes)); 
    @foo; }}

# Find the initial letter in a string, or *.
# Uses unicode decomposition to reduce accented characters to A-Z
# If $force is true, skips any non-letter initials
sub initial {
  my($self,$string,$force)=@_;
  $string = NFD($string);	# Decompose accents, etc.
  $string =~ s/^[^a-zA-Z]*// if $force;
  ($string =~/^([a-zA-Z])/ ? uc($1) : '*'); }

sub trimChildNodes {
  my($self,$node)=@_;
  if(!$node){ (); }
  elsif(!ref $node){ ($node); }
  elsif(my @children = $node->childNodes){
    if($children[0]->nodeType == XML_TEXT_NODE){
      my $s = $children[0]->data;
      $s =~ s/^\s+//;
      $children[0]->setData($s); }
    if($children[-1]->nodeType == XML_TEXT_NODE){
      my $s = $children[-1]->data;
      $s =~ s/\s+$//;
      $children[-1]->setData($s); }
    @children; }
  else { (); }}
    
#======================================================================

sub addNavigation {
  my($self,$direction,$id)=@_;
  my $ref = ['ltx:ref',{idref=>$id,class=>$direction,show=>'fulltitle'}];
  if(my $nav = $self->findnode('//ltx:navigation')){
    $self->addNodes($nav,$ref); }
  else {
    $self->addNodes($self->getDocumentElement, ['ltx:navigation',{},$ref]);}}

#======================================================================
# Support for ID's

sub recordID {
  my($self,$id,$node)=@_;
  # make an issue if already there?
###print STDERR "REGISTER $$self{destination} ID=".$id."\n";
  $$self{idcache}{$id}=$node; }

sub findNodeByID {
  my($self,$id)=@_;
  $$self{idcache}{$id}; }

sub realizeXMNode {
  my($self,$node)=@_;
  if($self->getQName($node) eq 'ltx:XMRef'){
    if(my $realnode = $self->findNodeByID($node->getAttribute('idref'))){
      $realnode; }
    else {
      $self->Error("Cannot find a node with xml:id=".$node->getAttribute('idref')); }}
  else {
    $node; }}

# Generate, add and register an xml:id for $node.
# Unless it already has an id, the created id will
# be "structured" relative to it's parent using $prefix
sub generateNodeID {
  my($self,$node,$prefix)=@_;
  my $id = $node->getAttribute('xml:id');
  return $id if $id;
  # Find the closest parent with an ID
  my ($parent,$pid,$n) = ($node->parentNode,undef,undef);
  while($parent && !( $pid = $parent->getAttribute('xml:id'))){
    $parent = $parent->parentNode; }
  # Now find the next unused id relative to the parent id, as "prefix<number>"
  $pid .= '.' if $pid;
  for($n=1;  $$self{idcache}{$id = $pid.$prefix.$n}; $n++){}
  $node->setAttribute('xml:id'=>$id);
  $$self{idcache}{$id} = $node;
  # If we've already been scanned, and have fragid's, create one here, too.
  if(my $fragid = $parent && $parent->getAttribute('fragid')){
    $node->setAttribute(fragid=>$fragid.'.'.$prefix.$n); }
  $id; }

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
  if(defined $value){
    $$self{cache}{$key} = $value; }
  else {
    delete $$self{cache}{$key}; }}

sub openCache {
  my($self)=@_;
  if(!$$self{cache}){
    $$self{cache}={};
    my $dbfile = $self->checkDestination("LaTeXML.cache");
    tie %{$$self{cache}}, 'DB_File', $dbfile,  O_RDWR|O_CREAT
      or return $self->Error("Couldn't create DB cache for ".$self->getDestination.": $!"
      .(-f $dbfile ? "\n(possibly incompatible db format?)":''));
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

