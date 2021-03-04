#======================================================================
# Unit tests for LaTeXML
#======================================================================
# I'd like to have a directory of unit tests, so it can be more easily
# grown, but this will be a start

use Test::More;
BEGIN { use_ok('LaTeXML'); }
#BEGIN { use_ok('LaTeXML::Global'); }
BEGIN { use_ok('LaTeXML::Package'); }

my $letter = 'x';
my ($t, $tx, $tz);

# Basic Token() tests
ok(eval { $t = T_LETTER($letter); 1; }, "Make Token (x)");
is(eval { Stringify($t); }, 'T_LETTER[x]', "Got correct token (x)");
ok(eval { $tx = T_LETTER($letter); }, "Make Token (x)");
$letter = 'z';
is(eval { Stringify($tx); }, 'T_LETTER[x]', "Got correct deref (x)");
ok(eval { $tz = T_LETTER($letter); }, "Make Token (z)");
is(eval { Stringify($tz); }, 'T_LETTER[z]', "Got correct token (z)");

# Basic Tokens() tests.
my ($ts, $ts3, $ts3x, $ts3z, $tss);
ok(eval { $ts = Tokens($t); }, "Make Tokens (x)");
is(eval { Stringify($ts); }, 'Tokens[x]', "Got correct token (x)");
ok(eval { $ts3 = Tokens($t, $t, $t); }, "Make Tokens from Token's (x,x,x)");
is(eval { Stringify($ts3); }, 'Tokens[x,x,x]', "Got correct tokens");
ok(eval { $ts3x = Tokens($t, $t, $t); }, "Make Tokens from Tokens (x,x,x)");
ok(eval { $t = T_LETTER('z'); }, "Make Token (z)");
is(eval { Stringify($ts3x); }, 'Tokens[x,x,x]', "Got correct deref (x,x,x)");
ok(eval { $ts3z = Tokens($t, $t, $t); }, "Make Tokens from Token's (z,z,z)");
is(eval { Stringify($ts3z); }, 'Tokens[z,z,z]', "Got correct tokens (z,z,z)");
ok(eval { $tss = Tokens($ts3); }, "Make Tokens from Tokens (x,x,x)");
is(eval { Stringify($tss); }, 'Tokens[x,x,x]', "Got correct tokens (x,x,x)");

# Balance Tokens tests
my ($balanced, $unbalanced);
ok(eval { $balanced = Tokens(T_LETTER('a'), T_BEGIN, T_OTHER('...'), T_END, T_LETTER('z')); },
  "Make balanced tokens");
ok(eval { $balanced->isBalanced; }, "Check is balanced");
ok(eval { $unbalanced = Tokens(T_LETTER('a'), T_BEGIN, T_OTHER('...'), T_LETTER('z')); },
  "Make unbalanced tokens");
ok(eval { !$unbalanced->isBalanced; }, "Check is not balancde");

# Macro arg substitution tests
my ($subst, $nosubst, $pattern);
ok(eval { $nosubst = $balanced->substituteParameters(T_LETTER('u'), T_LETTER('v'), T_LETTER('w')); },
  "substitute tokens w/o params");
is(eval { Stringify($nosubst); }, 'Tokens[a,{,...,},z]', "Got correct (non)substitution");
ok(eval { $pattern = Tokens(T_LETTER('a'),T_BEGIN,T_ARG('1'),T_LETTER('m'),T_ARG('2'),T_END,T_LETTER('z'));  },
 "make tokens w/ params");
ok(eval { $subst = $pattern->substituteParameters(T_LETTER('u'),T_LETTER('v'),T_LETTER('w'));  },
 "subsitute tokens w/params");
is(eval { Stringify($subst); }, 'Tokens[a,{,u,m,v,},z]', "Got correct substitution");

# Strip Braces tests
is(eval {
    ToString(Tokens(T_LETTER('a'))->stripBraces); }, "a", "Strip no braces");
is(eval {
    ToString(Tokens(T_BEGIN, T_LETTER('a'), T_END)->stripBraces); },
  "a", "Strip one brace");
is(eval {
    ToString(Tokens(T_SPACE, T_LETTER('a'), T_SPACE)->stripBraces); },
  "a", "Strip spaces");
is(eval {
    ToString(Tokens(T_SPACE, T_BEGIN, T_LETTER('a'), T_END, T_SPACE)->stripBraces); },
  "a", "Strip brace & spaces");
is(eval {
    ToString(Tokens(T_BEGIN, T_SPACE, T_LETTER('a'), T_SPACE, T_END)->stripBraces); },
  " a ", "Strip spaces, not inner space");
is(eval {
    ToString(Tokens(T_BEGIN, T_BEGIN, T_LETTER('a'), T_END, T_END)->stripBraces); },
  "{a}", "Strip outer braces");
is(eval {
    ToString(Tokens(T_BEGIN, T_LETTER('a'), T_END, T_BEGIN, T_LETTER('b'), T_END)->stripBraces); },
  "{a}{b}", "Don't strip unbalanced braces");
is(eval {
    ToString(Tokens(T_BEGIN, T_BEGIN, T_LETTER('a'), T_END, T_BEGIN, T_LETTER('b'), T_END,, T_END)->stripBraces); },
  "{a}{b}", "strip outermost braces");

done_testing();
