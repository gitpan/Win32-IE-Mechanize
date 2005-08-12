#!/usr/bin/perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: tick.t 381 2005-08-12 01:34:10Z abeltje $

use Test::More;
plan $^O =~ /MSWin32|cygwin/ 
    ? (tests => 15) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/tick.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok( $ie, "Win32::IE::Mechanize" );

$ie->get( $uri );
ok $ie->success, "->success";

ok my $prev_uri = $ie->uri, "Got an uri back";

{
    my $form = $ie->form_number(1);
    isa_ok( $form, 'Win32::IE::Form' );
    $ie->tick("foo","hello");
    $ie->tick("foo","bye");
    $ie->untick("foo","hello");
    ok $ie->click( 'submit' ), "Click 'submit'";

    my $returi = $ie->uri;
    like $returi, qr/[&?]foo=bye\b/, "tick actions [foo=bye]";
    unlike $returi, qr/[&?]foo=hello\b/, "untick actions ![foo=hello]";
    like $returi, qr/[&?]submit=Submit\b/, "Submit $returi";
}

{
    ok $ie->get( $uri ), "get($uri)";
    ok $ie->submit_form(
        form_number => 1,
        tick        => {
            foo => { wibble => 1, bye => 0, hello => 1 },
        },
        button => 'submit',
    ), "submit_form()";

    my $returi = $ie->uri;
    like $returi, qr/[&?]foo=wibble\b/, "tick actions [foo=wibble]";
    unlike $returi, qr/[&?]foo=bye\b/, "untick actions ![foo=bye]";
    like $returi, qr/[&?]foo=hello\b/, "tick actions [foo=hello]";
    like $returi, qr/[&?]submit=Submit\b/, "Submit $returi";
}

$ENV{WIM_VISIBLE} or $ie->close;
