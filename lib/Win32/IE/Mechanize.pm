package Win32::IE::Mechanize;
use strict;

# $Id: Mechanize.pm 372 2005-08-07 17:35:51Z abeltje $
use vars qw( $VERSION $SLEEP $READYSTATE );
$VERSION = '0.009';

=head1 NAME

Win32::IE::Mechanize - Like "the mech" but with IE as user-agent

=head1 SYNOPSIS

    use Win32::IE::Mechanize;

    my $ie = Win32::IE::Mechanize->new( visible => 1 );

    $ie->get( $url );

    $ie->follow_link( text => $link_txt );

    $ie->form_name( $form_name );
    $ie->set_fields(
        username => 'yourname',
        password => 'dummy' 
    );
    $ie->click( $btn_name );

    # Or all in one go:
    $ie->submit_form(
        form_name => $form_name,
        fields    => {
            username => 'yourname',
            password => 'dummy',
        },
        button    => $btn_name,
    );

Now also trys to support Basic-Authentication like LWP::UserAgent

    use Win32::IE::Mechanize;

    my $ie = Win32::IE::Mechanize->new( visible => 1 );

    $ie->credentials( 'pause.perl.org:443', 'PAUSE', 'abeltje', '********' );
    $ie->get( 'https://pause.perl.org/pause/authenquery' );
 
=head1 DESCRIPTION

This module tries to be a sort of drop-in replacement for
L<WWW::Mechanize>. It uses L<Win32::OLE> to manipulate the Internet
Explorer.

Don't expect it to be like the mech in that the class is not derived
from the user-agent class (like LWP).

B<WARNING>: This is a work in progress and my first priority will be
to implement the C<L<WWW::Mechanize>> interface (which is still in
full development). Where ever possible and needed I will also
implement B<LWP::UserAgent> methods that the mech inherits and will
help make this thing useful.

B<Thank you Andy Lester for C<L<WWW::Mechanize>>. I ported a lot of that
code and nicked most of your documentation!>

For more information on the OLE2 interface for InternetExplorer, google
for B<InternetExplorer.Application+msdn>.

=head1 CONSTRUCTION AND PROPERTIES

=cut

use URI;
use Win32::OLE;

# This was suggested by Bart Lateur
BEGIN {
    eval "use Time::HiRes qw/sleep/";
    $@ or $SLEEP = 0.055;
}
$READYSTATE = 2;

# These are properties of InternetExplorer.Application we support
my %ie_property = (
    addressbar => { type => 'b', value => undef },
    fullscreen => { type => 'b', value => undef },
    resizable  => { type => 'b', value => undef },
    statusbar  => { type => 'b', value => undef },
    toolbar    => { type => 'b', value => undef },
    visible    => { type => 'b', value => 0     },
    height     => { type => 'n', value => undef },
    width      => { type => 'n', value => undef },
    left       => { type => 'n', value => undef },
    top        => { type => 'n', value => undef },
);

=head2 Win32::IE::Mechanize->new( [%options] )

This initialises a new I<InternetExplorer.Application> through
C<L<Win32::OLE>> and sets all the properties that are passed via the
C<%options> hash(ref).

See C<L<set_property()>> for supported options.

=cut

sub new {
    my $class = shift;

    my $self = bless {
        _opt    => {},
        quiet   => 0,
        onwarn  => \&Win32::IE::Mechanize::__warn,
        onerror => \&Win32::IE::Mechanize::__die,
    }, $class;

    my %opt = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();
    $self->{_opt} = { map {
        ( $_ => __prop_value( $_, $opt{ $_ } ) )
    } grep exists $ie_property{ lc $_ } => keys %opt };

    # some more options not for IE
    $self->{ $_ } = exists $opt{ $_ } ? $opt{ $_ } : undef
        for qw( quiet onwarn onerror );

    $self->open;
}

=head2 $ie->set_property( %opt )

Allows you to set these supported properties:

=over 4

=item B<addressbar>

Set the visibility of the addressbar

=item B<fullscreen>

Set the window of IE to fullscreen (like F11)

=item B<resizable>

Set the resize-ability

=item B<statusbar>

Set the visibility of the statusbar

=item B<toolbar>

Set the visibility of the toolbar

=item B<visible>

Set the visibility of the IE window

=item B<height>

Set the height of the IE window

=item B<width>

Set the width of the IE window

=item B<left>

Set the left coordinate of the IE window

=item B<top>

Set the top-coordinate of the IE window

=back

=cut

sub set_property {
    my $self = shift;

    my %raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();
    my %opt = map {
        ( $_ => __prop_value( $_, $raw{ $_ } ) )
    } grep exists $ie_property{ lc $_ } => keys %raw;

    foreach my $prop ( keys %opt ) {
        defined $opt{ $prop } and
            $self->{agent}->{ $prop } = $opt{ $prop };
    }
}

=head2 $ie->close

Close the InternetExplorer instance.

=cut

sub close { $_[0]->{agent}->quit; $_[0]->{agent} = undef; }

sub open {
    my $self = shift;
    defined $self->{agent} and return;
    $self->{agent} = Win32::OLE->new( 'InternetExplorer.Application' ) or
        $self->die( "Cannot create an InternetExplorer.Application" );
    foreach my $prop ( keys %{ $self->{_opt} } ) {
        defined $self->{_opt}{ $prop } and
            $self->{agent}->{ $prop } = $self->{_opt}{ $prop };
    }
    return $self;
}

=head2 $ie->agent

Return a reference to the InternetExplorer automation object.

=cut

sub agent { $_[0]->{agent} }

=head1 PAGE-FETCHING METHODS

=head2 $ie->get( $url )

Use the C<Navigate> method of the IE object to get the C<$url> and
wait for it to be loaded.

=cut

