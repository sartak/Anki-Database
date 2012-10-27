package Anki::Database::Model;
use utf8::all;
use Any::Moose;

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has fields => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    required => 1,
);

has templates => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    required => 1,
);

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;


