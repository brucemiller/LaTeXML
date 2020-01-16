use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 8;

subtest "requirements" => sub {
  plan tests => 1;

  use_ok("LaTeXML::Post::BiBTeX::Runtime::Names");
};

subtest "abbrevName" => sub {
  plan tests => 4;

  sub isAbbrevName {
    my ($input, $expected) = @_;
    is(abbrevName($input), $expected, $input);
  }

  isAbbrevName("Charles",           "C");
  isAbbrevName("{Ch}arles",         "C");
  isAbbrevName("{\\relax Ch}arles", "{\\relax Ch}");
  isAbbrevName("{-}ky",             "k");
};

subtest "splitNames" => sub {
  plan tests => 7;

  sub isSplitNames {
    my ($input, $expected) = @_;
    is_deeply([splitNames($input)], $expected, $input);
  }

  isSplitNames("tom and jerry", ["tom", "jerry"]);
  isSplitNames("and jerry", ["and jerry"]);
  isSplitNames("tom { and { and } } jerry",           ["tom { and { and } } jerry"]);
  isSplitNames("jerry and",                           ["jerry and"]);
  isSplitNames("tom cat and jerry mouse",             ["tom cat", "jerry mouse"]);
  isSplitNames("tom cat and jerry mouse and nibbles", ["tom cat", "jerry mouse", "nibbles"]);
  isSplitNames("tom cat and jerry mouse and nibbles { and } Uncle Pecos", ["tom cat", "jerry mouse", "nibbles { and } Uncle Pecos"]);
};

subtest "numNames" => sub {
  plan tests => 7;

  sub isNumNames {
    my ($input, $expected) = @_;
    is(numNames($input), $expected, $input);
  }

  isNumNames("tom and jerry",                                           2);
  isNumNames("and jerry",                                               1);
  isNumNames("tom { and { and } } jerry",                               1);
  isNumNames("jerry and",                                               1);
  isNumNames("tom cat and jerry mouse",                                 2);
  isNumNames("tom cat and jerry mouse and nibbles",                     3);
  isNumNames("tom cat and jerry mouse and nibbles { and } Uncle Pecos", 3);
};

subtest "splitNameWords" => sub {
  plan tests => 14;

  sub isSplitNameWords {
    my ($input, $expected) = @_;
    is_deeply([splitNameWords($input)], $expected, $input);
  }

  isSplitNameWords('Catherine Crook de Camp', [['Catherine ', 'Crook ', 'de ', 'Camp'], [], []]);
  isSplitNameWords('{-}ky Jean Claude', [['{-}ky ', 'Jean ', 'Claude'], [], []]);
  isSplitNameWords('ky{-} Jean Claude', [['ky{-} ', 'Jean ', 'Claude'], [], []]);
  isSplitNameWords('ky {-} Jean Claude', [['ky ', '{-} ', 'Jean ', 'Claude'], [], []]);

  isSplitNameWords('Claude, Jon', [['Claude'], ['Jon'], []]);
  isSplitNameWords('Claude the , Jon e', [['Claude ', 'the '], ['Jon ', 'e'], []]);

  isSplitNameWords('the, jr, thing', [['the'], ['jr'], ['thing']]);
  isSplitNameWords('Freely, I.P.', [['Freely'], ['I.P.'], []]);

  isSplitNameWords('Jean-Claude Van Damme', [['Jean-', 'Claude ', 'Van ', 'Damme'], [], []]);
  isSplitNameWords('Jean{-}Claude Van Damme', [['Jean{-}Claude ', 'Van ', 'Damme'], [], []]);

  # from Names in BibTEX and MlBibTEX, page 245
  isSplitNameWords('Edgar  Rice', [['Edgar ', 'Rice'],  [], []]);
  isSplitNameWords('Edgar ~Rice', [['Edgar ', 'Rice'],  [], []]);
  isSplitNameWords('Edgar~ Rice', [['Edgar~', 'Rice'],  [], []]);
  isSplitNameWords('Karl- Heinz', [['Karl-',  'Heinz'], [], []]);
};