sub get {
    my $self = shift;
    my $agent = $self->{agent};
    my( $url ) = @_;
     
    my $uri = $self->uri 
        ? URI->new_abs( $url, $self->uri->as_string )
        : URI->new( $url );
    $agent->navigate({ URL     => $uri->as_string,
                       Headers => $self->_extra_headers( $uri ) });
    $self->_wait_while_busy;
}

=head2 $ie->reload()

Use the C<Refresh> method of the IE object and wait for it to be
loaded.

=cut

sub reload {
     $_[0]->{agent}->Refresh;
     $_[0]->_wait_while_busy;
}

=head2 $ie->back()

Use the C<GoBack> method of the IE object and wait for it to be
loaded.

=cut

sub back {
    $_[0]->{agent}->GoBack;
    $_[0]->_wait_while_busy;
}

=head1 STATUS METHODS

=head2 $ie->success

Return true for ReadyState >= 2;

=cut

sub success { $_[0]->{agent}->ReadyState >= 2 }

=head2 $ie->uri

Return the URI of this document (as an URI object).

=cut

sub uri { URI->new( $_[0]->{agent}->LocationURL ) }

=head2 $ie->ct

Fetch the C<mimeType> from the C<< $ie->Document >>. IE does not
return the MIME type in a way we expect.

=cut

sub ct { 
    my $ct = $_[0]->{agent}->Document->mimeType;
    CASE: {
        local $_ = $ct;
        /^HTML/i              and return "text/html";
        /^Text/i              and return "text/plain";
        /^(\w+) Image/i       and return "image/\L$1";
        /^(?:jpe?g|gif|png)/i and return "image/\L$1";

        return _ct_from_registry( $_ );
    }
}

=begin private

=head2 _ct_from_registry( $iemime )

This is a bit af a pain:

=over 4

=item * Find a key like C<qr/.+?file/> in HKEY_CLASSES_ROOT with value
$iemime (put it in @fts)

=item * Find a key like C<qr/\..+/> in HKEY_CLASSES_ROOT with value
$ft and a subkey I<Content Type>, that value can be used as Content Type.

=back

=end private

=cut

sub _ct_from_registry {
    my $iemime = shift;

    eval q{require Win32::TieRegisrty};
    $@ and return $iemime;

    Win32::TieRegistry->import( Delimiter => '/' );
    my $Registry = $Win32::TieRegistry::Registry;
    my @filetypes = grep m|^(.+?file/)$| &&
                         ($Registry->{ "Classes/$1/" }||'') eq $iemime
        => keys %{ $Registry->{'Classes/'} };

    my $mimeType = $iemime;
    for my $ft ( @filetypes ) {
        ( my $ftclean = $ft ) =~ s|/$||;
        my @exts = grep m|^(\..+?/)$| &&
                        ($Registry->{ "Classes/$1/" }||'') eq $ftclean &&
    		    $Registry->{ "Classes/${1}Content Type" }
            => keys %{$Registry->{'Classes/'}};
    
        @exts and $mimeType = $Registry->{ "Classes/$exts[0]Content Type" };
    }
    return $mimeType;
}

=head2 $ie->current_form

Returns the current form as an C<Win32::IE::Form> object.

=cut

sub current_form {
    my $self = shift;
    defined $self->{cur_form} or $self->form_number( 1 );
    $self->{cur_form};
}

=head2 $ie->is_html

Return true if this is an HTML Document.

=cut

sub is_html {
    my $self = shift;
    return $self->ct eq 'text/html';
}

=head2 $ie->title

Fetch the C<title> from the C<< $ie->Document >>.

=cut

sub title { $_[0]->{agent}->Document->title }

=head1 CONTENT-HANDLING METHODS

=head2 $ie->content

Fetch the C<outerHTML> from the C<< $ie->Document->documentElement >>.

