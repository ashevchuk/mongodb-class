#!/usr/bin/env perl

use lib "../lib";

use MongoDB::Class;
use Data::Dumper qw(Dumper);

my $dbx = MongoDB::Class->new(namespace => 'MyApp::Model::DB');

my $conn = $dbx->connect(host => 'localhost', port => 27017);

my $db = $conn->get_database('auth');

#my @persons = $db->get_collection('users')->find({});

#print Dumper(\@persons);
