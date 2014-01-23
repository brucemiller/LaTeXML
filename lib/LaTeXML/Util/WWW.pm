# /=====================================================================\ #
# |  LaTeXML::Util::WWW                                                 | #
# | Web Utilities for LaTeXML                                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev (d.ginev@jacobs-university.de)                  #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::WWW;
use strict;
use warnings;
use LaTeXML::Common::Error;
use LaTeXML::Global;
use URI;
use LWP;
use LWP::Simple;
use base qw(Exporter);
our @EXPORT = qw(&auth_get &url_find &url_split);

sub auth_get {
  my ($url, $authlist) = @_;
  my $browser;
  if ($url =~ /^https/) {
    $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }); }
  else {
    $browser = LWP::UserAgent->new; }
  my $response = $browser->get($url);
  my $realm    = $response->www_authenticate;
  if ($realm) {
    if ($realm =~ /^Basic realm="([^"]+)"$/) {
      $realm = $1; }
    # Prompt for username pass for this location:
    my $req; my $tries = 2;
    my ($uname, $pass) = ($$authlist{$realm} ? @{ $$authlist{$realm} } : (undef, undef));
    while (!($response && $response->is_success) && $tries > 0) {    # 2 tries
      $tries--;
      if (!$uname) {
        $req = HTTP::Request->new(GET => $url);
        $req->authorization_basic($uname, $pass);
        $response = $browser->request($req);
        $$authlist{$realm} = [$uname, $pass] if $response->is_success; }
      else {
        $req = HTTP::Request->new(GET => $url);
        $req->authorization_basic($uname, $pass);
        $response = $browser->request($req); } } }
  return auth_get("$url.tex", $authlist) if ((!$response->is_success) && $url !~ /\.tex$/);
  Fatal('www', 'get', $url, 'HTTP GET failed with: "' . $response->message . '"') unless ($response->is_success);
  return $response->content; }

sub url_find {
  my ($relative_url, %options) = @_;
  return if !($options{urlbase} && $relative_url &&
    length($options{urlbase}) > 0 && length($relative_url) > 0);
  $options{urlbase} =~ s/(\/+)$//g;
  $options{urlbase} .= '/';
  my $absolute_url = URI->new_abs($relative_url, $options{urlbase});
  my $browser;
  if ($absolute_url =~ /^https/) {
    $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }); }
  else {
    $browser = LWP::UserAgent->new; }
  my $response = $browser->head($absolute_url);
  if ($response->is_success) {
    return $absolute_url->as_string }
  else {
    # Only 404 is expected, anythign else is an error:
    Error("http_fail", $response->code, undef, " HTTP GET on $absolute_url failed. Reason: " . $response->message) if ($response->code != 404);
    return; } }

sub url_split {
  my ($url) = @_;
  return ($url =~ /^(.+)\/([^\/]+)$/ ? ($1, $2) : ($url, 'index.tex')); }    # Well, what????

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Util::WWW>  - auxiliaries for web-scalability of LaTeXML's IO

=head1 SYNOPSIS

    my $response = auth_get($url,$authlist);

=head1 DESCRIPTION

Utilities for enabling general interaction with the World Wide Web in LaTeXML's Input/Output.

Still in development, more functionality is expected at a later stage.

=head2 METHODS

=over 4

=item C<< my $response = auth_get($url,$authlist); >>

Given an authentication list, attempts a get request on a given URL ($url) and returns the $response.

If no authentication is possible automatically, the routine prompts the user for credentials.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
