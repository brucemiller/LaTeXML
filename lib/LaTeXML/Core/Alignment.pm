# /=====================================================================\ #
# |  LaTeXML::Core::Alignment                                           | #
# | Support for tabular/array environments                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Alignment;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Common::Object;
use LaTeXML::Common::XML;
use LaTeXML::Common::Dimension;
use LaTeXML::Core::Alignment::Template;
use List::Util qw(max sum);
use base qw(LaTeXML::Core::Whatsit);
use base qw(Exporter);
our @EXPORT = (qw(
    &ReadAlignmentTemplate &MatrixTemplate));

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# An "Alignment" is an array/tabular construct as:
#   <tabular><tr><td>...
# or, for math mode
#   <XMArray><XMRow><XMCell>...
# (where initially, each XMCell will contain an XMArg to indicate
# individual parsing of each cell's content is desired)
#
# An Alignment object is a sort of fake Whatsit;
# It takes some magic to sneak it into the Digestion stream
# (see TeX.pool \@start@alignment), but it needs to be created
# BEFORE the contents of the alignment are digested,
# since we stuff a lot of information into it
# (row, column boxes, borders, spacing, etc...)
# But once it has been captured, it should otherwise act
# like a Whatsit and be responsible for construction (beAbsorbed),
# and sizing estimation (computeSize)
#
# Ultimately, this should be better tied into DefConstructor
# because an Alignment currently doesn't know what CS created it (debugging!);
# Also, it would better connect the things being constructed, reversion, etc.
#======================================================================
DebuggableFeature('alignment', "Debug guessing headers of alignments/tables");

