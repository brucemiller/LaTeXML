#!/usr/bin/perl

# This helps convert explIntarray.pdf to the expected xml output.  Workflow:
# xelatex explIntarray
# pdftotxt explIntarray.pdf > explIntarray.txt
# perl pdftxt2ltxml.pl explIntarray.txt > explIntarray.xml

# The text file doesn't seem to be very consistent, so this may require tweaking
# between various pdftotxt versions.  On the other hand, once you have
# explIntarray.xml having the same format as what latexml outputs, then you don't
# need to change the xml file anymore, and can focus on getting latexml to match

use warnings;
use strict;

my $fileName = shift;

die "File does not exist\n" if (!-e $fileName);

open my $IN, '<', $fileName or die;

print <<ENDOFHEADER;
<?xml version="1.0" encoding="UTF-8"?>
<?latexml class="article"?>
<?latexml package="expl3"?>
<?latexml package="booktabs"?>
<?latexml package="latexml"?>
<?latexml RelaxNGSchema="LaTeXML"?>
<document xmlns="http://dlmf.nist.gov/LaTeXML">
  <resource src="LaTeXML.css" type="text/css"/>
  <resource src="ltx-article.css" type="text/css"/>
  <para xml:id="p1">
    <p><text font="typewriter">\\c__codepoint_#1_\\codepoint_str_generate:n{"#2}_tl:<break/><tabular vattach="middle">
          <thead>
            <tr>
              <td align="left" border="tt" thead="column">#1</td>
              <td align="left" border="tt" thead="column">#2</td>
              <td align="left" border="tt" thead="column"><text font="serif">actual</text></td>
              <td align="left" border="tt" thead="column"><text font="serif">expected</text></td>
            </tr>
          </thead>
          <tbody>
ENDOFHEADER

my @tableEntries;
my ($firstIntArray, $firstIntArrayDesc);
while (<$IN>) {
  chomp;
  if (/The integer array (.*)( contains .*$)/) {
    $firstIntArray     = $1;
    $firstIntArrayDesc = $2;
    last; }
  push(@tableEntries, $_) if $_; }

shift @tableEntries;

my $numRows = (@tableEntries / 4) - 1;
for (1 .. $numRows) {
  print <<ENDOFROW;
            <tr>
              <td align="left">$tableEntries[$_]</td>
              <td align="left">$tableEntries[$_+($numRows+1)]</td>
              <td align="left">$tableEntries[$_+($numRows+1)*2]</td>
              <td align="left">$tableEntries[$_+($numRows+1)*3]</td>
            </tr>
ENDOFROW
}

print <<ENDOFBRIDGE;
          </tbody>
        </tabular></text></p>
  </para>
  <pagination role="newpage"/>
  <para class="ltx_noindent" xml:id="p2">
    <p>The integer array <text font="typewriter">$firstIntArray</text>$firstIntArrayDesc</p>
  </para>
  <para xml:id="p3">
ENDOFBRIDGE

print '    <p>';    # no newline at end

my $paragraph = 3;
my $interRow;
while (<$IN>) {
  chomp;
  s/\x0C//g;
  s/\s+$//;
  next unless /\S/;
  if (/The integer array (.*)( contains .*$)/) {
    $paragraph++;
    print "</p>\n  </para>\n  <pagination role=\"newpage\"/>\n";
    print "  <para class=\"ltx_noindent\" xml:id=\"p$paragraph\">\n";
    print "    <p>The integer array <text font=\"typewriter\">$1</text>$2</p>\n";
    $paragraph++;
    print "  </para>\n  <para xml:id=\"p$paragraph\">\n    <p>";    # no newline
    $interRow = undef;
  } else {
    print $interRow if $interRow;
    print;
    $interRow = ' ';
  }
}
print "</p>\n  </para>\n  <pagination role=\"newpage\"/>\n</document>\n";
