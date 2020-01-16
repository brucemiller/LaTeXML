use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 5;

subtest "requirements" => sub {
  plan tests => 1;

  use_ok("LaTeXML::Post::BiBTeX::Common::StreamReader");
};

subtest 'peek, then read a read a string' => sub {
  plan tests => 16;

  my $reader = makeStringReader("hello\nworld", 0, '');

  peeks($reader, "1st character", "h", 0, 0, 0);
  reads($reader, "1st character", "h", 1, 1, 0);

  peeks($reader, "2nd character", "e", 1, 1, 0);
  reads($reader, "2nd character", "e", 1, 2, 0);

  reads($reader, "3rd character", "l",  1, 3, 0);
  reads($reader, "4th character", "l",  1, 4, 0);
  reads($reader, "5th character", "o",  1, 5, 0);
  reads($reader, "6th character", "\n", 1, 6, 0);

  peeks($reader, "7th character", "w", 1, 6, 0);
  reads($reader, "7th character", "w", 2, 1, 0);

  reads($reader, "8th character",  "o",   2, 2, 0);
  reads($reader, "9th character",  "r",   2, 3, 0);
  reads($reader, "10th character", "l",   2, 4, 0);
  reads($reader, "11th character", "d",   2, 5, 0);
  reads($reader, "12th character", "\n",  2, 6, 0);
  reads($reader, "13th character", undef, 3, 0, 1);

  $reader->finalize;
};

subtest 'readWhile() a string' => sub {
  plan tests => 2;

  # creating a reader from a string should work
  my $reader = makeStringReader("aaaaab", 0, '');

  readsWhile($reader, "read while 'a's", sub { return $_[0] =~ /a/; }, 'aaaaa');
  reads($reader, "fhe final b", "b", 1, 6, 0);

  $reader->finalize;
};

subtest 'peek, then eat a file' => sub {
  plan tests => 13;

  # creating a reader from a string should work
  my ($reader) = makeFixtureReader(__FILE__, 'streamreader', 'helloworld.txt');

  epeeks($reader, "1st character", "h",  0, 0, 0);
  epeeks($reader, "2nd character", "e",  1, 1, 0);
  epeeks($reader, "3rd character", "l",  1, 2, 0);
  epeeks($reader, "4th character", "l",  1, 3, 0);
  epeeks($reader, "5th character", "o",  1, 4, 0);
  epeeks($reader, "6th character", "\n", 1, 5, 0);

  epeeks($reader, "7th character",  "w",   1, 6, 0);
  epeeks($reader, "8th character",  "o",   2, 1, 0);
  epeeks($reader, "9th character",  "r",   2, 2, 0);
  epeeks($reader, "10th character", "l",   2, 3, 0);
  epeeks($reader, "11th character", "d",   2, 4, 0);
  epeeks($reader, "12th character", "\n",  2, 5, 0);
  epeeks($reader, "13th character", undef, 2, 6, 0);

  $reader->finalize;
};

subtest 'peek, then read a file' => sub {
  plan tests => 26;

  # creating a reader from a string should work
  my ($reader) = makeFixtureReader(__FILE__, 'streamreader', 'empty.txt');

  preads($reader, "h",   "h",  1, 1, 0);
  preads($reader, "e",   "e",  1, 2, 0);
  preads($reader, "l 1", "l",  1, 3, 0);
  preads($reader, "l 2", "l",  1, 4, 0);
  preads($reader, "o",   "o",  1, 5, 0);
  preads($reader, "end", "\n", 1, 6, 0);

  preads($reader, "empty line 1", "\n", 2, 1, 0);
  preads($reader, "empty line 2", "\n", 3, 1, 0);
  preads($reader, "empty line 3", "\n", 4, 1, 0);
  preads($reader, "empty line 4", "\n", 5, 1, 0);

  preads($reader, "w",   "w",  6, 1, 0);
  preads($reader, "o",   "o",  6, 2, 0);
  preads($reader, "r",   "r",  6, 3, 0);
  preads($reader, "l",   "l",  6, 4, 0);
  preads($reader, "d",   "d",  6, 5, 0);
  preads($reader, "end", "\n", 6, 6, 0);

  preads($reader, "empty line 7",  "\n", 7,  1, 0);
  preads($reader, "empty line 8",  "\n", 8,  1, 0);
  preads($reader, "empty line 9",  "\n", 9,  1, 0);
  preads($reader, "empty line 10", "\n", 10, 1, 0);

  preads($reader, "s",   "s",  11, 1, 0);
  preads($reader, "t",   "t",  11, 2, 0);
  preads($reader, "u",   "u",  11, 3, 0);
  preads($reader, "f 1", "f",  11, 4, 0);
  preads($reader, "f 2", "f",  11, 5, 0);
  preads($reader, "end", "\n", 11, 6, 0);

  $reader->finalize;
};

sub reads {
  my ($reader, $name, $echar, $eline, $ecol, $eeof) = @_;

  my ($gchar) = $reader->readChar;
  my ($gline, $gcol, $geof) = $reader->getPosition;

  is_deeply([$gchar, $gline, $gcol, $geof], [$echar, $eline, $ecol, $eeof], "read $name");
}

sub preads {
  my ($reader, $name, $echar, $eline, $ecol, $eeof) = @_;

  $reader->peekChar;
  my ($gchar) = $reader->readChar;
  my ($gline, $gcol, $geof) = $reader->getPosition;

  is_deeply([$gchar, $gline, $gcol, $geof], [$echar, $eline, $ecol, $eeof], "peek, then read $name");
}

sub peeks {
  my ($reader, $name, $echar, $eline, $ecol, $eeof) = @_;

  my ($gchar) = $reader->peekChar;
  my ($gline, $gcol, $geof) = $reader->getPosition;

  is_deeply([$gchar, $gline, $gcol, $geof], [$echar, $eline, $ecol, $eeof], "peek $name");
}

sub epeeks {
  my ($reader, $name, $echar, $eline, $ecol, $eeof) = @_;

  my ($gchar) = $reader->peekChar;
  my ($gline, $gcol, $geof) = $reader->getPosition;

  is_deeply([$gchar, $gline, $gcol, $geof], [$echar, $eline, $ecol, $eeof], "peek, then eat $name");

  $reader->eatChar;
}

sub readsWhile {
  my ($reader, $name, $pred, $echars) = @_;

  my ($gchars) = $reader->readCharWhile($pred);
  is($gchars, $echars, $name);
}

1;
