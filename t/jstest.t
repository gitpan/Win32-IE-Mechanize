#! perl -w
use strict;
use URI::file;

# $Id: jstest.t 116 2004-03-27 15:49:15Z abeltje $

use Test::More;

plan $^O eq 'MSWin32'
    ? (tests => 4) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

my $uri = URI::file->new_abs( "t/jstest.html" )->as_string;

my $t = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok $t, 'Win32::IE::Mechanize';

$t->get( $uri );
is $t->title, 'JS Redirection Success', "Right title()";

my $new_uri = URI::file->new_abs( "t/jstestok.html" )->as_string;
# is this a IE glitch?
$new_uri =~ s|^file://(\w)|file:///$1|;
is $t->uri, $new_uri, "Got the new uri()";
