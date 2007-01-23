# /=====================================================================\ #
# |  LaTeXML::Util::ObjectDB                                            | #
# | Database of Objects for crossreferencing, etc                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::ObjectDB;
use strict;
use LaTeXML::Util::Pathname;
use DB_File;
use Storable qw(nfreeze thaw);
use strict;
use Encode;
use Carp;
our @ISA=qw(Storable);

#======================================================================
# NOTES:
#  (1) If we can do make-like processing, when an entry is marked as
#       modified, any referrers to it also need processing.
#      (and we could defer a save if nothing was dirty)
#======================================================================
# Some Definitions:
#  * Object: places a link will take you to.  Several types
#    * chunk: any significant document object with a reference
#       number: sectional chunks, equations, ...
#    * index : the target is the entry in the index itself.
#         a back reference can take you to where the \index was invoked.
#    * bib   : the target is the entry in the bibliography.
#         a back reference can take you to the \cite.
#
#======================================================================

our @DBS=();
END {
  map($_->finish, @DBS);
}

#======================================================================
# Creating an ObjectDB object, hooking up initial database.
sub new {
  my($class, %options)=@_;
  my $dbfile = $options{dbfile};
  if($dbfile && $options{clean}){
    warn "\nWARN: Removing Object database file $dbfile!!!\n";
    unlink($dbfile); }

  my $self = bless {dbfile=>$dbfile,
		    objects=>{}, externaldb=>{},
		    verbosity => $options{verbosity}||0,
		    read_write => $options{read_write},
		   }, $class;
  if($dbfile){
##    my $flags = ($options{read_write} ? O_RDWR|O_CREAT : O_RDONLY);
    my $flags = O_RDWR|O_CREAT;
    tie %{$$self{externaldb}}, 'DB_File', $dbfile,$flags
      or die "Couldn't attach DB $dbfile for object table"; 
    $$self{opened_timestamp}=time(); }
  push(@DBS,$self);
  $self; }

sub status {
  my($self)=@_;
  my $status = scalar(keys %{$$self{objects}})." objects";
#  if($$self{dbfile}){ ...
  $status; }
    
#======================================================================
# This saves the db

