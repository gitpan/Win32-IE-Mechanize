#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();
$|++;

# $Id: 02ct.t 383 2005-08-12 17:18:35Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 23) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/basic.html" )->as_string;
my $urit = URI::file->new_abs( "$base/t/basic.txt" )->as_string;
my @image_uri = map URI::file->new_abs( "$base/t/$_" )->as_string
    => qw( reddot.gif greendot.jpg bluedot.png );


isa_ok my $ie = Win32::IE::Mechanize->new(
    visible => $ENV{WIM_VISIBLE},
), "Win32::IE::Mechanize";
isa_ok $ie->agent, "Win32::OLE";

ok $ie->get( $uri ), "get($uri)";
my $doc = $ie->agent->Document;
is $ie->title, "Test Page", "->title method";
is $ie->ct, "text/html", "->ct method ($doc->{mimeType})";

ok $ie->follow_link( text => 'Basic text' ), "Follow textlink";
$doc = $ie->agent->Document;
is $ie->ct, 'text/plain', "Plain text ($doc->{mimeType})";

ok $ie->reload, "reload()";
$doc = $ie->agent->Document;
is $ie->ct, 'text/plain', "same content-type ($doc->{mimeType})";

$ie->quiet( 1 );
ok ! $ie->follow_link( n => 'all' ), "Cannot follow_link( n => 'all' )";

( my $ouri = $uri ) =~ s|:///?([A-Z]):|:///\U$1:|i;
ok $ie->back, "back()";
$doc = $ie->agent->Document;
is $ie->ct, 'text/html', "text/html ($doc->{mimeType})";
is $ie->uri, $ouri, "back to $ouri";

{
    for my $img ( @image_uri ) {
        ok $ie->get( $img ), "get( $img )";
        my $ctype = $img =~ /\.(\w+)$/ ? $1 : 'unknown';
        $ctype =~ s/jpg/jpeg/;
        $doc = $ie->{agent}->Document;
        is $ie->ct, "image/$ctype", "ct() eq $ctype ($doc->{mimeType})";
        my $rct = Win32::IE::Mechanize::_ct_from_registry( $doc->{mimeType} );
        is $rct, "image/$ctype", "_ct_from_registry($doc->{mimeType}) = $rct";
    }
}
