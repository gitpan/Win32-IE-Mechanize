#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: jstest.t 381 2005-08-12 01:34:10Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i
    ? (tests => 4) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/jstest.html" )->as_string;
my $new_uri = URI::file->new_abs( "$base/t/jstestok.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok $ie, 'Win32::IE::Mechanize';

$ie->get( $uri );
is $ie->title, 'JS Redirection Success', "Right title()";

# is this a IE glitch?
$new_uri =~ s|^file:///?([a-z]):|file:///\U$1:|i;
# This Windows, case-insensitive
is $ie->uri, $new_uri, "Got the new uri()";

$ENV{WIM_VISIBLE} or $ie->close;
