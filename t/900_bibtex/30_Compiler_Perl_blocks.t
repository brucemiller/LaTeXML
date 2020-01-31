use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 6;

my $target = "LaTeXML::Post::BiBTeX::Compiler::Target";
my $base = fixture(__FILE__, "compiler", "blocks", "");

sub doesCompileBlock {
  my ($kind, $name, $output, $input, @args) = @_;
  my $compiler = \&{"LaTeXML::Post::BiBTeX::Compiler::Block::compile$kind"};
  my ($result, $error) = &{$compiler}($target, $input, 0, @args);
  diag($error) if $error;
  # puts($base . $output, $result); # to generate test cases
  is(slurp($base . $output), $result, $name);
}

subtest "requirements" => sub {
  plan tests => 4;

  use_ok("LaTeXML::Post::BiBTeX::Common::Utils");
  use_ok("LaTeXML::Post::BiBTeX::Compiler::Block");
  use_ok("LaTeXML::Post::BiBTeX::Runtime");
  use_ok("$target");
};

subtest "compileInteger" => sub {
  plan tests => 2;

  doesCompileBlock('Integer', 'integer 1', '01_integer_a.txt', StyString('NUMBER', 1, [(undef, 1, 1, 1, 3)]));
  doesCompileBlock('Integer', 'integer -1', '01_integer_b.txt', StyString('NUMBER', -1, [(undef, 1, 1, 1, 4)]));
};

subtest "compileQuote" => sub {
  plan tests => 2;

  doesCompileBlock('Quote', 'quote with spaces', '02_quote_a.txt', StyString('QUOTE', 'hello world', [(undef, 1, 1, 1, 15)]));
  doesCompileBlock('Quote', 'empty quote', '02_quote_b.txt', StyString('QUOTE', '', [(undef, 1, 1, 1, 2)]));
};

subtest "compileVariable" => sub {
  plan tests => 12;
  sub refname { StyString('REFERENCE', $_[0], [(undef, 1, 2, 1, 9)]), $_[0] }

  doesCompileBlock('Reference', 'GLOBAL_STRING', '03_reference_a.txt', refname('example'), 'GLOBAL_STRING');
  doesCompileBlock('Reference', 'BUILTIN_GLOBAL_STRING', '03_reference_b.txt', refname('example'), 'BUILTIN_GLOBAL_STRING');

  doesCompileBlock('Reference', 'GLOBAL_INTEGER', '03_reference_c.txt', refname('example'), 'GLOBAL_INTEGER');
  doesCompileBlock('Reference', 'BUILTIN_GLOBAL_INTEGER', '03_reference_d.txt', refname('entry.max$'), 'BUILTIN_GLOBAL_INTEGER');

  doesCompileBlock('Reference', 'ENTRY_FIELD', '03_reference_e.txt', refname('example'), 'ENTRY_FIELD');
  doesCompileBlock('Reference', 'BUILTIN_ENTRY_FIELD', '03_reference_f.txt', refname('crossref'), 'BUILTIN_ENTRY_FIELD');

  doesCompileBlock('Reference', 'ENTRY_STRING', '03_reference_g.txt', refname('example'), 'ENTRY_STRING');
  doesCompileBlock('Reference', 'BUILTIN_ENTRY_STRING', '03_reference_h.txt', refname('sort.key$'), 'BUILTIN_ENTRY_STRING');

  doesCompileBlock('Reference', 'ENTRY_INTEGER', '03_reference_i.txt', refname('example'), 'ENTRY_INTEGER');
  doesCompileBlock('Reference', 'BUILTIN_ENTRY_INTEGER', '03_reference_j.txt', refname('example'), 'BUILTIN_ENTRY_INTEGER');

  doesCompileBlock('Reference', 'FUNCTION', '03_reference_k.txt', refname('h.e_ll0_:='), 'FUNCTION');
  doesCompileBlock('Reference', 'BUILTIN_FUNCTION', '03_reference_l.txt', refname('add.period$'), 'BUILTIN_FUNCTION');
};

subtest "compileLiteral" => sub {
  plan tests => 12;
  sub litname { StyString('LITERAL', $_[0], [(undef, 1, 2, 1, 9)]), $_[0] }

  doesCompileBlock('Literal', 'GLOBAL_STRING', '04_literal_a.txt', litname('example'), 'GLOBAL_STRING');
  doesCompileBlock('Literal', 'BUILTIN_GLOBAL_STRING', '04_literal_b.txt', litname('example'), 'BUILTIN_GLOBAL_STRING');

  doesCompileBlock('Literal', 'GLOBAL_INTEGER', '04_literal_c.txt', litname('example'), 'GLOBAL_INTEGER');
  doesCompileBlock('Literal', 'BUILTIN_GLOBAL_INTEGER', '04_literal_d.txt', litname('entry.max$'), 'BUILTIN_GLOBAL_INTEGER');

  doesCompileBlock('Literal', 'ENTRY_FIELD', '04_literal_e.txt', litname('example'), 'ENTRY_FIELD');
  doesCompileBlock('Literal', 'BUILTIN_ENTRY_FIELD', '04_literal_f.txt', litname('crossref'), 'BUILTIN_ENTRY_FIELD');

  doesCompileBlock('Literal', 'ENTRY_STRING', '04_literal_g.txt', litname('example'), 'ENTRY_STRING');
  doesCompileBlock('Literal', 'BUILTIN_ENTRY_STRING', '04_literal_h.txt', litname('sort.key$'), 'BUILTIN_ENTRY_STRING');

  doesCompileBlock('Literal', 'ENTRY_INTEGER', '04_literal_i.txt', litname('example'), 'ENTRY_INTEGER');
  doesCompileBlock('Literal', 'BUILTIN_ENTRY_INTEGER', '04_literal_j.txt', litname('example'), 'BUILTIN_ENTRY_INTEGER');

  doesCompileBlock('Literal', 'FUNCTION', '04_literal_k.txt', litname('h.e_ll0_:='), 'FUNCTION');
  doesCompileBlock('Literal', 'BUILTIN_FUNCTION', '04_literal_l.txt', litname('add.period$'), 'BUILTIN_FUNCTION');
};

subtest "compileInlineBlock" => sub {
  plan tests => 2;

  doesCompileBlock('InlineBlock', 'simple block', '05_block_a.txt', StyString('BLOCK', [(StyString('QUOTE', 'content', [(undef, 1, 5, 1, 10)]))], [(undef, 1, 4, 1, 11)]));
  doesCompileBlock('InlineBlock', 'nested block', '05_block_b.txt', StyString('BLOCK', [(StyString('QUOTE', 'outer', [(undef, 1, 1, 1, 7)]), StyString('BLOCK', [(StyString('QUOTE', 'inner', [(undef, 2, 2, 2, 7)]))], [(undef, 2, 1, 2, 8)]), StyString('QUOTE', 'outer', [(undef, 3, 1, 3, 7)]))], [(undef, 1, 4, 3, 8)]));
};

1;
