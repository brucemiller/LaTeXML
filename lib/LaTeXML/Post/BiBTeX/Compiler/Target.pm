# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Compiler::Target                            | #
# | Compilation Target Implementation                                   | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Compiler::Target;
use strict;
use warnings;

# This file contains reusable functions that translate the AST to Perl Code.

# makeIndent($level) - make indent of a given level
# - $indent:   integer, indicating level of indent to make
sub makeIndent { '  ' x $_[1]; }

# character escapes for all the names
# we use 'Z' as an escape character, and everything after it has special meaning
our %ESCAPES = (

    # numbers
    '0' => '0',
    '1' => '1',
    '2' => '2',
    '3' => '3',
    '4' => '4',
    '5' => '5',
    '6' => '6',
    '7' => '7',
    '8' => '8',
    '9' => '9',

    # small letters
    'a' => 'a',
    'b' => 'b',
    'c' => 'c',
    'd' => 'd',
    'e' => 'e',
    'f' => 'f',
    'g' => 'g',
    'h' => 'h',
    'i' => 'i',
    'j' => 'j',
    'k' => 'k',
    'l' => 'l',
    'm' => 'm',
    'n' => 'n',
    'o' => 'o',
    'p' => 'p',
    'q' => 'q',
    'r' => 'r',
    's' => 's',
    't' => 't',
    'u' => 'u',
    'v' => 'v',
    'w' => 'w',
    'x' => 'x',
    'y' => 'y',
    'z' => 'zz',

    # capital letters
    'A' => 'A',
    'B' => 'B',
    'C' => 'C',
    'D' => 'D',
    'E' => 'E',
    'F' => 'F',
    'G' => 'G',
    'H' => 'H',
    'I' => 'I',
    'J' => 'J',
    'K' => 'K',
    'L' => 'L',
    'M' => 'M',
    'N' => 'N',
    'O' => 'O',
    'P' => 'P',
    'Q' => 'Q',
    'R' => 'R',
    'S' => 'S',
    'T' => 'T',
    'U' => 'U',
    'V' => 'V',
    'W' => 'W',
    'X' => 'X',
    'Y' => 'Y',
    'Z' => 'ZZ',

    # special characters
    '_' => '_',
    '.' => 'Zo',
    '$' => 'Zs',
    '>' => 'Zg',
    '<' => 'Zl',
    '=' => 'Ze',
    '+' => 'Zp',
    '-' => 'Zm',
    '*' => 'Za',
    ':' => 'Zc',
);

# escape the name of a function or variable for use as the name
# of a subrutine in generated perl code
sub escapeName {
    my ( $class, $name ) = @_;
    my $result = '';
    my @chars = split( //, $name );
    foreach my $char (@chars) {
        if ( defined( $ESCAPES{$char} ) ) {
            $result .= $ESCAPES{$char};
        }
        else {
            $result .= 'Z' . ord($char) . 'Z';
        }
    }
    return $result;
}

# escapeBuiltinName($name) - escapes the name of a built-in function
# - $name:  the name of the function to be escaped
sub escapeBuiltinName {
    my ( $class, $name ) = @_;

    # we can remove some more relax encoding
    # because we know that the symbols are going to be rather contained
    $name =~ s/\$$//g;             # remove trailing '$'s
    $name =~ s/\.(.)/uc($1)/ge;    # change period seperator to CamelCase
    $name =~ s/^(.)/uc($1)/e;      # upper-case the first letter

    # finally we still need to escape all our characters (just because)
    'builtin' . escapeName( $class, $name );
}

# escapeFunctionName($name) - escapes the name of a user-defined function
# - $name:  the name of the function to be escaped
sub escapeFunctionName { 'bst__' . escapeName(@_); }

# escapeString($string) - escapes a string constant
# - $string:    the string to be escaped
sub escapeString {
    my ( $class, $string ) = @_;
    $string =~ s/\\/\\\\/g;          # escape \ as \\
    $string =~ s/'/\\'/g;            # escape ' as \'
    return '\'' . $string . '\'';    #  surround in single quotes
}

# escapeInteger($name) - escapes an integer
# - $integer:    the integer to be escaped
sub escapeInteger {
    my ( $class, $integer ) = @_;
    return '' . $integer;    # just turn it into a string
}

# escapeUsrFunctionReference($name) - escapes the reference to a usr-defined function
# - $name:    the (escaped) name of the bst function to call
sub escapeUsrFunctionReference {
    my ( $class, $name ) = @_;
    return '$' . $name;    # we need a perl function reference
}

# escapeBstFunctionReference($name) - escapes the reference to a bst-level (i.e. builtin) function reference
# - $name:    the (escaped) name of the bst function to call
sub escapeBstFunctionReference {
    my ( $class, $name ) = @_;
    return '\\&' . $name;    # we need a perl function reference
}

# escapeBstInlineBlock($block, $sourceString, $outerIndent, $innerIndent) - escapes the definition of a bst-inline block
# - $block:         the (compiled) body of the block to define
# - $sourceString:  the StyString this inline function was defined from
# - $outerIndent:   the (generated) outer indent, for use in multi-line outputs
# - $innerIndent:   the (generated) inner indent, for use in multi-line outputs
sub escapeBstInlineBlock {
    my ( $class, $block, $sourceString, $outerIndent, $innerIndent ) = @_;
    my $code = "sub { \n";
    $code .=
      $innerIndent . 'my ($context, $config) = @_; ' . "\n";
    $code .= $block . $outerIndent . '}';
    return $code;
}

# bstFunctionDefinition($name, $name, $sourceString, $body, $outerIndent, $innerIndent) - escapes the definition to a bst function
# - $name:          the (unescaped) name of the bst function to define
# - $sourceString:  the StyString this function was defined from
# - $body:          the (compiled) body of the function to define
# - $outerIndent:   the (generated) outer indent, for use in multi-line outputs
# - $innerIndent:   the (generated) inner indent, for use in multi-line outputs
sub bstFunctionDefinition {
    my ( $class, $name, $sourceString, $body, $outerIndent, $innerIndent ) = @_;
    my $code = 'my $' . $class->escapeFunctionName($name) . " = sub { \n";
    $code .=
      $innerIndent . 'my ($context, $config) = @_; ' . "\n";
    $code .= $body . $outerIndent . "}; \n";

    # perl-specific runtime-call
    $code .= $outerIndent
      . $class->runtimeFunctionCall(
        'registerFunctionDefinition',
        $sourceString,
        $class->escapeString($name),
        $class->escapeUsrFunctionReference( $class->escapeFunctionName($name) )
      ) . "; ";
    return $code;
}

# usrFunctionCall($name, $sourceString, @arguments) - compiles a call to a user-defined function
# - $name:          the name of the runtime function to call
# - $sourceString:  the StyString this call was made from
# - @arguments:     a set of appropriatly escaped arguments to give to the call
sub usrFunctionCall {
    my ( $class, $name, $sourceString, @arguments ) = @_;
    my $call = join( ", ", @arguments, $sourceString->stringify );
    return "\$$name->(\$context, \$config, " . $call . '); ';
}

# bstFunctionCall($name, $sourceString, @argument) - compiles a call to a bst-level function
# - $name:          the name of the bst function to call
# - $sourceString:  the StyString this call was made from
# - @arguments:     a set of appropriatly escaped arguments to give to the call
sub bstFunctionCall {
    return runtimeFunctionCall(@_);
}

# runtimeFunctionCall($name, $sourceString, @arguments) - compiles a call to function in the runtime
# - $name:          the name of the runtime function to call
# - $sourceString:  the StyString this call was made from
# - @arguments:     a set of appropriatly escaped arguments to give to the call
sub runtimeFunctionCall {
    my ( $class, $name, $sourceString, @arguments ) = @_;
    my $call = join( ", ", @arguments, $sourceString->stringify );
    return "$name(\$context, \$config, " . $call . '); ';
}

# wrapProgram($program, $name) - function used to wrap a compiled program
# - $program:      the compiled program
# - $name:         the (string escaped) file name of the program to be compiled
sub wrapProgram {
    my ( $class, $program, $name ) = @_;

    my $code = "sub { \n";
    $code .=
      $class->makeIndent(1) . "# code automatically generated by BiBTeXML \n";
    $code .= $class->makeIndent(1) . 'use LaTeXML::Post::BiBTeX::Runtime; ' . "\n";
    $code .= $class->makeIndent(1) . 'my ($context, $config) = @_; ' . "\n";
    $code .= $class->makeIndent(1) . '$config->setName(' . $name . '); ' . "\n";
    $code .= $program;
    $code .= "\n\n";
    $code .= $class->makeIndent(1) . 'return $context; ' . "\n";
    $code .= $class->makeIndent(1) . "# end of automatically generated code \n";
    $code .= "}";

    return $code;
}

1;
