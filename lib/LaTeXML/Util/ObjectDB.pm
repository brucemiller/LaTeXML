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
  }
  $self; }

sub DESTROY {
  my($self)=@_;
  $self->finish; }

sub status {
  my($self)=@_;
  my $status = scalar(keys %{$$self{objects}})."/".scalar(keys %{$$self{externaldb}})." objects";
#  if($$self{dbfile}){ ...
  $status; }
    
#======================================================================
# This saves the db

sub finish {
  my($self)=@_;
  if($$self{externaldb} && $$self{dbfile}){
    my $n=0;
    my %types=();
    foreach my $key (keys %{$$self{objects}}){
      my $row = $$self{objects}{$key};
      # Skip saving, unless there's some difference between stored value
      if(my $stored = $$self{externaldb}{Encode::encode('utf8',$key)}){ # Get the external object
	next if compare_hash($row,thaw($stored)); }
      $n++;
      my %item = %$row;
      $$self{externaldb}{Encode::encode('utf8',$key)} = nfreeze({%item}); }

    print STDERR "ObjectDB Stored $n objects (".scalar(keys %{$$self{externaldb}})." total)\n"
      if $$self{verbosity} > 0; 
    untie %{$$self{externaldb}};  }

 $$self{externaldb}=undef;
 $$self{objects}=undef;
}

sub compare {
  my($a,$b)=@_;
  my $ra = ref $a;
  if(! $ra){
    if(ref $b){ 0; }
    else { compare_scalar($a,$b); }}
  elsif($ra ne ref $b){ 0; }
  elsif($ra eq 'HASH'){ compare_hash($a,$b); }
  elsif($ra eq 'ARRAY'){ compare_array($a,$b); }
  else { compare_scalar($a,$b); }}

sub compare_scalar {
  my ($a,$b) = @_;
  ((! defined $a) && (! defined $b)) ||
    (defined $a && defined $b && $a eq $b); }

sub compare_hash {
  my($a,$b)=@_;
  my %attr = ();
  map($attr{$_}=1, keys %$a);
  map($attr{$_}=1, keys %$b);
  (grep( !( (exists $$a{$_}) && (exists $$b{$_})
	    && compare($$a{$_}, $$b{$_}) ), keys %attr) ? 0 : 1); }

sub compare_array {
  my($a,$b)=@_;
  my @a = @$a;
  my @b = @$b;
  while(@a && @b){
    return 0 unless compare(shift(@a),shift(@b)); }
  (@a || @b ? 0 : 1); }

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
  return unless defined $key;
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
    $$self{objects}{$key}=$entry; }
  $entry->setValues(%props);

  $entry; }

sub unregister {
  my($self,$key)=@_;
  delete $$self{objects}{$key};
  # Must remove external entry (if any) as well, else it'll get pulled back in!
  delete $$self{externaldb}{Encode::encode('utf8',$key)} if $$self{externaldb}; }

#********************************************************************************
# DB Entries
#********************************************************************************
package LaTeXML::Util::ObjectDB::Entry;
use strict;
use LaTeXML::Common::XML;

our $XMLParser = LaTeXML::Common::XML::Parser->new();

sub new {
  my($class,$key,%data)=@_;
  bless {key=>$key,%data},$class; }

sub key { $_[0]->{key}; }

sub getAttributes {
  my($self)=@_;
  keys %$self; }

# Get/Set a value (column) in the DBRow entry, noting whether it modifies the entry.
# Note that XML data is stored in it's serialized form, prefixed by "XML::".
sub hasValue {
  my($self,$attr)=@_;
  exists $$self{$attr}; }

sub getValue {
  my($self,$attr)=@_;
  decodeValue($$self{$attr}); }

sub setValues {
  my($self,%avpairs)=@_;
  foreach my $attr (keys %avpairs){
    my $value = encodeValue($avpairs{$attr});
    if(! defined $value){
      if(defined $$self{$attr}){
	delete $$self{$attr}; }}
    elsif((! defined $$self{$attr}) || ($$self{$attr} ne $value)){
      $$self{$attr}=$value; }}}

sub pushValues {
  my($self,$attr,@values)=@_;
  my $list = $$self{$attr};
  foreach my $value (@values){
    push(@$list, encodeValue($value)) if defined $value; }}

sub pushNew {
  my($self,$attr,@values)=@_;
  my $list = $$self{$attr};
  foreach my $value (@values){
    my $value = encodeValue($value);
    push(@$list, $value) if (defined $value) && !grep($_ eq $value, @$list)  ; }}

# Note an association with this entry
# Roughly equivalent to $$entry{key1}{key2}{...}=1,
# but keeps track of modification timestamps. --- not any more!
sub noteAssociation {
  my($self,@keys)=@_;
  my $hash = $self;
  while(@keys){
    my $key = shift(@keys);
    if(defined $$hash{$key}){
      $hash = $$hash{$key}; }
    else {
      $hash = $$hash{$key} = (@keys ? {} : 1); }}}

# Debugging aid
use Text::Wrap;
sub show {
  my($self)=@_;
  my $string = "ObjectDB Entry for: $$self{key}\n";
  foreach my $attr (grep($_ ne 'key', keys %{$self})){
    $string .= wrap(sprintf(' %16s : ',$attr),(' 'x20), showvalue($self->getValue($attr)))."\n"; }
  $string; }

sub showvalue {
  my($value)=@_;
  if((ref $value) =~ /^XML::/){ $value->toString; }
  elsif(ref $value eq 'HASH'){
    "{".join(', ',map("$_=>".showvalue($$value{$_}), keys %$value))."}"; }
  elsif(ref $value eq 'ARRAY'){
  "[".join(', ',map(showvalue($_),@$value))."]"; }
  else { "$value"; }}

#======================================================================
# Internal methods to encode/decode values; primarily to serialize/deserialize XML.
# Yikes, this ultimately needs to be recursive!
sub encodeValue {
  my($value)=@_;
  my $ref = ref $value;
  if(!defined $value){     $value; }
  elsif(!$ref){            $value; }
  # The node is cloned so as to copy any inherited namespace nodes.
  elsif($ref =~ /^XML::/){ "XML::".$value->cloneNode(1)->toString; }
  elsif($ref eq 'ARRAY'){  [map(encodeValue($_),@$value)]; }
  elsif($ref eq 'HASH'){   my %h=map( ($_=>encodeValue($$value{$_})), keys %$value); \%h; }
  else {		    $value; }}

sub decodeValue {
  my($value)=@_;
  my $ref = ref $value;
  if(!defined $value){       $value; }
  elsif($value =~ /^XML::/){ $XMLParser->parseChunk(substr($value,5)); }
  elsif(!$ref){              $value; }
  elsif($ref eq 'ARRAY'){    [map(decodeValue($_),@$value)]; }
  elsif($ref eq 'HASH'){     my %h =map( ($_=>decodeValue($$value{$_})), keys %$value); \%h; }
  else {		     $value; }}

#======================================================================
1;
