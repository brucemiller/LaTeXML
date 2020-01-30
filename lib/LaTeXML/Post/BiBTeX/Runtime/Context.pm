# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime::Context                            | #
# | The entire context of a runtime                                     | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
package LaTeXML::Post::BiBTeX::Runtime::Context;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Bibliography::BibParser qw(readFile);
use LaTeXML::Post::BiBTeX::Common::Utils;

use LaTeXML::Post::BiBTeX::Runtime::Entry;

###
### The Context
###

### The context, a.k.a. state, contains all values of the runtime system, with the exception of builtins.
### It consists of the following items:

sub new {
    my ($class) = @_;
    return bless {
        ### the stack
        stack => [],

        ### - a set of macros
        macros => {},

        ### - a set of global string variables (with three values each, as in the stack)
        ### along with the types ('GLOBAL_STRING', 'ENTRY_STRING', 'GLOBAL_INTEGER', 'ENTRY_INTEGER', 'ENTRY_FIELD');
        variables     => {},
        variableTypes => {},

        ### - a list of read entries, and the current entry (if any)
        entries => undef,
        entryHash => undef,
        entry   => undef,

        ### - an output buffer (split into an array of string, and an array of references)
        outputString   => [],
        outputSource   => [],
        preambleString => [],
        preambleSource => [],

    }, $class;
}

###
### Low-level stack access
###

### Each entry in the runtime stack internally consists of a triple (type, valuye, source):
###  - 'type' contains types of objects
###  - 'value' the actual objects
###  - 'source' contains the source references of objects
### Entries on the stack are considered immutable (even though Perl provides no guarantees that it is indeed so).
### Any changes to the underlying values should be performed on a copy of the data.

### The following types are defined:

### 0. 'UNSET' - if a variable has not been set
### 1. 'MISSING' - a missing value of a field (TODO: perhaps also an uninititialized constant)
### 2. 'STRING' - a simple string
### 3. 'INTEGER' -- an integer
### 4. 'FUNCTION' -- a function
### 5. 'REFERENCE' -- a reference to a variable or function on the stack. Starts with 'GLOBAL_' or 'ENTRY_'.

### These have the corresponding values:

### 0. 'UNSET' -- undef
### 1. 'MISSING' -- undef
### 2. 'STRING' -- a tuple of strings
### 3. 'INTEGER' -- a single integer
### 4. 'FUNCTION' -- the function reference
### 5. 'REFERENCE' -- a pair (variable type, reference) of the type of variable being referenced and the actual value being referened

### The corresponding source references are:
### 0. 'UNSET' -- undef
### 1. 'MISSING' -- a tuple(key, field) this value comes from
### 2. 'STRING' -- a tuple (key, field) or undef for each string
### 3. 'INTEGER' -- a tuple (key, field) or undef, when joining take the first one
### 4. 'FUNCTION' -- undef
### 5. 'REFERENCE' -- undef

# TODO: Allow re-running a context without having to re-parse the bib files
# (There should probably be a reset function that clear entries, but keeps the read .bib files)

# 'popStack' pops and returns a value from the stack, or returns undef, undef, undef
# The value returned from the stack is immutable, and should be copied if any changes are made
sub popStack {
    my ($self) = @_;
    return ( @{ pop( @{ $$self{stack} } ) || return undef, undef, undef } );
}

# 'peekStack' peeks at position $index from the top of the stac, or undef, undef, undef if it is not defined.
# Note that index is 1-based, i.e. peekStack(1) returns the top-most element on the stack
sub peekStack {
    my ( $self, $index ) = @_;
    return ( @{ $$self{stack}[ -$index ] || return undef, undef, undef } );
}

# 'pushStack' pushes a single value onto the stack
sub pushStack {
    my ( $self, $type, $value, $source ) = @_;
    push( @{ $$self{stack} }, [ $type, $value, $source ] );
}

# 'pushString' pushes an string without a source refence onto the stack.
sub pushString {
    my ( $self, $string ) = @_;
    push( @{ $$self{stack} }, [ 'STRING', [$string], [undef] ] );
}

