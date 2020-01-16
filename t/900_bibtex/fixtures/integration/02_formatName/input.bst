% This file is intended to act as a test-suite for built-in BiBTeX function
% We check if the format.name$ function works as intended
% Note: We delimit strings with "^" and "$" at the beginning and end
% to work around issues with space-handling

ENTRY { format name expected } { ok } { result got }
INTEGERS { count.pass count.fail count.total num.zeros }

%%%
%%% UTILITY FUNCTIONS (to be called by user)
%%%

% prints a string and its' name, followed by a newline
FUNCTION {print.string} {
  swap$ " = {" * swap$ * "}" * write$ newline$
}

% prints an integer and its' name, followed by a newline
FUNCTION {print.integer} {
  int.to.str$
  print.string
}

%%%
%%% TestSuite Runner (to be adapted by user)
%%%

% function to run the test for a given entry 
FUNCTION {user.run.test} {
  name #1 format format.name$ 'got :=
  "^" got * "$" * 'got :=
  expected got = 'ok :=
}

% function to print the arguments of this testcase
FUNCTION {user.print.arguments} {
  "format   " format print.string
  "name     " name   print.string
}

% function to print the result of a testcase
FUNCTION {user.print.result} {
  "got      " got      print.string
  "expected " expected print.string
}

%%%
%%% Built-in functions (you shouldn't need to change this)
%%%

FUNCTION { init.vars } {
  #0 'count.pass :=
  #0 'count.fail :=
  #0 'count.total :=
}

FUNCTION { run.test } {
  % run the test (user code)
  user.run.test

  % update the appropriate counter
  ok
  {
    #1 count.pass + 'count.pass :=
    #1 count.total + 'count.total :=
  }
  {
    #1 count.fail + 'count.fail :=
    #1 count.total + 'count.total :=
  }
  if$
}

FUNCTION { print.test } {
    % print testcase header
  "testcase " cite$ * ": " *
  ok { "PASS" } { "FAIL "} if$
  * write$ newline$
  
  ok {
    % If the testcase is ok, print nothing
    skip$
  } {
    % print testcase argument (user code)
    user.print.arguments
    newline$

    % print the result (user code) 
    user.print.result
  }
  if$

  newline$
}

FUNCTION { int.to.zeros } {
  
  % turn integer into string
  int.to.str$

  % add zeros while the text length is shorter than 3
  {
    duplicate$ text.length$ num.zeros <
  }
  {
    "0" swap$ *
  }
  while$
}



FUNCTION { print.summary } 
{
  
  % Write out a summary block 
  "===============" write$ newline$
  "Summary: "
  count.fail { "FAIL" } { "PASS" } if$
  * write$ newline$
  "===============" write$ newline$

  % set the number of zeros to however many digits count.total has
  count.total int.to.str$ text.length$ 'num.zeros :=

  % print some counters
  "PASS: " count.pass int.to.zeros * "/" * count.total int.to.zeros * write$ newline$
  "FAIL: " count.fail int.to.zeros * "/" * count.total int.to.zeros * write$ newline$

  newline$
}

% dummy function to avoid warnings
FUNCTION { testcase } { skip$ }

READ

EXECUTE {init.vars}

ITERATE {run.test}

EXECUTE {print.summary}

ITERATE {print.test}

