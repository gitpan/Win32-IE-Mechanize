#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: swaplist.t 381 2005-08-12 01:34:10Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 32) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $url = URI::file->new_abs( "$base/t/swaplist.html" )->as_string;

isa_ok my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} ),
       "Win32::IE::Mechanize";
isa_ok $ie->{agent}, "Win32::OLE";

ok $ie->get( $url ), "get($url)";

is $ie->title, "Swaplist Test Page", "->title method";

is $ie->ct, "text/html", "->ct method";

my $form = $ie->form_name( 'swaplist' );
isa_ok $form, 'Win32::IE::Form';

my $ni_list = $form->find_input( 'notin', 'select-multiple' );
isa_ok $ni_list, 'Win32::IE::Input';

my @preset = qw( choice1 choice3 );
my @selected = $ie->field( 'notin', \@preset );
is_deeply \@selected, \@preset, "Select-Multi has two values";

ok $ie->click_button( value => 'Add >>', nowait => 1 ), "Click 'Add >>'";
ok $ie->click_button( value => 'Submit', nowait => 1 ), "Click 'Submit'";
my @isin = $ie->field( 'isin' );
is_deeply \@isin, \@preset, "Transfer succeded";

my @takeout = qw( choice1 );
$ie->field( 'isin', \@takeout );
ok $ie->click_button( value => '<< Remove', nowait => 1 ), "Click '<< Remove'";
ok $ie->click_button( value => 'Submit',    nowait => 1 ), "Click 'Submit'";
my %notinscr = map { ( $_ => undef ) } qw( choice1 choice2 choice4 choice5 );
my %notinfrm = map { ( $_ => undef ) } $ie->field( 'notin' );
is_deeply \%notinfrm, \%notinscr, "Put choice1 back";

ok $ie->click_button( value => 'Submit', nowait => 1 ), "Click 'Submit'";
@isin = $ie->field( 'isin' );
is_deeply \@isin, [ 'choice3' ], "Only one left in the isin box";

is $ie->field( 'dosubmit' ), 0, "Submit state false";
ok $ie->click_button( value => 'May Submit', nowait => 1 ),
   "Click 'May Submit'";
is $ie->field( 'dosubmit' ), 1, "Submit state true";

ok $ie->click_button( value => 'Submit' ), "Click 'Submit'";
my $uri = $ie->uri->as_string;
like $uri, qr/\bdosubmit=1\b/, "'dosubmit' was passed";
like $uri, qr/\bisin=choice3\b/, "'isin=choice3' was passed";
for my $notin_val ( keys %notinscr ) {
    like $uri, qr/\bnotin=$notin_val/, "'notin=$notin_val' was passed";
}

unlike $uri, qr/\bnotin=choice3\b/, "'notin=choice3' was not passed";
for my $notin_val ( keys %notinscr ) {
    unlike $uri, qr/\bisin=$notin_val/, "'isin=$notin_val' was not passed";
}

$ENV{WIM_VISIBLE} or $ie->close;
