use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 4;

subtest "requirements" => sub {
  plan tests => 1;

  use_ok("LaTeXML::Post::BiBTeX::Runtime::Context");
};

subtest "stack behaviour" => sub {
  plan tests => 16;

  my $context = LaTeXML::Post::BiBTeX::Runtime::Context->new();

  # push an integer
  $context->pushInteger(42);
  is_deeply([$context->popStack], ['INTEGER', 42, undef], 'pushing and popping an integer');

  # push a string
  $context->pushString('hello world');
  is_deeply([$context->popStack], ['STRING', ['hello world'], [undef]], 'pushing and popping a string');

  # push and peek
  $context->pushInteger(-3);
  $context->pushInteger(-2);
  $context->pushInteger(-1);

  is_deeply([$context->peekStack(1)], ['INTEGER', -1,    undef], 'peek last value');
  is_deeply([$context->peekStack(2)], ['INTEGER', -2,    undef], 'peek second last value');
  is_deeply([$context->peekStack(3)], ['INTEGER', -3,    undef], 'peek third last value');
  is_deeply([$context->peekStack(4)], [undef,     undef, undef], 'peek non-existent last value');

  # pop + duplicate the empty stack
  $context->emptyStack;
  is_deeply([$context->popStack], [undef, undef, undef], 'pop the empty stack');
  is_deeply($context->duplicateStack, 0, 'duplicate the empty stack');

  # actually duplicate the stack
  $context->pushInteger(42);
  $context->duplicateStack;

  is_deeply([$context->peekStack(1)], ['INTEGER', 42, undef], 'peek last value of duplication');
  is_deeply([$context->peekStack(2)], ['INTEGER', 42, undef], 'peek second last value of duplication');

  # don't do anything to the empty stack
  $context->emptyStack;
  is($context->duplicateStack, 0, 'duplicating empty stack');

  # check that swapping the non-empty stack works
  $context->emptyStack;
  $context->pushInteger(43);
  $context->pushInteger(42);
  $context->pushString("hello world");

  is($context->swapStack, 1, 'swapping non-empty stack');

  is_deeply([$context->peekStack(1)], ['INTEGER', 42, undef], 'push and swap, peek last');
  is_deeply([$context->peekStack(2)], ['STRING', ['hello world'], [undef]], 'push and swap, peek second last');
  is_deeply([$context->peekStack(3)], ['INTEGER', 43, undef], 'push and swap, peek third last');

  # don't do anything to the empty stack
  $context->emptyStack;
  is($context->swapStack, 0, 'swapping empty stack');

};

subtest "macro behaviour" => sub {
  plan tests => 3;

  # create a new context
  my $context = LaTeXML::Post::BiBTeX::Runtime::Context->new();

  is_deeply($context->hasMacro("hello"), '', 'check if macro does not exist');
  $context->setMacro("hello", "world");
  is_deeply($context->hasMacro("hello"), 1,       'check if macro exists');
  is_deeply($context->getMacro("hello"), "world", 'get a macro');
};

subtest "reading variable in non-context" => sub {
  plan tests => 11;

  # create a new context
  my $context = LaTeXML::Post::BiBTeX::Runtime::Context->new();

  # set an undefined variable
  is_deeply([$context->getVariable('example')], [undef, undef, undef], 'Getting an undefined variable');
  is_deeply($context->setVariable('example', ['INTEGER', 0, undef]), 1, 'Setting an undefined variable');

  # defining a variable
  is_deeply($context->defineVariable('example', 'GLOBAL_INTEGER'), 1, 'Defining a variable');
  is_deeply($context->defineVariable('example', 'GLOBAL_INTEGER'), 0, 'Re-defining a variable');

  # setting a value
  is_deeply([$context->getVariable('example')], ['UNSET', undef, undef], 'Getting an unset variable');
  is_deeply($context->setVariable('example', ['INTEGER', 0, undef]), 0, 'Setting a value');
  is_deeply([$context->getVariable('example')], ['INTEGER', 0, undef], 'Getting a set variable');

  # reading entry variable
  is_deeply([$context->getVariable('example2')], [undef, undef, undef], 'Getting an undefined entry variable');
  is_deeply($context->defineVariable('example2', 'ENTRY_INTEGER'), 1, 'Defining an entry variable');
  is_deeply([$context->getVariable('example2')], ['UNSET', undef, undef], 'Getting an entry variable in non-entry context');
  is_deeply($context->setVariable('example2', ['INTEGER', 0, undef]), 2, 'Setting an entry variable');
  }
