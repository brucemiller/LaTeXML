# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime::Names                              | #
# | Runtime name parsing / processing functions                         | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef Subroutines::RequireArgUnpacking);

package LaTeXML::Post::BiBTeX::Runtime::Names;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Runtime::Strings;

use base qw(Exporter);
our @EXPORT = qw(
  &splitNames &numNames
  &splitNameParts &splitNameWords
  &abbrevName &formatNameSubpattern &formatName
);

###
### Splitting a list of names
###

# 'splitNames' splits a string into a list of names.
# Multiple names are seperated by 'and's at brace level 0.
sub splitNames {
  my ($string) = @_;
  my $level    = 0;
  my $buffer   = '';
  my @result   = ('');
  my @cache;
  my $character;
  # accumalate entries inside of a buffer
  # and then split the buffer, once we reach a non-zero level
  my @characters = split(//, $string);
  while (defined($character = shift(@characters))) {
    if ($level == 0) {
      $buffer .= $character;
      if ($character eq '{') {
        @cache = split(/\sand\s/, $buffer);
        $result[-1] .= shift(@cache);
        push(@result, @cache);
        # clear the buffer
        $buffer = '';
        $level++; } }
    else {
      $level++ if $character eq '{';
      $level-- if $character eq '}';
      # because we do not split
      # do not add to the buffer but into the last character
      $result[-1] .= $character; } }
  # split the buffer and put it into result
  if ($buffer) {
    @cache = split(/\sand\s/, $buffer);
    $result[-1] .= shift(@cache);
    push(@result, @cache); }
  # and return the results
  return @result; }

# 'numNames' counts the number of names in a given string and implements num.names$
# This corresponds to the number of times the word 'and' surrounded by spaces occors at brace level 0
sub numNames {
  return scalar(splitNames(@_)); }

###
### Splitting a single name
###

# 'splitNameParts' splits a name into the first, von, jr and last parts.
sub splitNameParts {
  my ($string) = @_;
  # split the name into words
  my ($pre, $mid, $post) = splitNameWords($string);
  my @prec  = @$pre;
  my @midc  = @$mid;
  my @postc = @$post;
  # prepare all the parts
  my @first = ();
  my @von   = ();
  my @jr    = ();
  my @last  = ();
  # start by splitting off everything except for 'von Last'
  # which we will both store in @von for now (and split below)
  my $word;
  my $gotlower = 0;
  # Style (i): "First von Last"
  if (scalar(@midc) == 0 && scalar(@postc) == 0) {
    # if we only have upper case letters, they are all last names
    while (defined($word = shift(@prec))) {
      # if we encounter a lower-case, everything before that is first name
      # and everything including and after it is "von Last"
      if (getCase($word) eq 'l') {
        $gotlower = 1;
        @first    = @von;
        @von      = ($word, @prec);
        last; }
      push(@von, $word); }
    # if we did not get any lower-case words
    # then the last word is the last name
    # and the rest the first name.
    unless ($gotlower) {
      @first = @von;
      @von   = pop(@first); }
    # we did not get any words in the 'von Last' part
    # so that the last of the first name
    if (scalar(@von) == 0) {
      push(@von, pop(@first)); } }
  # Style (ii): "von Last, First"
  elsif (scalar(@postc) == 0) {
    @von   = @prec;
    @first = @midc; }
  # Style (iii): "von Last, Jr, First"
  else {
    @von   = @prec;
    @jr    = @midc;
    @first = @postc; }
  my $haslast = 0;
  # we now split the "von Last" part
  while ($word = pop(@von)) {
    # find the last small word and push it into last
    if ($haslast && getCase($word) eq 'l') {
      push(@von, $word);
      last; }
    # push all the big words from 'von' into 'last'
    else {
      unshift(@last, $word);
      $haslast = 1; } }
  # If the Last part follows the '-' character
  # then that part belongs to the last part too
  if (scalar(@von) == 0 && scalar(@last) > 0) {
    while (scalar(@first) && substr($first[-1], -1, 1) eq '-') {
      $last[0] = pop(@first) . $last[0]; } }
  return [@first], [@von], [@jr], [@last]; }

# 'splitNameWords' splits a single name into three lists:
# one before all commas, one after the first one, one after the second one
sub splitNameWords {
  my ($string) = @_;
  # HACK HACK HACK we want to support things without a comma
  # for now we forcibly add a comma between them.
  # TODO: Do this later on fo
  $string =~ s/,(?!\s)/, /g;
  my $level  = 0;
  my $buffer = '';
  my @result = ('');
  my @cache;
  my $character;
  my @characters = split(//, $string);

  while (defined($character = shift(@characters))) {
    if ($level == 0) {
      $buffer .= $character;
      if ($character eq '{') {
        @cache = split(/[\s~-]+\K/, $buffer)
          ;    # use '\K' to split right *after* the match
        $result[-1] .= shift(@cache);
        push(@result, @cache);
        # clear the buffer
        $buffer = '';
        $level++; } }
    else {
      $level++ if $character eq '{';
      $level-- if $character eq '}';
      # because we do not split
      # do not add to the buffer but into the last character
      $result[-1] .= $character; } }
  # split the buffer and put it into result
  if ($buffer) {
    @cache = split(/[\s~-]+\K/, $buffer)
      ;    # use '\K' to split right *after* the match
    $result[-1] .= shift(@cache);
    push(@result, @cache); }
  my @precomma  = ();
  my @midcomma  = ();
  my @postcomma = ();
  my $pastcomma = 0;
  # iterate over our result array
  # and pop into the three appropriate lists
  my $seperator;
  while (defined($buffer = shift(@result))) {
    # split off everything except for the first seperator
    $buffer =~ s/([\s~-])[\s~-]*$/$1/;
    # we did not yet have a comma
    # so push everything into the first array
    # until we encounter a comma
    if ($pastcomma == 0) {
      if ($buffer =~ /,\s+$/) {
        $buffer =~ s/,\s+$//;
        push(@precomma, $buffer) if length($buffer) > 0;
        $pastcomma++; }
      else {
        push(@precomma, $buffer); } }
    # we had one comma

    elsif ($pastcomma == 1) {
      if ($buffer =~ /,\s+$/) {
        $buffer =~ s/,\s+$//;
        push(@midcomma, $buffer) if length($buffer) > 0;
        $pastcomma++; }
      else {
        push(@midcomma, $buffer); } }
    # we had a third comma
    else {
      push(@postcomma, $buffer); } }
  # and return the results
  return [@precomma], [@midcomma], [@postcomma]; }

###
### Formatting a name
###

# 'abbrevName' abbreviates a name and return's only it's first letter
sub abbrevName {
  my ($string) = @_;
  my ($letters, $levels) = splitLetters($string);
  # we return the first character which either
  # - is an accent
  # - contains an alphabetical character
  foreach my $letter (@$letters) {
    return $letter if isSpecial($letter);
    # else, return the first letter of it
    if ($letter =~ /[a-z]/i) {
      ($letter) = ($letter =~ m/([a-z])/i);
      return $letter; } }
  # we got no letter at all
  # not sure what to return here
  return undef; }

# 'formatNameSubpattern' formats a single name subpattern
sub formatNameSubpattern {
  my ($tokens, $abbrevName, $sep, $pre, $post) = @_;
  my $result = $pre;
  # If no explicit seperator was provided, we need to insert the default one.
  unless (defined($sep)) {
    my ($seperator, $isDefaultSeperator, $index) = ('', '', 0, 0);
    my $lastIndex = scalar(@$tokens) - 1;
    # iterate through all the names and fetch the seperators from the tokens themselves
    foreach my $part (@$tokens) {
      # cleanup this part of the name and seperator
      ($seperator) = ($part =~ m/([\s~-])$/);
      $part =~ s/([\s~-]+)$//;
      # abbreviate the current name if needed
      $part = abbrevName($part) if $abbrevName;
      # if we are at the last index, bail out
      if ($index == $lastIndex) {
        $result .= $part;
        last; }
      $part .= '.' if $abbrevName;
      # if we have a seperator character (which is '~' or '-') we want to use that
      if (defined($seperator) && ($seperator eq '~' || $seperator eq '-')) {
        $part .= $seperator; }
      elsif (($index == $lastIndex - 1) || ($index == 0 && textLength($pre . $part) <= 2)) {
        $part .= '~'; }
      else {
        $part .= ' '; }
      $result .= $part;
      $index++; } }
  else {
    # a token
    my @names = map { $_ =~ s/([\s~-]+)$//r; } @$tokens;
    @names = map { abbrevName($_) } @names if $abbrevName;
    $result .= join($sep, @names); }
  # append all the letters that are to be inserted after the actual tokens
  $result .= $post;
# handle a discretionary tilde:
# - if we have a single trailing ~, we remove it.
# - if we have two trailing ~s, we either replace it with a space (if the result is long enough), or we leave it untouched
# In some cases we get spaces even though we should have ~s and it is unclear as to why
  if ($result =~ /~$/) {
    $result =~ s/~$//;
    unless ($result =~ /~$/) {
      if (textLength($result) < 3) {
        $result .= '~'; }
      else {
        $result .= ' '; } } }
  return $result; }

# 'formatName' formats a single name according to a BiBTeX specification.
# Together with the functions above, it implements the format.name$ builtin.
sub formatName {
  my ($name, $spec) = @_;
  # split the specification and the name into parts
  my @characters = split(//, $spec);
  my ($first, $von, $jr, $last) = splitNameParts($name);
  # declare a lot of variables
  my ($character, $letter, $level, $partresult, $post, $result, $seperator, $short);
  my (@tokens);
  while (defined($character = shift(@characters))) {
    if ($character eq '{') {
      # iterate through the subpattern
      $partresult = '';
      while ($character = shift(@characters)) {
        # we finally hit the alphabetic character
        if ($character =~ /[a-z]/i) {
          # use the tokens for the current characters
          if    ($character eq 'f') { @tokens = @$first; }
          elsif ($character eq 'v') { @tokens = @$von; }
          elsif ($character eq 'j') { @tokens = @$jr; }
          elsif ($character eq 'l') { @tokens = @$last; }
          else                      { return undef, 'Invalid name part: ' . $character; }
          # read the next part
          $letter    = $character;
          $character = shift(@characters);
          return undef, 'Unexpected end of pattern'
            unless defined($character);
          # if we have the letter repeated, it is a long pattern
          if ($character =~ /[a-z]/i) {
            return undef,
              "Unexpected letter $character, $letter should be repeated. "
              unless $character eq $letter;
            $short     = 0;
            $character = shift(@characters);
            return 'Unexpected end of pattern'
              unless defined($character); }
          # else if must be a short pattern.
          else {
            $short = 1; }
          # if we have a '{', read the seperator
          $seperator = undef;
          if ($character eq '{') {
            $level     = 1;
            $seperator = '';
            while (defined($character = shift(@characters))) {
              $level++ if $character eq '{';
              $level-- if $character eq '}';
              last     if $level == 0;
              $seperator .= $character; } }
          else {
            unshift(@characters, $character); }
          # read whatever comes next until we are balaned again
          # until the closing '}' brace
          $post  = '';
          $level = 1;
          while (defined($character = shift(@characters))) {
            $level++ if $character eq '{';
            $level-- if $character eq '}';
            last     if $level == 0;
            $post .= $character; }
          # now format the current part according to what we read.
          unless (scalar(@tokens) == 0) {
            $partresult = formatNameSubpattern([@tokens], $short, $seperator, $partresult, $post); }
          else {
            $partresult = ''; }
          last; }
        elsif ($character eq '}') {
          # If we closed the part without having anything alphabetic then something weird is going on.
          # Fallback to inserting literally
          $partresult = '{' . $partresult . '}';
          last; }
        else {
          $partresult .= $character; } }
      $result .= $partresult; }
    else {
      # at the outer brace level, we insert characters unconditionally
      $result .= $character;
    } }
  return $result; }

1;
