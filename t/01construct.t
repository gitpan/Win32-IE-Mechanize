#! perl -w
use strict;
use URI::file;
use Cwd;        # These help the cygwin tests
require Win32;
my $base = Win32::GetCwd();

# $Id: 01construct.t 383 2005-08-12 17:18:35Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 13) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';
$Win32::IE::Mechanize::DEBUG = $Win32::IE::Mechanize::DEBUG = $ENV{WIM_DEBUG};

local $^O = 'MSWin32';
my $uri = URI::file->new_abs( "$base/t/formbasics.html" )->as_string;

{ # No arguments for constructor
    isa_ok my $ie = Win32::IE::Mechanize->new(  ),
           "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";
    $ie->close;
}    
{ # hashref for arguments
    isa_ok my $ie = Win32::IE::Mechanize->new( {visible => 0}  ),
           "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";
    $ie->close;
}
{ # Unupported arguments mixed in
    isa_ok my $ie = Win32::IE::Mechanize->new({
        visible => 0,
        olewarn => 0,
        unsupported => 1,
    }), "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";
    $ie->close;
}
{ # Supply our own onwarn/ondie handler
    isa_ok my $ie = Win32::IE::Mechanize->new(
        onwarn => sub { die @_ },
        readystate => 3,
    ), "Win32::IE::Mechanize";
    isa_ok $ie->agent, "Win32::OLE";

    ok $ie->get( $uri ), "get( $uri )";

    # form_number 0 becomes 1!
    my $frm0 = eval { $ie->form_number( 0 ) };
    isa_ok $frm0, 'Win32::IE::Form';

    my $frm3 = eval { $ie->form_number( 3 ) };
    is $frm3, undef, "undef for invalid formnumber (high)";
    like $@, qr/There is no form/, "select wrong form (high)";
    $ie->close;
}
