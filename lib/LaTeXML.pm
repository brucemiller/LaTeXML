# /=====================================================================\ #
# |  LaTeXML                                                            | #
# | Overall LaTeXML Converter                                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML;
use strict;
use warnings;

use Carp;
use Encode;
use Data::Dumper;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use File::Spec;

use LaTeXML::Core;
use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;
use LaTeXML::Util::ObjectDB;
use LaTeXML::Util::Config;
use LaTeXML::Post::Scan;

#**********************************************************************
#our @IGNORABLE = qw(timeout profile port preamble postamble port destination log removed_math_formats whatsin whatsout math_formats input_limit input_counter dographics mathimages mathimagemag );

# Switching to white-listing options that are important for new_latexml:
our @COMPARABLE = qw(preload paths verbosity strict comments inputencoding includestyles documentid mathparse);
our %DAEMON_DB = ();

sub new {
  my ($class, $config) = @_;
  $config = LaTeXML::Util::Config->new() unless (defined $config);
  # The daemon should be setting the identity:
  my $self = bless { opts => $config->options, ready => 0, log => q{}, runtime => {},
    latexml => undef }, $class;
  # Special check if the debug directive is on, just to neutralize the bind_log
  my $debug_directives = $self->{opts}->{debug};
  $LaTeXML::DEBUG = 1 if (ref $debug_directives eq 'ARRAY') && (grep { /converter/i } @$debug_directives);
  $self->bind_log;
  my $rv = eval { $config->check; };
  $self->{log} .= $self->flush_log;
  return $self; }

sub prepare_session {
  my ($self, $config) = @_;
  # TODO: The defaults feature was never used, do we really want it??
  #0. Ensure all default keys are present:
  # (always, as users can specify partial options that build on the defaults)
  #foreach (keys %{$self->{defaults}}) {
  #  $config->{$_} = $self->{defaults}->{$_} unless exists $config->{$_};
  #}
  # 1. Ensure option "sanity"
  $self->bind_log;
  my $rv = eval { $config->check; };
  $self->{log} .= $self->flush_log;

  my $opts                 = $config->options;
  my $opts_comparable      = { map { $_ => $opts->{$_} } @COMPARABLE };
  my $self_opts_comparable = { map { $_ => $self->{opts}->{$_} } @COMPARABLE };
  #TODO: Some options like paths and includes are additive, we need special treatment there
  #2.2. Compare old and new $opts hash
  my $something_to_do;
  $something_to_do = LaTeXML::Util::ObjectDB::compare($opts_comparable, $self_opts_comparable) ? 0 : 1;
  #2.3. Set new options in converter:
  $self->{opts} = $opts;

  #3. If there is something to do, initialize a session:
  $self->initialize_session if ($something_to_do || (!$self->{ready}));

  return;
}

sub initialize_session {
  my ($self) = @_;
  $self->{runtime} = {};
  $self->bind_log;
  # Empty the package namespace
  foreach my $subname (keys %LaTeXML::Package::Pool::) {
    delete $LaTeXML::Package::Pool::{$subname};
  }

  my $latexml;
  my $init_eval_return = eval {
    # Prepare LaTeXML object
    $latexml = new_latexml($self->{opts});
    1;
  };
  local $@ = 'Fatal:conversion:unknown Session initialization failed! (Unknown reason)' if ((!$init_eval_return) && (!$@));
  if ($@) {    #Fatal occured!
    print STDERR "$@\n";
    print STDERR "\nInitialization complete: " . $latexml->getStatusMessage . ". Aborting.\n" if defined $latexml;
    # Close and restore STDERR to original condition.
    $self->{log} .= $self->flush_log;
    $self->{ready} = 0;
    return;
  } else {
    # Demand errorless initialization
    my $init_status = $latexml->getStatusMessage;
    if ($init_status =~ /error/i) {
      print STDERR "\nInitialization complete: " . $init_status . ". Aborting.\n";
      $self->{log} .= $self->flush_log;
      $self->{ready} = 0;
      return;
    }
  }

  # Save latexml in object:
  $self->{log} .= $self->flush_log;
  $self->{latexml} = $latexml;
  $self->{ready}   = 1;
  return;
}

