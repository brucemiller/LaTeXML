use ExtUtils::Manifest qw(fullcheck);
use Test::More;

if ($ENV{"CI"}) {
  plan tests => 2;
  my($missing, $extra) = fullcheck();

  ok(!@$missing, "MANIFEST contains outdated files: \n\t".join("\n\t", @$missing));
  ok(!@$extra, "Files missing from MANIFEST: \n\t".join("\n\t", @$extra));
} else {
  plan skip_all => "Only checked in continuous integration. (set environment var CI=true and rerun tests)";
}

done_testing();