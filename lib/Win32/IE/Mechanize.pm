package Win32::IE::Mechanize;
use strict;

# $Id: Mechanize.pm 121 2004-03-28 15:33:47Z abeltje $
use vars qw( $VERSION );
$VERSION = '0.004';

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

=head1 Construction and properties

=cut

use URI;
use Win32::OLE;

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
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my $self = {
        agent => Win32::OLE->new( 'InternetExplorer.Application' ),
    };
    my %opt = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();
    $self->{_opt} = { map {
        ( $_ => __prop_value( $_, $opt{ $_ } ) )
    } grep exists $ie_property{ lc $_ } => keys %opt };
    foreach my $prop ( keys %{ $self->{_opt} } ) {
        defined $self->{_opt}{ $prop } and
            $self->{agent}->{ $prop } = $self->{_opt}{ $prop };
    }

    # some more options not for IE
    $self->{ $_ } = exists $opt{ $_ } ? $opt{ $_ } : undef
        for qw( quiet );

    bless $self, $class;
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
        ( $_ => _prop_value( $_, $raw{ $_ } ) )
    } grep exists $ie_property{ lc $_ } => keys %raw;

    foreach my $prop ( keys %opt ) {
        defined $opt{ $prop } and
            $self->{agent}->{ $prop } = $opt{ $prop };
    }
}

=head2 $ie->close

Close the InternetExplorer instance.

=cut

sub close { $_[0]->{agent}->quit; }

=head1 Page-fetching methods

=head2 $ie->get( $url )

Navigate to the C<$url> and wait for it to be loaded.

=cut

sub get {
    my $self = shift;
    my( $url ) = @_;

    $url = (URI->new_abs( $url, $self->uri ))->as_string
        if $self->uri; # && $url !~ m!^(?:https?|ftp)://!;
    $self->{agent}->navigate( $url );
    $self->_wait_while_busy;
}

=head2 $ie->reload()

Use the C<Refresh> method of the IE object.

=cut

sub reload {
     $_[0]->{agent}->Refresh;
     $_[0]->_wait_while_busy;
}

=head2 $ie->back()

Use the C<GoBack> method of the IE object.

=cut

sub back {
    $_[0]->{agent}->GoBack;
    $_[0]->_wait_while_busy;
}

=head1 Link-following methods

=head2 $ie->follow_link( %opt )

Uses the C<< $self->find_link() >> interface to locate a link and C<<
$self->get() >> it.

=cut

sub follow_link {
    my $self = shift;
    
    my $link = $self->find_link( @_ );
    $self->get( $link->url ) if $link;
}

=head1 Form field filling methods

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
    if ( $number <= @{ $self->{forms} } ) {
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

Given the name of a field, set its value to the value specified.  This
applies to the current form (as set by the C<L<form_name()>> or
C<L<form_number()>> method or defaulting to the first form on the page).

The optional I<$index> parameter is used to distinguish between two fields
with the same name. The fields are numbered from 1.

=cut

sub field {
    my $self = shift;

    my( $name, $value, $index ) = @_;
    $self->form_number( 1 ) unless defined $self->{cur_form};
    my @inputs = $self->{cur_form}->find_input( $name );
    $index ||= 1;
    my $control = $inputs[ $index - 1 ];
    defined $value ? $control->value( $value ) : $control->value();
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

    $self->form_number( 1 ) unless defined $self->{cur_form};

    my $form = $self->{cur_form};
    my %opt = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();
    while ( my( $fname, $value ) = each %opt ) {
        if ( ref $value eq 'ARRAY' ) {
            my( $input ) = $form->find_input( $fname, undef, $value->[1] );
            $input->value( $value->[0] );
        } else {
            my( $input ) = $form->find_input( $fname );
            $input->value( $value );
        }
    }
}

=head2 $ie->tick( $name, $value[, $set] )

'Ticks' the first checkbox that has both the name and value assoicated
with it on the current form.  Dies if there is no named check box for
that value.  Passing in a false value as the third optional argument
will cause the checkbox to be unticked.

=cut

sub tick {
    my $self = shift;

    $self->form_number( 1 ) unless defined $self->{cur_form};
    my( $name, $value, $set ) = @_;
    $set = 1 if @_ <= 2;
    my @check_boxes = grep $_->value eq $value
        => $self->{cur_form}->find_input( $name, 'checkbox' );

    $self->warn( "No checkbox '$name'  for value '$value' in form." )
        unless @check_boxes;

    foreach my $check_box ( @check_boxes ) {
        next unless $check_box->value eq $value;
        ${$check_box}->{checked} = $set;
    }
}

=head2 $ie->untick( $name, $value )

Causes the checkbox to be unticked. Shorthand for
C<tick( $name, $value, undef)>

=cut

sub untick {
    my $self = shift;
    $self->tick( @_[0, 1], undef );
}

=head1 Form submission methods

=head2 $ie->click( $button )

Call the click method on an INPUT object with the name C<$button> Has
the effect of clicking a button on a form.  The first argument is the
name of the button to be clicked. I have not found a way to set the
(x,y) coordinates of the click in IE.

=cut

sub click {
    my( $self, $button ) = @_;

    $self->form_number( 1 ) unless defined $self->{cur_form};
    
    my( $toclick ) = sort { 
        ${$a}->{sourceIndex} <=> ${$b}->{sourceIndex} 
    } $self->{cur_form}->find_input( $button, 'button' ),
      $self->{cur_form}->find_input( $button, 'image' ),
      $self->{cur_form}->find_input( $button, 'submit' );

    $toclick and ${$toclick}->click;
    $self->_wait_while_busy;
}

=head2 $ie->submit( )

Submits the page, without specifying a button to click.  Actually,
no button is clicked at all.

This will call the C<Submit()> method of the currently selected form.

=cut

sub submit {
    my $self = shift;

    $self->form_number( 1 ) unless defined $self->{cur_form};

    $self->{cur_form}->submit;
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
        $self->click( $opt{button} );
    } else {
        $self->submit();
    }

    return $self->success;
}

