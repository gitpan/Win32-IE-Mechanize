#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: select.t 216 2004-12-29 18:32:42Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 26) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/select.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} );
isa_ok $ie, 'Win32::IE::Mechanize';

ok $ie->get( $uri ), "Fetched $uri";

{
    my( $val1 ) = $ie->field( 'sel1' );
    is $val1, '1', "Preset for sel1 ($val1)";

    my @val2 = $ie->field( 'sel2' );
    is_deeply \@val2, [1, 2], "Preset for sel2 [@val2]";
}
# Test the select-one interface
{
    ok $ie->select( sel1 => '3' ), "Selected single value (3)";
    my( $val1 ) = $ie->field( 'sel1' );
    is $val1, 3, "select() set the single value ($val1)";
}
{
    my @newset = ( 5, 4 );
    ok $ie->select( sel1 => \@newset ), "select() with multiple values";
    my( $val1 ) = $ie->field( 'sel1' );
    local $" = ', ';
    is $val1, $newset[-1],
       "select(@newset) set the last of multivalues ($val1)";
}
{
    ok $ie->select( sel1 => { n => 3  } ),
       "select() with the { n => 3 } interface";
    my( $val1 ) = $ie->field( 'sel1' );
    is $val1, 3, "select() set the fifth item ($val1)";
}
{
    ok $ie->select( sel1 => { n => [ 5 ] } ),
       "select() with the { n => [ 5 ] } interface";
    my( $val1 ) = $ie->field( 'sel1' );
    is $val1, '5', "select() set the fifth item ($val1)";
}
# Test the select-multiple interface
local $" = ', ';
{
    ok $ie->select( sel2 => '3' ), "Selected single value (3)";
    my @val2 = $ie->field( 'sel2' );
    is_deeply \@val2, [ 3 ], "select() set the single value (@val2)";
}
{
    my @newset = ( 5, 4 );
    ok $ie->select( sel2 => \@newset ),
       "select( sel2 => [ @newset ] ) with multiple values";
    my @val2  = $ie->field( 'sel2' );
    is_deeply [sort {$a <=> $b} @val2], [sort {$a <=> $b} @newset],
       "select(@newset) set all multivalues (@val2)";
}
{
    ok $ie->select( sel2 => { n => 3 } ),
       "select() with the { n => 3 } interface";
    my @val2 = $ie->field( 'sel2' );
    is_deeply \@val2, [ 3 ], "select() set the fifth item (@val2)";
}
{
    ok $ie->select( sel2 => { n => [ 4, 5 ] } ),
       "select() with the { n => [ 4, 5 ] } interface";
    my @val2 = $ie->field( 'sel2' );
    is_deeply \@val2, [ 4, 5 ], "select() set the fifth item (@val2)";
}

ok $ie->select( sel1 => 1 ), "select(sel1 => 1)";
ok $ie->select( sel2 => [2,3] ), "select(sel2 => [2,3])";
ok $ie->submit, "submit the form";

my $ret_url = $ie->uri;
like $ret_url, qr/sel1=1/, "return contains 'sel1=1'";
like $ret_url, qr/sel2=2&sel2=3/, "return contains 'sel2=2&sel2=3'";

$ENV{WIM_VISIBLE} or $ie->close;
