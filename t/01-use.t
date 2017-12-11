#!/usr/bin/perl

#
# Copyright (C) 2017 Joelle Maslak
# All Rights Reserved - See License
#

use Parallel::WorkUnit::Batcher::Boilerplate 'script';

use Test2::V0 0.000096;

MAIN: {
    require Parallel::WorkUnit::Batcher;
    ok(1);
    done_testing;
}

1;


