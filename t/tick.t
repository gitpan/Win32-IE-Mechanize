#!/usr/bin/perl -w
use strict;
use URI::file;

# $Id: tick.t 76 2003-11-30 22:00:38Z abeltje $

use Test::More;
plan $^O eq 'MSWin32' 
    ? (tests => 6) : (skip_all => "This is not MSWin32!");

use_ok( 'Win32::IE::Mechanize' );

my $mech = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok( $mech, "Win32::IE::Mechanize" );

my $uri = URI::file->new_abs( "t/tick.html" )->as_string;
$mech->get( $uri );
ok $mech->success, "->success";

ok my $base = $mech->uri, "Got an uri back";

my $form = $mech->form_number(1);
isa_ok( $form, 'Win32::IE::Form' );

$mech->tick("foo","hello");
$mech->tick("foo","bye");
$mech->untick("foo","hello");

$mech->click( 'submit' );

is $mech->uri, "$base?foo=bye&submit=Submit", "(un)tick actions";

$mech->close;
