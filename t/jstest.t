#! perl -w
use strict;
use URI::file;

# $Id: jstest.t 194 2004-04-24 20:19:55Z abeltje $

use Test::More;

plan $^O eq 'MSWin32'
    ? (tests => 4) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

my $uri = URI::file->new_abs( "t/jstest.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok $ie, 'Win32::IE::Mechanize';

$ie->get( $uri );
is $ie->title, 'JS Redirection Success', "Right title()";

my $new_uri = URI::file->new_abs( "t/jstestok.html" )->as_string;
# is this a IE glitch?
$new_uri =~ s|^file://(\w)|file:///$1|;
is $ie->uri, $new_uri, "Got the new uri()";

$ie->close;
