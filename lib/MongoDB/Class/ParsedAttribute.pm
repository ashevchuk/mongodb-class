package MongoDB::Class::ParsedAttribute;

our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose::Role;
use namespace::autoclean;

requires 'expand';

requires 'collapse';

1;