sub finish {
  my($self)=@_;
  if($$self{externaldb} && $$self{dbfile}){
    my $n=0;
    my %types=();
    my $opened = $$self{opened_timestamp};
    foreach my $key (keys %{$$self{objects}}){
      my $row = $$self{objects}{$key};
      next if $$row{timestamp} < $opened;
      $n++;
      my %item = %$row;
      delete $item{key}; 		# Don't store these
      delete $item{sort_order};	# Just in case
      delete $item{sort_delta};
      #    $$row{timestamp}=$opened;
      $$self{externaldb}{Encode::encode('utf8',$key)} = nfreeze({%item}); }

    print STDERR "ObjectDB Stored $n objects (".scalar(keys %{$$self{externaldb}})." total)\n"
      if $$self{verbosity} > 0; 
    untie %{$$self{externaldb}};  }

 $$self{externaldb}=undef;
 $$self{objects}=undef;
}

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub getKeys {
  my($self)=@_;
  # Get union of all keys in externaldb & local objects.
  my %keys = ();
  map($keys{$_}=1, keys %{$$self{objects}});
  map($keys{Encode::decode('utf8',$_)}=1, keys %{$$self{externaldb}}); 
  keys %keys; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Lookup of various kinds of things in the DB.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Lookup the Object associated with label
# If it is not already fetched from the external db (if any), fetch it now.

sub lookup {
  my($self,$key)=@_;
  return undef unless defined $key;
  my $entry = $$self{objects}{$key}; # Get the local copy.
  return $entry if $entry;
  $entry = $$self{externaldb}{Encode::encode('utf8',$key)}; # Get the external object
  if($entry){
    $entry = thaw($entry);
    $$entry{key} = $key;
    bless $entry, 'LaTeXML::Util::ObjectDB::Entry';
    $$self{objects}{$key} = $entry; }
  $entry; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Register various interesting document nodes.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Register the labeled object $node, creating, or filling in, and
# returning a Chunk entry.
sub register {
  my($self,$key,%props)=@_;
  carp("Missing key for object!") unless $key;
  my $entry = $self->lookup($key);
  if(!$entry){
    $entry = {key=>$key};
    bless $entry, 'LaTeXML::Util::ObjectDB::Entry';
    $$self{objects}{$key}=$entry;
    $$entry{timestamp}=time(); }
  $entry->setValues(%props);

  $entry; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#  Pathnames stored in the DB, will be portable if made relative to the
# DB's location.
sub storablePathname {
  my($self,$path)=@_;
  ($$self{dbfile} ? pathname_relative($path,$$self{dbfile}) : $path); }

#********************************************************************************
# Sorting Objects
#********************************************************************************
sub sort_targets {
  my($self,@ids)=@_;
  my @objects = map($self->lookup($_),@ids);
  map($self->compute_sort_order($_), @objects);
  map($_->key, sort { $$a{sort_order} <=> $$b{sort_order}} @objects); }

# Scheme for deferred computation of the order of nodes.
# based on (recursive) position within parent's children.
sub compute_sort_order {
  my($self,$chunk)=@_;
  if($$chunk{sort_order}){}
  elsif(my $parent=$chunk->parent){
    # Compute fractional position of this child within parent's children
    my $parent_chunk = $self->lookup($parent);
    $self->compute_sort_order($parent_chunk);
    my @sibs = $parent_chunk->children;
    $$chunk{sort_delta} = $$parent_chunk{sort_delta}/(scalar(@sibs)+1);
    my $pos = 1;
    my $key = $chunk->key;
    while($key ne shift(@sibs)){ $pos++; }
    $$chunk{sort_order} = $$parent_chunk{sort_order} + $$chunk{sort_delta}*$pos; }
  else {
    $$chunk{sort_order}=0;
    $$chunk{sort_delta}=1; }
  $$chunk{sort_order}; }

#********************************************************************************
# DB Entries
#********************************************************************************
package LaTeXML::Util::ObjectDB::Entry;
use strict;
use XML::LibXML;

our $XMLParser = XML::LibXML->new();
$XMLParser->clean_namespaces(1);

sub new {
  my($class,$key,%data)=@_;
  bless {key=>$key,%data},$class; }

sub key { $_[0]->{key}; }

# Get/Set a value (column) in the DBRow entry, noting whether it modifies the entry.
sub getValue {
  my($self,$attr)=@_;
  my $value = $$self{$attr}; 
  if($value && $value =~ /^XML::/){
    $value = $XMLParser->parse_xml_chunk(substr($value,5));
    # Simplify, if we get a single node Document Fragment.
    if($value && (ref $value eq 'XML::LibXML::DocumentFragment')) {
      my @k = $value->childNodes;
      $value = $k[0] if(scalar(@k) == 1); }}
  $value; }

sub setValues {
  my($self,%avpairs)=@_;
  foreach my $attr (keys %avpairs){
    my $value = $avpairs{$attr};
    if(((ref $value) || '') =~ /^XML::/){
      # The node is cloned so as to copy any inherited namespace nodes.
      $value = "XML::".$value->cloneNode(1)->toString; }
    if(! defined $value){
      if(defined $$self{$attr}){
	delete $$self{$attr};
	$$self{timestamp}=time(); }}
    elsif((! defined $$self{$attr}) || ($$self{$attr} ne $value)){
      $$self{$attr}=$value;
      $$self{timestamp} = time(); }}}

# Note an association with this entry
# Roughly equivalent to $$entry{key1}{key2}{...}=1,
# but keeps track of modification timestamps.
sub noteAssociation {
  my($self,@keys)=@_;
  my $hash = $self;
  while(@keys){
    my $key = shift(@keys);
    if(defined $$hash{$key}){
      $hash = $$hash{$key}; }
    else {
      $$self{timestamp} = time();
      $hash = $$hash{$key} = (@keys ? {} : 1); }}}

# Debugging aid
use Text::Wrap;
sub show {
  my($self)=@_;
  print "ObjectDB Entry for: $$self{key}\n";
  foreach my $attr (qw(timestamp), grep(!/^(key|timestamp)$/, keys %{$self})){
    my $value = $self->getValue($attr);
    if((ref $value) =~ /^XML::/){
      $value = $value->toString; }
    elsif(ref $value eq 'HASH'){
      $value = showhash($value); }
    elsif($attr eq 'timestamp'){
      $value = localtime($value); }
    print wrap(sprintf(' %16s : ',$attr),(' 'x20), $value)."\n"; }
}

sub showhash {
  my($hash)=@_;
  "{".join(', ',map((ref $$hash{$_} ? "$_=>".showhash($$hash{$_}) : $_),sort keys %$hash))."}"; }

#======================================================================
1;
