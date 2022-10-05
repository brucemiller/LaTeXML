# /=====================================================================\ #
# |  LaTeXML::BibTeX::Runtime::Buffer                                   | #
# | Emulates BibTeX's buffer implementation                             | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
package LaTeXML::BibTeX::Runtime::Buffer;
use strict;
use warnings;
use LaTeXML::Common::Error;

# The Buffer class emulates the output buffering implemented by BibTeX
# In addition to the raw BibTeX behavior this class also implements
# wrapping source references around specific output strings.
# Forefficency the wrapping behavior of BibTeX is only enabled
# when $wrapEnabled is set.
sub new {
  my ($class, $handle, $wrapEnabled, $sourceMacro) = @_;
  return bless {
    # handle to send output to
    handle        => $handle,
    wrapEnabled   => $wrapEnabled,
    sourceMacro   => $sourceMacro,
    minLineLength => 3,
    maxLineLength => 79,
    # state for
    buffer     => "",    # current internal buffer
    skipSpaces =>
      0,                 # flag to indicate if whitespace is currently being skipped
  }, $class; }

# Write writes a string from the buffer to the output handle
# and emulates BibTeX's hard-wrapping
sub write {
  my ($self, $string, $source) = @_;
  # add the string to the buffer
  $$self{buffer} .= $self->wrapSource($string, $source);
  return unless $$self{wrapEnabled};
  # while the buffer is long enough
  my ($candidate, $index);
  while (length($$self{buffer}) > $$self{maxLineLength}) {
    # find whitespace at the beginning of the string (if applicable)
    $candidate = reverse(
      substr(
        $$self{buffer},
        $$self{minLineLength},
        $$self{maxLineLength} - $$self{minLineLength} + 1
      )
    );
    if ($candidate =~ /\s/) {
      $index = $$self{maxLineLength} - $-[0]; }
    # if there isn't any, find whitespace afterwards or bail out
    else {
      return
        unless substr($$self{buffer}, $$self{maxLineLength}) =~ /\s/;
      $index = $$self{maxLineLength} + $-[0]; }
    # split the buffer at the index
    $candidate     = substr($$self{buffer}, 0, $index);
    $$self{buffer} = substr($$self{buffer}, $index);
    $self->writeLineInternal($candidate);
# By default, we trim all the spaces from the next line.
# However, there is a bug in the BibTeX implementation, where this does not always work.
# When there are at least two spaces beginning at exactly the boundary between two lines, an additional space is left on the line.
    unless ($$self{maxLineLength} == $index && $$self{buffer} =~ /^\s\s/) {
      $$self{buffer} =~ s/^\s+//; }
    else {
      $$self{buffer} =~ s/^\s+/ /; }
    # and add two spaces to the next line
    $$self{buffer} = '  ' . $$self{buffer}; }
  return; }

# WriteLn writes whatever is currently in the buffer
sub writeLn {
  my ($self) = @_;
  $self->writeLineInternal($$self{buffer});
  $$self{buffer} = '';
  return; }

# writeLineInternal internally writes a line to the output
sub writeLineInternal {
  my ($self, $line) = @_;
  # trim trailing whitespace and then print it
  $line =~ s/\s+$//;
  # print it
  print { $$self{handle} } $line . "\n";
  return; }

# wrapSource wraps a source-referenced string into the appropriate
# source macro for this buffer. If source or macro are undef, returns
# the original string
sub wrapSource {
  my ($self, $string, $source) = @_;
#####  return $string unless defined($source) && $$self{sourceMacro};
### NOTE: Somehow, we're getting a $source, but it's not the expected array [entry,field]
  return $string unless defined($source) && (ref $source) && $$self{sourceMacro};
##Debug("WRAP '$string' from ".(ref $source ? '['.join(',',@$source).']' : $source));
##return $string;
  my ($fn, $entry, $field) = @{$source};
  return $string unless $field;
  return
    '\\'
    . $$self{sourceMacro} . '{'
    . $fn . '}{'
    . $entry . '}{'
    . $field . '}{'
    . $string . '}'; }

# finalize closes this buffer and flushes whatever is left in the buffer to STDOUT
sub finalize {
  my ($self) = @_;
  # print whatever is left in the handle to the buffer
  print { $$self{handle} } $$self{buffer};
  # state reset (not really needed, buf whatever)
  $$self{buffer}     = '';
  $$self{counter}    = 0;
  $$self{skipSpaces} = 0;
  close($$self{handle});
  return; }

1;
