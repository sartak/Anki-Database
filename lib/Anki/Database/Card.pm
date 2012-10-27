package Anki::Database::Card;
use utf8::all;
use Any::Moose;

with (
    'Anki::Database::WithFields',
    'Anki::Database::WithTags',
);

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has model => (
    is       => 'ro',
    isa      => 'Anki::Database::Model',
    required => 1,
);

has created => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has template => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has type => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);
sub suspended { $_[0] < 2 }

around BUILDARGS => sub {
    my $orig = shift;
    my $args = $orig->(@_);

    $args->{template} = $args->{model}->templates->[$args->{ordinal}];

    return $args;
};

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

