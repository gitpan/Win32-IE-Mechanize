package Win32::IE::Form;
use strict;
use warnings;

# $Id: Form.pm 397 2005-08-24 10:43:44Z abeltje $
use vars qw( $VERSION );
$VERSION = '0.005';

=head1 NAME

Win32::IE::Form - Mimic L<HTML::Form>

=head1 SYNOPSIS

    use Win32::OLE;
    use Win32::IE::Form;

    my $agent = Win32::OLE->new( 'InternetExplorer.Application' );
    $agent->Navigate( $uri );

    # extract the images and wrap them as Win32::IE::Image
    my $doc = $agent->Document;
    my @forms;
    for ( my $i=0; $i < $doc->forms->lenght; $i++ ) {
        push @forms, Win32::IE::Form->new( $doc->forms( $i ) );
    }

    # print the information from the forms:
    foreach my $form ( @forms ) {
        printf "%s as %s\n", $form->action, $img->name||"";
    }

=head1 DESCRIPTION

The C<Win32::IE::Form> object is a thin wrapper around the DOM-object
supplied by the InternetExplorer.Application. It is implemented as a
blessed reference to the Win32::OLE-DOM object.

=head1 METHODS

=head2 Win32::IE::Form->new( $form_obj );

Initialize a new object, it is only a ref to a scalar, the rest is
done through the methods.

=cut

sub new {
    my $class = shift;
    
    bless \(my $self = shift), $class;
}

=head2 $form->method( [$new_method] )

Get/Set the I<method> used to submit the from (i.e. B<GET> or
B<POST>).

=cut

sub method {
    my $self = shift;
    my $form = $$self;
    
    $form->{method} = shift if  @_;
    return $form->{method};
}

=head2 $form->action( [$new_action] )

Get/Set the I<action> for submitting the form.

=cut

sub action {
    my $self = shift;
    my $form = $$self;
    
    $form->{action} = shift if @_;
    return $form->{action};
}

=head2 $form->enctype( [$new_enctype] )

Get/Set the I<enctype> of the form.

=cut

sub enctype {
    my $self = shift;
    my $form = $$self;

    $form->{enctype} = shift if @_;
    return $form->{enctype};
}

=head2 $form->attr( $name[, $new_value] )

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

=head2 $form->name()

Return the name of this form.

=cut

sub name {
    my $self = shift;
    my $form = $$self;

    return ref $form->{name} ? $self->attr( 'name' ) : $form->{name};
}

=head2 $form->inputs()

Returns a list of L<Win32::IE::Input> objects. In scalar context it
will return the number of inputs.

=cut

sub inputs {
    my $self = shift;
    my $form = $$self;

    my $ok_tags = join "|", qw( BUTTON INPUT SELECT TEXTAREA );
    my( @inputs, %radio_seen );
    $form->elements->length or return;
    for ( my $i = 0; $i < $form->elements->length; $i++ ) {
        next unless $form->elements( $i );
        next unless grep /tagName/ => keys %{ $form->elements( $i ) };
        next unless $form->elements( $i )->tagName =~ /$ok_tags/i;

        my $hastype = grep /^type$/i => keys %{ $form->elements( $i ) };
        if ( lc( $form->elements( $i )->tagName ) eq 'input' &&
            $hastype                                            &&
            lc( $form->elements( $i )->type    ) eq 'radio' ) {

            $radio_seen{ $form->elements( $i )->name }++ or
                push @inputs, Win32::IE::Input->new($form->elements( $i ));

        } else {
            push @inputs, Win32::IE::Input->new($form->elements( $i ));
        }
    }

    return wantarray ? @inputs : scalar @inputs;
}

=head2 $form->find_input( $name[, $type[, $index]] )

This method is used to locate specific inputs within the form.  All
inputs that match the arguments given are returned.  In scalar context
only the first is returned, or C<undef> if none match.

If $name is specified, then the input must have the indicated name.

If $type is specified, then the input must have the specified type.
The following type names are used: "text", "password", "hidden",
"textarea", "file", "image", "submit", "radio", "checkbox" and "option".

The $index is the sequence number of the input matched where 1 is the
first.  If combined with $name and/or $type then it select the I<n>th
input with the given name and/or type.

(This method is ported from L<HTML::Form>)

=cut

sub find_input {
    my $self = shift;
    my $form = $$self;

    my( $name, $type, $index ) = @_;
    my $typere = qr/.*/;
    $type and $typere = $type =~ /^select/i ? qr/^$type/i : qr/^$type$/i; 

    if ( wantarray ) {
        my( $cnt, @res ) = ( 0 );
        for my $input ( $self->inputs ) {
            if ( defined $name ) {
                $input->name or next;
                $input->name ne $name and next;
            }
            $input->type =~ $typere or next;
            $cnt++;
            $index && $index ne $cnt and next;
            push @res, $input;
        }
        return @res;
    } else {
        $index ||= 1;

        for my $input ( $self->inputs ) {
            if ( defined $name ) {
                $input->name or next;
                $input->name ne $name and next;
            }
            $input->type =~ $typere or next;
            --$index and next;
            return $input;
        }
        return undef;
    }
}

=head2 $form->value( $name[, $new_value] )

Get/Set the value for the input-contol with specified name.

=cut

sub value {
    my $self = shift;
    my $form = $$self;

    my $input = $self->find_input( shift );
    return $input->value( @_ );
}

=head2 $form->submit()

Submit this form.

=cut

sub submit {
    my $self = shift;
    my $form = $$self;

    $form->submit;
}

=head2 $self->_radio_group( $name )

Returns a list of Win32::OLE objects with C<< <input type="radio"
name="$name"> >>.

=cut

sub _radio_group {
    my $self = shift;
    my $form = $$self;

    my $name = shift or return;
    my @rgroup;
    for ( my $i = 0; $i < $form->all->length; $i++ ) {
        next unless $form->all( $i )->tagName =~ /input/i;
        next unless $form->all( $i )->type =~ /radio/i;
        next unless $form->all( $i )->name eq $name;
        push @rgroup, $form->all( $i );
    }

    return wantarray ? @rgroup : \@rgroup;
}

=head1 COPYRIGHT AND LICENSE

Copyright MMIV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
