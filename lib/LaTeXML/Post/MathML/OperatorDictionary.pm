# /=====================================================================\ #
# |  LaTeXML::Post::MathML::OperatorDictionary                          | #
# | MathML generator for LaTeXML                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::MathML::OperatorDictionary;
use strict;
use warnings;
use LaTeXML::Common::Error;
use LaTeXML::Util::Unicode;
use base qw(Exporter);
our @EXPORT = (qw( &opdict_lookup));

#======================================================================
# Algorithm loosely derived from MathML Core 2.6.1

# Special Tables defined at end
our $Operators_2_ascii_chars;
our $Operators_fence;
our $Operators_separator;
our $Content_form;
our $Category_data;
# Spacing constants, defined at end
our $thin;     #  = 0.167;    # 3 mu in ems
our $med;      #   = 0.222;    # 4 mu
our $thick;    # = 0.278;    # 5 mu

# Rough assumption of what MathML form each role corresponds to
# (without actually looking at its position within the expression!)
our $role_form = {
  ATOM    => 'infix',
  UNKNOWN => 'infix',
  ID      => 'infix',
  NUMBER  => 'infix',
  ARRAY   => 'Inner',
  RELOP   => 'infix',
  OPEN    => 'prefix',
  CLOSE   => 'postfix',
  MIDDLE  => 'infix',
  #  PUNCT            => 'postfix',
  PUNCT            => 'infix',
  VERTBAR          => 'postfix',
  PERIOD           => 'postfix',
  METARELOP        => 'infix',
  MODIFIEROP       => 'infix',
  MODIFIER         => 'infix',
  ARROW            => 'infix',
  ADDOP            => 'infix',
  MULOP            => 'infix',
  BINOP            => 'infix',
  POSTFIX          => 'postfix',
  FUNCTION         => 'infix',
  OPFUNCTION       => 'prefix',
  TRIGFUNCTION     => 'prefix',
  APPLYOP          => 'infix',
  COMPOSEOP        => 'infix',
  SUPOP            => 'infix',      #?
  BIGOP            => 'prefix',
  SUMOP            => 'prefix',
  INTOP            => 'prefix',
  LIMITOP          => 'prefix',
  DIFFOP           => 'infix',
  OPERATOR         => 'prefix',
  POSTSUBSCRIPT    => 'infix',
  POSTSUPERSCRIPT  => 'infix',
  FLOATSUPERSCRIPT => 'infix',
  FLOATSUBSCRIPT   => 'infix', };