# 'pushInteger' pushes an integer without a source refence onto the stack.
sub pushInteger {
    my ( $self, $integer ) = @_;
    push( @{ $$self{stack} }, [ 'INTEGER', $integer, undef ] );
}

# 'stackEmpty' returns a boolean indicating if the stack is empty.
sub stackEmpty {
    my ($self) = @_;
    return @{ $$self{stack} } == 0;
}

# 'emptyStack' empties the stack.
sub emptyStack {
    my ($self) = @_;
    $$self{stack} = [];
}

# 'duplicateStack' duplicates the top-most entry of the stack.
# returns a boolean indicating if duplication succeeded (i.e. if the stack was empty or not).
sub duplicateStack {
    my ($self) = @_;

    # grab and duplicate value (if needed)
    push( @{ $$self{stack} }, $$self{stack}[-1] || return 0 );
    return 1;
}

# 'swapStack' swaps the two top-most entries of the stack.
# returns a boolean indicating if swapping succeeded (i.e. if the stack had at least two element or not).
sub swapStack {
    my ($self) = @_;
    return 0 unless scalar( @{ $$self{stack} } ) > 1;

    @{ $$self{stack} }[ -1, -2 ] = @{ $$self{stack} }[ -2, -1 ];
    return 1;
}

###
### MACROS
###

# 'setMarco' sets a macro of the provided name to the provided value.
sub setMacro {
    my ( $self, $name, $value ) = @_;
    $$self{macros}{ lc $name } = $value;
}

# 'getMacro' gets a macro of the provided name
sub getMacro {
    my ( $self, $name ) = @_;
    return $$self{macros}{ lc $name };
}

# 'hasMacro' returns a boolean indicating if the given macro exists
sub hasMacro {
    my ( $self, $name ) = @_;
    return defined( $$self{macros}{ lc $name } );
}

###
### VARIABLES
###

# 'hasVariable' checks if a variable of the given name and type exists.
# When type is omitted, checks if any variable of the given type exists
sub hasVariable {
    my ( $self, $name, $type ) = @_;
    return ( $$self{variableTypes}{$name} || return 0 ) eq
      ( $type || return 1 );
}

# 'defineVariable' defines a new variable of the given type.
# returns 1 if the variable was defined, 0 if it already existed.
sub defineVariable {
    my ( $self, $name, $type ) = @_;
    return 0 if defined( $$self{variableTypes}{$name} );

    # store the type and set initial value if global
    $$self{variableTypes}{$name} = $type;
    $$self{variables}{$name}     = [ ( 'UNSET', undef, undef ) ]
      unless startsWith( $type, 'ENTRY_' );

    return 1;
}

# 'getVariable' gets a variable of the given name
# Returns a triple (type, value, source).
sub getVariable {
    my ( $self, $name ) = @_;

    # if the variable does not exist, return nothing
    my $type = $$self{variableTypes}{$name} || return undef, undef, undef;

    # we need to look up inside the current entry
    if (   $type eq 'ENTRY_FIELD'
        or $type eq 'ENTRY_STRING'
        or $type eq 'ENTRY_INTEGER' )
    {
        my $entry = $$self{entry} || return ( 'UNSET', undef, undef );
        return $entry->getVariable($name);
    }

    # 'global' variable => return from our own state
    return ( @{ $$self{variables}{$name} } );
}

# 'setVariable' sets a variable of the given name.
# A variable is represented by a reference to a triple (type, value, source).
# returns 0 if ok, 1 if it doesn't exist,  2 if an invalid context, 3 if read-only, 4 if unknown type
sub setVariable {
    my ( $self, $name, $value ) = @_;

    # if the variable does not exist, return nothing
    my $type = $$self{variableTypes}{$name};
    return 1 unless defined($type);

    # normalize name of variable
    $name = lc $name;

    # we need to look up inside the current entry
    if (   $type eq 'ENTRY_FIELD'
        or $type eq 'ENTRY_STRING'
        or $type eq 'ENTRY_INTEGER' )
    {
        my $entry = $$self{entry} || return 2;
        return $entry->setVariable( $name, $value );

        # we have a global variable, so take it from our stack
    }
    elsif ($type eq 'GLOBAL_STRING'
        or $type eq 'GLOBAL_INTEGER'
        or $type eq 'FUNCTION' )
    {
        # else assign the value
        $$self{variables}{$name} = $value;

        # and return
        return 0;

        # I don't know the type
    }
    else {
        return 4;
    }
}

