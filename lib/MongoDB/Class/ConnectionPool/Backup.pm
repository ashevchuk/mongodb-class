package MongoDB::Class::ConnectionPool::Backup;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use Carp;

with 'MongoDB::Class::ConnectionPool';


has 'backup_conn' => (
  is     => 'ro',
  isa    => 'MongoDB::Class::Connection',
  writer => '_set_backup',
);


sub get_conn {
  my $self = shift;


  if (scalar @{$self->pool}) {
    return $self->_take_from_pool;
  }


  if ($self->num_used < $self->max_conns) {

    return $self->_get_new_conn;
  }


  return $self->backup_conn;
}


sub return_conn {
  my ($self, $conn) = @_;


  return if $conn->is_backup;


  if (scalar @{$self->pool} + $self->num_used - 1 < $self->max_conns) {
    $self->_add_to_pool($conn);
    $self->_inc_used(-1);
  }
}


sub BUILD {
  my $self = shift;

  my %params = %{$self->params};
  $params{is_backup} = 1;
  $self->_set_backup(MongoDB::Class::Connection->new(%params));
}

sub _take_from_pool {
  my $self = shift;

  my $pool = $self->pool;
  my $conn = shift @$pool;
  $self->_set_pool($pool);
  $self->_inc_used;
  return $conn;
}

around 'get_conn' => sub {
  my ($orig, $self) = @_;

  return $self->$orig || $self->backup_conn;
};


__PACKAGE__->meta->make_immutable;
