#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: formbasics.t 233 2005-01-09 19:29:28Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i
    ? (tests => 33) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

local $^O = 'MSWin32';
my $url = URI::file->new_abs( "$base/t/formbasics.html" )->as_string;

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE}, quiet => 1 );

isa_ok $ie, "Win32::IE::Mechanize";
isa_ok $ie->agent, "Win32::OLE";

ok $ie->get( $url ), "get($url)";

is $ie->title, "Test-forms Page", "->title method";

is $ie->ct, "text/html", "->ct method";

ok $ie->is_html, "content is html";

my @forms = $ie->forms;
is scalar @forms, 2, "Form count";

{
    my $form_nb = $ie->form_number(2);
    is $form_nb->name, 'form2', "Form name found";

    my( $value ) = $ie->field( query => 'Modified' );
    is $form_nb->value( "query" ), 'Modified',
       "Form field eq browser field";
    is $ie->value( 'query' ), $value,
       "value(query) method returns '$value'";

    my $form_nm = $ie->form_name( 'form2' );
    is $form_nb, $form_nm, "form-by-name eq form-by-number";

    foreach my $field (qw( dummy2 query )) {
        ok defined $form_nb->find_input( $field ), "Fields exist";
    }

    my $furi = 'formbasics.html';
    is $form_nb->action, $furi, "action( $furi )";
    is lc $form_nb->method, 'get', "method=GET";
    is $form_nb->enctype, 'application/x-www-form-urlencoded', "enctype()";
    my $fname = $form_nb->attr( 'name' );
    is $fname, 'form2', "attr( 'name' ) eq $fname";
    is $form_nb->attr( 'unknown' ), undef, "unkown attribute";
    is $form_nb->find_input( 'unknown' ), undef, "unknown input controle";
    my $submit = $form_nb->find_input( undef, 'submit' );
    is $submit->value, 'Submit', "Submit-button";

    my @flags = $form_nb->find_input( 'flags' );
    is scalar @flags, 2, "number of checkboxes";

    my $flag2 = $form_nb->find_input( 'flags', undef, 2);
    is $flag2->value, 2, "second value";
    my( $flag1 ) = $form_nb->find_input( 'flags', undef, 1);
    is $flag1->value, 1, "first value";
    {
        isa_ok $ie->form_number( 2 ), 'Win32::IE::Form';
        ok $ie->tick( flags => 1 ), "tick( 1 )";
        ok $ie->tick( flags => 2 ), "tick( 2 )";
        my @vals = $ie->value( 'flags' );
        is_deeply \@vals, [1, 2], "values( flags )";
    }
    ok !$ie->form_name( 'doesnotexist' ),
       "Cannot select unknown form";
}

{
    my $form_nb = $ie->form_number( 1 );
    ok $form_nb, "Form number found";

    ok !$ie->form_name( 'doesnotexist' ),
       "Cannot select unknown form";
}

my $prev_uri = $ie->uri;
ok $ie->form_name( 'form2' ), "Selected the form";
$ie->untick( flags => $_ ) for ( 1..2 );
$ie->submit_form(
    form_name => 'form2',
    fields    => {
        dummy2 => 'filled',
        query  => 'text',
    }
);
is $ie->uri, "$prev_uri?dummy2=filled&query=text",
   "Form submitted";

$ENV{WIM_VISIBLE} or $ie->close;
