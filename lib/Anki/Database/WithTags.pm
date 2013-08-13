package Anki::Database::WithTags;
use utf8::all;
use Any::Moose 'Role';

has tags => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    required => 1,
);

has tags_as_hash => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        return { map { $_ => 1 } @{ shift->tags } };
    },
);

sub tags_as_string {
    my ($self) = @_;
    return join ' ', @{ $self->tags };
}

sub has_tag {
    my ($self, $tag) = @_;
    return exists $self->tags_as_hash->{$tag};
}

around BUILDARGS => sub {
    my $orig = shift;
    my $args = $orig->(@_);

    if (!ref($args->{tags})) {
        $args->{tags} = [ split ' ', $args->{tags} ];
    }

    return $args;
};

1;