# 'assignVariable' defines and sets a variable to the given value.
# A variable is represented by a reference to a triple (type, value, source).
# Returns 0 if ok, 1 if it already exists, 2 if an invalid context, 3 if read-only, 4 if unknown type
sub assignVariable {
    my ( $self, $name, $type, $value ) = @_;

    # define the variable
    my $def = $self->defineVariable( $name, $type );
    return 1 unless $def == 1;

    return $self->setVariable( $name, $value );
}

###
### ENTRIES
###

# 'getEntries' gets a list of all entries
sub getEntries {
    my ($self) = @_;
    return $$self{entries};
}

# 'readEntries' reads in all entries and builds an entry list.
# Returns (0, warnings) if ok, (1, undef) if entries were already read and (2, error) if something went wrong while reading
# Always closes all readers, if status != 1.
sub readEntries {
    my ( $self, $inputs, $citations ) = @_;

    my @readers = @{$inputs};

    return 1, undef if defined( $$self{entries} );

    my @entries   = ();
    my @warnings  = ();
    my @locations = ();

    my ( $name, $reader, $parse, $parseError, $entry, $warning, $location,
        $cite );
    while ( defined( $reader = shift(@readers) ) ) {
        $name = $reader->getFilename;
        ( $parse, $parseError ) = readFile( $reader, 1, %{ $$self{macros} } );
        $reader->finalize;

        # if we have a parse error, close all the other readers
        if ( scalar( @{$parseError} ) > 0 ) {
            foreach $reader (@readers) {
                $reader->finalize;
            }
            return 2, $parseError;
        }

        # iterate over all the entries
        foreach $entry ( @{$parse} ) {
            ( $entry, $warning, $location ) =
              LaTeXML::Post::BiBTeX::Runtime::Entry->new( $name, $self, $entry );
            if ( defined($entry) ) {

                # if we didn't get a ref, it's a preamble + source
                unless ( ref $entry ) {
                    push( @{ $$self{preambleString} }, $entry );
                    push( @{ $$self{preambleSource} }, $warning );
                    next;
                }

                push( @entries, $entry );
            }
            push( @warnings,  @$warning )  if defined($warning);
            push( @locations, @$location ) if defined($location);
        }
    }

    # build a map of entries
    my (%entryHash) = ();
    my ($key);
    foreach $entry (@entries) {
        $key = $entry->getKey;
        if ( defined( $entryHash{$key} ) ) {

            push( @warnings,  "Skipping duplicate entry for key $key" );
            push( @locations, $$entry{entry}->getSource );
            next;
        }
        $entryHash{$key} = $entry;
    }
    $$self{entryHash} = \%entryHash;

    # build the entry list and keep track of warnings and locations of warnings
    ( $$self{entries}, $warning, $location ) =
      $self->buildEntryList( [@entries], $citations, 2 )
      ;    # TODO: Allow numcrossref customization
    push( @warnings,  @$warning )  if defined($warning);
    push( @locations, @$location ) if defined($location);

    return 0, [@warnings], [@locations];
}