=head1 Status methods

=head2 $ie->success

Return true for ReadyState >= 2;

=cut

sub success { $_[0]->{agent}->ReadyState >= 2 }

=head2 $ie->uri

Return the URI of this document.

=cut

sub uri { $_[0]->{agent}->LocationURL }

=head2 $ie->ct

Fetch the C<mimeType> from the C<< $ie->Document >>. IE does not
return the MIME type in a way we expect.

=cut

sub ct { 
    my $ct = $_[0]->{agent}->Document->mimeType;
    CASE: {
        local $_ = $ct;
        /^HTML Document/i and return "text/html";
        /^(\w+) Image/i   and return "text/\L$1";

        return $_;
    }
}

=head2 $ie->content

Fetch the C<outerHTML> from the C<< $ie->Document->documentElement >>.

I have found no way to get to the exact contents of the document.
This is basically the interpretation of IE of what the HTML looks like
and beware all tags are upcased :(

=cut

sub content { $_[0]->{agent}->Document->documentElement->{outerHTML} }

=head2 $ie->forms

When called in a list context, returns a list of the forms found in the
last fetched page. In a scalar context, returns a reference to an array
with those forms. The forms returned are all C<Win32::IE::Form> objects.

=cut

sub forms {
    my $self = shift;

    defined $self->{forms} or $self->{forms} = $self->_extract_forms;

    return wantarray ? @{ $self->{forms} } : $self->{forms};
}

=head2 $ie->current_form

Returns the current form as an C<Win32::IE::Form> object.

=cut

sub current_form { $_[0]->{curr_form} }

=head2 $ie->links

When called in a list context, returns a list of the links found in
the last fetched page. In a scalar context it returns a reference to
an array with those links. The links returned are all
C<Win32::IE::Link> objects.

=cut

sub links {
    my $self = shift;

    defined $self->{links} or $self->{linkss} = $self->_extract_links;

    return wantarray ? @{ $self->{links} } : $self->{links};
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

=head1 Content-handling methods

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

=item * text => string

Matches the text of the link against I<string>, which must be an
exact match.

To select a link with text that is exactly "download", use

    $a->find_link( text => "download" );

=item * text_regex => regex

Matches the text of the link against I<regex>.

To select a link with text that has "download" anywhere in it,
regardless of case, use

    $a->find_link( text_regex => qr/download/i );

=item * url => string

Matches the URL of the link against I<string>, which must be an
exact match.  This is similar to the C<text> parm.

=item * url_regex => regex

Matches the URL of the link against I<regex>.  This is similar to
the C<text_regex> parm.

=item * n => I<number>

Matches against the I<n>th link.

The C<n> parms can be combined with the C<text*> or C<url*> parms
as a numeric modifier.  For example,
C<< text => "download", n => 3 >> finds the 3rd link which has the
exact text "download".

=back

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

    $self->_extract_links unless defined $self->{links};

    my %opt = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();
    $opt{n} = 1 unless exists $opt{n};
    my $wantall = lc $opt{n} eq 'all';

    foreach my $key ( keys %opt ) {
        my $val = $opt{ $key };
        if ( $key !~ /^(n|(text|url|name|tag)(_regex)?)$/ ) {
            $self->warn( qq{Unknown link-finding parameter "$key"} );
            delete $opt{$key};
            next;
        }

        if ( ($key =~ /_regex$/) && (ref($val) ne "Regexp" ) ) {
            $self->warn( qq{$val passed as $key is not a regex} );
            delete $opt{$key};
            next;
        }
    }

    my $matchfunc = __setup_matchfunc( %opt );

    my( $cnt, @found ) = 0;
    for my $link ( @{ $self->{links} } ) {
        ++$cnt, push @found, $link if $matchfunc->( $link );
        return $link if !$wantall && $cnt >= $opt{n};
    }
    
    return unless $wantall;
    return wantarray ? @found : \@found;
}

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

=head1 Internal-only methods

=head2 $ie->_extract_forms()

Return a list of forms using the C<< $ie->Document->forms >>
interface. All forms are mapped onto the L<Win32::IE::Form> interface
that mimics L<HTML::Form>.

=cut

sub _extract_forms {
    my $self = shift;

    my $doc = $self->{agent}->Document;
    $self->{forms} = undef;
    for ( my $i = 0; $i < $doc->forms->length; $i++ ) {
        push @{ $self->{forms} }, Win32::IE::Form->new( $doc->forms( $i ) );
    }

    return wantarray ? @{ $self->{forms} } : $self->{forms};
}

=head2 $self->_extract_links()

The links come from the following:

=over 0

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
        push @links, Win32::IE::Link->new( $doc->all( $i ) );
    }
    $self->{links} = \@links;
}

