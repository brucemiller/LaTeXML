# /=====================================================================\ #
# |  LaTeXML::BibTeX::Runtime::Utils                                    | #
# | Various runtime utility functions                                   | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::BibTeX::Runtime::Utils;
use strict;
use warnings;
use LaTeXML::Common::Error;

use base qw(Exporter);
our @EXPORT = qw(
  &concatString &simplifyString &applyPatch
  &fmtType
  &showStrings
);

sub showStrings {
  my ($strings, $sources) = @_;
  my @str = @$strings;
  my @src = @$sources;
  return join(', ',
    map { "'" . $str[$_] . "'[" . (defined $src[$_] ? $src[$_] : '<none>') . ']'; }
      0 .. $#str); }

# given two runtime strings, join them and their sources together
# and return a new runtime string
sub concatString {
  my ($stringA, $sourceA, $stringB, $sourceB) = @_;
  # join the strings and sources
  # Note: Both strings and sources are copies at this point and can be treated as mutable.
  my @strings = (@$stringA, @$stringB);
  # Make sure we have sources (even undefined ones) corresponding to EACH string entry
  my @sources = ((defined $sourceA ? @$sourceA : map { (undef); } @$stringA),
    (defined $sourceB ? @$sourceB : map { (undef); } @$stringB));
  ##Debug("CONCAT : " . showStrings([@strings],[@sources]));
  my @newstrings = ();
  my @newsources = ();
  my ($string, $source);
  while (defined($string = shift(@strings))) {
    $source = shift(@sources);
    next if $string eq '';
    # else push it
    # if no previous entry, just push this one
    if (!scalar(@newstrings)) {    # No previous entry, so just push this one
      push(@newstrings, $string);
      push(@newsources, $source); }
    # if previous is same source (even undef), join them
    elsif ((defined $source
        ? (defined $newsources[-1]) && ($source eq $newsources[-1])
        : !defined $newsources[-1])) {
      $newstrings[-1] .= $string; }    # Just combine them
        # if previous source is undef, but before that source is same (defined) source, join all three
    elsif ((defined $source) && (!defined $newsources[-1])
      && (defined $newsources[-2]) && ($source eq $newsources[-2])) {
      $newstrings[-2] .= $newstrings[-1] . $string;
      pop(@newstrings); pop(@newsources); }
    # Else, append new entry
    else {
      push(@newstrings, $string);
      push(@newsources, $source); } }
  # and return the strings and sources
  ## Debug(" ===>  " . showStrings([@newstrings],[@newsources]));
  return [@newstrings], [@newsources]; }

# given a runtime string turn it into a single string and useful source
# NOTE: This LOSES sources!
sub simplifyString {
  my ($string, $sources) = @_;
  # return the first 'defined' source
  # i.e. one that comes from a source file.
  my ($source);
  foreach my $asource (@$sources) {
    $source = $asource;
###    last if defined($source); }
    last if defined($source) && ($source ne ''); }
  return join('', @$string), $source; }

# Given a runtime string (which might be a complex object
# consisting of several parts) and it's corresponding source
# references, apply a plain-text patch() function to it.
# applyPatch attempts to maintain reasonable source references
# where possible. It does this based on the 'semantics' parameter.
# - 'inplace':
#              When the length of the patched string is longer than
#              the length of the original string, split the resulting
#              string in two parts, one with the original source
#              reference, and one ontouched.
# - any other value:
#              Return the patched string as having the source reference of the
#              old string.
# Whenever the patch() function returns the original string, the original source
# references are maintained in their entirety.
# NOTE: This LOSES sources!
sub applyPatch {
  my ($oldString, $oldSource, $patch, $semantics) = @_;
  # simplify the old string
  my ($theOldString, $theOldSource) =
    simplifyString($oldString, $oldSource);
  # apply the patch
  my $theNewString = &{$patch}($theOldString);
  # if nothing changed, return as is
  if ($theOldString eq $theNewString) {
    return $oldString, $oldSource; }
  # when we the semantics state 'inplace'
  elsif ($semantics eq 'inplace'
    && length($oldString) != 0
    && length($theNewString) > length($theOldString))
  {
    $theOldString = substr($theNewString, 0, length($theOldString));
    $theNewString = substr($theNewString, length($theOldString));
    # we had an in-place e
    return [$theOldString, $theNewString], [$theOldSource, undef]; }
  # else, return only the simplified source
  else {
    return [$theNewString], [$theOldSource]; } }

sub fmtType {
  my ($type, $value) = @_;
  if ($type eq 'UNSET' or $type eq 'MISSING') {
    return "($type)"; }
  elsif ($type eq 'STRING') {
    return "($type) " . join('', @$value); }
  elsif ($type eq 'INTEGER') {
    return "($type) $value"; }
  elsif ($type eq 'FUNCTION') {
    return "($type) <reference>"; }
  elsif ($type eq 'REFERENCE') {
    my ($rtype, $rname) = @$value;
    return "($type) ($rtype) $rname"; }
  else {
    return '(unknown)'; }
}

1;
