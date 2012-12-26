package Anki::Database::WithFields;
use utf8::all;
use Any::Moose 'Role';

has fields => (
    is       => 'ro',
    isa      => 'HashRef[Maybe[Str]]',
    required => 1,
);

sub field {
    my ($self, $name) = @_;
    return $self->fields->{$name};
}

around BUILDARGS => sub {
    my $orig = shift;
    my $args = $orig->(@_);

    if (!ref($args->{fields})) {
        my %fields;

        my @keys = @{ $args->{model}->fields };
        my @values = split "\x1f", $args->{fields};

        @fields{@keys} = @values;

        $args->{fields} = \%fields;
    }

    return $args;
};

1;

