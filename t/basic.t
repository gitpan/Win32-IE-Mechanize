#! perl -w
use strict;
use URI::file;

# $Id: basic.t 76 2003-11-30 22:00:38Z abeltje $

use Test::More;

plan $^O eq 'MSWin32' 
    ? (tests => 6) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

isa_ok my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} ),
       "Win32::IE::Mechanize";
isa_ok $ie->{agent}, "Win32::OLE";

my $url = (URI::file->new_abs( "t/basic.html" ))->as_string;
$ie->get( $url );

is $ie->title, "Test Page", "->title method";

is $ie->ct, "text/html", "->ct method";

like $ie->content, qr|<p>Simple paragraph</p>|i, "Content";

$ie->close;
