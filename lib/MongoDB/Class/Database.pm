package MongoDB::Class::Database;

our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use version;

extends 'MongoDB::Database';

override 'get_collection' => sub {
  MongoDB::Class::Collection->new(_database => shift, name => shift);
};

sub _connection {
  $_[0]->_client;
}

__PACKAGE__->meta->make_immutable;
