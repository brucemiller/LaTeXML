# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime::Utils                              | #
# | Various runtime utility functions                                   | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
package LaTeXML::Post::BiBTeX::Runtime::Utils;
use strict;
use warnings;

use base qw(Exporter);
our @EXPORT = qw(
  &concatString &simplifyString &applyPatch
  &popType &fmtType &popFunction
  &fmtLogMessage
);

# given two runtime strings, join them and their sources together
# and return a new runtime string
sub concatString {
    my ( $stringA, $sourceA, $stringB, $sourceB ) = @_;

    # join the strings and sources
    # Note: Both strings and sources are copies at this point and can be treated as mutable.
    my @strings = ( @$stringA, @$stringB );
    my @sources = ( @$sourceA, @$sourceB );

    my @theString  = ();
    my @theSources = ();

    my ( $hasElement, $string, $source, $prevSource ) = (0);
    while ( defined( $string = shift(@strings) ) ) {
        $source = shift(@sources);

        # if we have a non-empty string
        unless ( $string eq '' ) {

            # we can join element iff the following conditions are met
            # - we have at least one source already
            # - the previous element has no source
            # - the current element has no source
            if ( $hasElement && !defined($prevSource) && !defined($source) ) {
                $theString[-1] .= $string;

               # in any other case, we need to setup a new element in the result
            }
            else {
                push( @theString,  $string );
                push( @theSources, $source );

                $prevSource = $source;
                $hasElement = 1;
            }
        }
    }

    # and return the strings and sources
    return [@theString], [@theSources];
}

# given a runtime string turn it into a single string and useful source
sub simplifyString {
    my ( $string, $sources ) = @_;

    # return the first 'defined' source
    # i.e. one that comes from a source file.
    my ( $source );
    foreach my $asource (@$sources) {
        $source = $asource;
        last if defined($source);
    }

    return join( '', @$string ), $source;
}

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
sub applyPatch {
    my ( $oldString, $oldSource, $patch, $semantics ) = @_;

    # simplify the old string
    my ( $theOldString, $theOldSource ) =
      simplifyString( $oldString, $oldSource );

    # apply the patch
    my $theNewString = &{$patch}($theOldString);

    # if nothing changed, return as is
    if ( $theOldString eq $theNewString ) {
        return $oldString, $oldSource;

        # when we the semantics state 'inplace'
    }
    elsif ($semantics eq 'inplace'
        && length($oldString) != 0
        && length($theNewString) > length($theOldString) )
    {
        $theOldString = substr( $theNewString, 0, length($theOldString) );
        $theNewString = substr( $theNewString, length($theOldString) );

        # we had an in-place e
        return [ $theOldString, $theNewString ], [ $theOldSource, undef ];

        # else, return only the simplified source
    }
    else {
        return [$theNewString], [$theOldSource];
    }
}

# pops a string, or throws an error
sub popType {
    my ( $context, $config, $type, $onMissing, $source ) = @_;
    my ( $tp, $value, $src ) = $context->popStack;

    unless ( defined($tp) ) {
        $config->log(
            'WARN',
            'Attempted to pop the empty stack',
            $config->location($source)
        );
        return undef, undef, undef;
    }

    if ( $tp ne $type ) {
        if ( $tp eq 'MISSING' && defined($onMissing) ) {
            return @$onMissing;
        }
        $config->log(
            'WARN',
            "Expected to pop type $type from stack, but got type $tp",
            $config->location($source)
        );
        return undef, undef, undef;
    }

    return $tp, $value, $src;
}

# pops a function from the stack, or converts a popped Reference to a function
sub popFunction {
    my ( $context, $config, $source ) = @_;
    my ( $tp,      $value,  $src )    = $context->popStack;

    unless ( defined($tp) ) {
        $config->log(
            'WARN',
            'Attempted to pop the empty stack',
            $config->location($source)
        );
        return undef, undef, undef;
    }

    if ( $tp eq 'FUNCTION' ) {
        return $tp, $value, $src;
    }
    elsif ( $tp eq 'REFERENCE' ) {
        my ( $vtype, $vname ) = @$value;
        return $tp, sub {
            my ( $ctx, $cfg, $cs ) = @_;
            my ( $t,   $v,   $s )  = $ctx->getVariable($vname);
            if ( defined($t) ) {
                $ctx->pushStack( $t, $v, $s );
            }
            else {
                $cfg->log( 'WARN',
                    "Can not push variable $vname: Does not exist", $cs );
            }
        }, $src;
    }
    else {
        $config->log(
            'WARN',
"Expected to pop type 'FUNCTION' or 'REFERENCE' from stack, but got type $tp",
            $config->location($source)
        );
    }

    return undef, undef, undef;
}

sub fmtType {
    my ( $type, $value ) = @_;
    if ( $type eq 'UNSET' or $type eq 'MISSING' ) {
        return "($type)";
    }
    elsif ( $type eq 'STRING' ) {
        return "($type) " . join( '', @$value );
    }
    elsif ( $type eq 'INTEGER' ) {
        return "($type) $value";
    }
    elsif ( $type eq 'FUNCTION' ) {
        return "($type) <reference>";
    }
    elsif ( $type eq 'REFERENCE' ) {
        my ( $rtype, $rname ) = @$value;
        return "($type) ($rtype) $rname";
    }
    else {
        return '(unknown)';
    }
}

# formats a log message consisting of a level, a message and a source
sub fmtLogMessage {
    my ( $level, $message, $source ) = @_;
    if ( defined($source) && ref $source eq 'ARRAY' ) {
        $source = join( ' ', @$source );
    }
    else {
        $source = 'unknown location';
    }
    return "[$level] $message ($source)";
}

1;
