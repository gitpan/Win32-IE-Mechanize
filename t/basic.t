#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: basic.t 233 2005-01-09 19:29:28Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 12) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/basic.html" )->as_string;
my $url = URI::file->new_abs( "$base/t/formbasics.html" )->as_string;

isa_ok my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} ),
       "Win32::IE::Mechanize";
isa_ok $ie->agent, "Win32::OLE";

ok $ie->get( $uri ), "get($uri)";

is $ie->title, "Test Page", "->title method";

is $ie->ct, "text/html", "->ct method";

like $ie->content, qr|<p>Simple paragraph</p>|i, "Content";

ok $ie->follow_link( text => 'formbasics' ), "follow_link()";
(my $f_uri = $url ) =~ s|://([a-z]):|:///\U$1:|i;
is $ie->uri, $f_uri, "new uri $f_uri";
ok $ie->back, "back()";
(my $o_uri = $uri ) =~ s|://([a-z]):|:///\U$1:|i;
is $ie->uri, $o_uri, "back at $o_uri";

my $link = $ie->find_link( text => 'formbasics' );
is $link->name, '', "<A> has no name";

$ENV{WIM_VISIBLE} or $ie->close;
