#!/usr/bin/perl

#
# Copyright (C) 2017 Joelle Maslak
# All Rights Reserved - See License
#

package Parallel::WorkUnit::Batcher::Command;
use strict;

use Parallel::WorkUnit::Batcher::Boilerplate 'class';

has 'type' => (
    is  => 'rw',
    isa => 'Str',
);

has 'line_number' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

## Please see file perltidy.ERR
has 'options' => (
    is  => 'rw',
    isa => 'HashRef[Str]',
);

__PACKAGE__->meta->make_immutable;

1;