=head2 $self->_wait_while_busy()

This is still a mess, but we need to poll IE to see if it is ready
loading and displaying the page, before we can move on.

=cut

sub _wait_while_busy {
    my $self = shift;
    my $agent = $self->{agent};

    my $sleep = 0; # 0.4;
    while ( $agent->{Busy} == 1 ) { $sleep and sleep( $sleep ) }
    return unless $agent->{ReadyState};
    while ( $agent->{ReadyState} != 4 ) { $sleep and sleep( $sleep ) }
    $self->{ $_ } = undef for qw( forms cur_form links );
    return $self->success;
}

=head2 $self->warn( $msg )

Uses Carp::carp as that seems more useful.

=cut

sub warn {
    my $self = shift;
    $self->{quiet} and return;

    eval "require Carp";
    if ( $@ ) {
        warn @_;
    } else {
        &Carp::carp;
    }
}

=head1 Internal only non-methods

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

=head2 __setup_matchfunc( %opt )

Stolen from L<WWW::Mechanize>, but adjusted for the use in this module.

=cut

sub __setup_matchfunc {
    my %opt = @_;
    my @cond;

    push @cond, q/ $_[0]->url  eq $opt{url} /
        if defined $opt{url};
    push @cond, q/ $_[0]->url  =~ $opt{url_regex} /
        if defined $opt{url_regex};
    push @cond, q/ $_[0]->text eq $opt{text} /
        if defined $opt{text};
    push @cond, q/ $_[0]->text =~ $opt{text_regex} /
        if defined $opt{text_regex};
    push @cond, q/ $_[0]->name eq $opt{name} /
        if defined $opt{name};
    push @cond, q/ $_[0]->name =~ $opt{name_regex} /
        if defined $opt{name_regex};
    push @cond, q/ lc $_[0]->tag  eq lc $opt{tag} /
        if defined $opt{tag};
    push @cond, q/ lc $_[0]->tag =~ $opt{tag_regex} /
        if defined $opt{tag_regex};

    {
        local $" = " && ";
        return @cond ? eval "sub { @cond }" : sub { 1 };
    }
}

1;

package Win32::IE::Form;

=head1 PACKAGE

Win32::IE::Form - Like <HTML::Form> but for the IE form object.

=head1 METHODS

=over 4

=item Win32::IE::Form->new( $form_obj );

Initialize a new object, it is only a ref to a scalar, the rest is
done through the methods.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;
    
    bless \(my $self = shift), $class;
}

=item $form->method( [$new_method] )

Get/Set the I<method> used to submit the from (i.e. B<GET> or
B<POST>).

=cut

sub method {
    my $self = shift;
    my $form = $$self;
    
    $form->{method} = shift if  @_;
    return $form->{method};
}

=item $form->action( [$new_action] )

Get/Set the I<action> for submitting the form.

