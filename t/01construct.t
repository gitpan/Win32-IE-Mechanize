#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: 01construct.t 233 2005-01-09 19:29:28Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 13) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/formbasics.html" )->as_string;

{ # No arguments for constructor
    isa_ok my $ie = Win32::IE::Mechanize->new(  ),
           "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";
}    
{ # hashref for arguments
    isa_ok my $ie = Win32::IE::Mechanize->new( {visible => 0}  ),
           "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";
}
{ # Unupported arguments mixed in
    isa_ok my $ie = Win32::IE::Mechanize->new({
        visible => 0,
        unsupported => 1
    }), "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";
}
{ # Supply our own onwarn/ondie handler
    isa_ok my $ie = Win32::IE::Mechanize->new( onwarn => sub { die @_ } ),
           "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";

    ok $ie->get( $uri ), "get( $uri )";

    # form_number 0 becomes 1!
    my $frm0 = eval { $ie->form_number( 0 ) };
    isa_ok $frm0, 'Win32::IE::Form';

    my $frm3 = eval { $ie->form_number( 3 ) };
    is $frm3, undef, "undef for invalid formnumber (high)";
    like $@, qr/There is no form/, "select wrong form (high)";
}
