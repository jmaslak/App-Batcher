#!/usr/bin/perl

#
# Copyright (C) 2017 Joelle Maslak
# All Rights Reserved - See License
#

use Parallel::WorkUnit::Batcher::Boilerplate 'script';

use Test2::V0 0.000096;

MAIN: {
    require Parallel::WorkUnit::Batcher;
    my $batcher = Parallel::WorkUnit::Batcher->new();

    my (@tests) = (
        {
            input => 'ABC DEF',
            tokens => [
                'ABC',
                'DEF',
            ],
            options => { },
            expected => 'compare',
            comment => "Zero options",
        },
        {
            input => 'ABC A=abc',
            tokens => [
                'ABC',
            ],
            options => {
                A => 'abc',
            },
            expected => 'compare',
            comment => "Single option",
        },
        {
            input => 'ABC A=abc B=def C=ghi XYZ',
            tokens => [
                'ABC',
                'XYZ',
            ],
            options => {
                A => 'abc',
                B => 'def',
                C => 'ghi',
            },
            expected => 'compare',
            comment => "Three options",
        },
        {
            input => 'ABC=1 ABC=2',
            output => qr/option defined more than once/ims,
            expected => 'dies',
            comment => "Test same param appears twice",
        },
    );

    foreach my $test (@tests) {
        if ($test->{expected} eq 'compare') {
            my (@tokens) = $batcher->split_line(1, $test->{input});
            my $r = $batcher->parse_options(1, \@tokens);

            is(\@tokens, $test->{tokens}, "Parsing good line, tokens: ".$test->{comment});
            is($r, $test->{options}, "Parsing good line, options: ".$test->{comment});
        } elsif ($test->{expected} eq 'dies') {
            my (@tokens) = $batcher->split_line(1, $test->{input});
            my $r = dies { $batcher->parse_options(1, \@tokens) };

            like($r, $test->{output}, "Parsing bad line, options: ".$test->{comment});
        } else {
            die("Unknown test type: " . $test->{expected});
        }
    }

    done_testing;
}

1;


