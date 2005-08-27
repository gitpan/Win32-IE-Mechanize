#! perl
use strict;
use warnings;
$|++;

# $Id: test-smoke-org.pl 397 2005-08-26 12:02:05Z abeltje $

=head1 NAME

test-smoke-org.pl - Show the TinySmoke db current overview

=head1 SYNOPSS

    C:>perl test-smoke-org.pl

=head1 DESCRIPTION

This program opens an IE with L<http://www.test-smoke.org> and
navigates to the status overview. Once it has retrieved the overview,
it shows the browser window.

I<NOTE>: The website is quite slow, so be patient please...

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";

use Win32;
use Win32::IE::Mechanize;

# Simple program that shows the overview the latest Smoke reports

my %opt = (
   url => 'http://www.test-smoke.org/',
);

print "Getting the 'TinySmoke db' overview takes a while!\n";
# Hide the browser while loading
my $ie = Win32::IE::Mechanize->new( visible => 0 ) or
    die "Cannot create an InternetExplorer.Application\n";

print "IE running...\n";
# make sure IE is shutdow even if ^C is pressed
local $SIG{INT} = sub { $ie->close; exit };

print "\tget( '$opt{url}' )";
$ie->get( $opt{url} );

print " done\n\tfollow_link( text => qr/TineySmoke db/i )";
$ie->follow_link( text_regex => qr/TinySmoke DB/i );

print " done\n\tfollow_link( url_regex => qr|cgi/tsdb| )";
$ie->follow_link( url_regex  => qr|cgi/tsdb| );

print " done\n\tsubit_form(form_number => 1, button => {value => 'latest Only'} )";
$ie->submit_form(
    form_number => 1,
    button      => { value => 'latest Only' },
);print " done\n";

# Now show the wanted page
$ie->set_property( visible => 1 );
Win32::MsgBox( "Click to shutdown IE and stopt the program",
               MB_ICONINFORMATION, $0 );

$ie->close;

=head1 COPYRIGHT AND LICENSE

Copyright MMV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
