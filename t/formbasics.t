#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: formbasics.t 216 2004-12-29 18:32:42Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i
    ? (tests => 19) : (skip_all => "This is not MSWin32!");

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
