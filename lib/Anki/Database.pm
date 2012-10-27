package Anki::Database;
use utf8::all;
use Any::Moose;
use DBI;
# ABSTRACT: interact with your Anki (ankisrs.net) database

use Anki::Database::Field;

has file => (
    is       => 'ro',
    isa      => 'Str',
    default  => sub { $ENV{ANKI2_DECK} },
);

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $dbh = DBI->connect("dbi:SQLite:dbname=" . shift->file);
        $dbh->{sqlite_unicode} = 1;
        $dbh
    },
    handles => ['prepare', 'do'],
);

1;

