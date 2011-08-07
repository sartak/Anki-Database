package Anki::Database;
use Any::Moose;
use DBI;
# ABSTRACT: interact with your Anki (ankisrs.net) database

has file => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $dbh = DBI->connect("dbi:SQLite:dbname=" . shift->file);
        $dbh->{sqlite_unicode} = 1;
        $dbh
    },
    handles => ['prepare'],
);

1;