sub convert {
  my ($self, $source) = @_;
  # Initialize session if needed:
  $self->{runtime} = {};
  $self->initialize_session unless $self->{ready};
  if (!$self->{ready}) {    # We can't initialize, return error:
    return { result => undef, log => $self->{log}, status => "Initialization failed.", status_code => 3 };
  }

  $self->bind_log;
  # Inform of identity, increase conversion counter
  my $opts    = $self->{opts};
  my $runtime = $self->{runtime};
  ($runtime->{status}, $runtime->{status_code}) = (undef, undef);
  print STDERR "\n$LaTeXML::IDENTITY\n" if $opts->{verbosity} >= 0;
  print STDERR "processing started " . localtime() . "\n" if $opts->{verbosity} >= 0;
  # Handle What's IN:
  # We use a new temporary variable to avoid confusion with daemon caching
  my ($current_preamble, $current_postamble);
  # 1. Math needs to magically trigger math mode if needed
  if ($opts->{whatsin} eq "math") {
    $current_preamble  = 'literal:\begin{document}\ensuremathfollows';
    $current_postamble = 'literal:\ensuremathpreceeds\end{document}'; }
  # 2. Fragments need to have a default pre- and postamble, if none provided
  elsif ($opts->{whatsin} eq 'fragment') {
    $current_preamble  = $opts->{preamble}  || 'standard_preamble.tex';
    $current_postamble = $opts->{postamble} || 'standard_postamble.tex'; }
  elsif ($opts->{whatsin} eq 'archive') {
    # Sandbox the input
    $opts->{archive_sourcedirectory} = $opts->{sourcedirectory};
    my $sandbox_directory = tempdir();
    $opts->{sourcedirectory} = $sandbox_directory;
    # Extract the archive in the sandbox
    use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
    use File::Spec::Functions qw(catfile);
    my $zip_handle = Archive::Zip->new();
    if (pathname_is_literaldata($source)) {
      # Literal, just use the data
      use IO::String;
      my $content_handle = IO::String->new($source);
      unless ($zip_handle->readFromFileHandle($content_handle) == AZ_OK) {
        print STDERR "Fatal:IO:Archive Can't read in literal archive:\n $source\n"; } }
    else {    # Otherwise, read in from file
      unless ($zip_handle->read($source) == AZ_OK) {
        print STDERR "Fatal:IO:Archive Can't read in source archive: $source\n"; } }
    # Extract the Perl zip datastructure to the temporary directory
    foreach my $member ($zip_handle->memberNames()) {
      $zip_handle->extractMember($member, catfile($sandbox_directory, $member)); }
    # Set $source to point to the main TeX file in that directory
    my @TeX_file_members = map { $_->fileName() } $zip_handle->membersMatching('\.tex$');
    if (scalar(@TeX_file_members) == 1) {
      # One file, that's the input!
      $source = catfile($sandbox_directory, $TeX_file_members[0]); }
    else {
      # Heuristically determine the input (borrowed from arXiv::FileGuess)
      my %Main_TeX_likelihood;
      foreach my $tex_file (@TeX_file_members) {
        # Read in the content
        $tex_file = catfile($sandbox_directory, $tex_file);
        # Open file and read first few bytes to do magic sequence identification
        # note that file will be auto-closed when $FILE_TO_GUESS goes out of scope
        open(my $FILE_TO_GUESS, '<', $tex_file) ||
          (print STDERR "failed to open '$tex_file' to guess its format: $!. Continuing.\n");
        local $/ = "\n";
        my ($maybe_tex, $maybe_tex_priority, $maybe_tex_priority2);
      TEX_FILE_TRAVERSAL:
        while (<$FILE_TO_GUESS>) {
          if ((/\%auto-ignore/ && $. <= 10) ||    # Ignore
            ($. <= 10 && /\\input texinfo/) ||    # TeXInfo
            ($. <= 10 && /\%auto-include/))       # Auto-include
          { $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }    # Not primary
          if ($. <= 12 && /^\r?%\&([^\s\n]+)/) {
            if ($1 eq 'latex209' || $1 eq 'biglatex' || $1 eq 'latex' || $1 eq 'LaTeX') {
              $Main_TeX_likelihood{$tex_file} = 3; last TEX_FILE_TRAVERSAL; }    # LaTeX
            else {
              $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; } }    # Mac TeX
              # All subsequent checks have lines with '%' in them chopped.
              #  if we need to look for a % then do it earlier!
          s/\%[^\r]*//;
          if (/(^|\r)\s*\\document(style|class)/) {
            $Main_TeX_likelihood{$tex_file} = 3; last TEX_FILE_TRAVERSAL; }    # LaTeX
          if (/(^|\r)\s*(\\font|\\magnification|\\input|\\def|\\special|\\baselineskip|\\begin)/) {
            $maybe_tex = 1;
            if (/\\input\s+amstex/) {
              $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; } }    # TeX Priority
          if (/(^|\r)\s*\\(end|bye)(\s|$)/) {
            $maybe_tex_priority = 1; }
          if (/\\(end|bye)(\s|$)/) {
            $maybe_tex_priority2 = 1; }
          if (/\\input *(harv|lanl)mac/ || /\\input\s+phyzzx/) {
            $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; }        # Mac TeX
          if (/beginchar\(/) {
            $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }        # MetaFont
          if (/(^|\r)\@(book|article|inbook|unpublished)\{/i) {
            $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }        # BibTeX
          if (/^begin \d{1,4}\s+[^\s]+\r?$/) {
            if ($maybe_tex_priority) {
              $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; }      # TeX Priority
            if ($maybe_tex) {
              $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; }      # TeX
            $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }        # UUEncoded or PC
          if (m/paper deliberately replaced by what little/) {
            $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }
        }
        close $FILE_TO_GUESS || warn "couldn't close file: $!";
        if (!defined $Main_TeX_likelihood{$tex_file}) {
          if ($maybe_tex_priority) {
            $Main_TeX_likelihood{$tex_file} = 2; }
          elsif ($maybe_tex_priority2) {
            $Main_TeX_likelihood{$tex_file} = 1.5; }
          elsif ($maybe_tex) {
            $Main_TeX_likelihood{$tex_file} = 1; }
          else {
            $Main_TeX_likelihood{$tex_file} = 0; }
        }
      }
      # The highest likelihood (>0) file gets to be the main source.
      my @files_by_likelihood = sort { $Main_TeX_likelihood{$a} <=> $Main_TeX_likelihood{$b} } grep { $Main_TeX_likelihood{$_} > 0 } keys %Main_TeX_likelihood;
      if (@files_by_likelihood) {
       # If we have a tie for max score, grab the alphanumerically first file (to ensure deterministic runs)
        my $max_likelihood = $Main_TeX_likelihood{ $files_by_likelihood[0] };
        @files_by_likelihood = sort { $a cmp $b } grep { $Main_TeX_likelihood{$_} = $max_likelihood } @files_by_likelihood;
        $source = shift @files_by_likelihood; }
      else {    # If none, return an error.
                # Clean up sandbox directory.
        remove_tree($opts->{sourcedirectory});
        $opts->{sourcedirectory} = $opts->{archive_sourcedirectory};
        my $log = $self->flush_log;
        return { result => undef, log => $log, status => "Fatal:IO:Archive Can't detect a source TeX file!", status_code => 3 }; }
    }
  }

  # Handle Whats OUT (if we need a sandbox)
  if ($opts->{whatsout} eq 'archive') {
    $opts->{archive_sitedirectory} = $opts->{sitedirectory};
    $opts->{archive_destination}   = $opts->{destination};
    my $destination_name  = pathname_name($opts->{destination});
    my $sandbox_directory = tempdir();
    my $extension         = $opts->{format};
    $extension =~ s/\d//g;
    $extension =~ s/^epub|mobi$/xhtml/;
    my $sandbox_destination = "$destination_name.$extension";
    $opts->{sitedirectory} = $sandbox_directory;

    if ($opts->{format} eq 'epub') {
      $opts->{resource_directory} = File::Spec->catdir($sandbox_directory, 'OPS');
      $opts->{destination} = pathname_concat(File::Spec->catdir($sandbox_directory, 'OPS'), $sandbox_destination); }
    else {
      $opts->{destination} = pathname_concat($sandbox_directory, $sandbox_destination); }
  }

  # Prepare daemon frame
  my $latexml = $self->{latexml};
  $latexml->withState(sub {
      my ($state) = @_;    # Sandbox state
      $state->pushDaemonFrame;
      $state->assignValue('_authlist', $opts->{authlist}, 'global');
      $state->assignValue('REMOTE_REQUEST', (!$opts->{local}), 'global');
  });

  # First read and digest whatever we're given.
  my ($digested, $dom, $serialized) = (undef, undef, undef);

  # Digest source:
  my $convert_eval_return = eval {
    local $SIG{'ALRM'} = sub { die "Fatal:conversion:timeout Conversion timed out after " . $opts->{timeout} . " seconds!\n"; };
    alarm($opts->{timeout});
    my $mode = ($opts->{type} eq 'auto') ? 'TeX' : $opts->{type};
    $digested = $latexml->digestFile($source, preamble => $current_preamble,
      postamble    => $current_postamble,
      mode         => $mode,
      noinitialize => 1);
    # Now, convert to DOM and output, if desired.
    if ($digested) {
      require LaTeXML::Global;
      local $LaTeXML::Global::STATE = $latexml->{state};
      if ($opts->{format} eq 'tex') {
        $serialized = LaTeXML::Global::UnTeX($digested);
      } elsif ($opts->{format} eq 'box') {
        $serialized = $digested->toString;
      } else {    # Default is XML
        $dom = $latexml->convertDocument($digested);
      }
    }
    alarm(0);
    1;
  };
  local $@ = 'Fatal:conversion:unknown TeX to XML conversion failed! (Unknown Reason)' if ((!$convert_eval_return) && (!$@));
  my $eval_report = $@;
  $runtime->{status}      = $latexml->getStatusMessage;
  $runtime->{status_code} = $latexml->getStatusCode;
  $runtime->{status_data}->{$_} = $latexml->{state}->{status}->{$_} foreach (qw(warning error fatal));
  # End daemon run, by popping frame:
  $latexml->withState(sub {
      my ($state) = @_;    # Remove current state frame
      $state->popDaemonFrame;
      $state->{status} = {};
  });
  if ($eval_report || ($runtime->{status_code} == 3)) {
    # Terminate immediately on Fatal errors
    $runtime->{status_code} = 3;
    print STDERR $eval_report . "\n" if $eval_report;
    print STDERR "\nConversion complete: " . $runtime->{status} . ".\n";
    print STDERR "Status:conversion:" . ($runtime->{status_code} || '0') . "\n";
    # If we just processed an archive, clean up sandbox directory.
    if ($opts->{whatsin} eq 'archive') {
      remove_tree($opts->{sourcedirectory});
      $opts->{sourcedirectory} = $opts->{archive_sourcedirectory}; }

    # Close and restore STDERR to original condition.
    my $log = $self->flush_log;
    # Hope to clear some memory:
    $serialized = $dom if ($opts->{format} eq 'dom');
    $serialized = $dom->toString if ($dom && (!defined $serialized));
    $self->sanitize($log);

    return { result => $serialized, log => $log, status => $runtime->{status}, status_code => $runtime->{status_code} }; }
  else {
    # Standard report, if we're not in a Fatal case
    print STDERR "\nConversion complete: " . $runtime->{status} . ".\n"; }

  if ($serialized) {
    # If serialized has been set, we are done with the job
    # If we just processed an archive, clean up sandbox directory.
    if ($opts->{whatsin} eq 'archive') {
      remove_tree($opts->{sourcedirectory});
      $opts->{sourcedirectory} = $opts->{archive_sourcedirectory}; }
    my $log = $self->flush_log;
    return { result => $serialized, log => $log, status => $runtime->{status}, status_code => $runtime->{status_code} };
  }
  # Continue with the regular XML workflow...
  my $result = $dom;
  if ($opts->{post} && $dom) {
    my $post_eval_return = eval {
      local $SIG{'ALRM'} = sub { die "alarm\n" };
      alarm($opts->{timeout});
      $result = $self->convert_post($dom);
      alarm(0);
      1;
    };
    local $@ = 'Fatal:conversion:unknown Post-processing failed! (Unknown Reason)'
      if ((!$post_eval_return) && (!$@));
    if ($@) {    #Fatal occured!
      $runtime->{status_code} = 3;
      if ($@ =~ "Fatal:perl:die alarm") {    #Alarm handler: (treat timeouts as fatals)
        print STDERR "Fatal:post:timeout Postprocessing timeout after "
          . $opts->{timeout} . " seconds!\n"; }
      else {
        print STDERR "Fatal:post:generic Post-processor crashed! $@\n"; }
      #Since this is postprocessing, we don't need to do anything
      #   just avoid crashing...
      $result = undef; } }

  # Clean-up everything we sandboxed
  if ($opts->{whatsin} eq 'archive') {
    remove_tree($opts->{sourcedirectory});
    $opts->{sourcedirectory} = $opts->{archive_sourcedirectory}; }
  if ($opts->{whatsout} eq 'archive') {
    remove_tree($opts->{sitedirectory});
    $opts->{sitedirectory} = $opts->{archive_sitedirectory};
    $opts->{destination}   = $opts->{archive_destination};
  }

  # Serialize result for direct use:
  undef $serialized;
  if ((defined $result) && (ref $result)) {
    if ($opts->{format} =~ 'x(ht)?ml') {
      $serialized = $result->toString(1); }
    elsif ($opts->{format} =~ /^html/) {
      if (ref($result) =~ '^LaTeXML::(Post::)?Document$') {    # Special for documents
        $serialized = $result->getDocument->toStringHTML; }
      else {                                                   # Regular for fragments
        do {
          local $XML::LibXML::setTagCompression = 1;
          $serialized = $result->toString(1);
          } } }
    elsif ($opts->{format} eq 'dom') {
      $serialized = $result; } }
  else { $serialized = $result; }                              # Compressed case

  print STDERR "Status:conversion:" . ($runtime->{status_code} || '0') . " \n";
  my $log = $self->flush_log;
  $self->sanitize($log) if ($runtime->{status_code} == 3);
  return { result => $serialized, log => $log, status => $runtime->{status}, 'status_code' => $runtime->{status_code} };
}

###########################################
####       Converter Management       #####
###########################################
sub get_converter {
  my ($self, $config) = @_;
  # TODO: Make this more flexible via an admin interface later
  my $key = $config->get('cache_key') || $config->get('profile') || 'custom';
  my $d = $DAEMON_DB{$key};
  if (!defined $d) {
    $d = LaTeXML->new($config->clone);
    $DAEMON_DB{$key} = $d; }
  return $d; }

###########################################
####       Helper routines            #####
###########################################
sub convert_post {
  my ($self, $dom) = @_;
  my $opts    = $self->{opts};
  my $runtime = $self->{runtime};
  my ($xslt, $parallel, $math_formats, $format, $verbosity, $defaultresources, $embed) =
    map { $opts->{$_} } qw(stylesheet parallelmath math_formats format verbosity defaultresources embed);
  $verbosity = $verbosity || 0;
  my %PostOPS = (verbosity => $verbosity,
    validate           => $opts->{validate},
    sourceDirectory    => $opts->{sourcedirectory},
    siteDirectory      => $opts->{sitedirectory},
    resource_directory => $opts->{resource_directory},
    nocache            => 1,
    destination        => $opts->{destination},
    is_html            => $opts->{is_html});
  #Postprocess
  $parallel = $parallel || 0;

  my $DOCUMENT = LaTeXML::Post::Document->new($dom, %PostOPS);
  my @procs = ();
  #TODO: Add support for the following:
  my $dbfile = $opts->{dbfile};
  if (defined $dbfile && !-f $dbfile) {
    if (my $dbdir = pathname_directory($dbfile)) {
      pathname_mkdir($dbdir); } }
  my $DB = LaTeXML::Util::ObjectDB->new(dbfile => $dbfile, %PostOPS);
  ### Advanced Processors:
  if ($opts->{split}) {
    require LaTeXML::Post::Split;
    push(@procs, LaTeXML::Post::Split->new(split_xpath => $opts->{splitpath}, splitnaming => $opts->{splitnaming},
        db => $DB, %PostOPS)); }
  my $scanner = ($opts->{scan} || $DB) && (LaTeXML::Post::Scan->new(db => $DB, %PostOPS));
  push(@procs, $scanner) if $opts->{scan};
  if (!($opts->{prescan})) {
    if ($opts->{index}) {
      require LaTeXML::Post::MakeIndex;
      push(@procs, LaTeXML::Post::MakeIndex->new(db => $DB, permuted => $opts->{permutedindex},
          split => $opts->{splitindex}, scanner => $scanner,
          %PostOPS)); }
    if (@{ $opts->{bibliographies} }) {
      if (grep { /$LaTeXML::Util::Config::is_bibtex/ } @{ $opts->{bibliographies} }) {
        my $bib_converter =
          $self->get_converter(LaTeXML::Util::Config->new(
            type => "BibTeX", post => 0, format => 'dom', whatsout => 'document', whatsin => 'document'));
        $self->{log} .= $self->flush_log;
        @{ $opts->{bibliographies} } = map { /$LaTeXML::Util::Config::is_bibtex/ ?
            $bib_converter->convert($_)->{result} : $_ } @{ $opts->{bibliographies} };
        $self->bind_log;
      }
      require LaTeXML::Post::MakeBibliography;
      push(@procs, LaTeXML::Post::MakeBibliography->new(db => $DB, bibliographies => $opts->{bibliographies},
          split => $opts->{splitbibliography}, scanner => $scanner,
          %PostOPS)); }
    if ($opts->{crossref}) {
      require LaTeXML::Post::CrossRef;
      push(@procs, LaTeXML::Post::CrossRef->new(db => $DB, urlstyle => $opts->{urlstyle}, format => $format,
          ($opts->{numbersections} ? (number_sections => 1) : ()),
          ($opts->{navtoc} ? (navigation_toc => $opts->{navtoc}) : ()),
          %PostOPS)); }
    if ($opts->{picimages}) {
      require LaTeXML::Post::PictureImages;
      push(@procs, LaTeXML::Post::PictureImages->new(%PostOPS));
    }
    if ($opts->{dographics}) {
      # TODO: Rethink full-fledged graphics support
      require LaTeXML::Post::Graphics;
      my @g_options = ();
      if ($opts->{graphicsmaps} && scalar(@{ $opts->{graphicsmaps} })) {
        my @maps = map { [split(/\./, $_)] } @{ $opts->{graphicsmaps} };
        push(@g_options, (graphics_types => [map { $$_[0] } @maps],
            type_properties => { map { ($$_[0] => { destination_type => ($$_[1] || $$_[0]) }) } @maps })); }
      push(@procs, LaTeXML::Post::Graphics->new(@g_options, %PostOPS));
    }
    if ($opts->{svg}) {
      require LaTeXML::Post::SVG;
      push(@procs, LaTeXML::Post::SVG->new(%PostOPS)); }
    if (@$math_formats) {
      my @mprocs = ();
      ###    # If XMath is not first, it must be at END!  Or... ???
      foreach my $fmt (@$math_formats) {
        if ($fmt eq 'xmath') {
          require LaTeXML::Post::XMath;
          push(@mprocs, LaTeXML::Post::XMath->new(%PostOPS)); }
        elsif ($fmt eq 'pmml') {
          require LaTeXML::Post::MathML;
          if (defined $opts->{linelength}) {
            push(@mprocs, LaTeXML::Post::MathML::PresentationLineBreak->new(
                linelength => $opts->{linelength},
                (defined $opts->{plane1} ? (plane1 => $opts->{plane1}) : (plane1 => 1)),
                ($opts->{hackplane1} ? (hackplane1 => 1) : ()),
                %PostOPS)); }
          else {
            push(@mprocs, LaTeXML::Post::MathML::Presentation->new(
                (defined $opts->{plane1} ? (plane1 => $opts->{plane1}) : (plane1 => 1)),
                ($opts->{hackplane1} ? (hackplane1 => 1) : ()),
                %PostOPS)); } }
        elsif ($fmt eq 'cmml') {
          require LaTeXML::Post::MathML;
          push(@mprocs, LaTeXML::Post::MathML::Content->new(
              (defined $opts->{plane1} ? (plane1 => $opts->{plane1}) : (plane1 => 1)),
              ($opts->{hackplane1} ? (hackplane1 => 1) : ()),
              %PostOPS)); }
        elsif ($fmt eq 'om') {
          require LaTeXML::Post::OpenMath;
          push(@mprocs, LaTeXML::Post::OpenMath->new(
              (defined $opts->{plane1} ? (plane1 => $opts->{plane1}) : (plane1 => 1)),
              ($opts->{hackplane1} ? (hackplane1 => 1) : ()),
              %PostOPS)); }
      }
      ###    $keepXMath  = 0 unless defined $keepXMath;
      ### OR is $parallelmath ALWAYS on whenever there's more than one math processor?
      if ($parallel) {
        my $main = shift(@mprocs);
        $main->setParallel(@mprocs);
        push(@procs, $main); }
      else {
        push(@procs, @mprocs); }
    }
    if ($opts->{mathimages}) {
      require LaTeXML::Post::MathImages;
      push(@procs, LaTeXML::Post::MathImages->new(magnification => $opts->{mathimagemag}, %PostOPS));
    }
    if ($xslt) {
      require LaTeXML::Post::XSLT;
      my $parameters = { LATEXML_VERSION => "'$LaTeXML::VERSION'" };
      my @searchpaths = ('.', $DOCUMENT->getSearchPaths);
      foreach my $css (@{ $opts->{css} }) {
        if (pathname_is_url($css)) {    # external url ? no need to copy
          print STDERR "Using CSS=$css\n" if $verbosity > 0;
          push(@{ $parameters->{CSS} }, $css); }
        elsif (my $csssource = pathname_find($css, types => ['css'], paths => [@searchpaths],
            installation_subdir => 'style')) {
          print STDERR "Using CSS=$csssource\n" if $verbosity > 0;
          my $cssdest = pathname_absolute($css, pathname_directory($opts->{destination}));
          $cssdest .= '.css' unless $cssdest =~ /\.css$/;
          warn "CSS source $csssource is same as destination!" if $csssource eq $cssdest;
          pathname_copy($csssource, $cssdest) if ($opts->{local} || ($opts->{whatsout} eq 'archive')); # TODO: Look into local copying carefully
          push(@{ $$parameters{CSS} }, $cssdest); }
        else {
          warn "Couldn't find CSS file $css in paths " . join(',', @searchpaths) . "\n";
          push(@{ $$parameters{CSS} }, $css); } }    # but still put the link in!

      foreach my $js (@{ $opts->{javascript} }) {
        if (pathname_is_url($js)) {                  # external url ? no need to copy
          print STDERR "Using JAVASCRIPT=$js\n" if $verbosity > 0;
          push(@{ $$parameters{JAVASCRIPT} }, $js); }
        elsif (my $jssource = pathname_find($js, types => ['js'], paths => [@searchpaths],
            installation_subdir => 'style')) {
          print STDERR "Using JAVASCRIPT=$jssource\n" if $verbosity > 0;
          my $jsdest = pathname_absolute($js, pathname_directory($opts->{destination}));
          $jsdest .= '.js' unless $jsdest =~ /\.js$/;
          warn "Javascript source $jssource is same as destination!" if $jssource eq $jsdest;
          pathname_copy($jssource, $jsdest) if ($opts->{local} || ($opts->{whatsout} eq 'archive')); #TODO: Local handling
          push(@{ $$parameters{JAVASCRIPT} }, $jsdest); }
        else {
          warn "Couldn't find Javascript file $js in paths " . join(',', @searchpaths) . "\n";
          push(@{ $$parameters{JAVASCRIPT} }, $js);
        }
      }    # but still put the link in!
      if ($opts->{icon}) {
        if (my $iconsrc = pathname_find($opts->{icon}, paths => [$DOCUMENT->getSearchPaths])) {
          print STDERR "Using icon=$iconsrc\n" if $verbosity > 0;
          my $icondest = pathname_absolute($opts->{icon}, pathname_directory($opts->{destination}));
          pathname_copy($iconsrc, $icondest) if ($opts->{local} || ($opts->{whatsout} eq 'archive'));
          $$parameters{ICON} = $icondest; }
        else {
          warn "Couldn't find ICON " . $opts->{icon} . " in paths " . join(',', @searchpaths) . "\n";
          $$parameters{ICON} = $opts->{icon};
        }
      }
      if (!defined $opts->{timestamp}) { $opts->{timestamp} = localtime(); }
      if ($opts->{timestamp}) { $$parameters{TIMESTAMP} = "'" . $opts->{timestamp} . "'"; }
      # Now add in the explicitly given XSLT parameters
      foreach my $parm (@{ $opts->{xsltparameters} }) {
        if ($parm =~ /^\s*(\w+)\s*:\s*(.*)$/) {
          $$parameters{$1} = "'" . $2 . "'"; }
        else {
          warn "xsltparameter not in recognized format: 'name:value' got: '$parm'\n"; }
      }

      push(@procs, LaTeXML::Post::XSLT->new(stylesheet => $xslt,
          parameters => $parameters,
          noresources => (defined $opts->{defaultresources}) && !$opts->{defaultresources},
          %PostOPS));
    }
  }

  # If we are doing a local conversion OR
  # we are going to package into an archive
  # write all the files to disk during post-processing
  if ($opts->{destination} &&
    (($opts->{local} && ($opts->{whatsout} eq 'document'))
      || ($opts->{whatsout} eq 'archive'))) {
    require LaTeXML::Post::Writer;
    push(@procs, LaTeXML::Post::Writer->new(
        format => $format, omit_doctype => $opts->{omit_doctype},
        %PostOPS));
  }

  # Do the actual post-processing:
  my @postdocs;
  my $latexmlpost = LaTeXML::Post->new(verbosity => $verbosity || 0);
  @postdocs = $latexmlpost->ProcessChain($DOCUMENT, @procs);

  # Finalize by arranging any manifests and packaging the output.
  # If our format requires a manifest, create one
  if (($opts->{whatsout} eq 'archive') && ($format !~ /^x?html|xml/)) {
    require LaTeXML::Post::Manifest;
    my $manifest_maker = LaTeXML::Post::Manifest->new(db => $DB, format => $format, %PostOPS);
    $manifest_maker->process(@postdocs); }
  # Archives: when a relative --log is requested, write to sandbox prior packing
  if ($opts->{log} && ($opts->{whatsout} eq 'archive') && (!pathname_is_absolute($opts->{log}))) {
    my $destination_directory = $postdocs[0]->getDestinationDirectory();
    my $log_file = pathname_absolute($opts->{log}, $destination_directory);
    if (pathname_is_contained($log_file, $destination_directory)) {
      print STDERR "\nPost-processing complete: " . $latexmlpost->getStatusMessage . "\n";
      print STDERR "processing finished " . localtime() . "\n" if $verbosity >= 0;
      print STDERR "Status:conversion:" . ($self->{runtime}->{status_code} || '0') . " \n";
      open my $log_fh, '>', $log_file;
      print $log_fh $self->flush_log;
      close $log_fh;
      $self->bind_log; }
    else { print STDERR "Error:IO:log The target log file isn't contained in the destination directory!\n"; } }
  # Handle the output packaging
  require LaTeXML::Post::Pack;
  my $packer = LaTeXML::Post::Pack->new(whatsout => $opts->{whatsout}, format => $format, %PostOPS);
  my ($postdoc) = $packer->process(@postdocs);

  $DB->finish;

  # TODO: Refactor once we know how to merge the core and post State objects
  # Merge postprocessing and main processing reports
  foreach my $message_type (qw(warning error fatal)) {
    my $count = $latexmlpost->{status}->{$message_type} || 0;
    $runtime->{status_data}->{$message_type} += $count; }
  $runtime->{status}      = getStatusMessage($runtime->{status_data});
  $runtime->{status_code} = getStatusCode($runtime->{status_data});

  print STDERR "\nPost-processing complete: " . $latexmlpost->getStatusMessage . "\n";
  print STDERR "processing finished " . localtime() . "\n" if $verbosity >= 0;
  # Avoid writing the main file twice (non-archive documents):
  if ($opts->{destination} && $opts->{local} && ($opts->{whatsout} eq 'document')
    && ($opts->{whatsout} ne 'archive')) {
    undef $postdoc; }
  return $postdoc; }

sub new_latexml {
  my ($opts) = @_;

  # TODO: Do this in a GOOD way to support filepath/URL/string snippets
  # If we are given string preloads, load them and remove them from the preload list:
  my $preloads = $opts->{preload};
  my (@pre, @str_pre);
  foreach my $pre (@$preloads) {
    if (pathname_is_literaldata($pre)) {
      push @str_pre, $pre;
    } else {
      push @pre, $pre;
    }
  }
  require LaTeXML;
  my $latexml = LaTeXML::Core->new(preload => [@pre], searchpaths => [@{ $opts->{paths} }],
    graphicspaths   => ['.'],
    verbosity       => $opts->{verbosity}, strict => $opts->{strict},
    includeComments => $opts->{comments},
    inputencoding   => $opts->{inputencoding},
    includeStyles   => $opts->{includestyles},
    documentid      => $opts->{documentid},
    nomathparse     => $opts->{nomathparse},                            # Backwards compatibility
    mathparse       => $opts->{mathparse});

  if (my @baddirs = grep { !-d $_ } @{ $opts->{paths} }) {
    warn "\n$LaTeXML::IDENTITY : these path directories do not exist: " . join(', ', @baddirs) . "\n"; }

  $latexml->withState(sub {
      my ($state) = @_;
      $latexml->initializeState('TeX.pool', @{ $latexml->{preload} || [] });
  });

  # TODO: Do again, need to do this in a GOOD way as well:
  $latexml->digestFile($_, noinitialize => 1) foreach (@str_pre);

  return $latexml;
}

sub bind_log {
  # TODO: Move away from global file handles, they will inevitably end up causing problems..
  my ($self) = @_;
  if (!$LaTeXML::DEBUG) {    # Debug will use STDERR for logs
                             # Tie STDERR to log:
    my $log_handle;
    open($log_handle, ">>", \$self->{log}) or croak "Can't redirect STDERR to log! Dying...";
    *STDERR_SAVED = *STDERR;
    *STDERR       = *$log_handle;
    binmode(STDERR, ':encoding(UTF-8)');
    $self->{log_handle} = $log_handle;
  }
  return; }

sub flush_log {
  my ($self) = @_;
  # Close and restore STDERR to original condition.
  if (!$LaTeXML::DEBUG) {
    close $self->{log_handle};
    delete $self->{log_handle};
    *STDERR = *STDERR_SAVED;
  }
  my $log = $self->{log};
  $self->{log} = q{};
  return $log; }

sub sanitize {
  my ($self, $log) = @_;
  if ($log =~ m/^Fatal:internal/m) {
    # TODO : Anything else? Clean up the whole stomach etc?
    $self->{latexml}->withState(sub {
        my ($state) = @_;                   # Remove current state frame
        my $stomach = $state->getStomach;
        undef $stomach;
    });
    $self->{ready} = 0; }
  return; }

sub getStatusMessage {
  my ($status) = @_;
  my @report = ();
  push(@report, "$$status{warning} warning" . ($$status{warning} > 1 ? 's' : '')) if $$status{warning};
  push(@report, "$$status{error} error" .       ($$status{error} > 1 ? 's' : '')) if $$status{error};
  push(@report, "$$status{fatal} fatal error" . ($$status{fatal} > 1 ? 's' : '')) if $$status{fatal};
  return join('; ', @report) || 'No obvious problems'; }

sub getStatusCode {
  my ($status) = @_;
  my $code;
  if ($$status{fatal} && $$status{fatal} > 0) {
    $code = 3; }
  elsif ($$status{error} && $$status{error} > 0) {
    $code = 2; }
  elsif ($$status{warning} && $$status{warning} > 0) {
    $code = 1; }
  else {
    $code = 0; }
  return $code; }

1;

__END__

=pod 

=head1 NAME

C<LaTeXML> - Converter object and API for LaTeXML and LaTeXMLPost conversion.

=head1 SYNOPSIS

    use LaTeXML;
    my $converter = LaTeXML->get_converter($config);
    my $converter = LaTeXML->new($config);
    $converter->prepare_session($opts);
    $converter->initialize_session; # TODO: should be internal only
    $hashref = $converter->convert($tex);
    my ($result,$log,$status) = map {$hashref->{$_}} qw(result log status);

=head1 DESCRIPTION

A Converter object represents a converter instance and can convert files on demand, until dismissed.

=head2 METHODS

=over 4

=item C<< my $converter = LaTeXML->new($config); >>

Creates a new converter object for a given LaTeXML::Util::Config object, $config.

=item C<< my $converter = LaTeXML->get_converter($config); >>

Either creates, or looks up a cached converter for the $config configuration object.

=item C<< $converter->prepare_session($opts); >>

Top-level preparation routine that prepares both a correct options object
    and an initialized LaTeXML object,
    using the "initialize_options" and "initialize_session" routines, when needed.

Contains optimization checks that skip initializations unless necessary.

Also adds support for partial option specifications during daemon runtime,
     falling back on the option defaults given when converter object was created.

=item C<< my ($result,$status,$log) = $converter->convert($tex); >>

Converts a TeX input string $tex into the LaTeXML::Core::Document object $result.

Supplies detailed information of the conversion log ($log),
         as well as a brief conversion status summary ($status).
=back

=head2 INTERNAL ROUTINES

=over 4

=item C<< $converter->initialize_session($opts); >>

Given an options hash reference $opts, initializes a session by creating a new LaTeXML object 
      with initialized state and loading a daemonized preamble (if any).

Sets the "ready" flag to true, making a subsequent "convert" call immediately possible.

=item C<< my $latexml = new_latexml($opts); >>

Creates a new LaTeXML object and initializes its state.

=item C<< my $postdoc = $converter->convert_post($dom); >>

Post-processes a LaTeXML::Core::Document object $dom into a final format,
               based on the preferences specified in $self->{opts}.

Typically used only internally by C<convert>.

=item C<< $converter->bind_log; >>

Binds STDERR to a "log" field in the $converter object

=item C<< my $log = $converter->flush_log; >>

Flushes out the accumulated conversion log into $log,
         reseting STDERR to its usual stream.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Deyan Ginev <deyan.ginev@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