# build a list of entries that should be cited.
sub buildEntryList {
    my ( $self, $entryList, $citeList, $numCrossRefs ) = @_;

    sub locationOf {
        my ($entry) = @_;
        return $entry->getName, $$entry{entry}->getSource;
    }

    my ( @warnings, @locations ) = ();

    my ($citeKey);    # current cite key the user requested
    my %citedKeys = ();    # same as citeList, but key => 1 mapping

    my %related = ();      # resolved reference entries
    my @xrefed  = ();
    my @entries = ();
    my %refmap  = ();      # [xrefed] => referencing entries

    # hash for resolving entries
    my $entryHash = $$self{entryHash};
    my %entryMap = %$entryHash;

    my ( $entry, $error );
    while ( defined( $citeKey = shift(@$citeList) ) ) {

# If we already cited something it does not need to be cited again.
# This is *not* an error, it might regularly occur if things are cited multiple times.
        next if exists( $citedKeys{$citeKey} );

     # When we receive a '*' key, we need to add all the entries that we know of
        if ( $citeKey eq '*' ) {
            foreach $entry (@$entryList) {
                push( @$citeList, $entry->getKey );
            }
            next;
        }

        # find the current entry
        $entry = $entryMap{$citeKey};
        unless ( defined($entry) ) {

            push( @warnings,
                ["I didn't find a database entry for \"$citeKey\""] );
            push( @locations, undef );
            next;
        }

        # push this entry into the list of cited 'stuff'
        push( @entries, $entry );
        $citedKeys{$citeKey} = 1;

        # grab the cross-referenced entry and resolve it
        my ( $xref, $xrefentry ) = $entry->resolveCrossReference($entryHash);
        next unless defined($xref);

        # if the cross-referenced entry doesn't exist
        # TODO: Better warning location
        unless ( defined($xrefentry) ) {
            push(
                @warnings,
                [
"A bad cross reference---entry \"$citeKey\" refers to entry \"$xref\", which doesn't exist"
                ]
            );
            push( @locations, [ locationOf($entry) ] );
            $entry->clearCrossReference();
            next;
        }

        # Add this item to the 'cited'
        unless ( defined( $refmap{$xref} ) ) {
            push( @xrefed, $xref );
            $refmap{$xref} = [ () ];
        }

        # and add the current entry to the xrefed entry
        push( @{ $refmap{$xref} }, $entry );
    }

    # iterate over everything that was cross-referenced
    # and either inline or add it to the citation list
    my ( $related, $exists, $hideCrossref, @references );
    foreach my $value (@xrefed) {
        @references = @{ $refmap{$value} };
        $related    = $entryMap{$value};
        $exists     = exists( $citedKeys{$value} );

# We always inline cross-referenced entries.
# When the number of references to a specific entry is small enough we remove the 'crossref' key.
        $hideCrossref = !$exists && scalar @references < $numCrossRefs;

        foreach my $reference (@references) {
            $reference->inlineCrossReference( $related, $hideCrossref );
        }

        # if there are more, it is included in the list of entries
        push( @entries, $related ) unless ( $hideCrossref || $exists );
    }

    return [@entries], @warnings, @locations;
}

sub getPreamble {
    my ($self) = @_;
    return $$self{preambleString}, $$self{preambleSource};
}

# sort entries in-place using a comparison function
# return 1 iff entriues have been sorted
sub sortEntries {
    my ( $self, $comp ) = @_;

    $$self{entries} = [ sort { &{$comp}( $a, $b ) } @{ $$self{entries} } ];
    return 1;
}

# sets the current entry
sub setEntry {
    my ( $self, $entry ) = @_;
    $$self{entry} = $entry;
    return $entry;
}

# 'findEntry' finds and activates the entry with the given key and returns it. 
# If no such entry exists, returns undef. 
sub findEntry {
    my ($self, $key) = @_;
    my $theEntry;
    # if we have a hash for entries (i.e. we were initialized)
    # we should just lookup the key
    my $entryHash = $$self{entryHash};
    if(defined($entryHash)) {
        my %hash = %{$entryHash};
        $theEntry = $hash{$key}; }
    # if we weren't initalized, we need to iterate
    else {
        foreach my $entry (@{$self->getEntries}) {
            if($entry->getKey eq $key) {
                $theEntry = $entry;
                last; } } }
    # set the active entry and return it
    return $self->setEntry($theEntry) if defined($theEntry); }

# gets the current entry (if any)
sub getEntry {
    my ($self) = @_;
    return $$self{entry};
}

# leave the current entry (if any)
sub leaveEntry {
    my ($self) = @_;
    $$self{entry} = undef;
}

1;
