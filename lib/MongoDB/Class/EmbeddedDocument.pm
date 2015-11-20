package MongoDB::Class::EmbeddedDocument;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose::Role;
use namespace::autoclean;


has '_collection' =>
  (is => 'ro', isa => 'MongoDB::Class::Collection', required => 1);


has '_class' => (is => 'ro', isa => 'Str', required => 1);


sub as_hashref {
  my ($self, $hash) = (shift, {});

  foreach my $ha (keys %$self) {
    next if $ha eq '_collection' || $ha eq '_class';
    $hash->{$ha} = $self->{$ha};
  }

  return $hash;
}


sub _database {
  shift->_collection->_database;
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


1;
