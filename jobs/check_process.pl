#!/usr/bin/perl

use strict;
use warnings;
use Proc::ProcessTable;

my $table = Proc::ProcessTable->new;
print "\n------------Check process script started---------";

for my $process (@{$table->table}) {
  print "\n",  $process->cmndline;
}
