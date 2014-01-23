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
use warnings;
use LaTeXML::Util::Pathname;
use DB_File;
use Storable qw(nfreeze thaw);
use strict;
use Encode;
use Carp;
use base qw(Storable);
use LaTeXML::Util::ObjectDB::Entry;

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
  my ($class, %options) = @_;
  my $dbfile = $options{dbfile};
  if ($dbfile && $options{clean}) {
    warn "\nWARN: Removing Object database file $dbfile!!!\n";
    unlink($dbfile); }

  my $self = bless { dbfile => $dbfile,
    objects => {}, externaldb => {},
    verbosity => $options{verbosity} || 0,
    readonly => $options{readonly},
  }, $class;
  if ($dbfile) {
##    my $flags = ($options{read_write} ? O_RDWR|O_CREAT : O_RDONLY);
    my $flags = O_RDWR | O_CREAT;
    tie %{ $$self{externaldb} }, 'DB_File', $dbfile, $flags
      or die "Couldn't attach DB $dbfile for object table";
  }
  return $self; }

sub DESTROY {
  my ($self) = @_;
  $self->finish;
  return; }

sub status {
  my ($self) = @_;
  my $status = scalar(keys %{ $$self{objects} }) . "/" . scalar(keys %{ $$self{externaldb} }) . " objects";
  #  if($$self{dbfile}){ ...
  return $status; }

#======================================================================
# This saves the db

sub finish {
  my ($self) = @_;
  if ($$self{externaldb} && $$self{dbfile} && !$$self{readonly}) {
    my $n     = 0;
    my %types = ();
    foreach my $key (keys %{ $$self{objects} }) {
      my $row = $$self{objects}{$key};
      # Skip saving, unless there's some difference between stored value
      if (my $stored = $$self{externaldb}{ Encode::encode('utf8', $key) }) {    # Get the external object
        next if compare_hash($row, thaw($stored)); }
      $n++;
      my %item = %$row;
      $$self{externaldb}{ Encode::encode('utf8', $key) } = nfreeze({%item}); }

    print STDERR "ObjectDB Stored $n objects (" . scalar(keys %{ $$self{externaldb} }) . " total)\n"
      if $$self{verbosity} > 0;
    untie %{ $$self{externaldb} }; }

  $$self{externaldb} = undef;
  $$self{objects}    = undef;
  return }

sub compare {
  my ($a, $b) = @_;
  my $ra = ref $a;
  if (!$ra) {
    if (ref $b) {
      return 0; }
    else {
      return compare_scalar($a, $b); } }
  elsif ($ra ne ref $b) {
    return 0; }
  elsif ($ra eq 'HASH') {
    return compare_hash($a, $b); }
  elsif ($ra eq 'ARRAY') {
    return compare_array($a, $b); }
  else {
    return compare_scalar($a, $b); } }

sub compare_scalar {
  my ($a, $b) = @_;
  return ((!defined $a) && (!defined $b)) ||
    (defined $a && defined $b && $a eq $b); }

sub compare_hash {
  my ($a, $b) = @_;
  my %attr = ();
  map { $attr{$_} = 1 } keys %$a;
  map { $attr{$_} = 1 } keys %$b;
  return (grep { !((exists $$a{$_}) && (exists $$b{$_}) && compare($$a{$_}, $$b{$_})) }
      keys %attr) ? 0 : 1; }

sub compare_array {
  my ($a, $b) = @_;
  my @a = @$a;
  my @b = @$b;
  while (@a && @b) {
    return 0 unless compare(shift(@a), shift(@b)); }
  return (@a || @b ? 0 : 1); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub getKeys {
  my ($self) = @_;
  # Get union of all keys in externaldb & local objects.
  my %keys = ();
  map { $keys{$_} = 1 } keys %{ $$self{objects} };
  map { $keys{ Encode::decode('utf8', $_) } = 1 } keys %{ $$self{externaldb} };
  return (sort keys %keys); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Lookup of various kinds of things in the DB.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Lookup the Object associated with label
# If it is not already fetched from the external db (if any), fetch it now.

sub lookup {
  my ($self, $key) = @_;
  return unless defined $key;
  my $entry = $$self{objects}{$key};    # Get the local copy.
  return $entry if $entry;
  $entry = $$self{externaldb}{ Encode::encode('utf8', $key) };    # Get the external object
  if ($entry) {
    $entry = thaw($entry);
    $$entry{key} = $key;
    bless $entry, 'LaTeXML::Util::ObjectDB::Entry';
    $$self{objects}{$key} = $entry; }
  return $entry; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Register various interesting document nodes.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Register the labeled object $node, creating, or filling in, and
# returning a Chunk entry.
sub register {
  my ($self, $key, %props) = @_;
  carp("Missing key for object!") unless $key;
  my $entry = $self->lookup($key);
  if (!$entry) {
    $entry = { key => $key };
    bless $entry, 'LaTeXML::Util::ObjectDB::Entry';
    $$self{objects}{$key} = $entry; }
  $entry->setValues(%props);

  return $entry; }

sub unregister {
  my ($self, $key) = @_;
  delete $$self{objects}{$key};
  # Must remove external entry (if any) as well, else it'll get pulled back in!
  delete $$self{externaldb}{ Encode::encode('utf8', $key) } if $$self{externaldb};
  return; }

#======================================================================
1;
