use ExtUtils::Manifest qw(fullcheck);
use Test::More;

my($missing, $extra) = fullcheck();

ok(!@$missing, "MANIFEST contains outdated files: \n\t".join("\n\t", @$missing));
ok(!@$extra, "Files missing from MANIFEST: \n\t".join("\n\t", @$extra));

 done_testing();