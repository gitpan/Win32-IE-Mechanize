#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: frames.t 381 2005-08-12 01:34:10Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i
    ? (tests => 5) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $url = URI::file->new_abs( "$base/t/frames.html" )->as_string;

isa_ok my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} ),
       "Win32::IE::Mechanize";
isa_ok $ie->{agent}, "Win32::OLE";

ok $ie->get( $url ), "get($url)";

is $ie->title, "Frames Page", "->title method";

$ENV{WIM_VISIBLE} or $ie->close;

