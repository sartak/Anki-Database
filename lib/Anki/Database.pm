package Anki::Database;
use utf8::all;
use Any::Moose;
use DBI;
# ABSTRACT: interact with your Anki (ankisrs.net) database

has file => (
    is       => 'ro',
    isa      => 'Str',
    default  => sub { $ENV{ANKI_DECK} },
);

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $dbh = DBI->connect("dbi:SQLite:dbname=" . shift->file);
        $dbh->{sqlite_unicode} = 1;
        $dbh
    },
    handles => {
        prepare => 'prepare_cached',
        do      => 'do',
    },
);

1;

