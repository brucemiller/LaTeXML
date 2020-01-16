# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime::Strings                            | #
# | Runtime string functions                                            | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
package LaTeXML::Post::BiBTeX::Runtime::Strings;
use strict;
use warnings;

use base qw(Exporter);
our @EXPORT = qw(
  &addPeriod
  &splitLetters &splitSpecial &isSpecial
  &changeCase &getCase
  &textSubstring
  &textLength
  &textPrefix
  &textWidth
  &textPurify
);

###
### Adding periods
###

# takes a string and adds a ‘.’ to it
# if the last non-'}' character isn’t a ‘.’, ‘?’, or ‘!’, and pushes this resulting string.
# implements the add.period$ built-in
sub addPeriod {
    my ($string) = @_;

    # do not add a period if the string is empty
    return "" if $string eq "";

    # find the last character that is not a '}'
    my ($match) = ( $string =~ m/(.)(?:\})*$/ );

    # and add a '.' if it's not punctiation
    unless ( $match && ( $match eq '!' or $match eq '.' or $match eq '?' ) ) {
        return $string . '.';
    }
    else {
        return $string;
    }
}

###
### Splitting text into characters
###

# splits text into an array of semantic characters (i.e. including accents).
# includes a second array, stating the level of each characters
sub splitLetters {
    my ($string) = @_;

    # split the string into characters
    my @characters = split( //, $string );

    # current letter and brace level
    my ( $buffer, $hadLetter, $level ) = ( '', 0, 0 );
    my @letters = ('');
    my @levels  = (0);

    my $char;
    while ( defined( $char = shift(@characters) ) ) {
        if ( $char eq '{' ) {
            $level++;
            if ( $level eq 1 ) {

         # if the next character is a \, then we need to go into accent handling
         # and read up until the end of the accent.
                $char = shift(@characters);
                if ( defined($char) && $char eq '\\' ) {
                    $buffer = '{\\';

                    # read characters until we are balanced again
                    while ( defined( $char = shift(@characters) ) ) {
                        $buffer .= $char;
                        $level++ if $char eq '{';
                        $level-- if $char eq '}';
                        last     if $level eq 0;
                    }

                    # push the collected 'accent' and go back into normal mode
                    shift(@letters) unless $hadLetter;
                    shift(@levels)  unless $hadLetter;
                    push( @letters, $buffer );
                    push( @levels, isSpecial($buffer) ? 0 : 1 );
                    $hadLetter = 1;
                    next;
                }

                unshift( @characters, $char ) if defined($char);
                $char = '{';
            }

            # for nested opening braces
            # add to the previous one
            if ( $hadLetter && substr( $letters[-1], -1 ) eq '{' ) {
                $letters[-1] .= '{';
                $levels[-1] = $level;

            }
            else {
                # create a new opening statement
                shift(@letters) unless $hadLetter;
                shift(@levels)  unless $hadLetter;
                push( @letters, $char );
                push( @levels,  $level );
                $hadLetter = 1;
            }

        }
        elsif ( $char eq '}' ) {

            # if we have a closing brace, just add it to the previous one
            # and decrease the level (but never go negative)
            $letters[-1] .= '}';
            $hadLetter = 1;
            $level-- unless $level eq 0;
        }

        elsif ( $hadLetter && substr( $letters[-1], -1 ) eq '{' ) {

            # if we had an opening brace, append to it
            $letters[-1] .= $char;

        }
        else {
            # else push a normal character
            shift(@letters) unless $hadLetter;
            shift(@levels)  unless $hadLetter;
            push( @letters, $char );
            push( @levels,  $level );
            $hadLetter = 1;
        }
    }

    my @theletters = ();
    my @thelevels  = ();

    my $letter;
    while ( defined( $letter = shift(@letters) ) ) {
        $level = shift(@levels);

        # if we have a letter that is only braces
        if ( $letter =~ /^[\{\}]*$/ ) {

            # then try and prepend to the next letter
            if ( scalar(@letters) ne 0 ) {
                $letters[0] = $letter . $letters[0];

                # or the last letter in the output
            }
            elsif ( scalar(@theletters) ne 0 ) {
                $theletters[-1] .= $letter;

                # if we don't have anything, then only push the letter
                # so that scalar(@levels) still indiciates the string length
            }
            else {
                push( @theletters, $letter );
            }
        }
        else {
            push( @theletters, $letter );
            push( @thelevels,  $level );
        }

    }
    return [@theletters], [@thelevels];
}


# 'splitSpecial' splits a string starting with a potentially special character and returns a 4-tuple ($isSpecial, $head, $tail, $command) where
# - $isSpecial: 1 when the string starts with something that looks like a command sequence, 0 when not
# - $head:     Part of the first letter of the string that is not affected by case-sensitivity. 
# - $tail:     Part of the first letter which are affected by case-sensitivity and remaining letters.
# - $command:  Either 'undef' or one of the special known accented command sequences.
# For any input, $head . $tail will always equal $string. 
sub splitSpecial {
    my ($string) = @_;

    # if we do not have an accent, don't parse it
    return 0, '', $string, undef unless $string =~ /^[\{\}]*\{\\/;

    # split into head + tail, but keep the command
    my ($head, $tail, $command) = $string =~ m/^([\{\}]*\{\\)(([^\{\}\s]+).*)$/;

    $command =~ s/[^a-zA-Z]//g;
    unless ($command eq "i" ||
        $command eq "j" ||
        $command eq "oe" ||
        $command eq "OE" ||
        $command eq "ae" ||
        $command eq "AE" ||
        $command eq "aa" ||
        $command eq "AA" ||
        $command eq "o" ||
        $command eq "O" ||
        $command eq "l" ||
        $command eq "L" ||
        $command eq "ss"
    ) {
        # We do not have a known command sequence, hence it should not change case and be a part of the 'head'
        ($command, $tail) = $tail =~ m/^([a-zA-Z]*[\s\{\}]*)(.*)$/; # split off leading command sequence
        $head .= $command;
        $command = undef;
    }

    return 1, $head, $tail, $command;
}

# isSpecial checks if a character is 'special' according to the 'splitSpecial function'.
sub isSpecial {
    my ($string) = @_;
    return $string =~ /^[\{\}]*\{\\/;
}

###
### Changing case of a string
###

# known accent control sequences
my %ACCENT_SEQUENCES = (
    'i' => 1, 
    'j' => 1, 
    'oe' => 1, 
    'OE' => 1, 
    'ae' => 1, 
    'AE' => 1, 
    'aa' => 1, 
    'AA' => 1, 
    'o' => 1, 
    'O' => 1, 
    'l' => 1, 
    'L' => 1, 
    'ss' => 1
);


# Changes the case of $string according to $spec
# - if $spec is 't', then upper-case the first character and lower-case the rest
# - if $spec is 'u' then upper-case everything
# - if $spec is 'l' then lower-case everything
# This implements the change.case$ built-in.

sub changeCase {
    my ($string, $conversion_type) = @_;

    # This code has been roughly adapted from 'bibtex.web', and in principle works as follows: 
    # 1. split() the string into a character array
    # 2. Iterate through the array of characters
    # 3. Convert the values in the array in place
    # 4. join() the array back into a single string

    # check that we have one of the three known conversion types
    $conversion_type = lc $conversion_type;
    return unless (
        $conversion_type eq 'l' ||
        $conversion_type eq 'u' ||
        $conversion_type eq 't'
    );

    my @chars = split( //, $string ); # array of characters (ex_buf in the original source)
    my $char_ptr = 0;   # current index into the character array (ex_buf_ptr in the original source)
    my $chars_xptr = 0; # beginning of control sequence (not always set, ex_buf_xptr in the original source)
    my $chars_length = scalar(@chars); # number of chars (ex_buf_len in the original source)

    my $brace_level = 0; # the current brace_level
    my $prev_colon = 0; # are we following a colon (only relevant for 't' case)

    # Iterate over the character array
    while($char_ptr < $chars_length) {

        if($chars[$char_ptr] eq '{') {

            $brace_level++;

            # When opening a new brace the brace level increases and we need to consider accents and commands. 
            # This large if statement checks that all the conditions for an 'accent' or 'command' are fullfilled
            if(
                ($brace_level != 1) || # only on level 1!
                (($char_ptr + 4 > $chars_length) || ($chars[$char_ptr+1] ne '\\')) || # we don't have anything that could be a command

                # in title case, we need to be at the beginning of the string or following a colon
                (
                    ($conversion_type eq 't') &&
                    (($char_ptr == 0) || (($prev_colon) && ($chars[$char_ptr-1] =~ /\s/)))
                )
            ) {
                # In the original source this is handled with a goto ok_pascal_i_give_up. 
                # To be slightly cleaner we inline the code. 
                $prev_colon = 0;
                $char_ptr++;
                next;
            }
            $char_ptr++;
            
            # All the conditions are fullfilled, we can now convert the control sequence or special character. 
            while (($char_ptr < $chars_length) && ($brace_level > 0)) {
                
                # the control sequence starts here, but we can skip the '\'
                $char_ptr++;
                $chars_xptr = $char_ptr;

                # scan the title of the control sequence (with alphabetical characters)
                my $ctrl_sequence = '';
                while (($char_ptr < $chars_length) && ($chars[$char_ptr] =~ /[a-zA-Z]/)) {
                    $ctrl_sequence .= $chars[$char_ptr];
                    $char_ptr++;
                }

                # If the control sequence is a special 'accented' control sequence
                # convert the accented or foreign character            
                if(defined($ACCENT_SEQUENCES{$ctrl_sequence})) {

                    # 'l' || 't' => convert the upper accents to lower ones
                    # leave the rest of them alone. 
                    unless($conversion_type eq 'u') {
                        if(
                            $ctrl_sequence eq 'L'  ||
                            $ctrl_sequence eq 'O'  ||
                            $ctrl_sequence eq 'OE' ||
                            $ctrl_sequence eq 'AE' ||
                            $ctrl_sequence eq 'AA') {
                                foreach my $i ($chars_xptr..$char_ptr-1) {
                                    $chars[$i] = lc($chars[$i]);
                                }
                        }
                    # 'u'
                    } else {

                        # these sequences have an uppercase equivalent
                        if(
                            $ctrl_sequence eq 'l'  ||
                            $ctrl_sequence eq 'o'  ||
                            $ctrl_sequence eq 'oe' ||
                            $ctrl_sequence eq 'ae' ||
                            $ctrl_sequence eq 'aa') {
                                foreach my $i ($chars_xptr..$char_ptr-1) {
                                    $chars[$i] = uc($chars[$i]);
                                }
                        # these sequences do not have an uppercase equivalent
                        # hence convert, then remove the control sequence
                        } elsif(
                            $ctrl_sequence eq 'i'  ||
                            $ctrl_sequence eq 'j'  ||
                            $ctrl_sequence eq 'ss') {

                                # convert it to uppercase
                                foreach my $i ($chars_xptr..$char_ptr-1) {
                                    $chars[$i] = uc($chars[$i]);
                                }

                                # remove the '\\'
                                $chars[$chars_xptr-1] = '';
                                $chars_xptr = $char_ptr - 1;

                                # remove any trailing spaces
                                while (($char_ptr < $chars_length) && ($chars[$char_ptr] =~ /\s/)) {
                                    $chars[$char_ptr] = '';
                                    $char_ptr++;
                                }

                                # and reset $char_ptr
                                $char_ptr = $chars_xptr;
                        }
                    }
                }

                $chars_xptr = $char_ptr;
                
                # scan until the next control sequence
                while (($char_ptr < $chars_length) && ($brace_level > 0) && ($chars[$char_ptr] ne '\\')) {
                    if ($chars[$char_ptr] eq '}') {
                        $brace_level--;
                    } elsif ($chars[$char_ptr] eq '{') {
                        $brace_level++;
                    }
                    $char_ptr++;   
                }

                # and convert it
                unless ($conversion_type eq 'u') {
                    foreach my $i ($chars_xptr..$char_ptr-1) {
                        $chars[$i] = lc($chars[$i]);
                    }
                } else {
                    foreach my $i ($chars_xptr..$char_ptr-1) {
                        $chars[$i] = uc($chars[$i]);
                    }
                }
            }
            
            # unskip the right closing '}'
            $char_ptr--;
            $prev_colon = 0;
        
        # whenever we have a closing brace, decrease the level
        } elsif ($chars[$char_ptr] eq '}' ) {
            $brace_level-- unless $brace_level eq 0;
            $prev_colon = 0;
        
        } elsif ($brace_level == 0) {
            # Now convert a brace_level = 0 character
            if ($conversion_type eq 't') {

                # for 't', we need to convert to lowercase
                # if we are either at the first character, or we are following a colon + whitespace
                unless (
                    ($char_ptr == 0) ||
                    ($prev_colon) && ($chars[$char_ptr-1] =~ /\s/)
                ) {
                    $chars[$char_ptr] = lc($chars[$char_ptr]);
                }

                # for the next iteration, we need to know if there was a ':'. 
                if ($chars[$char_ptr] eq ':') {
                    $prev_colon = 1
                
                # reset the flag only if we didn't have any whitespace
                } elsif (!($chars[$char_ptr] =~ /\s/)) {
                    $prev_colon = 0;
                }
            } elsif ($conversion_type eq 'l') {
                $chars[$char_ptr] = lc($chars[$char_ptr]);
            } elsif ($conversion_type eq 'u') {
                $chars[$char_ptr] = uc($chars[$char_ptr]);
            }
        }
        $char_ptr++;
    }
    
    return join('', @chars);
}

# 'getCase' gets the case of word, that it returns either 'l' for lowercase or 'u' for uppercase. 
# If no character exists, returns 'l'.
sub getCase {
    my ($string, $isSpecial, $head, $tail, $command) = @_;
    
    # keep working on the first letter of the string
    while(length($string) > 0) {
        # if we have a letter in the front, work with it
        return 'u' if($string =~ /^[A-Z]/);
        return 'l' if ($string =~ /^[a-z]/);
        
        # if we have a special character, ignore the head
        ($isSpecial, $head, $tail, $command) = splitSpecial($string);
        if ($isSpecial) {
            $string = $tail;
            next;
        }

        # parse a non-accent braced string
        ($head, $tail) = $string =~ m/^{([^}]+)\}(.*)$/;
        if(defined($head) || defined($tail)) {
            return 'u' if(defined($head) && $head =~ /[a-zA-Z]/); # if it has some letters, we have an uppercase character
            $string = $tail; # else skip it
            next;
        }
        
        $string = substr($string, 1); # ignore this character, it's not a letter
    }

    # there were no letters at all
    return 'l';
}

###
### Text Length, Width and substring
###

# 'textLength' counts the text-length of a string and implements text.length$
sub textLength {

# This code is a somewhat optimized inline version of:
# my ( $letters, $levels ) = splitLetters(@_);
# return scalar(@$levels);
# It saves on a second loop iteration and some parsing that is only needed for 'levels'

    # split the string into characters
    my ($string) = @_;
    my @characters = split( //, $string );

    # current letter and brace level
    my ( $buffer, $hadLetter, $level ) = ( '', 0, 0 );
    my @letters = ('');
    my @levels  = (0);

    my $char;
    while ( defined( $char = shift(@characters) ) ) {
        if ( $char eq '{' ) {
            $level++;
            if ( $level eq 1 ) {

         # if the next character is a \, then we need to go into accent handling
         # and read up until the end of the accent.
                $char = shift(@characters);
                if ( defined($char) && $char eq '\\' ) {
                    $buffer = '{\\';

                    # read characters until we are balanced again
                    while ( defined( $char = shift(@characters) ) ) {
                        $buffer .= $char;
                        $level++ if $char eq '{';
                        $level-- if $char eq '}';
                        last     if $level eq 0;
                    }

                    # push the collected accent and go back into normal mode
                    shift(@letters) unless $hadLetter;
                    push( @letters, $buffer );
                    $hadLetter = 1;
                    next;
                }

                unshift( @characters, $char ) if defined($char);
                $char = '{';
            }

            # for nested opening braces
            # add to the previous one
            if ( $hadLetter && substr( $letters[-1], -1 ) eq '{' ) {
                $letters[-1] .= '{';
                $levels[-1] = $level;

            }
            else {
                # create a new opening statement
                shift(@letters) unless $hadLetter;
                push( @letters, $char );
                $hadLetter = 1;
            }

        }
        elsif ( $char eq '}' ) {

            # if we have a closing brace, just add it to the previous one
            # and decrease the level (but never go negative)
            $letters[-1] .= '}';
            $hadLetter = 1;
            $level-- unless $level eq 0;
        }

        elsif ( $hadLetter && substr( $letters[-1], -1 ) eq '{' ) {

            # if we had an opening brace, append to it
            $letters[-1] .= $char;
        }
        else {
            # else push a normal character
            shift(@letters) unless $hadLetter;
            push( @letters, $char );
            $hadLetter = 1;
        }
    }

    # iterate and skip over non-leading brace-only letters
    my $letter;
    my $count = 0;
    while ( defined( $letter = shift(@letters) ) ) {
        $count++
          unless ( $letter =~ /^[\{\}]*$/
            && ( $count == 0 || scalar(@letters) == 0 ) );
    }
    return $count;
}

# returns the prefix of length $length of a string
# implements text.prefix$
sub textPrefix {
    my ( $string,  $length ) = @_;
    my ( $letters, $levels ) = splitLetters($string);

    # read a prefix of the string
    my $index  = 0;
    my $result = '';
    foreach my $letter (@$letters) {
        $result .= $letter;
        $index++;
        last if $index eq $length;
    }

    # balance brackets magically
    my $level = () = ( $result =~ /{/g );
    $level -= () = ( $result =~ /}/g );
    $result .= ( '}' x $level ) if ( $level >= 0 );

    return $result;
}

# table adpoted from
# https://metacpan.org/source/NODINE/Text-BibTeX-BibStyle-0.03/lib/Text/BibTeX/BibStyle.pm
# contains widths of accents and basic characters
our %WIDTHS = (
    0040 => 278,
    0041 => 278,
    0042 => 500,
    0043 => 833,
    0044 => 500,
    0045 => 833,
    0046 => 778,
    0047 => 278,
    0050 => 389,
    0051 => 389,
    0052 => 500,
    0053 => 778,
    0054 => 278,
    0055 => 333,
    0056 => 278,
    0057 => 500,
    0060 => 500,
    0061 => 500,
    0062 => 500,
    0063 => 500,
    0064 => 500,
    0065 => 500,
    0066 => 500,
    0067 => 500,
    0070 => 500,
    0071 => 500,
    0072 => 278,
    0073 => 278,
    0074 => 278,
    0075 => 778,
    0076 => 472,
    0077 => 472,
    0100 => 778,

    # A-Z
    0101 => 750,
    0102 => 708,
    0103 => 722,
    0104 => 764,
    0105 => 681,
    0106 => 653,
    0107 => 785,
    0110 => 750,
    0111 => 361,
    0112 => 514,
    0113 => 778,
    0114 => 625,
    0115 => 917,
    0116 => 750,
    0117 => 778,
    0120 => 681,
    0121 => 778,
    0122 => 736,
    0123 => 556,
    0124 => 722,
    0125 => 750,
    0126 => 750,
    0127 => 1028,
    0130 => 750,
    0131 => 750,
    0132 => 611,

    0133 => 278,
    0134 => 500,
    0135 => 278,
    0136 => 500,
    0137 => 278,
    0140 => 278,

    # a-z
    0141 => 500,
    0142 => 556,
    0143 => 444,
    0144 => 556,
    0145 => 444,
    0146 => 306,
    0147 => 500,
    0150 => 556,
    0151 => 278,
    0152 => 306,
    0153 => 528,
    0154 => 278,
    0155 => 833,
    0156 => 556,
    0157 => 500,
    0160 => 556,
    0161 => 528,
    0162 => 392,
    0163 => 394,
    0164 => 389,
    0165 => 556,
    0166 => 528,
    0167 => 722,
    0170 => 528,
    0171 => 528,
    0172 => 444,
    0173 => 500,
    0174 => 1000,
    0175 => 500,
    0176 => 500,

    aa   => 500,
    AA   => 750,
    o    => 500,
    O    => 778,
    l    => 278,
    L    => 625,
    ss   => 500,
    ae   => 722,
    oe   => 778,
    AE   => 903,
    OE   => 1014,
    '?`' => 472,
    '!`' => 278,
);

# compute the width of text in hundredths of a point, as specified by the June 1987 version of the cmr10 font
# implements width$
sub textWidth {
    my ($string) = @_;
    my ( $letters, $levels ) = splitLetters($string);

    # iterate over each of the letters
    my $width = 0;
    my @characters;
    my (
        $isSpecial, $head, $tail, $command, $level
    );

    foreach my $letter (@$letters) {
        $level = shift(@$levels);


        # on level 0 we want to check for special characters
        if ( defined($level) && $level eq 0 ) {
            (
                $isSpecial, $head, $tail, $command
            ) = splitSpecial($letter);

            if(defined($command)) {
                $width += $WIDTHS{$command} || 0;
                next;
            }
            if($isSpecial) {
                $tail =~ s/\}$//;
                $letter = $tail;
            }
        }
        
        # for all other cases, we add up the width of each character in the letters
        $width += ($WIDTHS{ord $_} || 500) foreach (split( //, $letter ));
    }
    return $width;
}

# returns the prefix of length $length of a string
# implements substring$
sub textSubstring {
    my ( $string, $start, $length ) = @_;

    # if we have a non-negative start, the indexes are straightforward
    return substr( $string, $start - 1, $length ) if $start > 0;

    # else we have a substring of length  ending at index $start
    $start = length($string) + $start - $length + 1;
    if ( $start < 0 ) {
        $length += $start;
        $start = 0;
    }
    return substr( $string, $start, $length );
}

###
### Purification
###

# purifies text to be used for sorting
# implements purify$
sub textPurify {
    my ($string) = @_;
    my ( $letters, $levels ) = splitLetters($string);

    # iterate over each of the letters
    my $purified = '';
    my @characters;
    my (
        $isSpecial, $head, $tail, $command, $level
    );
    foreach my $letter (@$letters) {
        $level = shift(@$levels);

        # on level 0, check for accents
        if ( defined($level) && $level eq 0 ) {

            # parse the accent
            (
                $isSpecial, $head, $tail, $command
            ) = splitSpecial($letter);

            # if we have one of the known command, transfer those into the appropriate ones
            if (defined($command)){
                # if it is one of the special commands, use their complete commands
                if(
                    $command eq 'oe' ||
                    $command eq 'OE' ||
                    $command eq 'ae' ||
                    $command eq 'AE' ||
                    $command eq 'ss'
                ) {
                    $purified .= $command;
                
                # else just use the first one
                } else {
                    $purified .= substr($command, 0, 1);
                }

            # if we had a command, but it was not one of the ones we knew
            # then just reproduce the argument
            }
            elsif ($isSpecial) {
                $tail =~ s/[^a-zA-Z0-9 ]//g; # side-effect: lowercase everything
                $purified .= $tail;

            # else replace as if we were on level 1
            }
            else {
                $letter =~ s/[\s\-~]/ /g;
                $letter =~ s/[^a-zA-Z0-9 ]//g;
                $purified .= $letter;
            }

# on level 1+, we replace all the - and ~s with spaces, and apart from those keep only spaces
        }
        else {
            $letter =~ s/[\s\-~]/ /g;
            $letter =~ s/[^a-zA-Z0-9 ]//g;
            $purified .= $letter;
        }
    }
    return $purified;
}

1;
