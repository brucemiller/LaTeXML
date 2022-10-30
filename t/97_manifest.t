use ExtUtils::Manifest qw(fullcheck);
use Test::More;

if ($ENV{"CI"}) {
  plan tests => 2;
  my($missing, $extra) = fullcheck();

  ok(!@$missing, "MANIFEST contains outdated files: \n\t".join("\n\t", @$missing));
  ok(!@$extra, "Files missing from MANIFEST: \n\t".join("\n\t", @$extra));
} else {
  plan skip_all => "Only checked in continuous integration. (use make test CI=true)";
}

done_testing();