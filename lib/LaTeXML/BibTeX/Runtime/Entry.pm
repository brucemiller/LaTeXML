# /=====================================================================\ #
# |  LaTeXML::BibTeX::Runtime::Entry                                    | #
# | A read BibTeX Entry                                                 | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::BibTeX::Runtime::Entry;
use strict;
use warnings;
use LaTeXML::Common::Error;
use Scalar::Util qw(blessed);

###
### Read entries
###

### An entry consists of the following values:
# $entry should be a BibEntry!
sub new {
  my ($class, $name, $runtime, $entry) = @_;
  # read our type, skip 'string's and 'comment's
  my $type   = $entry->getType;
  my $key    = $entry->getKey;
  my @fields = $entry->getFields;
  # make sure that we have a key
  return Warn('bibtex', 'runtime', $entry->getLocator, 'Expected non-empty key')
    unless $key;
  my %values = ();
  foreach my $field (@fields) {
    my $name  = $field->getName;
    my $value = $field->getContent;
    # if we have a duplicate valye
    if (defined($values{$name})) {
      Warn('bibtex', 'runtime', $field->getLocator,
        'Duplicate value in entry ' . $key . ': Field ' . $name . ' already defined. ');
      next; }
    # BibTeX normalizes values specifically
    $value =~ s/^\s+|\s+$//g;    # remove space on both sides
    $value =~ s/\s+/ /g;         # concat multiple whitespace into one
    $values{$name} = $value; }
  my $self = bless {
    name      => $name,
    runtime   => $runtime,       # the runtime corresponding to this entry
    type      => $type,          # the type, key and values for the entry
    key       => $key,
    values    => {%values},
    variables => {},             # the variables stored in this entry
    entry     => $entry,         # the original entry
  }, $class;
  return $self; }

# inlines a cross-refed entry '$xref' into this entry
sub inlineCrossReference {
  my ($self, $xref, $clearCrossRefValue) = @_;
  # copy over all the related keys
  my ($k, $v);
  keys %{ $$xref{values} };    # reset the interal iterator for each
  while (($k, $v) = each(%{ $$xref{values} })) {
    $$self{values}{$k} = $v unless defined($$self{values}{$k}); }
  # delete the 'crossref' key manually
  delete $$self{values}{crossref} if $clearCrossRefValue;
  return; }

# clears the cross-reference (if any) by this entry
sub clearCrossReference {
  my ($self) = @_;
  delete $$self{values}{crossref};
  return; }

# gets the cross-referenced entry
# and returns a pair ($key, $crossref)
sub resolveCrossReference {
  my ($self, $entryHash) = @_;
  # get the crossref key
  my $crossref = $$self{values}{crossref};
  return undef, undef unless defined($crossref);
  # if is exists case-senstive, return it!
  my $xref = $$entryHash{$crossref};
  return $crossref, $xref if defined($xref);
  # if resolution failed, try searching case-insensitivly
  foreach my $key (keys %$entryHash) {
    if (lc $key eq lc $crossref) {
      $$self{values}{crossref} = $key;    # update to the correct case!
      return $key, $$entryHash{$key}; } }
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
# get a variable (type, value, source), silently define it when it doesn't exist yet
sub getVariable {
  my ($self, $name) = @_;
  # lookup the type and return their value
  my $type = $$self{runtime}{variableTypes}{$name};
  return undef unless defined($type) && $type =~ /^ENTRY_/;
  # If we have an entry field
  # we need to take special care of where it comes from
  if ($type eq 'ENTRY_FIELD') {
    my $field = $$self{values}{ lc $name };
    return 'STRING', [$field],
      [[($$self{name}, $$self{key}, lc $name)]]
      if defined($field);
    return 'MISSING', undef, [($$self{name}, $$self{key}, lc $name)]; }
  my $value = $$self{variables}{$name};
  # silently set default values
  unless (defined($value)) {
    return 'INTEGER', 0, undef if $type eq 'ENTRY_INTEGER';
    return 'STRING', [""], [undef] if $type eq 'ENTRY_STRING';
    # other types do not have a sensible default
    return 'UNSET', undef, undef; }
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
  my $type = $$self{runtime}{variableTypes}{$name};
  return undef unless defined($type) && $type eq 'ENTRY_FIELD';
  # else return the value
  return $$self{values}{ lc $name }; }

# set a variable (type, value, source)
# returns 0 if ok, 1 if it doesn't exist,  2 if an invalid runtime, 3 if read-only
sub setVariable {
  my ($self, $name, $value) = @_;
  # if the variable does not exist, return nothing
  my $type = $$self{runtime}{variableTypes}{$name};
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
