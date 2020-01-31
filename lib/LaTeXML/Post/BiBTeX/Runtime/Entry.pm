# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime::Entry                              | #
# | A read BiBTeX Entry                                     | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::Post::BiBTeX::Runtime::Entry;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Common::Utils;
use Scalar::Util qw(blessed);

###
### Read entries
###

### An entry consists of the following values:

sub new {
  my ($class, $name, $context, $entry) = @_;

  sub locationOf {
    my ($n, $source) = @_;
    $source = $source->getSource if blessed($source);
    return $n, $source; }
  # read our type, skip 'string's and 'comment's
  my $type = lc $entry->getType->getValue;
  return undef, undef if $type eq 'string' or $type eq 'comment';
  # read the fields
  my @fields = @{ $entry->getFields };
  # if we have a preamble, return the conent of the preamble
  if ($type eq 'preamble') {
    return undef, ['Missing content for preamble'],
      [locationOf($name, $entry)]
      unless scalar(@fields) eq 1;
    my $preamble = shift(@fields);
    my $text     = $preamble->getContent->getValue =~ s/\s+/ /gr;
    return $text, [($name, '', 'preamble')]; }
  # Make sure that we have something
  return undef, ['Missing key for entry', [locationOf($name, $entry)]]
    unless scalar(@fields) > 0;
  # make sure that we have a key
  my $key = shift(@fields)->getContent->getValue;
  return undef, ['Expected non-empty key', [locationOf($name, $entry)]]
    unless $key;
  my ($value, $valueKey);
  my %values      = ();
  my (@warnings)  = ();
  my (@locations) = ();

  foreach my $field (@fields) {
    $valueKey = $field->getName;
    $value    = $field->getContent->getValue;
    # we need a key=value in this field
    unless (defined($valueKey)) {
      push(@warnings, 'Missing key for value');
      push(@locations, locationOf($name, $field->getContent));
      next; }
    $valueKey = lc $valueKey->getValue;
    # if we have a duplicate valye
    if (defined($values{$valueKey})) {
      push(@warnings,
        'Duplicate value in entry '
          . $key
          . ': Field '
          . $valueKey
          . ' already defined. ');
      push(@locations, locationOf($name, $field->getContent));
      next; }
    # BiBTeX normalizes values specifically
    $values{$valueKey} = normalizeString($value); }
  my $self = bless {
    name => $name,
    # the context corresponding to this entry
    context => $context,
    # - the type, key and values for the entry
    type   => $type,
    key    => $key,
    values => {%values},
    # the variables stored in this entry
    variables => {},
    # the original entry
    entry => $entry,
  }, $class;
  # if we have warnings, return them
  return $self, [@warnings], [@locations] if scalar(@warnings) > 0;
  # else just return self
  return $self, undef, undef; }

# inlines a cross-refed entry '$xref' into this entry
sub inlineCrossReference {
  my ($self, $xref, $clearCrossRefValue) = @_;
  # copy over all the related keys
  my ($k, $v);
  keys %{ $$xref{values} };    # reset the interal iterator for each
  while (($k, $v) = each(%{ $$xref{values} })) {
    $$self{values}{$k} = $v unless defined($$self{values}{$k}); }
  # delete the 'crossref' key manually
  delete $$self{values}{crossref} if $clearCrossRefValue; }

# clears the cross-reference (if any) by this entry
sub clearCrossReference {
  my ($self) = @_;
  delete $$self{values}{crossref}; }

# gets the cross-referenced entry
# and returns a pair ($key, $crossref)
sub resolveCrossReference {
  my ($self, $entryHash) = @_;
  # get the crossref key
  my $crossref = $$self{values}{crossref};
  return undef, undef unless defined($crossref);
  # if is exists case-senstive, return it!
  my $xref = $entryHash->{$crossref};
  return $crossref, $xref if defined($xref);
  # if resolution failed, try searching case-insensitivly
  foreach my $key (keys %$entryHash) {
    if (lc $key eq lc $crossref) {
      $$self{values}{crossref} = $key;    # update to the correct case!
      return $key, $entryHash->{$key}; } }
  # else we failed completly
  return $crossref, undef; }

sub getName {
  my ($self) = @_;
  return $$self{name}; }

sub getKey {
  my ($self) = @_;
  return $$self{key}; }

sub getType {
  my ($self) = @_;
  return $$self{type}; }

# gets the value of a given variable
# get a variable (type, value, source) or undef if it doesn't exist
sub getVariable {
  my ($self, $name) = @_;
  # lookup the type and return their value
  my $type = $$self{context}{variableTypes}{$name};
  return undef unless defined($type) && startsWith($type, 'ENTRY_');
  # If we have an entry field
  # we need to take special care of where it comes from
  if ($type eq 'ENTRY_FIELD') {
    my $field = $$self{values}{ lc $name };
    return 'STRING', [$field],
      [[($$self{name}, $$self{key}, lc $name)]]
      if defined($field);
    return 'MISSING', undef, [($$self{name}, $$self{key}, lc $name)]; }
  my $value = $$self{variables}{$name};
  return 'UNSET', undef, undef unless defined($value);
  # else we can just push from our own internal value stack
  # we duplicate here, where needed
  my ($t, $v, $s) = @{$value};
  $v = [@{$v}] if ref($v) && ref($v) eq 'ARRAY';
  $s = [@{$s}] if ref($s) && ref($s) eq 'ARRAY';
  return ($t, $v, $s); }

# 'getPlainField' gets a string valued field from this entry or fails
sub getPlainField {
  my ($self, $name) = @_;
  # if it's not an entry field, bail out
  my $type = $$self{context}{variableTypes}{$name};
  return undef unless defined($type) && $type eq 'ENTRY_FIELD';
  # else return the value
  return $$self{values}{ lc $name }; }

# set a variable (type, value, source)
# returns 0 if ok, 1 if it doesn't exist,  2 if an invalid context, 3 if read-only
sub setVariable {
  my ($self, $name, $value) = @_;
  # if the variable does not exist, return nothing
  my $type = $$self{context}{variableTypes}{$name};
  return 1 unless defined($type);
  # we can't assign anything global here
  return 2
    if ($type eq 'GLOBAL_STRING'
    or $type eq 'GLOBAL_INTEGER'
    or $type eq 'FUNCTION');
  # we can't assign entry fields, they're read only
  return 3 if $type eq 'ENTRY_FIELD';
  # and assign the value
  $$self{variables}{$name} = $value;
  return 0; }

1;