=cut

sub action {
    my $self = shift;
    my $form = $$self;
    
    $form->{action} = shift if @_;
    return $form->{action};
}

=item $form->enctype( [$new_enctype] )

Get/Set the I<enctype> of the form.

=cut

sub enctype {
    my $self = shift;
    my $form = $$self;

    $form->{enctype} = shift if @_;
    return $form->{enctype};
}

=item $form->attr( $name[, $new_value] )

Get/Set any of the attributes from the FORM-tag.

=cut

sub attr {
    my $self = shift;
    my $form = $$self;

    return unless @_;
    my $name = shift;
    my $index = undef;
    for (my $i = 0; $i < $form->attributes->length; $i++ ) {
        next unless $form->attributes( $i )->name eq $name;
        $index = $i;
        last;
    }
    if ( defined $index ) {
        $form->attributes( $index )->{value} = shift if @_;
        return $form->attributes( $index )->{value};
    } else {
        return;
    }
}

=item $form->name()

Return the name of this form.

=cut

sub name {
    my $self = shift;
    my $form = $$self;

    return $form->{name}
}

=item $form->inputs()

Returns a list of L<Win32::IE::Input> objects. In scalar context it
will return the number of inputs.

=cut

sub inputs {
    my $self = shift;
    my $form = $$self;

    my @inputs;
    for ( my $i = 0; $i < $form->all->length; $i++ ) {
        next unless $form->all( $i )->tagName =~ /INPUT|SELECT|TEXTAREA/i;
        push @inputs, Win32::IE::Input->new( $form->all( $i ) );
    }

    return wantarray ? @inputs : scalar @inputs;
}

=item $form->find_input( $name[, $type[, $index]] )

See L<HTML::Form::find_input>

=cut

sub find_input {
    my $self = shift;
    my $form = $$self;

    my( $name, $type, $index ) = @_;

    my @inputs = $self->inputs;
    return $inputs[ $index - 1 ] if defined $index && $index > 0;
    @inputs = grep $_->name && $_->name eq $name && 
                   ( !$type || ( lc( $_->type ) eq lc( $type ) ) ) => @inputs;

    return wantarray ? @inputs : $inputs[0];
}

=item $form->value( $name[, $new_value] )

Get/Set the value for the input-contol with spcified name.

=cut

sub value {
    my $self = shift;
    my $form = $$self;

    my $input = $self->find_input( shift );
    return $input->value( @_ );
}

=item $form->submit()

Submit this form.

=cut

sub submit {
    my $self = shift;
    my $form = $$self;

    $form->submit;
}

=back

=cut

package Win32::IE::Input;

=head1 PACKAGE

Win32::IE::Input - A small class to interface with the IE input objects.

=head1 METHODS

=over 4

=item Win32::IE::Input->new( $ie_input )

Initialize a new object (like L<Win32::IE::Form>).

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    bless \(my $self = shift), $class;
}

=item $input->name

Return the input-control name.

=cut

sub name { return ${ $_[0] }->name; }

=item $input->type

Return the type of the input control.

=cut

sub type { return ${ $_[0] }->type; }

=item $input->value( [$value] )

Get/Set the value of the input control.

=cut

sub value {
    my $self = shift;
    my $input = $$self;

    $input->{value} = shift if @_ && defined $_[0];
    return $input->{value};
}

=back

=head1 PACKAGE

Win32::IE::Link - A bit like WWW::Mechanize::Link

=cut

package Win32::IE::Link;

=head1 METHODS

=over 4

=item Win32::IE::Link->new( $element )

C<$element> is Win32::OLE object with a C<tagName()> of B<IFRAME>,
B<FRAME>, <AREA> or <A>.

B<Note>: Although it supports the same methods as
C<L<WWW::Mechanize::Link>> it is a completely different
implementation.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    bless \( my $self = shift ), $class;
}

sub url {
    my $self = ${ $_[0] };

    if ( $self->{tagName} =~ /^IFRAME|FRAME$/ ) {
        return $self->{src};
    } else {
        return $self->{href};
    }
}

sub name {
    my $self = ${ $_[0] };
    return scalar( grep lc( $_ ) eq 'name' => keys %$self )
        ? defined $self->{name} ? $self->{name} : '' : '';
}

sub tag {
    my $self = ${ $_[0] };
    return $self->{tagName};
}

sub text {
    my $self = ${ $_[0] };
    return defined $self->{innerHTML} ? $self->innerHTML : '';
}

=back

=head1 COPYRIGHT

Copyright 2003, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
