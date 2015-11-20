package MongoDB::Class::Document;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose::Role;
use namespace::autoclean;
use Carp;


has '_id' => (is => 'ro', isa => 'MongoDB::OID', required => 1);

has '_collection' =>
  (is => 'ro', isa => 'MongoDB::Class::Collection', required => 1);

has '_class' => (is => 'ro', isa => 'Str', required => 1);


sub id {
  shift->_id->to_string;
}

sub oid {
  shift->id;
}


sub update {
  my $self = shift;

  if (scalar @_ && ref $_[0] eq 'HASH') {
    $_[0]->{_class} = $self->_class;
    my $doc = $self->_connection->collapse($_[0]);
    delete $doc->{_class};


    my $ret =
      $self->_collection->update({_id => $self->_id}, {'$set' => $doc},
      $_[1]);


    $self->_update_self;

    return $ret;
  }
  else {
    my $doc = {_class => $self->_class};
    foreach ($self->meta->get_all_attributes) {
      my $name = $_->name;
      next if $name eq '_collection' || $name eq '_class';
      my $val = $self->$name;
      next unless defined $val;

      $name =~ s/^_//
        if (
           $_->{isa} eq 'MongoDB::Class::CoercedReference'
        || $_->{isa} eq 'ArrayOfMongoDB::Class::CoercedReference'
        || ( $_->documentation
          && $_->documentation eq 'MongoDB::Class::EmbeddedDocument')
        );

      $doc->{$name} = $val;
    }
    return $self->_collection->update({_id => $self->_id},
      $self->_connection->collapse($doc), $_[1]);
  }
}


sub delete {
  my $self = shift;

  $self->_collection->remove({_id => $self->_id});
}

sub remove { shift->delete }


sub _database {
  shift->_collection->_database;
}


sub _connection {
  shift->_database->_connection;
}


sub _attributes {
  my @names;
  foreach (shift->meta->get_all_attributes) {
    next if $_->name =~ m/^_(class|collection)$/;
    if (
      $_->{isa} =~ m/MongoDB::Class::CoercedReference/
      || ( $_->documentation
        && $_->documentation eq 'MongoDB::Class::EmbeddedDocument')
      )
    {
      my $name = $_->name;
      $name =~ s/^_//;
      push(@names, $name);
    }
    else {
      push(@names, $_->name);
    }
  }

  return sort @names;
}


sub _update_self {
  my $self = shift;

  my $new_version = $self->_collection->find_one({_id => $self->_id});
  unless ($new_version) {

    carp
      "Can't find document after update, object instance will remain unchanged.";
    return;
  }

  foreach ($self->meta->get_all_attributes) {
    my $new_val = $_->get_value($new_version);
    $_->set_value($self, $new_val) if defined $new_val;
  }
}


1;
