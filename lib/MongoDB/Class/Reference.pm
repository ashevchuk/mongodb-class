package MongoDB::Class::Reference;

our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use Carp;

with 'MongoDB::Class::EmbeddedDocument';

has 'ref_coll' => (is => 'ro', isa => 'Str', required => 1);

has 'ref_id' => (is => 'ro', isa => 'MongoDB::OID', required => 1);

sub load {
  my $self = shift;

  return $self->_collection->_database->get_collection($self->ref_coll)
    ->find_one($self->ref_id);
}

__PACKAGE__->meta->make_immutable;