I have found no way to get to the exact contents of the document.
This is basically the interpretation of IE of what the HTML looks like
and beware all tags are upcased :(

=cut

sub content { $_[0]->{agent}->Document->documentElement->{outerHTML} }

=head1 LINK METHODS

=head2 $ie->links

When called in a list context, returns a list of the links found in
the last fetched page. In a scalar context it returns a reference to
an array with those links. The links returned are all
C<Win32::IE::Link> objects.

=cut

sub links {
    my $self = shift;

    defined $self->{links} or $self->{links} = $self->_extract_links;

    return wantarray ? @{ $self->{links} } : $self->{links};
}

=head2 $ie->follow_link( %opt )

Uses the C<< $self->find_link() >> interface to locate a link and C<<
$self->get() >> it.

=cut

sub follow_link {
    my $self = shift;
    my %parms = ( n => 1, @_ );

    if ( $parms{n} eq "all" ) {
        delete $parms{n};
        $self->warn( qq{follow_link( n => "all" ) is not valid} );
    }

    my $link = $self->find_link( @_ );
    $self->get( $link->url ) if $link;
}

=head2 $ie->find_link( [%options] )

This method finds a link in the currently fetched page. It returns a
L<Win32::IE::Link> object which describes the link.  (You'll probably
be most interested in the C<url()> property.)  If it fails to find a
link it returns undef.

You can take the URL part and pass it to the C<get()> method.  If that's
your plan, you might as well use the C<follow_link()> method directly,
since it does the C<get()> for you automatically.

Note that C<< <FRAME SRC="..."> >> tags are parsed out of the the HTML
and treated as links so this method works with them.

You can select which link to find by passing in one or more of these
key/value pairs:

=over 4

=item * C<< text => 'string', >> and C<< text_regex => qr/regex/, >>

C<text> matches the text of the link against I<string>, which must be an
exact match.  To select a link with text that is exactly "download", use

    $mech->find_link( text => "download" );

C<text_regex> matches the text of the link against I<regex>.  To select a
link with text that has "download" anywhere in it, regardless of case, use

    $mech->find_link( text_regex => qr/download/i );

Note that the text extracted from the page's links are trimmed.  For
example, C<< <a> foo </a> >> is stored as 'foo', and searching for
leading or trailing spaces will fail.

=item * C<< url => 'string', >> and C<< url_regex => qr/regex/, >>

Matches the URL of the link against I<string> or I<regex>, as appropriate.
The URL may be a relative URL, like F<foo/bar.html>, depending on how
it's coded on the page.

=item * C<< url_abs => string >> and C<< url_abs_regex => regex >>

Matches the absolute URL of the link against I<string> or I<regex>,
as appropriate.  The URL will be an absolute URL, even if it's relative
in the page.

=item * C<< name => string >> and C<< name_regex => regex >>

Matches the name of the link against I<string> or I<regex>, as appropriate.

=item * C<< tag => string >> and C<< tag_regex => regex >>

Matches the tag that the link came from against I<string> or I<regex>,
as appropriate.  The C<tag_regex> is probably most useful to check for
more than one tag, as in:

    $mech->find_link( tag_regex => qr/^(a|frame)$/ );

The tags and attributes looked at are defined below, at
L<$mech->find_link() : link format>.

=item * C<< n => number >>

=back

The C<n> parms can be combined with the C<text*> or C<url*> parms
as a numeric modifier.  For example,
C<< text => "download", n => 3 >> finds the 3rd link which has the
exact text "download".

If C<n> is not specified, it defaults to 1.  Therefore, if you don't
specify any parms, this method defaults to finding the first link on the
page.

Note that you can specify multiple text or URL parameters, which
will be ANDed together.  For example, to find the first link with
text of "News" and with "cnn.com" in the URL, use:

    $ie->find_link( text => "News", url_regex => qr/cnn\.com/ );

=cut

sub find_link {
    my $self = shift;
    my %parms = ( n=>1, @_ );

    my $wantall = ( $parms{n} eq "all" );

    $self->_clean_keys( 
        \%parms,
        qr/^(n|(text|url|url_abs|name|tag)(_regex)?)$/ 
    );

    my @links = $self->links or return;

    my $nmatches = 0;
    my @matches;
    for my $link ( @links ) {
        if ( _match_any_link_parms($link,\%parms) ) {
            if ( $wantall ) {
                push( @matches, $link );
            } else {
                ++$nmatches;
                return $link if $nmatches >= $parms{n};
            }
        }
    } # for @links

    if ( $wantall ) {
        return @matches if wantarray;
        return \@matches;
    }

    return;
}

# Stolen from WWW::Mechanize-1.08
# Used by find_links to check for matches
# The logic is such that ALL parm criteria that are given must match
sub _match_any_link_parms {
    my $link = shift;
    my $p = shift;

    # No conditions, anything matches
    return 1 unless keys %$p;

    return if defined $p->{url}
        and !( $link->url eq $p->{url} );
    return if defined $p->{url_regex}
        and !( $link->url =~ $p->{url_regex} );
    return if defined $p->{url_abs}
        and !( $link->url_abs eq $p->{url_abs} );
    return if defined $p->{url_abs_regex}
        and !( $link->url_abs =~ $p->{url_abs_regex} );
    return if defined $p->{text}
        and !( defined($link->text) and $link->text eq $p->{text} );
    return if defined $p->{text_regex}
        and !( defined($link->text) and $link->text =~ $p->{text_regex} );
    return if defined $p->{name}
        and !( defined($link->name) and $link->name eq $p->{name} );
    return if defined $p->{name_regex}
        and !( defined($link->name) and $link->name =~ $p->{name_regex} );
    return if defined $p->{tag}
        and !( $link->tag and lc( $link->tag ) eq lc( $p->{tag} ) );
    return if defined $p->{tag_regex}
        and !( $link->tag and $link->tag =~ $p->{tag_regex} );

    # Success: everything that was defined passed.
    return 1;
}

# Cleans the %parms parameter for the find_link and find_image methods.
sub _clean_keys {
    my $self = shift;
    my $parms = shift;
    my $rx_keyname = shift;

    for my $key ( keys %$parms ) {
        my $val = $parms->{$key};
        if ( $key !~ qr/$rx_keyname/ ) {
            $self->warn( qq{Unknown link-finding parameter "$key"} );
            delete $parms->{$key};
            next;
        }

        my $key_regex = ( $key =~ /_regex$/ );
        my $val_regex = ( ref($val) eq "Regexp" );

        if ( $key_regex ) {
            if ( !$val_regex ) {
                $self->warn( qq{$val passed as $key is not a regex} );
                delete $parms->{$key};
                next;
            }
        } else {
            if ( $val_regex ) {
                $self->warn( qq{$val passed as '$key' is a regex} );
                delete $parms->{$key};
                next;
            }
            if ( $val =~ /^\s|\s$/ ) {
                $self->warn( qq{'$val' is space-padded and cannot succeed} );
                delete $parms->{$key};
                next;
            }
        }
    } # for keys %parms
} # _clean_keys()

=head2 $ie->find_all_links( %opt )

Returns all the links on the current page that match the criteria.
The method for specifying link criteria is the same as in
C<find_link()>.  Each of the links returned is in the same format
as in C<find_link()>.

In list context, C<find_all_links()> returns a list of the links.
Otherwise, it returns a reference to the list of links.

C<find_all_links()> with no parameters returns all links in the
page.

=cut

sub find_all_links {
    my $self = shift;
    $self->find_link( @_, n => 'all' );
}

=head1 IMAGE METHODS

=head2 $ie->images

Lists all the images on the current page.  Each image is a
Win32::IE::Image object. In list context, returns a list of all
images.  In scalar context, returns an array reference of all images.

B<NOTE>: Althoug L<WWW::Mechanize> explicitly only supports 
    <INPUT type=submit src="...">
constructs, this is B<not> supported by IE, it must be:
    <INPUT type=image src="...">
for IE to behave as expected.
 
=cut

sub images {
    my $self = shift;

    $self->_extract_images unless defined $self->{images};

    return wantarray ? @{ $self->{images} } : $self->{images};
}

=head2 $ie->find_image()

Finds an image in the current page. It returns a
L<Win32::IE::Image> object which describes the image.  If it fails
to find an image it returns undef.

You can select which link to find by passing in one or more of these
key/value pairs:

=over 4

=item * C<< alt => 'string' >> and C<< alt_regex => qr/regex/, >>

C<alt> matches the ALT attribute of the image against I<string>, which must be a
n
exact match. To select a image with an ALT tag that is exactly "download", use

    $ie->find_image( alt  => "download" );

C<alt_regex> matches the ALT attribute of the image  against a regular
expression.  To select an image with an ALT attribute that has "download"
anywhere in it, regardless of case, use

    $ie->find_image( alt_regex => qr/download/i );

=item * C<< url => 'string', >> and C<< url_regex => qr/regex/, >>

Matches the URL of the image against I<string> or I<regex>, as appropriate.
The URL may be a relative URL, like F<foo/bar.html>, depending on how
it's coded on the page.

=item * C<< url_abs => string >> and C<< url_abs_regex => regex >>

Matches the absolute URL of the image against I<string> or I<regex>,
as appropriate.  The URL will be an absolute URL, even if it's relative
in the page.

=item * C<< tag => string >> and C<< tag_regex => regex >>

Matches the tag that the image came from against I<string> or I<regex>,
as appropriate.  The C<tag_regex> is probably most useful to check for
more than one tag, as in:

    $ie->find_image( tag_regex => qr/^(img|input)$/ );

The tags supported are C<< <img> >> and C<< <input> >>.

=back

If C<n> is not specified, it defaults to 1.  Therefore, if you don't
specify any parms, this method defaults to finding the first image on the
page.

Note that you can specify multiple ALT or URL parameters, which
will be ANDed together.  For example, to find the first image with
ALT text of "News" and with "cnn.com" in the URL, use:

    $ie->find_image( image => "News", url_regex => qr/cnn\.com/ );

The return value is a reference to an array containing a
L<Win32::IE::Image> object for every image in C<< $self->content >>.

=cut

sub find_image {
    my $self = shift;
    my %parms = ( n=>1, @_ );

    my $wantall = ( $parms{n} eq "all" );

    $self->_clean_keys( \%parms, qr/^(n|(alt|url|url_abs|tag)(_regex)?)$/ );

    my @images = $self->images or return;

    my $nmatches = 0;
    my @matches;
    for my $image ( @images ) {
        if ( _match_any_image_parms($image,\%parms) ) {
            if ( $wantall ) {
                push( @matches, $image );
            } else {
                ++$nmatches;
                return $image if $nmatches >= $parms{n};
            }
        }
    } # for @images

    if ( $wantall ) {
        return @matches if wantarray;
        return \@matches;
    }

    return;
}

# Used by find_images to check for matches
# The logic is such that ALL parm criteria that are given must match
sub _match_any_image_parms {
    my $image = shift;
    my $p = shift;

    # No conditions, anything matches
    return 1 unless keys %$p;

    return if defined $p->{url}
        and !( $image->url eq $p->{url} );
    return if defined $p->{url_regex}
        and !( $image->url =~ $p->{url_regex} );
    return if defined $p->{url_abs}
        and !( $image->url_abs eq $p->{url_abs} );
    return if defined $p->{url_abs_regex}
        and !( $image->url_abs =~ $p->{url_abs_regex} );
    return if defined $p->{alt}
        and !( defined($image->alt) and $image->alt eq $p->{alt} );
    return if defined $p->{alt_regex}
        and !( defined($image->alt) and $image->alt =~ $p->{alt_regex} );
    return if defined $p->{tag}
        and !( $image->tag and lc( $image->tag ) eq lc( $p->{tag} ) );
    return if defined $p->{tag_regex}
        and !( $image->tag and $image->tag =~ $p->{tag_regex} );

    # Success: everything that was defined passed.
    return 1;
}

=head2 $ie->find_all_images( ... )

Returns all the images on the current page that match the criteria.  The
method for specifying image criteria is the same as in C<L<find_image()>>.
Each of the images returned is a L<Win32::IE::Image> object.

In list context, C<find_all_images()> returns a list of the images.
Otherwise, it returns a reference to the list of images.

C<find_all_images()> with no parameters returns all images in the
page.


=cut

sub find_all_images {
    my $self = shift;
    return $self->find_image( @_, n=>'all' );
}

=head1 FORM METHODS

=head2 $ie->forms

Lists all the forms on the current page.  Each form is an
Win32::IE::Form object.  In list context, returns a list of all forms.
In scalar context, returns an array reference of all forms.

=cut

sub forms {
    my $self = shift ;
    $self->_extract_forms unless defined $self->{forms};

    return wantarray ? @{ $self->{forms} } : $self->{forms};
}

=head2 $ie->form_number( $number )

Selects the numberth form on the page as the target for subsequent
calls to field() and click().  Also returns the form that was
selected.  Emits a warning and returns undef if there is no such form.
Forms are indexed from 1, so the first form is number 1, not zero.

=cut

sub form_number {
    my $self = shift;

    my $number = shift || 1;
    $self->_extract_forms unless defined $self->{forms};
    if ( @{ $self->{forms} } && $number <= @{ $self->{forms} } ) {
        $self->{cur_form} = $self->{forms}[ $number - 1 ];
    } else {
        $self->warn( "There is no form numbered $number." );
        return undef;
    }
}

=head2 $ie->form_name( $name )

Selects a form by name.  If there is more than one form on the page
with that name, then the first one is used, and a warning is
generated.  Also returns the form itself, or undef if it is not
found.

=cut

sub form_name {
    my $self = shift;
    
    my $name = shift or return undef;
    $self->_extract_forms unless defined $self->{forms};
    my @matches = grep $_->name && $_->name eq $name => @{ $self->{forms} };
    if ( @matches ) {
        $self->warn( "There are " . scalar @matches . "forms named '$name'. " .
                     "The first one was used." ) if @matches > 1;
        $self->{cur_form} = $matches[0];
    } else {
        $self->warn( "There is no form named '$name'." );
        return undef;
    }
}

=head2 $ie->field( $name[, $value[, $index]] )

=head2 $ie->field( $name, \@values[, $number ] )

Given the name of a field, set its value to the value specified.  This
applies to the current form (as set by the C<L<form_name()>> or
C<L<form_number()>> method or defaulting to the first form on the page).

The optional I<$index> parameter is used to distinguish between two fields
with the same name. The fields are numbered from 1.

=cut

sub field {
    my $self = shift;

    my( $name, $value, $index ) = @_;
    my $form = $self->current_form;

    my @inputs = $form->find_input( $name );
    @inputs or $self->warn( "No '$name' parameter exists" );
    $index ||= 1;
    my $control = $inputs[ $index - 1 ];
    defined $value ? $control->value( $value ) : $control->value();
}

=head2 $ie->select( $name, $value )

=head2 $ie->select( $name, \@values )

Given the name of a C<select> field, set its value to the value
specified.  If the field is not E<lt>select multipleE<gt> and the
C<$value> is an array, only the B<first> value will be set. Passing
C<$value> as a hash with an C<n> key selects an item by number
(e.g. C<{n => 3> or C<{n => [2,4]}>).  The numbering starts at 1.
This applies to the current form (as set by the C<L<form()>> method or
defaulting to the first form on the page).

Returns 1 on successfully setting the value. On failure, returns
undef and calls C<$self->warn()> with an error message.

=cut

sub select {
    my $self = shift;
    my( $name, $value ) = @_;

    my $form = $self->current_form;
    my $input = $form->find_input( $name, 'select' );
    if ( !$input ) {
        $self->warn( "Select '$name' not found." );
        return;
    }
    $input->select_value( $value );
    return 1;
}

=head2 $ie->set_fields( %arguments )

This method sets multiple fields of a form. It takes a list of field
name and value pairs. If there is more than one field with the same
name, the first one found is set. If you want to select which of the
duplicate field to set, use a value which is an anonymous array which
has the field value and its number as the 2 elements.

        # set the second foo field
        $ie->set_fields( $name => [ 'foo', 2 ] ) ;

The fields are numbered from 1.

This applies to the current form (as set by the C<L<form_name()>> or
C<L<form_number()>> method or defaulting to the first form on the
page).

=cut

sub set_fields {
    my $self = shift;

    my $form = $self->current_form;
    my %opt = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();
    while ( my( $fname, $value ) = each %opt ) {
        if ( ref $value eq 'ARRAY' ) {
            my( $input ) = $form->find_input( $fname, undef, $value->[1] );
            if ( $input ) {
                $input->value( $value->[0] );
            } else {
                $self->warn( "No inputcontrol by the name '$fname'" );
            }
        } else {
            my( $input ) = $form->find_input( $fname );
            if ( $input ) {
                $input->value( $value );
            } else {
                sssself->warn( "No inputcontrol by the name '$fname'" );
            }
        }
    }
}

=head2 $ie->set_visible( @criteria )

This method sets fields of a form without having to know their
names.  So if you have a login screen that wants a username and
password, you do not have to fetch the form and inspect the source
to see what the field names are; you can just say

    $ie->set_visible( $username, $password ) ;

and the first and second fields will be set accordingly.  The method
is called set_I<visible> because it acts only on visible fields;
hidden form inputs are not considered.  The order of the fields is
the order in which they appear in the HTML source which is nearly
always the order anyone viewing the page would think they are in,
but some creative work with tables could change that; caveat user.

Each element in C<@criteria> is either a field value or a field
specifier.  A field value is a scalar.  A field specifier allows
you to specify the I<type> of input field you want to set and is
denoted with an arrayref containing two elements.  So you could
specify the first radio button with

    $ie->set_visible( [ radio => "KCRW" ] ) ;

Field values and specifiers can be intermixed, hence

    $ie->set_visible( "fred", "secret", [ select => "Checking" ] ) ;

would set the first two fields to "fred" and "secret", and the I<next>
C<OPTION> menu field to "Checking".

The possible field specifier types are: "text", "password", "hidden",
"textarea", "file", "image", "submit", "radio", "checkbox" and "select".

This method was ported from L<WWW::Mechanize>.

=cut

sub set_visible {
    my $self = shift;

    my $form = $self->current_form;
    my @inputs = $form->inputs;

    while (my $value = shift) {
        if ( ref $value eq 'ARRAY' ) {
           my ( $type, $val ) = @$value;
           while ( my $input = shift @inputs ) {
               next if $input->type eq 'hidden';
               if ( $input->type eq $type ) {
                   $input->value( $val );
                   last;
               }
           } # while
        } else {
           while ( my $input = shift @inputs ) {
               next if $input->type eq 'hidden';
               $input->value( $value );
               last;
           } # while
       }
    } # while
}

=head2 $ie->tick( $name, $value[, $set] )

'Ticks' the first checkbox that has both the name and value assoicated
with it on the current form.  Dies if there is no named check box for
that value.  Passing in a false value as the third optional argument
will cause the checkbox to be unticked.

=cut

sub tick {
    my $self = shift;

    my $form = $self->current_form;

    my( $name, $value, $set ) = @_;
    $set = 1 if @_ <= 2;
    my @check_boxes = grep $_->value eq $value
        => $form->find_input( $name, 'checkbox' );

    $self->warn( "No checkbox '$name'  for value '$value' in form." ), return
        unless @check_boxes;

    foreach my $check_box ( @check_boxes ) {
        next unless $check_box->value eq $value;
        ${$check_box}->{checked} = $set || 0;
    }
    return 1;
}

=head2 $ie->untick( $name, $value )

Causes the checkbox to be unticked. Shorthand for
C<tick( $name, $value, undef)>

=cut

sub untick {
    my $self = shift;
    $self->tick( @_[0, 1], undef );
}

=head2 $mech->value( $name, $number )

Given the name of a field, return its value. This applies to the current
form (as set by the C<form()> method or defaulting to the first form on
the page).

The option I<$number> parameter is used to distinguish between two fields
with the same name.  The fields are numbered from 1.

If the field is of type file (file upload field), the value is always
cleared to prevent remote sites from downloading your local files.
To upload a file, specify its file name explicitly.

=cut

sub value {
    my $self = shift;
    my $name = shift;
    my $number = shift || 1;

    my $form = $self->current_form;
    if ( wantarray ) {
        my @inputs = $form->find_input( $name );
        return @inputs ? map $_->value() => @inputs : undef;
    }
    if ( $number > 1 ) {
        return $form->find_input( $name, undef, $number )->value();
    } else {
        return $form->value( $name );
    }
}

=head2 $ie->click( $button )

Call the click method on an INPUT object with the name C<$button> Has
the effect of clicking a button on a form.  The first argument is the
name of the button to be clicked. I have not found a way to set the
(x,y) coordinates of the click in IE.

=cut

sub click {
    my( $self, $button ) = @_;

    my $form = $self->current_form;
    
    my( $toclick ) = sort { 
        ${$a}->{sourceIndex} <=> ${$b}->{sourceIndex} 
    } $form->find_input( $button, 'button' ),
      $form->find_input( $button, 'image' ),
      $form->find_input( $button, 'submit' );

    $toclick and $toclick->click;
    $self->_wait_while_busy;
}

=head2 $ie->click_button( %args )

Has the effect of clicking a button on a form by specifying its name,
value, or index.  Its arguments are a list of key/value pairs.  Only
one of name, number, or value must be specified.

=over 4

=item * name => name

Clicks the button named I<name>.

=item * number => n

Clicks the I<n>th button in the form.

=item * value => value

Clicks the button with the value I<value>.

=back

B<NOTE>: Unlike WWW::Mechanize, Win32::IE::Mechanize takes
all buttonish types of C<< <INPUT type=> >> into accout: B<button>,
B<image> and B<submit>.

=cut

sub click_button {
    my $self = shift;
    my %args = @_;

    for ( keys %args ) {
        if ( !/^(number|name|value)$/ ) {
            $self->warn( qq{Unknown click_button_form parameter "$_"} );
        }
    }

    my $form = $self->current_form;
    my @buttons = sort { 
        ${$a}->{sourceIndex} <=> ${$b}->{sourceIndex} 
    } $form->find_input( $args{name}, 'button' ),
      $form->find_input( $args{name}, 'image' ),
      $form->find_input( $args{name}, 'submit' );

    @buttons or return;
    if ( $args{name} ) {
        $buttons[0]->click;
        return $self->_wait_while_busy;
    } elsif ( $args{number} ) {
        @buttons <= $args{number} and return
        $buttons[ $args{number} - 1 ]->click();
        return $self->_wait_while_busy;
    } elsif ( $args{value} ) {
        for my $button ( @buttons ) {
            if ( $button->value eq $args{value} ) {
                $button->click();
                return $self->_wait_while_busy;
            }
        }
    }
}

=head2 $ie->submit( )

Submits the page, without specifying a button to click.  Actually,
no button is clicked at all.

This will call the C<Submit()> method of the currently selected form.

B<NOTE>: It looks like this method does not call the C<onSubmit>
handler specified in the C<< <FORM> >>-tag, that only seems to work if
you call the C<click_button()> method with submit button.

=cut

sub submit {
    my $self = shift;

    my $form = $self->current_form;

    $form->submit;
    $self->_wait_while_busy;
}

=head2 $ie->submit_form( %opt )

This method lets you select a form from the previously fetched page,
fill in its fields, and submit it. It combines the form_number/form_name,
set_fields and click methods into one higher level call. Its arguments
are a list of key/value pairs, all of which are optional.

=over 4

=item * form_number => n

Selects the I<n>th form (calls C<L<form_number()>>).  If this parm is not
specified, the currently-selected form is used.

=item * form_name => name

Selects the form named I<name> (calls C<L<form_name()>>)

=item * fields => fields

Sets the field values from the I<fields> hashref (calls C<L<set_fields()>>)

=item * button => button

Clicks on button I<button> (calls C<L<click()>>)

=item * button => { value => value }

When you specify a hash_ref for button it calls C<click_button()>

=back

If no form is selected, the first form found is used.

If I<button> is not passed, then the C<L<submit()>> method is used instead.

Returns true on success.

=cut

sub submit_form {
    my $self = shift;

    my %opt = @_;
    if ( my $form_number = $opt{form_number} ) {
        $self->form_number( $form_number ) ;
    }
    elsif ( my $form_name = $opt{form_name} ) {
        $self->form_name( $form_name ) ;
    } else {
        $self->form_number( 1 ) unless defined $self->{cur_form};
    }

    if ( my $fields = $opt{fields} ) {
        if ( ref $fields eq 'HASH' ) {
            $self->set_fields( %{$fields} ) ;
        } # TODO: What if it's not a hash?  We just ignore it silently?
    }

    if ( $opt{button} ) {
        if ( ref $opt{button} ) {
            $self->click_button( %{ $opt{button} } );
        } else {
            $self->click( $opt{button} );
        }
    } else {
        $self->submit();
    }

    return $self->success;
}

=head1 MISCELANEOUS METHODS

=head2 $ie->add_header( name => $value [, name => $value... ] )

Sets HTTP headers for the agent to add or remove from the HTTP request.

    $ie->add_header( Encoding => 'text/klingon' );

If a I<value> is C<undef>, then that header will be removed from any
future requests.  For example, to never send a Referer header:

    $ie->add_header( Referer => undef );

Returns the number of name/value pairs added.

=cut

sub add_header {
    my $self = shift;
    my $npairs = 0;

    while ( @_ ) {
        my $key = shift;
        my $value = shift;
        ++$npairs;

        $self->{headers}{$key} = $value;
    }

    return $npairs;
}

=head2 $ie->delete_header( name [, name ... ] )

Removes HTTP headers from the agent's list of special headers.

B<NOTE>: This might not work like it does with C<WWW::Mechanize>

=cut

sub delete_header {
    my $self = shift;

    while ( @_ ) {
        my $key = shift;

        delete $self->{headers}{$key};
    }
}

=head2 $ie->quiet( [$state] )

Allows you to suppress warnings to the screen.

    $a->quiet(0); # turns on warnings (the default)
    $a->quiet(1); # turns off warnings
    $a->quiet();  # returns the current quietness status

=cut

sub quiet {
    my $self = shift;

    $self->{quiet} = $_[0] if @_;

    return $self->{quiet};
}

=head2 $ie->find_frame( $frame_name )

Returns the URL to the source of the frame with C<name eq $frame_name>

=cut

sub find_frame {
    my( $self, $frame ) = @_;

    my $agent = $self->{agent};
    my $doc = $agent->Document;
    for ( my $i = 0; $i < $doc->all->length; $i++ ) {
        my $obj = $doc->all( $i );
        next unless $obj && $obj->tagName &&
                    $obj->tagName eq 'FRAME' &&
                    $obj->name    eq $frame;

        return ( URI->new_abs( $obj->src, $doc->URL ) )->as_string;
    }
}

=head2 $ie->load_frame( $frame_name )

C<< $self->get( $self->find_frame( $frame_name )) >>

=cut

sub load_frame {
    my( $self, $frame ) = @_;

    $self->get( $self->find_frame( $frame ) );
}

=head1 LWP COMPATABILITY METHODS

=head2 $ie->credentials( $netloc, $realm, $uid, $pass )

Set the user name and password to be used for a realm.

C<$netloc> looks like C<hostname:port>.

=cut

sub credentials {
    my($self, $netloc, $realm, $uid, $pass) = @_;
    $self->{basic_authentication}{ $netloc }{ $realm } = [ $uid, $pass ];
    $self->{basic_authentication}{ $netloc }{__active_realm__} = $realm;
}

=head2 $ie->get_basic_credentials( $realm, $uri )

This is called by C<_extra_headers> to retrieve credentials for documents
protected by Basic Authentication.  The arguments passed in
are the C<$realm> and the C<$uri> requested.

The method should return a username and password.  It should return an
empty list to abort the authentication resolution attempt.

The base implementation simply checks a set of pre-stored member
variables, set up with the credentials() method.

=cut

sub get_basic_credentials {
    my($self, $realm, $uri ) = @_;

    my $host_port = $uri->can( 'host_port' )
        ? $uri->host_port : $uri->as_string;

    $realm ||= $self->{basic_authentication}{ $host_port }{__active_realm__};
    $realm or return ( );

    if ( exists $self->{basic_authentication}{ $host_port }{ $realm } ) {
        return @{ $self->{basic_authentication}{ $host_port }{ $realm } };
    }

    return ( );
}

=head2 $ie->set_realm( $netloc, $realm );

Sets the authentication realm to C<$realm> for C<$netloc>. An empty value
unsets the realm for C<$netloc>.

C<$netloc> looks like C<hostname:port>.

As I have not found a way to access response-headers, I cannot find
out the authentication realm (if any) and automagically set the right
headers. You will have to do some bookkeeping for now.

=cut

sub set_realm {
    my( $self, $netloc, $realm ) = @_;
    $netloc or return;
    defined $realm or $realm = "";
    $self->{basic_authentication}{ $netloc }{__active_realm__} = $realm;
}

=head1 INTERNAL-ONLY METHODS

=head2 DESTROY

We need to close the IE-instance, at least when not visible!

=cut

sub DESTROY {
    my $agent = shift->{agent};
    $agent && !$agent->{visible} and $agent->quit;
}

=head2 $ie->_extract_forms()

Return a list of forms using the C<< $ie->Document->forms >>
interface. All forms are mapped onto the L<Win32::IE::Form> interface
that mimics L<HTML::Form>.

=cut

sub _extract_forms {
    my $self = shift;
    my $doc = $self->{agent}->Document;

    my @forms;
    for ( my $i = 0; $i < $doc->forms->length; $i++ ) {
        push @forms, __new_form( $doc->forms( $i ) );
    }
    $self->{forms} = \@forms;

    return wantarray ? @{ $self->{forms} } : $self->{forms};
}

=head2 $self->_extract_links()

The links come from the following:

=over 2

=item "<A HREF=...>"

=item "<AREA HREF=...>"

=item "<FRAME SRC=...>"

=item "<IFRAME SRC=...>"

=back

=cut

sub _extract_links {
    my $self = shift;
    my $doc = $self->{agent}->Document;

    my @links;
    for ( my $i = 0; $i < $doc->all->length; $i++ ) {
        my $obj = $doc->all( $i );
        next unless $obj->tagName =~ /^(?:IFRAME|FRAME|AREA|A)$/i;
        next if lc $obj->tagName eq 'a' && !$obj->href;
        push @links, __new_link( $doc->all( $i ) );
    }
    $self->{links} = \@links;

    return wantarray ? @{ $self->{links} } : $self->{links};
}

=head2 $ie->_extract_images()

Return a list of images using the C<< $ie->Document->images >>
interface. All images are mapped onto the L<Win32::IE::Image> interface
that mimics L<WWW::Mechanize::Images>.

=cut

sub _extract_images {
    my $self = shift;
    my $doc = $self->{agent}->Document;

    my @images;
    for ( my $i = 0; $i < $doc->all->length; $i++ ) {
        my $obj = $doc->all( $i );
        if ( $obj->tagName eq 'IMG' ) {
            push @images, __new_image( $doc->all( $i ) );
	} elsif ( $obj->tagName eq 'INPUT' &&
                  grep /src/i && $obj->{src} => keys %$obj ) {
            push @images, __new_image( $doc->all( $i ) );
	}
    }
    $self->{images} = \@images;

    return wantarray ? @{ $self->{forms} } : $self->{forms};
}

=head2 $self->_wait_while_busy()

This is still a mess, but we need to poll IE to see if it is ready
loading and displaying the page, before we can move on.

=cut

sub _wait_while_busy {
    my $self = shift;
    my $agent = $self->{agent};

    # The documentation isn't clear on this.
    # The DocumentComplete event roughly says:
    # the event gets fired (for each frame) after ReadyState == 4
    # we might need to check if the first one has frames
    # and do some more checking.

#    while ( $agent->{Busy} == 1 ) { $SLEEP and sleep( $SLEEP ) }
#    return unless $agent->{ReadyState};
    while ( $agent->{ReadyState} <= $READYSTATE ) {
        $SLEEP and sleep( $SLEEP );
    }

    $self->{ $_ } = undef for qw( forms cur_form links images );
    return $self->success;
}

=head2 warn( @messages )

Centralized warning method, for diagnostics and non-fatal problems.
Defaults to calling C<CORE::warn>, but may be overridden by setting
C<onwarn> in the construcotr.

=cut

sub warn {
    my $self = shift;

    return unless my $handler = $self->{onwarn};

    return if $self->quiet;

    $handler->(@_);
}

=head2 die( @messages )

Centralized error method.  Defaults to calling C<CORE::die>, but
may be overridden by setting C<onerror> in the constructor.

=cut

sub die {
    my $self = shift;

    return unless my $handler = $self->{onerror};

    $handler->(@_);
}

# Not a method
sub __warn {

    eval "require Carp";
    if ( $@ ) {
        CORE::warn @_;
    } else {
        &Carp::carp;
    }
}

# Not a method
sub __die {
    require Carp;
    &Carp::croak; # pass thru
}

=head2 $self->_extra_headers( )

For the moment we only support B<basic authentication>.

=cut

sub _extra_headers {
    my( $self, $uri ) = @_;

    my $header = "";

    for my $header ( keys %{ $self->{headers} } ) {
        next unless defined $self->{headers}{ $header };
        ( my $hfield = $header ) =~ s/(\w+)/ucfirst lc $1/eg;
        $header .= "$hfield: $self->{headers}{ $header }\015\012";
    }

    my $host_port = $uri->can( 'host_port' )
        ? $uri->host_port : $uri->as_string;
    return $header unless exists $self->{basic_authentication}{ $host_port };

    my $realm = $self->{basic_authentication}{ $host_port }{__active_realm__};
    my( $user, $pass ) = $self->get_basic_credentials( $realm, $uri );

    $header .= defined $user ? __authorization_basic( $user, $pass ) : "";

    return $header;
}

=head1 INTERNAL ONLY NON-METHODS

=head2 __prop_value( $key[, $value] )

Check to see if we support the property C<$key> and return a validated
value or the default value from C<%ie_properties>.

=cut

sub __prop_value($;$) {
    my( $key, $value ) = @_;
    $key = lc $key;
    exists $ie_property{ $key } or return undef;
    @_ > 1 or return $ie_property{ $key }{value};
    CASE: {
        local $_ = $ie_property{ $key }{type};

        /^b$/ and do {
            defined $value or return undef;
            return $value ? 1 : 0;
        };
        /^n$/ and do {
            defined $value or return undef;
            return $value =~ /((?:\+|-)?[0-9]+)/ ? $1 : 0;
        };
    }
}

=head2 __authorization_basic( $user, $pass )

Return a HTTP "Authorization: Basic xxx" header.

=cut

sub __authorization_basic {
    my( $user, $pass ) = @_;
    defined $user && defined $pass or return;

    require MIME::Base64;
    return "Authorization: Basic " .
           MIME::Base64::encode_base64( "$user:$pass" ) .
           "\015\012";
}

=head1 ACCESS TO SUBPACKAGES

These subs just supply an interface to the Win32::IE::* sub objects.

=head2 __new_form( $form_obj )

Retuns a new Win32::IE::Form. NOT a method!

=head2 __new_input( $input_obj )

Retuns a new Win32::IE::Input. NOT a method!

=head2 __new_link( $link_obj )

Retuns a new Win32::IE::Link. NOT a method!

=head2 __new_image( $image_obj )

Retuns a new Win32::IE::Image. NOT a method!

=cut

use Win32::IE::Form;
sub __new_form  { return Win32::IE::Form->new( @_ )  }

use Win32::IE::Input;
sub __new_input { return Win32::IE::Input->new( @_ ) }

use Win32::IE::Link;
sub __new_link  { return Win32::IE::Link->new( @_ )  }

use Win32::IE::Image;
sub __new_image { return Win32::IE::Image->new( @_ ) }

1;

=head1 CAVEATS

The InternetExplorer automation object does not provide an interface
to the options menus. This means that you will need to set all options
needed for this automation before you start. This means that you may
need to set your security settings to a low and possibly unsafe level.

The InternetExplorer automation object does not provide an interface
to "popup windows" generated by security settings or JScript contained
in the page.

The InternetExplorer automation object does not provide an interface
to the content of frames from the toplevel document. This means that
you need to load the frame explicitly (using the follow_link()
method).

The basic authentication support is quite wonky and will only work
with the C<get()> method.

=head1 BUGS

Yes, there are bugs. The test-suite doesn't fully cover the codebase.

=over 4

=item frames

Some reports have come in regarding frames. So far nobody has been
able to provide me with a testcase, so I can't realy "fix" those.

=item forks

Gabor Szabo reported problems with forking and C<use
Win32::IE::Mechanize>. His workaround is to change the "global" C<use
Win32::IE::Mechanize> with localized C<require Win32::IE::Mechanize>
in the child's code.

=item encodings

Gabor Szabo reported problems with pages that use non-standard
encoding. In his case it turns out that somewhere along the line, the
right-to-left hebrew contents are lost.

=back

Please report bugs using L<http://rt.cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright MMIV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
