#!/usr/bin/perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: tick.t 216 2004-12-29 18:32:42Z abeltje $

use Test::More;
plan $^O =~ /MSWin32|cygwin/ 
    ? (tests => 6) : (skip_all => "This is not MSWin32!");

use_ok( 'Win32::IE::Mechanize' );

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/tick.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok( $ie, "Win32::IE::Mechanize" );

$ie->get( $uri );
ok $ie->success, "->success";

ok my $prev_uri = $ie->uri, "Got an uri back";

my $form = $ie->form_number(1);
isa_ok( $form, 'Win32::IE::Form' );

$ie->tick("foo","hello");
$ie->tick("foo","bye");
$ie->untick("foo","hello");

$ie->click( 'submit' );

is $ie->uri, "$prev_uri?foo=bye&submit=Submit", "(un)tick actions";

$ENV{WIM_VISIBLE} or $ie->close;
