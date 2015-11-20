package MongoDB::Class::ConnectionPool;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose::Role;
use namespace::autoclean;
use Carp;


has 'max_conns' => (
  is      => 'ro',
  isa     => 'Int',
  default => 100,
);

has 'pool' => (
  is      => 'ro',
  isa     => 'ArrayRef[MongoDB::Class::Connection]',
  writer  => '_set_pool',
  default => sub { [] },
);

has 'num_used' => (
  is      => 'ro',
  isa     => 'Int',
  writer  => '_set_used',
  default => 0,
);

has 'params' => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
);


requires 'get_conn';
requires 'return_conn';


sub _get_new_conn {
  my $self = shift;

  my $conn = MongoDB::Class::Connection->new(%{$self->params});
  $self->_inc_used;
  return $conn;
}


sub _inc_used {
  my ($self, $int) = @_;

  $int ||= 1;
  $self->_set_used($self->num_used + $int);
}


sub _add_to_pool {
  my ($self, $conn) = @_;

  my $pool = $self->pool;
  push(@$pool, $conn);
  $self->_set_pool($pool);
}


1;