sub opdict_lookup {
  my ($content, $role) = @_;
  my $form     = $$role_form{ $role // 'ATOM' } // 'infix';
  my $category = lookup_category($content, $form) || 'Default';
  my %data     = (
    %{ $$Category_data{$category} },
    ($$Operators_fence{$content}     ? (fence     => 1) : ()),
    ($$Operators_separator{$content} ? (separator => 1) : ()));
  Debug("OPDICT '$content' "
      . (length($content) == 1 ? '(' . sprintf("0x%05x", ord($content)) . ')' : '')
      . " as " . ($role || '<undefined>') . " ($form) is type $category: "
      . join(',', map { $_ . '=' . (defined $data{$_} ? $data{$_} : '<undefined>'); } sort keys %data))
    if $LaTeXML::DEBUG{mathspacing};
  return %data; }

sub lookup_category {
  my ($content, $form) = @_;
  return 'Default' unless defined $content;
  my $len = length($content);
  # (1) If Content as an UTF-16 string does not have length or 1 or 2 then exit with category Default.
  if ($len > 2) {
    return 'Default'; }
  my $code1 = ord(substr($content, 0, 1));
  # (2) If Content is a single character in the range U+0320–U+03FF then exit with category Default.
  if (($len == 1) && ($code1 >= 0x0320) && ($code1 <= 0x03FF)) {
    return 'Default'; }
  # Otherwise, if it has two characters:
  if ($len == 2) {
    my $code2 = ord(substr($content, 1, 1));
    # [ADDED TO $Content_form] If Content is the surrogate pairs corresponding to
    #   U+1EEF0 ARABIC MATHEMATICAL OPERATOR MEEM WITH HAH WITH TATWEEL
    #   or U+1EEF1 ARABIC MATHEMATICAL OPERATOR HAH WITH DAL and Form is postfix,
    #   exit with category I.
    #
    # If the second character is
    #   U+0338 COMBINING LONG SOLIDUS OVERLAY or U+20D2 COMBINING LONG VERTICAL LINE OVERLAY
    #   then replace Content with the first character and move to step 3.
    if (($code2 == 0x0338) || ($code2 == 0x20D2)) {
      $content = substr($content, 0, 1); }
    # Otherwise, if Content is listed in Operators_2_ascii_chars
    #   then replace Content with the Unicode character "U+0320
    #   plus the index of Content in Operators_2_ascii_chars"
    #   and move to step 3.
    elsif (my ($p) = grep { $$Operators_2_ascii_chars[$_] eq $content ? ($_) : (); } 0 .. $#$Operators_2_ascii_chars) {
      $code1   = 0x320 + $p;
      $content = chr($code1); }
    # Otherwise exit with category Default.
    else {
      return 'Default'; } }
# (3) If Form is infix and Content corresponds to one of U+007C VERTICAL LINE or U+223C TILDE OPERATOR
#   then exit with category ForceDefault.
# [Ignore the whole Table 27 complication]
  if (($form eq 'infix') && (($code1 == 0x007C) || ($code1 == 0x223C))) {
    return 'ForceDefault'; }
  if (my $cat = $$Content_form{$form}{$content}) {
    return $cat; }
  else {
    return 'Default'; } }

#======================================================================
# Utility for expanding Unocode values & ranges, as given in the MathML Core spec.
sub decode_ranges {
  my ($string, $value) = @_;
  $value = 1 unless defined $value;
  my %result = ();
  foreach my $entry (split(/,\s*/, $string)) {
    if ($entry =~ /^U\+(\w+)$/) {
      $result{ chr(hex($1)) } = $value; }
    elsif ($entry =~ /^\{U\+(\w+)\}$/) {
      $result{ chr(hex($1)) } = $value; }
    elsif ($entry =~ /^\[U\+(\w+).U\+(\w+)\]$/) {
      my ($min, $max) = (hex($1), hex($2));
      for (my $c = $min ; $c <= $max ; $c++) {
        $result{ chr($c) } = $value; } }
    else {
      Debug("MISUNDERSTOOD unicode range: '$entry'"); } }
  return %result; }

#======================================================================
# Special Table	Entries
BEGIN {
  # Figure 24 Special tables for the operator dictionary.
  #   Total size: 82 entries, 90 bytes
  #   (assuming characters are UTF-16 and 1-byte range lengths).
  # Operators_2_ascii_chars 18 entries (2-characters ASCII strings):
  $Operators_2_ascii_chars = [
'!!', '!=', '&&', '**', '*=', '++', '+=', '--', '-=', '->', '//', '/=', ':=', '<=', '<>', '==', '>=', '||'];
  # Note that fence & separator properties have no visible effect, but are for semantics
  # Operators_fence 61 entries (16 Unicode ranges):
  $Operators_fence = { decode_ranges(
"[U+0028-U+0029], {U+005B}, {U+005D}, [U+007B-U+007D], {U+0331}, {U+2016}, [U+2018-U+2019], [U+201C-U+201D], [U+2308-U+230B], [U+2329-U+232A], [U+2772-U+2773], [U+27E6-U+27EF], {U+2980}, [U+2983-U+2999], [U+29D8-U+29DB], [U+29FC-U+29FD]") };
  # Operators_separator	3 entries: U+002C, U+003B, U+2063,
  $Operators_separator = { decode_ranges("U+002C, U+003B, U+2063") };

  #======================================================================
  # Figure 25 Mapping from operator (Content, Form) to a category.
  # Total size: 725 entries, 639 bytes
  # (assuming characters are UTF-16 and 1-byte range lengths).
  # NOTE: replace – (\x{2013}) with -
  # (Content, Form) keys	Category
  $Content_form = {
    infix => {
      #  313 entries (35 Unicode ranges) in infix form:
      decode_ranges(
"[U+2190-U+2195], [U+219A-U+21AE], [U+21B0-U+21B5], {U+21B9}, [U+21BC-U+21D5], [U+21DA-U+21F0], [U+21F3-U+21FF], {U+2794}, {U+2799}, [U+279B-U+27A1], [U+27A5-U+27A6], [U+27A8-U+27AF], {U+27B1}, {U+27B3}, {U+27B5}, {U+27B8}, [U+27BA-U+27BE], [U+27F0-U+27F1], [U+27F4-U+27FF], [U+2900-U+2920], [U+2934-U+2937], [U+2942-U+2975], [U+297C-U+297F], [U+2B04-U+2B07], [U+2B0C-U+2B11], [U+2B30-U+2B3E], [U+2B40-U+2B4C], [U+2B60-U+2B65], [U+2B6A-U+2B6D], [U+2B70-U+2B73], [U+2B7A-U+2B7D], [U+2B80-U+2B87], {U+2B95}, [U+2BA0-U+2BAF], {U+2BB8}", 'A'),
      # 109 entries (32 Unicode ranges) in infix form:
      decode_ranges(
"{U+002B}, {U+002D}, {U+002F}, {U+00B1}, {U+00F7}, {U+0322}, {U+2044}, [U+2212-U+2216], [U+2227-U+222A], {U+2236}, {U+2238}, [U+228C-U+228E], [U+2293-U+2296], {U+2298}, [U+229D-U+229F], [U+22BB-U+22BD], [U+22CE-U+22CF], [U+22D2-U+22D3], [U+2795-U+2797], {U+29B8}, {U+29BC}, [U+29C4-U+29C5], [U+29F5-U+29FB], [U+2A1F-U+2A2E], [U+2A38-U+2A3A], {U+2A3E}, [U+2A40-U+2A4F], [U+2A51-U+2A63], {U+2ADB}, {U+2AF6}, {U+2AFB}, {U+2AFD}", 'B'),
      # 64 entries (33 Unicode ranges) in infix form:
      decode_ranges(
"{U+0025}, {U+002A}, {U+002E}, [U+003F-U+0040], {U+005E}, {U+00B7}, {U+00D7}, {U+0323}, {U+032E}, {U+2022}, {U+2043}, [U+2217-U+2219], {U+2240}, {U+2297}, [U+2299-U+229B], [U+22A0-U+22A1], {U+22BA}, [U+22C4-U+22C7], [U+22C9-U+22CC], [U+2305-U+2306], {U+27CB}, {U+27CD}, [U+29C6-U+29C8], [U+29D4-U+29D7], {U+29E2}, [U+2A1D-U+2A1E], [U+2A2F-U+2A37], [U+2A3B-U+2A3D], {U+2A3F}, {U+2A50}, [U+2A64-U+2A65], [U+2ADC-U+2ADD], {U+2AFE}", 'C'),
      # 7 entries (4 Unicode ranges) in infix form:
      decode_ranges("{U+005C}, {U+005F}, [U+2061-U+2064], {U+2206}", 'K'),
      # 3 entries in infix form:
      decode_ranges("U+002C, U+003A, U+003B", 'M'),
    },
    prefix => {
      # 52 entries (22 Unicode ranges) in prefix form:
      decode_ranges(
"{U+0021}, {U+002B}, {U+002D}, {U+00AC}, {U+00B1}, {U+0331}, {U+2018}, {U+201C}, [U+2200-U+2201], [U+2203-U+2204], {U+2207}, [U+2212-U+2213], [U+221F-U+2222], [U+2234-U+2235], {U+223C}, [U+22BE-U+22BF], {U+2310}, {U+2319}, [U+2795-U+2796], {U+27C0}, [U+299B-U+29AF], [U+2AEC-U+2AED]", 'D'),
      # 30 entries in prefix form:
      decode_ranges(
"U+0028, U+005B, U+007B, U+007C, U+2016, U+2308, U+230A, U+2329, U+2772, U+27E6, U+27E8, U+27EA, U+27EC, U+27EE, U+2980, U+2983, U+2985, U+2987, U+2989, U+298B, U+298D, U+298F, U+2991, U+2993, U+2995, U+2997, U+2999, U+29D8, U+29DA, U+29FC", 'F'),
      # 27 entries (2 Unicode ranges) in prefix form:
      decode_ranges("[U+222B-U+2233], [U+2A0B-U+2A1C]", 'H'),
      # 22 entries (6 Unicode ranges) in prefix form:
      decode_ranges(
        "[U+220F-U+2211], [U+22C0-U+22C3], [U+2A00-U+2A0A], [U+2A1D-U+2A1E], {U+2AFC}, {U+2AFF}", 'J'),
      # 6 entries (3 Unicode ranges) in prefix form:
      decode_ranges("[U+2145-U+2146], {U+2202}, [U+221A-U+221C]", 'L'),
    },
    postfix => {
      # 40 entries (21 Unicode ranges) in postfix form:
      decode_ranges(
"[U+0021-U+0022], [U+0025-U+0027], {U+0060}, {U+00A8}, {U+00B0}, [U+00B2-U+00B4], [U+00B8-U+00B9], [U+02CA-U+02CB], [U+02D8-U+02DA], {U+02DD}, {U+0311}, {U+0320}, {U+0325}, {U+0327}, {U+0331}, [U+2019-U+201B], [U+201D-U+201F], [U+2032-U+2037], {U+2057}, [U+20DB-U+20DC], {U+23CD}", 'E'),
      # 30 entries in postfix form:
      decode_ranges(
"U+0029, U+005D, U+007C, U+007D, U+2016, U+2309, U+230B, U+232A, U+2773, U+27E7, U+27E9, U+27EB, U+27ED, U+27EF, U+2980, U+2984, U+2986, U+2988, U+298A, U+298C, U+298E, U+2990, U+2992, U+2994, U+2996, U+2998, U+2999, U+29D9, U+29DB, U+29FD", 'G'),
      # 22 entries (13 Unicode ranges) in postfix form:
      decode_ranges(
"[U+005E-U+005F], {U+007E}, {U+00AF}, [U+02C6-U+02C7], {U+02C9}, {U+02CD}, {U+02DC}, {U+02F7}, {U+0302}, {U+203E}, [U+2322-U+2323], [U+23B4-U+23B5], [U+23DC-U+23E1]", 'I'),
      # additional range that the MathML Core spec handles in 'Step 2'
      decode_ranges("[U+1EEF0-U+1EEF1]", 'I'),
    },
  };

  #======================================================================
  # Figure 26 Operators values for each category.
  # The third column provides a 4-bit encoding of the categories
  # where the 2 least significant bits encode the form infix (0), prefix (1) and postfix (2).
  # Category Form Encoding rspace lspace properties
  $thin  = 0.167;    # 3 mu in ems
  $med   = 0.222;    # 4 mu
  $thick = 0.278;    # 5 mu
     # NOTE: The table headings lspace,rspace are swapped in the current CORE draft!!!! Report this!!!
  $Category_data = {
    Default      => { form => undef, encoding => undef, lspace => $thick, rspace => $thick },
    ForceDefault => { form => undef, encoding => undef, lspace => $thick, rspace => $thick },
    A => { form => 'infix',   encoding => 0x0, lspace => $thick, rspace => $thick, stretchy => 1 },
    B => { form => 'infix',   encoding => 0x4, lspace => $med,   rspace => $med },
    C => { form => 'infix',   encoding => 0x8, lspace => $thin,  rspace => $thin },
    D => { form => 'prefix',  encoding => 0x1, lspace => 0,      rspace => 0 },
    E => { form => 'postfix', encoding => 0x2, lspace => 0,      rspace => 0 },
    F => { form => 'prefix', encoding => 0x5, lspace => 0, rspace => 0, stretchy => 1, symmetric => 1 },
    G => { form => 'postfix', encoding => 0x6, lspace => 0, rspace => 0, stretchy => 1, symmetric => 1 },
    H => { form => 'prefix', encoding => 0x9, lspace => $thin, rspace => $thin, symmetric => 1, largeop => 1 },
    I => { form => 'postfix', encoding => 0xA, lspace => 0, rspace => 0, stretchy => 1 },
    J => { form => 'prefix', encoding => 0xD, lspace => $thin, rspace => $thin, symmetric => 1, largeop => 1, movablelimits => 1 },
    K => { form => 'infix',  encoding => 0xC,   lspace => 0,     rspace => 0 },
    L => { form => 'prefix', encoding => undef, lspace => $thin, rspace => 0 },
    M => { form => 'infix',  encoding => undef, lspace => 0,     rspace => $thin },
  };
  #======================================================================
}
1;