subtest "splitNameParts" => sub {
  plan tests => 14;

  sub isSplitNameParts {
    my ($input, $expected) = @_;
    is_deeply([splitNameParts($input)], $expected, $input);
  }

  # 'simple' cases
  isSplitNameParts('Catherine Crook de Camp', [['Catherine ', 'Crook '], ['de '], [], ['Camp']]);
  isSplitNameParts('{-}ky', [[], [], [], ['{-}ky']]);
  isSplitNameParts('jean de la fontaine du bois joli', [[], ['jean ', 'de ', 'la ', 'fontaine ', 'du ', 'bois '], [], ['joli']]);
  isSplitNameParts('Alfred Elton {van} Vogt', [['Alfred ', 'Elton ', '{van} '], [], [], ['Vogt']]);
  isSplitNameParts('Alfred Elton {\relax van} Vogt', [['Alfred ', 'Elton '], ['{\relax van} '], [], ['Vogt']]);
  isSplitNameParts('Alfred Elton {\relax Van} Vogt', [['Alfred ', 'Elton ', '{\relax Van} '], [], [], ['Vogt']]);
  isSplitNameParts('Michael {Marshall Smith}', [['Michael '], [], [], ['{Marshall Smith}']]);

  # 'hypenated' cases
  isSplitNameParts('Jean-Claude {Smit-le-B{\`e}n{\`e}dicte}', [['Jean-', 'Claude '], [], [], ['{Smit-le-B{\`e}n{\`e}dicte}']]);
  isSplitNameParts('Jean-Claude {Smit-le-B{\`e}n{\`e}dicte}', [['Jean-', 'Claude '], [], [], ['{Smit-le-B{\`e}n{\`e}dicte}']]);
  isSplitNameParts('Kenneth~Robeson', [['Kenneth~'], [], [], ['Robeson']]);
  isSplitNameParts('Louis-Albert', [[], [], [], ['Louis-Albert']]);

  # complete real-life examples
  isSplitNameParts('Charles Louis Xavier Joseph de la Vall{\`e}e Poussin', [['Charles ', 'Louis ', 'Xavier ', 'Joseph '], ['de ', 'la '], [], ['Vall{\`e}e ', 'Poussin']]);
  isSplitNameParts('Freely, I.P.', [['I.P.'], [], [], ['Freely']]);
  isSplitNameParts('Freely,I.P.', [['I.P.'], [], [], ['Freely']]);
};

subtest "formatNameSubpattern" => sub {
  plan tests => 10;

  sub isFormatNameSubpattern {
    my ($parts, $short, $seperator, $pre, $post, $expected) = @_;
    my $name = join('', @$parts);
    is_deeply(formatNameSubpattern($parts, $short, $seperator, $pre, $post), $expected, $name);
  }

  # long form
  isFormatNameSubpattern(['Dr ',  'Alex ', 'Bob ', 'Charlotte '], 0, undef, '', '', 'Dr~Alex Bob~Charlotte');
  isFormatNameSubpattern(['Dr-',  'Alex ', 'Bob ', 'Charlotte '], 0, undef, '', '', 'Dr-Alex Bob~Charlotte');
  isFormatNameSubpattern(['Dr. ', 'Alex ', 'Bob ', 'Charlotte '], 0, undef, '', '', 'Dr. Alex Bob~Charlotte');
  isFormatNameSubpattern(['Dr ', 'Charlotte '], 0, undef, '', '', 'Dr~Charlotte');

  # short form
  isFormatNameSubpattern(['Dr ',  'Alex ', 'Bob ', 'Charlotte '], 1, undef, '', '', 'D.~A. B.~C');
  isFormatNameSubpattern(['Dr-',  'Alex ', 'Bob ', 'Charlotte '], 1, undef, '', '', 'D.-A. B.~C');
  isFormatNameSubpattern(['Dr. ', 'Alex ', 'Bob ', 'Charlotte '], 1, undef, '', '', 'D.~A. B.~C');
  isFormatNameSubpattern(['Dr ', 'Charlotte '], 1, undef, '', '', 'D.~C');

  # custom seperator
  isFormatNameSubpattern(['Dr ', 'Alex ', 'Bob ', 'Charlotte '], 1, '/', '', '', 'D/A/B/C');
  isFormatNameSubpattern(['Dr ', 'Alex ', 'Bob ', 'Charlotte '], 0, '/', '', '', 'Dr/Alex/Bob/Charlotte');
};

