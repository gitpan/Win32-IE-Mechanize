#! perl -w
use strict;

# $Id: 00props.t 225 2005-01-03 22:37:27Z abeltje $

use Test::More;

plan $^O =~ /MSWin32|cygwin/i 
    ? (tests => 11) : (skip_all => "This is not MSWin32!");

use_ok 'Win32::IE::Mechanize';

isa_ok my $ie = Win32::IE::Mechanize->new( visible => $ENV{WIM_VISIBLE} ),
       "Win32::IE::Mechanize";
isa_ok $ie->agent, "Win32::OLE";

ok $ie->get( 'about:blank' ), "get(about:blank)";
my $agent = $ie->agent;

my $df_vis = $ENV{WIM_VISIBLE} || 0;
is $agent->{visible}, $df_vis, "Visible-attrib";

SKIP: {
    skip "Graphical system not available?", 1
        unless $ENV{LOGONSERVER} && !$ENV{SSH_TTY};
    $ie->set_property( visible => 1 );
    is $agent->{visible}, 1, "Visible!";
}

$ie->set_property( fullscreen => 1 );
is $agent->{fullscreen}, 1, "Fullscreen!";

$ie->set_property( fullscreen => 0 );
my %save;
for my $prop (qw( top left width height )) {
    $save{ $prop } = $agent->{ $prop };
}
my $new = { top => 0, left => 0, width => 640, height => 480 };
$ie->set_property( $new );

for my $prop (keys %$new) {
    is $agent->{ $prop }, $new->{ $prop }, "$prop => $new->{ $prop }";
}

$ie->set_property( visible => $df_vis, %save );

$ENV{WIM_VISIBLE} or $ie->close; 
