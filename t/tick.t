#!/usr/bin/perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: tick.t 366 2005-08-07 15:39:24Z abeltje $

use Test::More;
plan $^O =~ /MSWin32|cygwin/ 
    ? (tests => 8) : (skip_all => "This is not MSWin32!");

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

$ie->click( 'submit' ); $ie->_wait_while_busy;

like $ie->uri, qr/[&?]foo=bye\b/, "(un)tick actions [foo=bye]";
like $ie->uri, qr/[&?]submit=Submit\b/, "(un)tick actions [submit=Submit]";
unlike $ie->uri, qr/[&?]foo=hello\b/, "(un)tick actions ![foo=hello]";

$ENV{WIM_VISIBLE} or $ie->close;