# Create a new Alignment.
# %data can contain:
#    template : an Alignment::Template object
#    openContainer  = sub($doc,%attrib); creates the container element with given attributes
#    closeContainer = sub($doc); closes the container
#    openRow        = sub($doc,%attrib); creates the row element with given attributes
#    closeRow       = closes the row
#    openColumn     = sub($doc,%attrib); creates the column element with given attributes
#    closeColumn    = closes the column
#    attributes = hashref containing extra attributes for the container element.
sub new {
  my ($class, %data) = @_;
  my $self = bless {%data}, $class;
  $$self{template}       = LaTeXML::Core::Alignment::Template->new() unless $$self{template};
  $$self{template}       = parseAlignmentTemplate($$self{template})  unless ref $$self{template};
  $$self{rows}           = [];
  $$self{current_column} = 0;
  $$self{current_row}    = undef;
  $$self{level}          = $STATE->getFrameDepth;
  $$self{properties}     = {} unless $$self{properties};
  # Copy any attribute width, height, depth to main properties.
  if (my $attributes = $$self{properties}{attributes}) {
    $$self{properties}{width}  = $$attributes{width}  if $$attributes{width};
    $$self{properties}{height} = $$attributes{height} if $$attributes{height};
    $$self{properties}{depth}  = $$attributes{depth}  if $$attributes{depth}; }
  return $self; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Alignment specific accessors
sub getTemplate {
  my ($self, $template) = @_;
  return $$self{template}; }

sub currentRow {
  my ($self) = @_;
  return $$self{current_row}; }

sub newRow {
  my ($self) = @_;
  my $row = $$self{template}->clone;
  $$self{current_row}    = $row;
  $$self{current_column} = 0;
  push(@{ $$self{rows} }, $row);
  return $row; }

sub removeRow {
  my ($self) = @_;
  my @rows = @{ $$self{rows} };
  if (@rows) {
    my $row = pop(@rows);
    $$self{rows} = [@rows];
    return $row; }
  else {
    return; } }

sub prependRows {
  my ($self, @rows) = @_;
  unshift(@{ $$self{rows} }, @rows);
  return; }

sub appendRows {
  my ($self, @rows) = @_;
  push(@{ $$self{rows} }, @rows);
  return; }

sub rows {
  my ($self) = @_;
  return @{ $$self{rows} }; }

sub addLine {
  my ($self, $border, @cols) = @_;
  if (my $row = $$self{current_row}) {
    if (@cols) {
      foreach my $c (@cols) {
        my $colspec = $row->column($c);
        $$colspec{border} .= $border; } }
    else {
      foreach my $colspec (@{ $$row{columns} }) {
        $$colspec{border} .= $border; } } }
  return; }

sub nextColumn {
  my ($self) = @_;
  return unless $$self{current_row};
  my $colspec = $$self{current_row}->column(++$$self{current_column});
  if (!$colspec) {
    Error('unexpected', '&', $STATE->getStomach->getGullet, "Extra alignment tab '&'");
    $$self{current_row}->addColumn(align => 'center');
    $colspec = $$self{current_row}->column($$self{current_column}); }
  return $colspec; }

sub lastColumn {
  my ($self) = @_;
  my $row = $$self{current_row};
  return unless $row;
  $$self{current_column} = scalar @{ $$row{columns} };
  return $row->column($$self{current_column}); }

sub currentColumnNumber {
  my ($self) = @_;
  return $$self{current_column}; }

sub currentRowNumber {
  my ($self) = @_;
  my $n = 0;
  foreach my $row (@{ $$self{rows} }) {
    $n++ unless $$row{pseudorow}; }
  return $n; }

sub currentColumn {
  my ($self) = @_;
  return $$self{current_row} && $$self{current_row}->column($$self{current_column}); }

sub getColumn {
  my ($self, $n) = @_;
  return $$self{current_row} && $$self{current_row}->column($n); }

# Ugh... these take boxes; adding before/after columns takes tokens!
sub addBeforeRow {
  my ($self, @boxes) = @_;
  $$self{current_row}{before} = [@{ $$self{current_row}{before} || [] }, @boxes];
  return; }

sub addAfterRow {
  my ($self, @boxes) = @_;
  $$self{current_row}{after} = [@{ $$self{current_row}{after} || [] }, @boxes];
  return; }

sub omitColumn {
  my ($self) = @_;
  if (my $column = $self->currentColumn) {
    $$column{omitted} = 1; }
  return; }

sub omitNextColumn {
  my ($self) = @_;
  if (my $column = $$self{current_row} && $$self{current_row}->column($$self{current_column} + 1)) {
    $$column{omitted} = 1; }
  return; }

sub getColumnBefore {
  my ($self) = @_;
  my $column;
  if (($column = $self->currentColumn) && !$$column{omitted}) {
    return Tokens(T_CS('\@column@before'), @{ $$column{before} }); }
  else {
    return Tokens(); } }

sub getColumnAfter {
  my ($self) = @_;
  my $column;
  if (($column = $self->currentColumn) && !$$column{omitted}) {
    # Possible \@@eat@space ??? (if LaTeX style???)
    return Tokens(@{ $$column{after} }, T_CS('\@column@after')); }
  else {
    return Tokens(); } }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Support for building an alignment's Rows & Columns

sub startRow {
  my ($self, $pseudorow) = @_;
  $self->newRow;
  my $stomach = $STATE->getStomach;
  $stomach->bgroup;    # Grouping around ROW!
  if ($pseudorow) {
    $self->currentRow->{pseudorow} = 1; }
  else {
    push(@LaTeXML::LIST, $stomach->digest(T_CS('\@row@before'))); }
  $$self{in_row} = 1;
  $STATE->assignValue(alignmentStartColumn => 0);    # ???
  return; }

sub endRow {
  my ($self) = @_;
  return unless $$self{in_row};
  $self->endColumn() if $$self{in_column};
  $STATE->getStomach->egroup;                        # Grouping around ROW!
                                                     #  Digest(T_CS('\@row@after'));
  $$self{in_row} = undef;
  return; }

sub startColumn {
  my ($self, $pseudorow) = @_;
  if (!$$self{in_row}) {
    $self->startRow($pseudorow); }
  elsif ($pseudorow) {
    $self->currentRow->{pseudorow} = 1; }
  $STATE->getStomach->bgroup;    # Grouping around CELL!
                                 # Note: a VERY round-about way of tracking the column spanning!
  $STATE->assignValue(alignmentStartColumn => $self->currentColumnNumber);
  my $colspec = $self->nextColumn;
  $LaTeXML::ALIGN_STATE = 1000000;
  $$self{in_column} = 1;
  return; }

sub endColumn {
  my ($self) = @_;
  return unless $$self{in_column};
  $STATE->getStomach->egroup;    # Grouping around CELL!
  $$self{in_column} = undef;
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Making the Alignment act like a Whatsit
sub toString {
  my ($self) = @_;
  return "Alignment[]"; }

# Methods for overloaded operators
sub stringify {
  my ($self) = @_;
  return "Alignment[]"; }

sub revert {
  my ($self) = @_;
  if ($LaTeXML::DUAL_BRANCH && ($LaTeXML::DUAL_BRANCH eq 'content') && $$self{content_reversion}) {
    return $$self{content_reversion}->unlist; }
  return $$self{reversion}->unlist; }

sub setReversion {
  my ($self, $tokens) = @_;
  $$self{reversion} = $tokens;
  return; }

sub setContentReversion {
  my ($self, $tokens) = @_;
  $$self{content_reversion} = $tokens;
  return; }

sub computeSize {
  my ($self) = @_;
  $self->normalizeAlignment;
  return ($$self{cwidth}, $$self{cheight}, $$self{cdepth}); }

#======================================================================
# Constructing the XML for the alignment.

sub beAbsorbed {
  my ($self, $document) = @_;
  my $attr   = $self->getProperty('attributes');
  my $body   = $self->getBody;
  my $ismath = $$self{isMath};
  $self->normalizeAlignment;
  # We _should_ attach boxes to the alignment and rows,
  # but (ATM) we've only got sensible boxes for the cells.
  &{ $$self{openContainer} }($document, ($attr ? %$attr : ()),
    cwidth => $$self{cwidth}, cheight => $$self{cheight}, cdepth => $$self{cdepth},
  );
  foreach my $row (@{ $$self{rows} }) {
    my $vpad = $$row{padding};
    &{ $$self{openRow} }($document,
      'xml:id' => $$row{id}, tags => $$row{tags},
      # Which properties do we expose to the constructor?
      x => $$row{x}, y => $$row{y},
      cwidth => $$row{cwidth}, cheight => $$row{cheight}, cdepth => $$row{cdepth},
    );
    if (my $before = $$row{before}) {
      map { $document->absorb($_) } @$before; }
    foreach my $cell (@{ $$row{columns} }) {
      next if $$cell{skipped};
      # Normalize the border attribute
      my $border = join(' ', sort(map { split(/ */, $_) } $$cell{border} || ''));
      $border =~ s/(.) \1/$1$1/g;
      my $empty = $$cell{empty} || !$$cell{boxes} || !scalar($$cell{boxes}->unlist);
      $$cell{cell} = &{ $$self{openColumn} }($document,
        align => $$cell{align}, width => $$cell{width},
        vattach => $$cell{vattach},
        ($vpad                       ? (cssstyle => 'padding-bottom:' . ToString($vpad))     : ()),
        (($$cell{colspan} || 1) != 1 ? (colspan  => $$cell{colspan})                         : ()),
        (($$cell{rowspan} || 1) != 1 ? (rowspan  => $$cell{rowspan})                         : ()),
        ($border                     ? (border   => $border)                                 : ()),
        ($$cell{thead}               ? (thead    => join(' ', sort keys %{ $$cell{thead} })) : ()),
        # Which properties do we expose to the constructor?
        x => $$cell{x}, y => $$cell{y},
        cwidth => $$cell{cwidth}, cheight => $$cell{cheight}, cdepth => $$cell{cdepth},
      );
      if (!$empty) {
        local $LaTeXML::BOX = $$cell{boxes};
        $document->openElement('ltx:XMArg', rule => 'Anything,') if $ismath;    # Hacky!
        $document->absorb($$cell{boxes});
        $document->closeElement('ltx:XMArg') if $ismath;
      }
      &{ $$self{closeColumn} }($document); }
    if (my $after = $$row{after}) {
      map { $document->absorb($_) } @$after; }
    &{ $$self{closeRow} }($document); }
  my $node = &{ $$self{closeContainer} }($document);

  # If we're not nested inside another tabular
  # [This should be an afterConstruct somewhere?]
  # If requested to guess headers & we're not nested inside another tabular
  if (!$document->findnodes("ancestor::ltx:tabular", $node)) {
    my $hashead = $document->findnodes('descendant::ltx:td[@thead]', $node);
    # If requested && no cells are already marked as being thead, apply heuristic
    if ($self->getProperty('guess_headers') && !$hashead) {
      guess_alignment_headers($document, $node, $self); }
    # Otherwise, if not a math array, group thead & tbody rows
    elsif ($hashead && !$body->isMath) {    # in case already marked w/thead|tbody
      alignment_regroup_rows($document, $node); } }

  return $node; }

#======================================================================
# Normalize an alignment before construction
# * consolodating column & row spanning information
# * scanning for empty rows & columns and collapsing them
#   (while accounting for spanning, and copying borders appropriately)
# Note that a trailing \\ in allignment (often needed to effect \hline)
# causes an empty row at the end. Other fancy layout fine-tuning often
# involves adding extra rows & columsn for spacing.  HTML's table model
# is more forgiving that TeX's, so we don't need these extras
# and, in fact, they often mess up the html layout!
# However, math alignments, and those with expected structure (eg. eqnarray)
# should generally NOT have rows & columns collapsed --- except the last row!

# Also note the inconsistency between TeX & HTML's table models regarding spans.
# \multicolumn creates a cell that covers a certain number of columns
# which are then omitted from the LaTeX AND the HTML.
# OTOH, \multirow creates a cell which overlaps following rows!
# The & is still needed to allocate the cells in those rows.
# And in fact they need not even be empty! TeX will just pile them up!
# However, in HTML the spanned rows ARE omitted!
sub normalizeAlignment {
  my ($self) = @_;
  return if $$self{normalized};
  #======================================================================
  # Note: Cell Sizes & empty will have been set by extractAlignmentColumn
  $self->normalize_cell_sizes();
  $self->normalize_mark_spans();
  $self->normalize_prune_rows();
  $self->normalize_prune_columns();
  $self->normalize_sum_sizes();
  #======================================================================
  $$self{normalized} = 1;
  return; }

# Compute (approximate) sizes of all cells
sub normalize_cell_sizes {
  my ($self) = @_;
  # Examines: boxes, align, vattach
  # Sets: cwidth, cheight, cdepth (per cell) & empty
  # Whatabout: cellspan, rowspan?
  # Can we deal with those now, or only after other normalization???
  my $base = $STATE->lookupDefinition(T_CS('\baselineskip'))->valueOf->valueOf;
  foreach my $row (@{ $$self{rows} }) {
    # Do we need to account for any space in the $$row{before} or $$row{after}?
    foreach my $cell (@{ $$row{columns} }) {
      if (my $boxes = $$cell{boxes}) {
        my ($w, $h, $d, $cw, $ch, $cd)
          = $boxes->getSize(align => $$cell{align}, width => $$cell{width},
          vattach => $$cell{vattach});
        my $empty =
          ((!$cw) || $cw->valueOf < 1)
          || (((!$ch) || $ch->valueOf < 1)
          && ((!$cd) || $cd->valueOf < 1))
          || !(grep { !$_->getProperty('isSpace'); } $boxes->unlist);
        $$cell{cwidth}  = $cw;
        $$cell{cheight} = $ch;                 # + 1/4 base ???
        $$cell{cdepth}  = $cd;
        $$cell{empty}   = $empty;
        $$cell{align}   = undef if $empty; }
      else {
        $$cell{empty} = 1; }

  } }
  return; }

sub normalize_sum_sizes {
  my ($self)     = @_;
  my @rowheights = ();
  my @colwidths  = ();
  # Uses cell's cwidth,cheight,cdepth
  # Computes net row & column sizes & positions
  # add \baselineskip between rows? Or max the row heights with it ...
  my $base  = $STATE->lookupDefinition(T_CS('\baselineskip'))->valueOf->valueOf;
  my @rows  = @{ $$self{rows} };
  my $nrows = scalar(@rows);
  for (my $i = 0 ; $i < $nrows ; $i++) {
    my $row   = $rows[$i];
    my @cols  = @{ $$row{columns} };
    my $ncols = scalar(@cols);
    if (my $short = $ncols - scalar(@colwidths)) {
      push(@colwidths, map { 0 } 1 .. $short); }
    my ($rowh, $rowd) = ($base * 0.7, $base * 0.3);
    for (my $j = 0 ; $j < $ncols ; $j++) {
      my $cell = $cols[$j];
      next if $$cell{skipped};
      next unless $$cell{boxes};
      my $w = $$cell{cwidth};
      my $h = $$cell{cheight};
      my $d = $$cell{cdepth};
      if (($$cell{colspan} || 1) == 1) {
        $colwidths[$j] = max($colwidths[$j], $w->valueOf) if $w; }
      if (($$cell{rowspan} || 1) == 1) {
        $rowh = max($rowh, $h->valueOf) if $h;
        $rowd = max($rowd, $d->valueOf) if $d; }
      else { }    # Ditto spanned rows
    }
    $$row{height} = Dimension($rowh + 0.25 * $base);
    $$row{depth}  = Dimension($rowd + 0.25 * $base);
    # NOTE: Should be storing column widths to; individually, as well as per-column!
    push(@rowheights, $rowh + $rowd + 0.5 * $base); }    # somehow our heights are way too short????
  ## Now compute the positions
  my @rowpos = ();
  my @colpos = ();
  my $y      = 0;
  for (my $i = 0 ; $i < scalar(@rowheights) ; $i++) {
    $rowpos[$i] = Dimension($y); $y += $rowheights[$i]; }
  my $x = 0;
  for (my $j = 0 ; $j < scalar(@colwidths) ; $j++) {
    $colpos[$j] = Dimension($x); $x += $colwidths[$j]; }
  $$self{cwidth}  = Dimension($x);
  $$self{cheight} = Dimension($y);
  $$self{cdepth}  = Dimension(0);
  for (my $i = 0 ; $i < scalar(@rowheights) ; $i++) {
    my $row   = $rows[$i];
    my @cols  = @{ $$row{columns} };
    my $ncols = scalar(@cols);
    $$row{x}       = $colpos[0]; $$row{y} = $rowpos[$i];
    $$row{cheight} = Dimension($rowheights[$i]);
    for (my $j = 0 ; $j < $ncols ; $j++) {
      my $cell = $cols[$j];
      $$cell{x} = $colpos[$j]; $$cell{y} = $rowpos[$i]; } }
  return; }

# Mark any cells that are covered by rowspan or colspan
sub normalize_mark_spans {
  my ($self) = @_;
  # Examines: rowspan, colspan, pseudorow, empty
  # Sets: skipped, colspanned, rowspanned
  my @rows = @{ $$self{rows} };
  for (my $i = 0 ; $i < scalar(@rows) ; $i++) {
    my $row = $rows[$i];
    my @row = @{ $$row{columns} };
    for (my $j = 0 ; $j < scalar(@row) ; $j++) {
      my $col = $row[$j];
      my ($nc, $nr);
      # scan the row for spanned columns that also span rows! Move rowspan to leading column
      if (($nc = $$col{colspan} || 1) > 1) {
        foreach (my $jj = $j + 1 ; $jj < $j + $nc ; $jj++) {
          my $ccol = $row[$jj];
          $$ccol{skipped}    = 1;
          $$ccol{colspanned} = $j;            # note that this column is spanned by column $j
          if (my $cnr = $$ccol{rowspan}) {    # If this spanned column has rowspan
            $$col{rowspan} = $cnr; } } }      # copy rowspan to initial column
      if (($nr = $$col{rowspan} || 1) > 1) {    # If this column spans rows
        my $nr_orig = $nr;
        my $ncspan  = $$col{colspan} || 1;
        # Mark all spanned columns in following rows as skipped.
        my $nrc = $nr;
        my $ii;
        for ($ii = $i + 1 ; $nrc ; $ii++) {
          # Prescan the columns to make sure they're empty!
          my $rowempty  = 1;
          my $rrow      = $rows[$ii];
          my $rowpseudo = $$rrow{pseudorow};
          $nrc-- unless $rowpseudo;
          if ($rrow) {
            for (my $jj = $j ; $jj < $j + $ncspan ; $jj++) {
              if (my $ccol = $$rrow{columns}[$jj]) {
                if (!$$ccol{empty}) {
                  $rowempty = 0; } } } }
          if    (!$nrc) { }
          elsif (!$rrow || !$rowempty) {
            # Prescan the columns to make sure they're empty!
            my $oldnr = $nr;
            $nr  = $$col{rowspan} = $nr - $nrc;
            $nrc = 0;
            Info('unexpected', 'rowspan', undef,
              "Rowspan $oldnr in cell($i,$j) covers non-empty cells; truncating.to $nr"); }
          elsif ($rrow) {
            for (my $jj = $j ; $jj < $j + $ncspan ; $jj++) {
              if (my $ccol = $$rrow{columns}[$jj]) {
                $$ccol{skipped}    = 1;
                $$ccol{rowspanned} = $i; } } } }    # note that this column is spanned by row $i
            # And, if the last (skipped) columns have a bottom border, copy that to the rowspanned col
        if (my $rrow = $rows[$ii - 1]) {
          my $sborder = '';
          for (my $jj = $j ; $jj < $j + $nc ; $jj++) {
            if (my $ccol = $$rrow{columns}[$jj]) {
              my $border = $$ccol{border} || '';
              $border =~ s/[^bB]//g;    # mask all but bottom border
              $sborder = $border unless $sborder; } }
          $$col{border} .= $sborder if $sborder; }
  } } }
  return; }

# Now scan for and remove empty rows & columns
# but copying borders and adjusting rowspan's & colspan's appropriately.
sub normalize_prune_rows {
  my ($self) = @_;
  # Examines: rowspan,rowspanned, border, pseudorow, empty
  # Sets: border, rowspan
  my $preserve = $$self{isMath} || $self->getProperty('preserve_structure');
  # First, do rows.
  my @rows     = @{ $$self{rows} };
  my @filtered = ();
  for (my $i = 0 ; $i < scalar(@rows) ; $i++) {
    my $row = $rows[$i];
    if (grep { !$$_{empty} } @{ $$row{columns} }) {    # Not empty! so keep it
      push(@filtered, $row); }
    elsif (my $next = $rows[$i + 1]) {    # Remove empty row, but copy top border to NEXT row
      if ($preserve) {
        push(@filtered, $row); next; }    # don't remove inner rows from math
      my $nc = scalar(@{ $$row{columns} });
      for (my $j = 0 ; $j < $nc ; $j++) {
        my $col = $$row{columns}[$j];
        if (!$$row{pseudorow} && defined $$col{rowspanned}) {
          $rows[$$col{rowspanned}]{columns}[$j]{rowspan}--; }    # Decrement rowspan of spanning column
        my $border = $$col{border} || '';
        $border =~ s/[^tTbB]//g;                                 # mask all but top & bottom border
        $border =~ s/b/t/g;                                      # but convert to top
        $border =~ s/B/T/g;                                      # but convert to top
        $$next{columns}[$j]{border} .= $border; } }              # add to next row
    else {    # Remove empty last row, but copy top border to bottom of prev.
      my $prev = $filtered[-1];
      my $nc   = scalar(@{ $$row{columns} });
      for (my $j = 0 ; $j < $nc ; $j++) {
        my $col = $$row{columns}[$j];
        if (!$$row{pseudorow} && defined $$col{rowspanned}) {
          $rows[$$col{rowspanned}]{columns}[$j]{rowspan}--; }    # Decrement rowspan of spanning column
        my $border = $$col{border} || '';
        $border =~ s/[^tT]//g;                                   # mask all but top border
        $border =~ s/t/b/g;                                      # convert to bottom
        $border =~ s/T/B/g;                                      # convert to bottom
        my $ccol = $$prev{columns}[$j];
        if (defined $$ccol{rowspanned}) {                        # skip to spanning column if rowspanned!
          $ccol = $rows[$$ccol{rowspanned}]{columns}[$j]; }
        $$ccol{border} .= $border; } }                           # add to previous row.
  }
  @rows = @filtered;
  $$self{rows} = [@filtered];
  return; }

sub normalize_prune_columns {
  my ($self) = @_;
  my $preserve = $$self{isMath} || $self->getProperty('preserve_structure');
  # Now prune empty columns.
  if (!$preserve) {    # Don't remove empty columns from math.
    my @rows = @{ $$self{rows} };
    my $nc   = 0;
    foreach my $row (@rows) {
      my $n = scalar(@{ $$row{columns} });
      $nc = $n if $n > $nc; }
    for (my $j = $nc - 1 ; $j >= 0 ; $j--) {
      if (!grep { (defined $$_{columns}[$j]) && !$$_{columns}[$j]{empty} } @rows) {    # Empty!
        foreach my $row (@rows) {
          if (my $col = $$row{columns}[$j]) {
            if (defined $$col{colspanned}) {
              $$row{columns}[$$col{colspanned}]{colspan}--; }    # Decrement colspan of spanning column
            my $border = $$col{border} || '';
            if ($j > 0) {
              my $prev = $$row{columns}[$j - 1];
              if (my $jj = $$prev{colspanned}) {
                $prev = $$row{columns}[$jj]; }
              $border =~ s/[^rRlL]//g;                              # mask all but left border
              $border =~ s/l/r/g;                                   # convert to right
              $border =~ s/L/R/g;                                   # convert to right
              $$prev{border} .= $border;
              if (my @preserve = preservedBoxes($$col{boxes})) {    # Copy boxes over, in case side effects?
                $$prev{boxes} = LaTeXML::Core::List($$prev{boxes}
                  ? ($$prev{boxes}->unlist, @preserve) : @preserve); }
            }
            elsif (my $next = $$row{columns}[1]) {
              $border =~ s/[^rRlL]//g;                              # mask all but left & right border
              $border =~ s/r/l/g;                                   # but convert to left
              $border =~ s/R/L/g;                                   # but convert to left
              $$next{border} .= $border;                            # add to next row
              if (my @preserve = preservedBoxes($$col{boxes})) {    # Copy boxes over, in case side effects?
                $$next{boxes} = LaTeXML::Core::List($$col{boxes}
                  ? (@preserve, $$next{boxes}->unlist) : @preserve); }
            }    # Now, remove the column
            $$row{columns} = [grep { $_ ne $col } @{ $$row{columns} }];
    } } } }
  }
  return; }

sub show_row {
  my ($i, $row) = @_;
  Debug("\nRow[$i]:" . join(', ', map { $_ . '=' . ToString($$row{$_}); }
        grep { $_ ne 'columns'; } sort keys %$row));
  my @c = @{ $$row{columns} };
  for (my $j = 1 ; @c ; $j++) {
    show_col($i, $j, shift(@c)); }
  return; }

sub show_col {
  my ($i, $j, $col) = @_;
  Debug("Column[$i,$j]:" . join(', ', map { $_ . '=' . ToString($$col{$_}); } sort keys %$col));
  return; }

sub preservedBoxes {
  my ($boxes) = @_;
  return ($boxes ? grep { $_->getProperty('alignmentPreserve') } $boxes->unlist : ()); }
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Dealing with templates

# newcolumntype
#  defines \NC@rewrite@<char>
#    As macro
#    or "constructor" (or just sub that creates a column)

sub ReadAlignmentTemplate {
  my ($gullet) = @_;
  $gullet->skipSpaces;
  local $LaTeXML::BUILD_TEMPLATE =
    LaTeXML::Core::Alignment::Template->new(columns => [], tokens => []);
  my @tokens = (T_BEGIN);
  my $nopens = 0;
  while (my $open = $gullet->readToken) {
    if ($open->equals(T_BEGIN)) { $nopens++; }
    else                        { $gullet->unread($open); last; } }
  my $defn;
  while (my $op = $gullet->readToken) {
    if    ($op->equals(T_SPACE)) { }
    elsif ($op->equals(T_END)) {
      while (--$nopens && ($op = $gullet->readToken)->equals(T_END)) { }
      last unless $nopens;
      $gullet->unread($op); }
    elsif (defined($defn = $STATE->lookupDefinition(T_CS('\NC@rewrite@' . ToString($op))))
      && $defn->isExpandable) {
      $gullet->unread($defn->invoke($gullet, 1)); }
    elsif ($op->equals(T_BEGIN)) {    # Wrong, but a safety valve
      $gullet->unread($gullet->readBalanced); }
    else {
      Warn('unexpected', $op, $gullet, "Unrecognized tabular template '" . Stringify($op) . "'"); }
    last unless $nopens; }
  push(@tokens, T_END);
  $LaTeXML::BUILD_TEMPLATE->setReversion(@tokens);
  return $LaTeXML::BUILD_TEMPLATE; }

sub parseAlignmentTemplate {
  my ($spec) = @_;
  return $STATE->getStomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth->new("{" . $spec . "}"), sub {
      ReadAlignmentTemplate($_[0]); }); }

sub MatrixTemplate {
  return LaTeXML::Core::Alignment::Template->new(repeated => [{ before => Tokens(T_CS('\hfil')),
        after => Tokens(T_CS('\hfil')) }]); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Experimental alignment heading heuristications.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# We attempt to recognize patterns of rows/columns that indicate which might be headers.
# We'll characterize the cells by alignment, content and borders.
# Then, assuming that headers will be first and be noticably `different' from data lines,
# and also that the data lines will have similar structure,  we'll attempt to
# recognize groups of header lines and groups data lines, possibly alternating.

sub guess_alignment_headers {
  my ($document, $table, $alignment) = @_;
  # Assume that headers don't make sense for nested tables.
  # OR Maybe we should only do this within table environments???
  return if $document->findnodes("ancestor::ltx:tabular", $table);

  my $tag = $document->getModel->getNodeQName($table);
  my $x;
  Debug(('=' x 50) . "\nGuessing alignment headers for "
      . (($x = $document->findnode('ancestor-or-self::*[@xml:id]', $table)) ? $x->getAttribute('xml:id') : $tag))
    if $LaTeXML::DEBUG{alignment};

  my $ismath = $tag eq 'ltx:XMArray';
  local $LaTeXML::TR = ($ismath ? 'ltx:XMRow'  : 'ltx:tr');
  local $LaTeXML::TD = ($ismath ? 'ltx:XMCell' : 'ltx:td');
  my $reversed = 0;
  # Build a view of the table by extracting the rows, collecting & characterizing each cell.
  my @rows = collect_alignment_rows($document, $table, $alignment);
  # Flip the rows around to produce a column view.
  my @cols = ();
  return unless @rows;
  for (my $c = 0 ; $c < scalar(@{ $rows[0] }) ; $c++) {
    push(@cols, [map { $$_[$c] } @rows]); }

  # Attempt to recognize header lines.
  if (alignment_characterize_lines($document, 0, 0, @rows)) { }
  # This usually does something unpleasant
##  else {
##    Debug("Retry characterizing lines in reverse") if $LaTeXML::DEBUG{alignment};
##    $reversed=alignment_characterize_lines(0,1,reverse(@rows)); }
  alignment_characterize_lines($document, 1, 0, @cols);
  # Did we go overboard?
  my %n = (h => 0, d => 0);
  foreach my $r (@rows) {
    foreach my $c (@$r) {
      $n{ $$c{cell_type} }++; } }
  Debug("$n{h} header, $n{d} data cells") if $LaTeXML::DEBUG{alignment};
  if ($n{d} == 1) {    # Or any other heuristic?
    $n{h} = 0;
    foreach my $r (@rows) {
      foreach my $c (@$r) {
        $$c{cell_type} = 'd';
        $$c{cell}->removeAttribute('thead') if $$c{cell}; } } }
  # Regroup the rows into thead & tbody elements.
  # But not if it's a math array, or if reversed (since browsers get confused?)
  if (!$ismath && !$reversed) {
    alignment_regroup_rows($document, $table); }
  if ($n{h}) {    # Found some headers?
    $document->addClass($table, 'ltx_guessed_headers'); }

  # Debugging report!
  summarize_alignment([@rows], [@cols]) if $LaTeXML::DEBUG{alignment};
  return; }

#======================================================================
# Regroup the rows into thead, tbody & tfoot
# Any leading rows, all of whose cells have attribute thead should be in thead.
# UNLESS any of them have a rowspan that extends PAST the end of the thead!!!!
# trailing rows marked as thead go into tfoot.
sub alignment_regroup_rows {
  my ($document, $table) = @_;
  my @rows     = $document->findnodes("ltx:tr", $table);
  my @heads    = ();
  my $maxreach = 0;
  # Scan initial rows as potential thead
  while (@rows) {
    my @cells = $document->findnodes('ltx:td', $rows[0]);
    # Non header cells, done.
    last if scalar(grep { (!$_->getAttribute('thead')) } @cells);
    my $line = scalar(@heads);
    push(@heads, shift(@rows));
    $maxreach = max($maxreach, map { ($_->getAttribute('rowspan') || 0) + $line } @cells); }
  if ($maxreach > scalar(@heads)) {    # rowspan crossed over thead boundary!
    unshift(@rows, @heads); @heads = (); }
  # scan trailing rows as potential tfoot
  my @foots = ();
  while (@rows) {
    my @cells = $document->findnodes('ltx:td', $rows[-1]);
    # Non header cells, done.
    last if scalar(grep { (!$_->getAttribute('thead')) } @cells);
    unshift(@foots, pop(@rows)); }
  $document->wrapNodes('ltx:thead', @heads) if @heads;
  $document->wrapNodes('ltx:tbody', @rows)  if @rows;
  $document->wrapNodes('ltx:tfoot', @foots) if @foots;
  return; }

#======================================================================
# Build a View of the alignment, with characterized cells, for analysis.
my %ALIGNMENT_CODE = (    # CONSTANT
  right => 'r', left => 'l', center => 'c', justify => 'p');

sub collect_alignment_rows {
  my ($document, $table, $alignment) = @_;
  my @arows = @{ $$alignment{rows} };
  my $nrows = scalar(@arows);
  my $ncols = 0;
  foreach my $arow (@arows) {
    my $n = scalar(@{ $$arow{columns} });
    $ncols = $n if $n > $ncols; }
  my @rows = ();
  my ($h, $v) = (0, 0);
  foreach my $arow (@arows) {
    push(@rows, []);
    my @cols = @{ $$arow{columns} };
    foreach my $col (@cols) {
      push(@{ $rows[-1] }, $col);
      $$col{cell_type} = 'd';
      $$col{content_class} = (($$col{align} || '') eq 'justify' ? 'mx' # Assume mixed content for any justified cell???
        : ($$col{cell} ? classify_alignment_cell($document, $$col{cell}) : '?'));
      $$col{content_length} = ($$col{content_class} eq 'g' ? 1000
        : ($$col{cell} ? length($$col{cell}->textContent) : 0));
      my %border = (t => 0, r => 0, b => 0, l => 0);                   # Decode border
      map { $border{$_}++ } split(/ */, $$col{border} || '');
      $h = 1 if $border{t} || $border{b};
      $v = 1 if $border{r} || $border{l};
      map { $$col{$_} = $border{$_} } keys %border; }
    # pad the columns out.
    for (my $c = scalar(@cols) ; $c < $ncols ; $c++) {
      my $col = {};
      push(@{ $rows[-1] }, $col);
      $$col{align}          = 'c';
      $$col{cell_type}      = 'd';
      $$col{content_class}  = '_';
      $$col{content_length} = 0;
      map { $$col{$_} = 0 } qw(t r b l); }
  }
  # copy the characterizations to spanned cells
  for (my $r = 0 ; $r < $nrows ; $r++) {
    for (my $c = 0 ; $c < $ncols ; $c++) {
      my $rs = $rows[$r][$c]{rowspan} || 1;
      my $cs = $rows[$r][$c]{colspan} || 1;
      my $ca = $rows[$r][$c]{align};
      my $cc = $rows[$r][$c]{content_class};
      my $cl = $rows[$r][$c]{content_length};
      my $rb = $rows[$r][$c]{r}; $rows[$r][$c]{r} = 0;
      my $bb = $rows[$r][$c]{b}; $rows[$r][$c]{b} = 0;
      for (my $sc = 1 ; $sc < $cs ; $sc++) {
        $rows[$r][$c + $sc]{align}          = $ca;
        $rows[$r][$c + $sc]{content_class}  = $cc;
        $rows[$r][$c + $sc]{content_length} = $cl; }
      for (my $sr = 1 ; $sr < $rs ; $sr++) {
        for (my $sc = 0 ; $sc < $cs ; $sc++) {
          $rows[$r + $sr][$c + $sc]{align}          = $ca;
          $rows[$r + $sr][$c + $sc]{content_class}  = $cc;
          $rows[$r + $sr][$c + $sc]{content_length} = $cl; } }
      # move the outer borders
      for (my $sr = 0 ; $sr < $rs ; $sr++) {
        $rows[$r + $sr][$c + $cs - 1]{r} = $rb; }
      for (my $sc = 0 ; $sc < $cs ; $sc++) {
        $rows[$r + $rs - 1][$c + $sc]{b} = $bb; }
  } }

  # Now, do some border massaging...
  for (my $r = 0 ; $r < $nrows ; $r++) {
    $rows[$r][0]{l}          = $v;
    $rows[$r][0]{r}          = $rows[$r][1]{l}          if ($ncols > 1) && $rows[$r][1]{l};
    $rows[$r][$ncols - 1]{l} = $rows[$r][$ncols - 2]{r} if ($ncols > 1) && $rows[$r][$ncols - 2]{r};
    $rows[$r][$ncols - 1]{r} = $v; }
  for (my $c = 0 ; $c < $ncols ; $c++) {
    $rows[0][$c]{t}          = $h;
    $rows[0][$c]{b}          = $rows[1][$c]{t}          if ($nrows > 1) && $rows[1][$c]{t};
    $rows[$nrows - 1][$c]{t} = $rows[$nrows - 2][$c]{b} if ($nrows > 1) && $rows[$nrows - 2][$c]{b};
    $rows[$nrows - 1][$c]{b} = $h; }
  for (my $r = 1 ; $r < $nrows - 1 ; $r++) {
    for (my $c = 1 ; $c < $ncols - 1 ; $c++) {
      $rows[$r][$c]{t} = $rows[$r - 1][$c]{b} if $rows[$r - 1][$c]{b};
      $rows[$r][$c]{b} = $rows[$r + 1][$c]{t} if $rows[$r + 1][$c]{t};
      $rows[$r][$c]{l} = $rows[$r][$c - 1]{r} if $rows[$r][$c - 1]{r};
      $rows[$r][$c]{r} = $rows[$r][$c + 1]{l} if $rows[$r][$c + 1]{l}; } }
  if ($LaTeXML::DEBUG{alignment}) {
    Debug("Cell characterizations:");
    for (my $r = 0 ; $r < $nrows ; $r++) {
      for (my $c = 0 ; $c < $ncols ; $c++) {
        my $col = $rows[$r][$c];
        Debug("[$r,$c]=>" . ($$col{cell_type} || '?')
            . ($$col{align} ? $ALIGNMENT_CODE{ $$col{align} } : ' ')
            . ($$col{content_class} || '?')
            . ' ' . $$col{content_length}
            . ' ' . $$col{border} . "=>" . join('', grep { $$col{$_} } qw(t r b l))
            . (($$col{rowspan} || 1) > 1 ? " rowspan=" . $$col{rowspan} : '')
            . (($$col{colspan} || 1) > 1 ? " colspan=" . $$col{colspan} : '')); } } }
  return @rows; }

# Return one of: i(nteger), t(ext), m(ath), ? (unknown) or '_' (empty) (or some combination)
#  or 'mx' for alternating text & math.
sub classify_alignment_cell {
  my ($document, $xcell) = @_;
  my $content = $xcell->textContent;
  my $class   = '';
  #  if($content =~ /^\s*\d+\s*$/){
  if ($content =~ /^[\s\d]+$/) {
    $class = 'i'; }
  else {
    my @nodes = $xcell->childNodes;
    while (@nodes) {
      my $ch     = shift(@nodes);
      my $chtype = $ch->nodeType;
      if ($chtype == XML_TEXT_NODE) {
        my $text = $ch->textContent;
        $class .= 't'
          unless $text =~ /^\s*$/ || (($class eq 'm') && ($text =~ /^\s*[\.,;]\s*$/)); }
      elsif ($chtype == XML_ELEMENT_NODE) {
        my $chtag = $document->getModel->getNodeQName($ch);
        if ($chtag eq 'ltx:text') {    # Font would be useful, but haven't "resolved" it, yet!
          $class .= 't' unless $class eq 't'; }
        elsif ($chtag eq 'ltx:graphics') {
          $class .= 'g' unless $class eq 'g'; }
        elsif ($chtag eq 'ltx:Math') {
          $class .= 'm' unless $class eq 'm'; }
        elsif ($chtag eq 'ltx:XMText') {
          $class .= 't' unless $class eq 't'; }
        elsif ($chtag eq 'ltx:XMArg') {
          unshift(@nodes, $ch->childNodes); }
        elsif ($chtag =~ /^ltx:XM/) {
          $class .= 'm' unless $class eq 'm'; }
        else {
          $class .= '?' unless $class; }
  } } }
  $class = 'mx' if $class && (($class =~ /^((m|i)t)+(m|i)?$/) || ($class =~ /^(t(m|i))+t?$/));
  return $class || '_'; }

#======================================================================
# Scan pairs of rows/columns attempting to recognize differences that
# might indicate which are headers and which are data.
# Warning: This section is full of "magic numbers"
# guessed by sampling various test cases.

my $MIN_ALIGNMENT_DATA_LINES   = 1;    #  (or 2?) [CONSTANT]
my $MAX_ALIGNMENT_HEADER_LINES = 4;    # [CONSTANT]

# We expect to find header lines at the beginning, noticably different from the eventual data lines.
# Both header lines and data lines can consist of several neighboring lines.
# Check that header lines are `similar' to each other.  So, the strategy is to look
# for a `hump' in the line differences and consider blocks containing these lines to be potential headers.
my @axisname = ('column', 'row');

sub alignment_characterize_lines {
  my ($document, $axis, $reversed, @lines) = @_;
  my $n = scalar(@lines);
  return if $n < 2;
  local @::TABLINES = @lines;
  Debug("Characterizing $n " . ($axis ? "columns" : "rows"))
    if $LaTeXML::DEBUG{alignment};

  # Establish a scale of differences for the table.
  my ($diffhi, $difflo, $diffavg) = (0, 99999999, 0);
  for (my $l = 0 ; $l < $n - 1 ; $l++) {
    my $d = alignment_compare($axis, 1, $reversed, $l, $l + 1);
    $diffavg += $d;
    $diffhi = $d if $d > $diffhi;
    $difflo = $d if $d < $difflo; }
  $diffavg = $diffavg / ($n - 1);
  if ($diffhi < 0.05) {    # virtually no differences.
    Debug("Lines are almost identical => Fail") if $LaTeXML::DEBUG{alignment};
    return; }
  if (($n > 2) && (($diffhi - $difflo) < $diffhi * 0.5)) { # differences too similar to establish pattern
    Debug("Differences between lines are almost identical => Fail")
      if $LaTeXML::DEBUG{alignment};
    return; }
  #  local $::TAB_THRESHOLD = $difflo + 0.4*($diffhi-$difflo);
  local $::TAB_THRESHOLD = $difflo + 0.3 * ($diffhi - $difflo);
  #  local $::TAB_THRESHOLD = $difflo + 0.2*($diffhi-$difflo);
  #  local $::TAB_THRESHOLD = $diffavg;
  local $::TAB_AXIS = $axis;
  Debug("Differences $difflo -- $diffhi => threshold = $::TAB_THRESHOLD")
    if $LaTeXML::DEBUG{alignment};
  # Find the first hump in differences. These are candidates for header lines.
  Debug("Scanning for headers") if $LaTeXML::DEBUG{alignment};
  my $diff;
  my ($minh, $maxh) = (1, 1);
  while (($diff = alignment_compare($axis, 1, $reversed, $maxh - 1, $maxh)) < $::TAB_THRESHOLD) {
    $maxh++; }
  return if $maxh > $MAX_ALIGNMENT_HEADER_LINES;    # too many before even finding diffs? give up!
      #  while( alignment_compare($axis,1,$reversed,$maxh,$maxh+1) > $difflo + ($diff-$difflo)/6){
  while (alignment_compare($axis, 1, $reversed, $maxh, $maxh + 1) > $::TAB_THRESHOLD) {
    $maxh++; }
  $maxh = $MAX_ALIGNMENT_HEADER_LINES                if $maxh > $MAX_ALIGNMENT_HEADER_LINES;
  Debug("Found from $minh--$maxh potential headers") if $LaTeXML::DEBUG{alignment};

  my $nn = scalar(@{ $lines[0] }) - 1;
  # The sets of lines 1--$minh, .. 1--$maxh are potential headers.
  for (my $nh = $maxh ; $nh >= $minh ; $nh--) {
    #  for(my $nh = $minh; $nh <= $maxh; $nh++){
    # Check whether the set 1..$nh is plausable.
    if (my @heads = alignment_test_headers($nh)) {
      # Now, change all cells marked as header from td => th.
      foreach my $h (@heads) {
        my $i = 0;
        foreach my $cell (@{ $lines[$h] }) {
          $$cell{cell_type} = 'h';
          if (my $xcell = $$cell{cell}) {
            if (($$cell{content_class} eq '_')    # But NOT empty cells on outer edges.
              && ((($i == 0) && !$$cell{ ($axis == 0 ? 'l' : 't') })
                || (($i == $nn) && !$$cell{ ($axis == 0 ? 'r' : 'b') }))) { }
            else {
              $document->addSSValues($$cell{cell}, thead => $axisname[$axis]); } }
          $i++; } }
      return 1; } }
  return; }

# Test whether $nhead lines makes a good fit for the headers
sub alignment_test_headers {
  my ($nhead) = @_;
  Debug("Testing $nhead headers") if $LaTeXML::DEBUG{alignment};
  my ($headlength, $datalength) = (0, 0);
  my @heads = (0 .. $nhead - 1);    # The indices of heading lines.
  $headlength = alignment_max_content_length($headlength, 0, $nhead - 1);
  my $nextline = $nhead;            # Start from the end of the proposed headings.

  # Watch out for the assumed header being really data that is a repeated pattern.
  my $nrep = scalar(@::TABLINES) / $nhead;
  if (($nhead > 1) && ($nrep == int($nrep))) {
    Debug("Check for apparent header repeated $nrep times") if $LaTeXML::DEBUG{alignment};
    my $matched = 1;
    for (my $r = 1 ; $r < $nrep ; $r++) {
      $matched &&= alignment_match_head(0, $r * $nhead, $nhead); }
    Debug("Repeated headers: " . ($matched ? "Matched=> Fail" : "Nomatch => Succeed")) if $LaTeXML::DEBUG{alignment};
    return if $matched; }

  # And find a following grouping of data lines.
  my $ndata = alignment_skip_data($nextline);
  return if $ndata < $nhead;                     # ???? Well, maybe if _really_ convincing???
  return if ($ndata < $nhead) && ($ndata < 2);
  # Check that the content of the headers isn't dramatically larger than the content in the data
  $datalength = alignment_max_content_length($datalength, $nextline, $nextline + $ndata - 1);
  $nextline += $ndata;

  my $nd;
# If there are more lines, they should match either the previous data block, or the head/data pattern.
  while ($nextline < scalar(@::TABLINES)) {
    # First try to match a repeat of the 1st data block;
    # This would be the case when groups of data have borders around them.
    # Could want to match a variable number of datalines, but they should be similar!!!??!?!?
    if (($ndata > 1) && ($nd = alignment_match_data($nhead, $nextline, $ndata))) {
      $datalength = alignment_max_content_length($datalength, $nextline, $nextline + $nd - 1);
      $nextline += $nd; }
    # Else, try to match the first header block; less common.
    elsif (alignment_match_head(0, $nextline, $nhead)) {
      push(@heads, $nextline .. $nextline + $nhead - 1);
      $headlength = alignment_max_content_length($headlength, $nextline, $nextline + $nhead - 1);
      $nextline += $nhead;
      # Then attempt to match a new data block.
      #      my $d = alignment_skip_data($nextline);
      #      return unless ($d >= $nhead) || ($d >= 2);
      #      $nextline += $d; }
      # No, better be the same data block?
      return unless ($nd = alignment_match_data($nhead, $nextline, $ndata));
      $datalength = alignment_max_content_length($datalength, $nextline, $nextline + $nd - 1);
      $nextline += $nd; }
    else { return; } }
  # Header content seems too large relative to data?
  Debug("header content = $headlength; data content = $datalength")
    if $LaTeXML::DEBUG{alignment};
##  if(($headlength > 10) && (0.3*$headlength > $datalength)){
  if (($headlength > 10) && (0.25 * $headlength > $datalength)) {
    Debug("header content too much longer than data content")
      if $LaTeXML::DEBUG{alignment};
    return; }
  # Or if a header cell has "large" content?
  if ($headlength >= 1000) {    # Or if a header cell has "large" content?
    Debug("header content too large")
      if $LaTeXML::DEBUG{alignment};
    return; }

  Debug("Succeeded with $nhead headers") if $LaTeXML::DEBUG{alignment};
  return @heads; }

sub alignment_match_head {
  my ($p1, $p2, $nhead) = @_;
  Debug("Try match $nhead header lines from $p1 to $p2") if $LaTeXML::DEBUG{alignment};
  my $nh = alignment_match_lines($p1, $p2, $nhead);
  my $ok = $nhead == $nh;
  Debug("Matched $nh header lines => " . ($ok ? "Succeed" : "Failed")) if $LaTeXML::DEBUG{alignment};
  return ($ok ? $nhead : 0); }

sub alignment_match_data {
  my ($p1, $p2, $ndata) = @_;
  Debug("Try match $ndata data lines from $p1 to $p2")
    if $LaTeXML::DEBUG{alignment};
  my $nd = alignment_match_lines($p1, $p2, $ndata);
  my $ok = ($nd * 1.0) / $ndata > 0.66;
  Debug("Matched $nd data lines => " . ($ok ? "Succeed" : "Failed"))
    if $LaTeXML::DEBUG{alignment};
  return ($ok ? $nd : 0); }

# Match the $n lines starting at $i2 to those starting at $i1.
sub alignment_match_lines {
  my ($p1, $p2, $n) = @_;
  for (my $i = 0 ; $i < $n ; $i++) {
    return $i if ($p1 + $i >= scalar(@::TABLINES)) || ($p2 + $i >= scalar(@::TABLINES))
      || alignment_compare($::TAB_AXIS, 0, 0, $p1 + $i, $p2 + $i) >= $::TAB_THRESHOLD; }
  return $n; }

# Skip through a block of lines starting at $i that appear to be data, returning the number of lines.
# We'll assume the 1st line is data, compare it to following lines,
# but also accept `continuation' data lines.
sub alignment_skip_data {
  my ($i) = @_;
  return 0                   if $i >= scalar(@::TABLINES);
  Debug("Scanning for data") if $LaTeXML::DEBUG{alignment};
  my $n = 1;
  while ($i + $n < scalar(@::TABLINES)) {
    last if (alignment_compare($::TAB_AXIS, 1, 0, $i + $n - 1, $i + $n) >= $::TAB_THRESHOLD)
      # Accept an outlying `continuation line' as data, if mostly empty
      && (($n < 2)
      || (scalar(grep { $$_{content_class} eq '_' } @{ $::TABLINES[$i + $n] }) <= 0.4 * scalar($::TABLINES[0])));
    $n++; }
  Debug("Found $n data lines at $i") if $LaTeXML::DEBUG{alignment};
  return ($n >= $MIN_ALIGNMENT_DATA_LINES ? $n : 0); }

sub XXXalignment_max_content_length {
  my ($length, $from, $to) = @_;
  foreach my $j (($from .. $to)) {
    foreach my $cell (@{ $::TABLINES[$j] }) {
      $length = $$cell{content_length}
        if $$cell{content_length} && ($$cell{content_length} > $length); } }
  return $length; }

# Return the maximum "content length" for lines from $from to $to.
sub alignment_max_content_length {
  my ($length, $from, $to) = @_;
  foreach my $j (($from .. $to)) {
    my $l = 0;
    foreach my $cell (@{ $::TABLINES[$j] }) {
      $l += $$cell{content_length} || 0; }
    $length = $l if $l > $length; }
  return $length; }

#======================================================================
# The comparator.
# our %cell_class_diff =
#   ('_'=>{'_'=>0.0, m=>0.1, i=>0.1, t=>0.1, '?'=>0.1, mx=>0.1},
#    m  =>{'_'=>0.1, m=>0.0, i=>0.1, mx=>0.2},
#    i  =>{'_'=>0.1, m=>0.1, i=>0.0, mx=>0.2},
#    t  =>{'_'=>0.1, t=>0.0, mx=>0.2},
#    '?'=>{'_'=>0.1, '?'=>0.0, mx=>0.2},
#    mx=>{'_'=>0.1, m=>0.2, i=>0.2, t=>0.2, '?'=>0.2, mx=>0.0});

my %cell_class_diff = (    # [CONSTANT]
  '_' => { '_' => 0.0,  m   => 0.05, i  => 0.05, t  => 0.05, '?' => 0.05, mx => 0.05 },
  m   => { '_' => 0.05, m   => 0.0,  i  => 0.1,  mx => 0.2 },
  i   => { '_' => 0.05, m   => 0.1,  i  => 0.0,  mx => 0.2 },
  t   => { '_' => 0.05, t   => 0.0,  mx => 0.2 },
  '?' => { '_' => 0.05, '?' => 0.0,  mx => 0.2 },
  mx  => { '_' => 0.05, m   => 0.2,  i  => 0.2, t => 0.2, '?' => 0.2, mx => 0.0 });

# Compare two lines along $axis (0=row,1=column), returning a measure of the difference.
# The borders are compared differently if
#  $foradjacency: we adjacent lines that might belong to the same block,
#  otherwise    : comparing two lines that ought to have identical patterns (eg. in a repeated block)
sub alignment_compare {
  my ($axis, $foradjacency, $reversed, $p1, $p2) = @_;
  my $line1 = $::TABLINES[$p1];
  my $line2 = $::TABLINES[$p2];
  return 0      if !($line1 && $line2);
  return 999999 if $line1 xor $line2;
  my @cells1 = @$line1;
  my @cells2 = @$line2;
  my $ncells = scalar(@cells1);
  my $diff   = 0.0;

  while (@cells1 && @cells2) {
    my $cell1 = shift(@cells1);
    my $cell2 = shift(@cells2);
    # Annoying test avoids warnings if cells inconsistent; likely due to incorrect row/col spans
    next if grep { !defined $$cell1{$_} } qw(content_class r l t b);
    next if grep { !defined $$cell2{$_} } qw(content_class r l t b);
    #    $diff += 0.5 if (($$cell1{align}||'') ne ($$cell2{align}||''))
    $diff += 0.75 if (($$cell1{align} || '') ne ($$cell2{align} || ''))
      && ($$cell1{content_class} ne '_') && ($$cell2{content_class} ne '_');
    if (my $d = $cell_class_diff{ $$cell1{content_class} }{ $$cell2{content_class} }) {
      $diff += $d; }
    elsif ($$cell1{content_class} ne $$cell2{content_class}) {
      $diff += 0.75; }
    # compare certain edges
    if ($foradjacency) {    # Compare edges for adjacent rows of potentially different purpose
      $diff += 0.3 * scalar(grep { $$cell1{$_} != $$cell2{$_} } ($axis == 0 ? qw(r l) : qw(t b)));
      # Penalty for apparent divider between.
      my $pedge = ($axis == 0 ? ($reversed ? 't' : 'b') : ($reversed ? 'l' : 'r'));
      if ($$cell1{$pedge} && ($$cell1{$pedge} != $$cell2{$pedge})) {
        $diff += abs($$cell1{$pedge} - $$cell2{$pedge}) * 1.0; }
    }
    else {                  # Compare edges for rows from diff places for potential similarity
      $diff += 0.3 * scalar(grep { $$cell1{$_} != $$cell2{$_} } qw(r l t b)); }
  }
  $diff /= $ncells;
  Debug("$p1-$p2 => $diff; ") if $LaTeXML::DEBUG{alignment};
  return $diff; }

#======================================================================
# Debugging.
sub summarize_alignment {
  my ($rows, $cols) = @_;
  my $r = 0;
  my ($nrows, $ncols) = (scalar(@$rows), scalar(@{ $$rows[0] }));
  foreach my $cell (@{ $$rows[0] }) {
    Debug(' ' . ($$cell{t} ? ('-' x 6) : (' ' x 6))); }
  foreach my $row (@$rows) {
    my $maxb = 0;
    Debug(($$row[0]{l} ? ('|' x $$row[0]{l}) : ' '));
    foreach my $cell (@$row) {
      Debug(sprintf(" %4s ",
          ($$cell{cell_type} || '?')
            . ($$cell{align} ? $ALIGNMENT_CODE{ $$cell{align} } : ' ')
            . ($$cell{content_class} || '?')
            . ($$cell{r} ? ('|' x $$cell{r}) : ' ')));
      $maxb = $$cell{b} if $$cell{b} > $maxb; }
    #    Debug(sprintf("%.3f",alignment_compare(0,1,$$rows[$r],$$rows[$r+1])) if ($r < $nrows-1));
    for (my $b = 0 ; $b < $maxb ; $b++) {
      foreach my $cell (@$row) {
        Debug(' ' . ($b < $$cell{b} ? ('-' x 6) : (' ' x 6))); } }
    $r++; }
  #  for(my $c = 0; $c < $ncols-1; $c++){
  #    Debug(sprintf(" %.3f ",alignment_compare(1,1,$$cols[$c],$$cols[$c+1]))); }
  return; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Alignment> - representation of aligned structures

=head1 DESCRIPTION

This module defines aligned structures.  It needs more documentation.
It extends L<LaTeXML::Common::Object>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut



