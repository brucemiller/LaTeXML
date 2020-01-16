# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Compiler::Block                             | #
# | .bst compile block implementation                                   | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Compiler::Block;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Compiler::Calls;

use base qw(Exporter);
our @EXPORT = qw(
  &compileQuote
  &compileInteger
  &compileReference
  &compileLiteral
  &compileInlineBlock &compileBlockBody
);

sub compileInstruction {
    my ( $target, $instruction ) = @_;

    my $type = $instruction->getKind;
    if ( $type eq 'LITERAL' ) {
        return compileLiteral(@_);
    }
    elsif ( $type eq 'REFERENCE' ) {
        return compileReference(@_);
    }
    elsif ( $type eq 'BLOCK' ) {
        return compileInlineBlock(@_);
    }
    elsif ( $type eq 'QUOTE' ) {
        return compileQuote(@_);
    }
    elsif ( $type eq 'NUMBER' ) {
        return compileInteger(@_);
    }
    else {
        return undef, "Unknown instruction of type $type",
          $instruction->getSource;
    }
}

# compiles a single literal
sub compileLiteral {
    my ( $target, $variable, $indent, %context ) = @_;
    return undef, 'Expected a LITERAL', $variable->getSource
      unless $variable->getKind eq 'LITERAL';

    # lookup type of variable
    my $name = lc $variable->getValue;
    return undef, "Unknown literal $name in literal", $variable->getSource
      unless exists( $context{$name} );
    my $type = $context{$name};

    my $result;
    if ( $type eq 'GLOBAL_STRING' or $type eq 'BUILTIN_GLOBAL_STRING' ) {
        $result = callLookupGlobalString( $target, $variable );
    }
    elsif ( $type eq 'GLOBAL_INTEGER' or $type eq 'BUILTIN_GLOBAL_INTEGER' ) {
        $result = callLookupGlobalInteger( $target, $variable );
    }
    elsif ( $type eq 'ENTRY_STRING' or $type eq 'BUILTIN_ENTRY_STRING' ) {
        $result = callLookupEntryString( $target, $variable );
    }
    elsif ( $type eq 'ENTRY_FIELD' or $type eq 'BUILTIN_ENTRY_FIELD' ) {
        $result = callLookupEntryField( $target, $variable );
    }
    elsif ( $type eq 'ENTRY_INTEGER' or $type eq 'BUILTIN_ENTRY_INTEGER' ) {
        $result = callLookupEntryInteger( $target, $variable );
    }
    elsif ( $type eq 'FUNCTION' ) {
        $result .= callCallFunction( $target, $variable );
    }
    elsif ( $type eq 'BUILTIN_FUNCTION' ) {
        $result .= callCallBuiltin( $target, $variable );
    }
    else {
        return undef,
          "Attempted to reference " . $name . " of type $type in literal",
          $variable->getSource;
    }

    return $target->makeIndent($indent) . $result . "\n";
}

# compiles a single reference (i.e. 'something)
sub compileReference {
    my ( $target, $reference, $indent, %context ) = @_;
    return undef, 'Expected a REFERENCE', $reference->getSource
      unless $reference->getKind eq 'REFERENCE';

    # lookup type of variable
    my $name = lc $reference->getValue;
    return undef, "Unknown literal $name in reference", $reference->getSource
      unless exists( $context{$name} );
    my $type = $context{$name};

    my $result;
    if ( $type eq 'GLOBAL_STRING' or $type eq 'BUILTIN_GLOBAL_STRING' ) {
        $result = callPushGlobalString( $target, $reference );
    }
    elsif ( $type eq 'GLOBAL_INTEGER' or $type eq 'BUILTIN_GLOBAL_INTEGER' ) {
        $result = callPushGlobalInteger( $target, $reference );
    }
    elsif ( $type eq 'ENTRY_FIELD' or $type eq 'BUILTIN_ENTRY_FIELD' ) {
        $result = callPushEntryField( $target, $reference );
    }
    elsif ( $type eq 'ENTRY_STRING' or $type eq 'BUILTIN_ENTRY_STRING' ) {
        $result = callPushEntryString( $target, $reference );
    }
    elsif ( $type eq 'ENTRY_INTEGER' or $type eq 'BUILTIN_ENTRY_INTEGER' ) {
        $result = callPushEntryInteger( $target, $reference );
    }
    elsif ( $type eq 'FUNCTION' ) {
        $result .= callPushFunction( $target, $reference );
    }
    elsif ( $type eq 'BUILTIN_FUNCTION' ) {
        $result .= callPushBuiltin( $target, $reference );
    }
    else {
        return undef,
          "Attempted to resolve " . $name . " of type $type in literal",
          $reference->getSource;
    }
    return $target->makeIndent($indent) . $result . "\n";
}

# compiles a single inline block
sub compileInlineBlock {
    my ( $target, $block, $indent, %context ) = @_;
    return undef, 'Expected a BLOCK', $block->getSource
      unless $block->getKind eq 'BLOCK';

    # compile the inline body instruction-per-instruction
    my ( $body, $error, $location ) =
      compileBlockBody( $target, $block, $indent, %context );
    return $body, $error, $location if defined($error);

    # wrap it in an appropriate definition
    $body = $target->escapeBstInlineBlock(
        $body, $block,
        $target->makeIndent($indent),
        $target->makeIndent( $indent + 1 )
    );

    return
      $target->makeIndent($indent)
      . callPushBlock( $target, $block, $body ) . "\n";
}

# compiles the body of a block
sub compileBlockBody {
    my ( $target, $block, $indent, %context ) = @_;
    return undef, 'Expected a BLOCK', $block->getSource
      unless $block->getKind eq 'BLOCK';

    my $body         = '';
    my @instructions = @{ $block->getValue };
    my ( $compilation, $compilationError, $compilationSource );
    foreach my $instruction (@instructions) {
        ( $compilation, $compilationError, $compilationSource ) =
          compileInstruction( $target, $instruction, $indent + 1, %context );
        return $compilation, $compilationError, $compilationSource
          unless defined($compilation);
        $body .= $compilation;
    }

    return $body;
}

# compile a single quote
sub compileQuote {
    my ( $target, $quote, $indent ) = @_;
    return undef, 'Expected a QUOTE', $quote->getSource
      unless $quote->getKind eq 'QUOTE';

    return
      $target->makeIndent($indent) . callPushString( $target, $quote ) . "\n";
}

# compiles a single number
sub compileInteger {
    my ( $target, $number, $indent ) = @_;
    return undef, 'Expected a NUMBER', $number->getSource
      unless $number->getKind eq 'NUMBER';
    return
      $target->makeIndent($indent) . callPushInteger( $target, $number ) . "\n";
}

1;