subtest "formatName" => sub {
  plan tests => 26;

  sub isFormatName {
    my ($name, $spec, $expected) = @_;
    my ($result, $error) = formatName($name, $spec);
    diag($error) if $error;
    is_deeply($result, $expected, 'format(<' . $name . '>, <' . $spec . '>)');
  }

  # from the official BiBTeX documentation
  isFormatName('Charles Louis Xavier Joseph de la Vall{\`e}e Poussin', '{vv~}{ll}{, jj}{, f}?', 'de~la Vall{\`e}e~Poussin, C. L. X.~J?');

  # examples from "Names in BibTEX and MlBibTEX", Figure 5 LHS lastname => "Le Clerc De La Herverie"
  isFormatName('von Le Clerc De La Herverie', '{ll}',         'Le~Clerc De La~Herverie');
  isFormatName('von Le Clerc De La Herverie', '{ll/}',        'Le~Clerc De La~Herverie/');
  isFormatName('von Le Clerc De La Herverie', '{ll/,}',       'Le~Clerc De La~Herverie/,');
  isFormatName('von Le Clerc De La Herverie', '{ll{/},}',     'Le/Clerc/De/La/Herverie,');
  isFormatName('von Le Clerc De La Herverie', '{ll{},}',      'LeClercDeLaHerverie,');
  isFormatName('von Le Clerc De La Herverie', '{ll~}',        'Le~Clerc De La~Herverie ');
  isFormatName('von Le Clerc De La Herverie', '{ll~~}',       'Le~Clerc De La~Herverie~');
  isFormatName('von Le Clerc De La Herverie', '{ll{~}~}',     'Le~Clerc~De~La~Herverie ');
  isFormatName('von Le Clerc De La Herverie', '{ll{~}~~}',    'Le~Clerc~De~La~Herverie~');
  isFormatName('von Le Clerc De La Herverie', '{ll{/},~}',    'Le/Clerc/De/La/Herverie, ');
  isFormatName('von Le Clerc De La Herverie', '{ll{/}~,~}',   'Le/Clerc/De/La/Herverie~, ');
  isFormatName('von Le Clerc De La Herverie', '{ll{/}~~,~~}', 'Le/Clerc/De/La/Herverie~~,~');

  # example from "Names in BibTEX and MlBibTEX", Figure 5 LHS lastname => "Zeb Chillicothe Mantey"
  isFormatName('von Zeb Chillicothe Mantey', '{ll}', 'Zeb Chillicothe~Mantey');

# examples from "Names in BibTEX and MlBibTEX", Figure 5 RHS firstname => "Jean-Michel-Georges-Albert"
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f}',         'J.-M.-G.-A');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f/}',        'J.-M.-G.-A/');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f/,}',       'J.-M.-G.-A/,');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{/},}',     'J/M/G/A,');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{},}',      'JMGA,');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f~}',        'J.-M.-G.-A ');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f~~}',       'J.-M.-G.-A~');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{~}~}',     'J~M~G~A ');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{~}~~}',    'J~M~G~A~');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{/},~}',    'J/M/G/A, ');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{/}~,~}',   'J/M/G/A~, ');
  isFormatName('Jean-Michel-Georges-Albert Lastname', '{f{/}~~,~~}', 'J/M/G/A~~,~');
};
