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
  }
  push(@DBS,$self);
  $self; }

sub status {
  my($self)=@_;
  my $status = scalar(keys %{$$self{objects}})."/".scalar(keys %{$$self{externaldb}})." objects";
#  if($$self{dbfile}){ ...
  $status; }
    
#======================================================================
# This saves the db

sub XXXfinish {
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
      #    $$row{timestamp}=$opened;
##print STDERR "Saving: ".$row->show."\n";
      $$self{externaldb}{Encode::encode('utf8',$key)} = nfreeze({%item}); }

    print STDERR "ObjectDB Stored $n objects (".scalar(keys %{$$self{externaldb}})." total)\n"
      if $$self{verbosity} > 0; 
    untie %{$$self{externaldb}};  }

 $$self{externaldb}=undef;
 $$self{objects}=undef;
}


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
##print STDERR "Saving: ".$row->show."\n";
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
    else { $a eq $b; }}
  elsif($ra ne ref $b){ 0; }
  elsif($ra eq 'HASH'){ compare_hash($a,$b); }
  elsif($ra eq 'ARRAY'){ compare_array($a,$b); }
  else { $a eq $b;}}

sub compare_hash {
  my($a,$b)=@_;
  my %attr = ();
  map($attr{$_}=1, keys %$a);
  map($attr{$_}=1, keys %$b);
  (grep( !( (defined $$a{$_}) && (defined $$b{$_})
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
    $$self{objects}{$key}=$entry; }
  $entry->setValues(%props);

  $entry; }

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

# Get/Set a value (column) in the DBRow entry, noting whether it modifies the entry.
# Note that XML data is stored in it's serialized form, prefixed by "XML::".
sub getValue {
  my($self,$attr)=@_;
  my $value = $$self{$attr}; 
  if($value && $value =~ /^XML::/){
    $value = $XMLParser->parseChunk(substr($value,5)); }
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
	delete $$self{$attr}; }}
    elsif((! defined $$self{$attr}) || ($$self{$attr} ne $value)){
      $$self{$attr}=$value; }}}

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
1;
