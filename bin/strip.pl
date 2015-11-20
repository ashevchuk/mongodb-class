#!/usr/bin/env perl

use Perl::Stripper;
use File::Slurp;

my $perl = read_file($ARGV[0]);
die "No input" unless $ARGV[0];

my $stripper = Perl::Stripper->new(
    maintain_linum => 1, # the default, keep line numbers unchanged
    strip_ws       => 1, # the default, strip extra whitespace
    strip_comment  => 1, # the default
    strip_pod      => 1, # the default
    strip_log      => 0, # default is 0, strip Log::Any log statements
);

my $stripped = $stripper->strip($perl);

write_file($ARGV[0], $stripped);
