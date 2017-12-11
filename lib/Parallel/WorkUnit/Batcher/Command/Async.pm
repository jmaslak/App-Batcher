#!/usr/bin/perl

#
# Copyright (C) 2017 Joelle Maslak
# All Rights Reserved - See License
#

package Parallel::WorkUnit::Batcher::Command::Async;
use strict;

use Parallel::WorkUnit::Batcher::Boilerplate 'class';

extends 'Parallel::WorkUnit::Batcher::Command';

has '+type' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { 'async' },
);

has 'command_line' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub pool($self) {
    if ( exists( $self->options->{pool} ) ) {
        return $self->options->{pool};
    } else {
        return 'default';
    }
}

__PACKAGE__->meta->make_immutable;

1;

