#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: field.t 381 2005-08-12 01:34:10Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i
    ? (tests => 12) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/field.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok $ie, 'Win32::IE::Mechanize';

ok $ie->get( $uri ), "Fetched $uri";

{
    my $val = 'Modified!';
    my( $rval ) = $ie->field( dingo => $val );
    is $rval, $val, "field($val) returns the set value ($rval)";
    my $form = $ie->current_form;
    is $form->value( "dingo" ), $val, "dingo => $val";
    my( $value ) = $ie->value( 'dingo' );
    is $value, $val, "value() returns the set value ($value)";
}

{
    $ie->set_visible( "bingo", "bango" );
    my $form = $ie->current_form();
    is $form->value( "dingo" ), "bingo", "dingo => bingo";
    is $ie->value( 'dingo' ), 'bingo', "value(dingo) == bingo";
    is $form->value( "bongo" ), "bango", "bongo => bango";
    is $ie->value( "bongo" ), "bango", "value(bongo) == bango";
}

{
    $ie->set_visible( [ radio => "wongo!" ], "boingo" );
    my $form = $ie->current_form();
    is $form->value( "wango" ), "wongo!", "wango => wongo!";
    is $form->find_input( "dingo", undef, 2 )->value, "boingo",
       "dingo(2) => boingo";
}

$ENV{WIM_VISIBLE} or $ie->close;
