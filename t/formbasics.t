#! perl -w
use strict;
use FindBin;
use URI::file;

# $Id: formbasics.t 120 2004-03-28 15:02:29Z abeltje $

use Test::More;

plan $^O eq 'MSWin32' 
    ? (tests => 17) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE}, quiet => 1 );

isa_ok $ie, "Win32::IE::Mechanize";
isa_ok $ie->{agent}, "Win32::OLE";

my $url = (URI::file->new_abs( "t/formbasics.html" ))->as_string;

$ie->get( $url );

is $ie->title, "Test-forms Page", "->title method";

is $ie->ct, "text/html", "->ct method";

ok $ie->is_html, "content is html";

my @forms = $ie->forms;
is scalar @forms, 2, "Form count";

{
    my $form_nb = $ie->form_number(2);
    is $form_nb->name, 'form2', "Form name found";

    $ie->field( query => 'Modified' );
    is $form_nb->value( "query" ), 'Modified',
       "Form field eq browser field";

    my $form_nm = $ie->form_name( 'form2' );
    is $form_nb, $form_nm, "form-by-name eq form-by-number";

    foreach my $field (qw( dummy2 query )) {
        ok defined $form_nb->find_input( $field ), "Fields exist";
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

my $base = $ie->uri;
ok $ie->form_name( 'form2' ), "Selected the form";

$ie->submit_form(
    form_name => 'form2',
    fields    => {
        dummy2 => 'filled',
        query  => 'text',
    }
);
is $ie->uri, "$base?dummy2=filled&query=text",
   "Form submitted";

$ie->close;
