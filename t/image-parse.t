#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: image-parse.t 233 2005-01-09 19:29:28Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 20) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/image-parse.html" )->as_string;
my $url1 = URI::file->new_abs( "$base/t/wango.jpg" )->as_string;
my $url2 = URI::file->new_abs( "$base/t/bongo.gif" )->as_string;

isa_ok my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} ),
       "Win32::IE::Mechanize";
isa_ok $ie->agent, "Win32::OLE";

ok $ie->get( $uri ), "get($uri)";

is $ie->title, "Image Test Page", "->title method";

is $ie->ct, "text/html", "->ct method";

my @images = $ie->images;
is scalar @images, 2, "Only two images";

my $first = $images[0];
is lc $first->tag, "img", "img tag";
(my $juri = $url1 ) =~ s|://([a-z]):|:///\U$1:|i;
is $first->url, $juri, "src=$juri";
is $first->alt, "The world of the wango", "alt=The world of the wango";

my $second = $images[1];
is lc $second->tag, "input", "input tag";
(my $guri = $url2 ) =~ s|://([a-z]):|:///\U$1:|i;
is $second->url, $guri, "src=$guri";
is $second->alt, '', "alt";
is $second->height, 142, "height";
is $second->width, 43, "width";

my $fia1 = $ie->find_image( alt => "The world of the wango" );
isa_ok $fia1, 'Win32::IE::Image';
is $fia1, $images[0], "find_image( alt )";
my $fiar1 = $ie->find_image( alt_regex => qr/The world of/ );
isa_ok $fiar1, 'Win32::IE::Image';
is $fiar1, $images[0], "find_image( alt_regex )";

{
    my $imagelist = $ie->find_all_images;
    is scalar @$imagelist, 2, "fins_all_images()";
}
