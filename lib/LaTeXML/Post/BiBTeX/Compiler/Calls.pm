# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Compiler::Calls                             | #
# | .bst -> perl compiler runtime encoding                              | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Compiler::Calls;
use strict;
use warnings;

use base qw(Exporter);
our @EXPORT = qw(
  &callDefineEntryField &callDefineEntryInteger &callDefineEntryString
  &callDefineGlobalString &callDefineGlobalInteger
  &callDefineMacro
  &callReadEntries &callSortEntries
  &callIterateFunction &callIterateBuiltin
  &callReverseFunction &callReverseBuiltin
  &callPushBlock &callPushFunction &callPushBuiltin
  &callPushGlobalString &callPushGlobalInteger &callPushEntryField &callPushEntryString &callPushEntryInteger &callCallFunction &callCallBuiltin
  &callLookupGlobalString &callLookupGlobalInteger &callLookupEntryField &callLookupEntryString &callLookupEntryInteger
  &callPushString &callPushInteger
);

### entry

sub callDefineEntryField {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('defineEntryField', $styString,
    $target->escapeString(lc $styString->getValue)); }

sub callDefineEntryInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('defineEntryInteger', $styString,
    $target->escapeString($styString->getValue)); }

sub callDefineEntryString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('defineEntryString', $styString,
    $target->escapeString($styString->getValue)); }

### strings

sub callDefineGlobalString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('defineGlobalString', $styString,
    $target->escapeString($styString->getValue)); }

sub callDefineGlobalInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('defineGlobalInteger', $styString,
    $target->escapeString($styString->getValue)); }

sub callDefineMacro {
  my ($target, $name, $value) = @_;
  return $target->runtimeFunctionCall(
    'defineMacro', $name,
    $target->escapeString(lc $name->getValue),
    $target->escapeString($value->getValue)
    ); }

### read && sort

sub callReadEntries {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('readEntries', $styString); }

sub callSortEntries {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('sortEntries', $styString); }

### iterate

sub callIterateFunction {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall(
    'iterateFunction',
    $styString,
    $target->escapeUsrFunctionReference(
      $target->escapeFunctionName($styString->getValue)
      )
    ); }

sub callIterateBuiltin {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall(
    'iterateFunction',
    $styString,
    $target->escapeBstFunctionReference(
      $target->escapeBuiltinName($styString->getValue)
      )
    ); }

### iterate

sub callReverseFunction {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall(
    'reverseFunction',
    $styString,
    $target->escapeUsrFunctionReference(
      $target->escapeFunctionName($styString->getValue)
      )
    ); }

sub callReverseBuiltin {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall(
    'reverseFunction',
    $styString,
    $target->escapeBstFunctionReference(
      $target->escapeBuiltinName($styString->getValue)
      )
    ); }

### block

sub callPushBlock {
  my ($target, $styString, $function) = @_;
  return $target->runtimeFunctionCall('pushFunction', $styString,
    $function); }

### variables

sub callPushGlobalString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushGlobalString', $styString,
    $target->escapeString($styString->getValue)); }

sub callPushGlobalInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushGlobalInteger', $styString,
    $target->escapeString($styString->getValue)); }

sub callPushEntryField {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushEntryField', $styString,
    $target->escapeString($styString->getValue)); }

sub callPushEntryString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushEntryString', $styString,
    $target->escapeString($styString->getValue)); }

sub callPushEntryInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushEntryInteger', $styString,
    $target->escapeString($styString->getValue)); }

sub callCallFunction {
  my ($target, $styString) = @_;
  return $target->usrFunctionCall(
    $target->escapeFunctionName($styString->getValue), $styString,); }

sub callCallBuiltin {
  my ($target, $styString) = @_;
  return $target->bstFunctionCall(
    $target->escapeBuiltinName($styString->getValue), $styString,); }

### references

sub callLookupGlobalString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('lookupGlobalString', $styString,
    $target->escapeString($styString->getValue)); }

sub callLookupGlobalInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('lookupGlobalInteger', $styString,
    $target->escapeString($styString->getValue)); }

sub callLookupEntryField {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('lookupEntryField', $styString,
    $target->escapeString($styString->getValue)); }

sub callLookupEntryString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('lookupEntryString', $styString,
    $target->escapeString($styString->getValue)); }

sub callLookupEntryInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('lookupEntryInteger', $styString,
    $target->escapeString($styString->getValue)); }

sub callPushFunction {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall(
    'pushFunction',
    $styString,
    $target->escapeUsrFunctionReference(
      $target->escapeFunctionName($styString->getValue)
      )
    ); }

sub callPushBuiltin {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall(
    'pushFunction',
    $styString,
    $target->escapeBstFunctionReference(
      $target->escapeBuiltinName($styString->getValue)
      )
    ); }

### strings + integers

sub callPushString {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushString', $styString,
    $target->escapeString($styString->getValue)); }

sub callPushInteger {
  my ($target, $styString) = @_;
  return $target->runtimeFunctionCall('pushInteger', $styString,
    $target->escapeInteger($styString->getValue)); }

1;

