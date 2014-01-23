# /=====================================================================\ #
# |  LaTeXML::Util::ObjectDB::Entry                                     | #
# |  Database of Objects for crossreferencing, etc                      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::ObjectDB::Entry;
use strict;
use warnings;
use LaTeXML::Common::XML;

my $XMLParser = LaTeXML::Common::XML::Parser->new();    # [CONSTANT]

sub new {
  my ($class, $key, %data) = @_;
  return bless { key => $key, %data }, $class; }

sub key {
  my ($entry) = @_;
  return $$entry{key}; }

sub getAttributes {
  my ($self) = @_;
  return keys %$self; }

# Get/Set a value (column) in the DBRow entry, noting whether it modifies the entry.
# Note that XML data is stored in it's serialized form, prefixed by "XML::".
sub hasValue {
  my ($self, $attr) = @_;
  return exists $$self{$attr}; }

sub getValue {
  my ($self, $attr) = @_;
  return decodeValue($$self{$attr}); }

sub setValues {
  my ($self, %avpairs) = @_;
  foreach my $attr (keys %avpairs) {
    my $value = encodeValue($avpairs{$attr});
    if (!defined $value) {
      if (defined $$self{$attr}) {
        delete $$self{$attr}; } }
    elsif ((!defined $$self{$attr}) || ($$self{$attr} ne $value)) {
      $$self{$attr} = $value; } }
  return; }

sub pushValues {
  my ($self, $attr, @values) = @_;
  my $list = $$self{$attr};
  foreach my $value (@values) {
    push(@$list, encodeValue($value)) if defined $value; }
  return; }

sub pushNew {
  my ($self, $attr, @values) = @_;
  my $list = $$self{$attr};
  foreach my $value (@values) {
    my $value = encodeValue($value);
    push(@$list, $value) if (defined $value) && !grep { $_ eq $value } @$list; }
  return; }

# Note an association with this entry
# Roughly equivalent to $$entry{key1}{key2}{...}=1,
# but keeps track of modification timestamps. --- not any more!
sub noteAssociation {
  my ($self, @keys) = @_;
  my $hash = $self;
  while (@keys) {
    my $key = shift(@keys);
    if (defined $$hash{$key}) {
      $hash = $$hash{$key}; }
    else {
      $hash = $$hash{$key} = (@keys ? {} : 1); } }
  return; }

# Debugging aid
use Text::Wrap;

sub show {
  my ($self) = @_;
  my $string = "ObjectDB Entry for: $$self{key}\n";
  foreach my $attr (grep { $_ ne 'key' } keys %{$self}) {
    $string .= wrap(sprintf(' %16s : ', $attr), (' ' x 20), showvalue($self->getValue($attr))) . "\n"; }
  return $string; }

sub showvalue {
  my ($value) = @_;
  if ((ref $value) =~ /^XML::/) {
    return $value->toString; }
  elsif (ref $value eq 'HASH') {
    return "{" . join(', ', map { "$_=>" . showvalue($$value{$_}) } keys %$value) . "}"; }
  elsif (ref $value eq 'ARRAY') {
    return "[" . join(', ', map { showvalue($_) } @$value) . "]"; }
  else {
    return "$value"; } }

#======================================================================
# Internal methods to encode/decode values; primarily to serialize/deserialize XML.
# Yikes, this ultimately needs to be recursive!
sub encodeValue {
  my ($value) = @_;
  my $ref = ref $value;
  if (!defined $value) {
    return $value; }
  elsif (!$ref) {
    return $value; }
  # The node is cloned so as to copy any inherited namespace nodes.
  elsif ($ref =~ /^XML::/) {
    return "XML::" . $value->cloneNode(1)->toString; }
  elsif ($ref eq 'ARRAY') {
    return [map { encodeValue($_) } @$value]; }
  elsif ($ref eq 'HASH') {
    my %h = map { ($_ => encodeValue($$value{$_})) } keys %$value;
    return \%h; }
  else {
    return $value; } }

sub decodeValue {
  my ($value) = @_;
  my $ref = ref $value;
  if (!defined $value) {
    return $value; }
  elsif ($value =~ /^XML::/) {
    return $XMLParser->parseChunk(substr($value, 5)); }
  elsif (!$ref) {
    return $value; }
  elsif ($ref eq 'ARRAY') {
    return [map { decodeValue($_) } @$value]; }
  elsif ($ref eq 'HASH') {
    my %h = map { ($_ => decodeValue($$value{$_})) } keys %$value;
    return \%h; }
  else {
    return $value; } }

#======================================================================
1;
