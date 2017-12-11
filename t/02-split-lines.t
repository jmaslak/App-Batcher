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
            input => 'ABC "abc',
            output => qr/double quoted string not terminated/ims,
            expected => 'dies',
            comment => "Test unclosed double quote",
        },
        {
            input => "ABC \"\\",
            output => qr/escape character not followed by a character/ims,
            expected => 'dies',
            comment => "Test bad escape character",
        },
        {
            input => "ABC \"a\"",
            output => [
                'ABC',
                'a'
            ],
            expected => 'compare',
            comment => "Testing quoted string",
        },
        {
            input => "ABC \"\\a\"",
            output => qr/unknown character following escape character/ims,
            expected => 'dies',
            comment => "Test bad escape character",
        },
        {
            input => 'ABC FOO="ABC DEF" ::ls /dev',
            output => [
                'ABC',
                'FOO=ABC DEF',
                'ls /dev',
            ],
            expected => 'compare',
            comment => "example in manpage",
        },
        {
            input => '',
            output => [ ],
            expected => 'compare',
            comment => "blank line",
        },
    );

    foreach my $test (@tests) {
        if ($test->{expected} eq 'compare') {
            my (@r) = $batcher->split_line(1, $test->{input});
            is(\@r, $test->{output}, "Parsing good line: ".$test->{comment});
        } elsif ($test->{expected} eq 'dies') {
            my $exception = dies { $batcher->split_line(1, $test->{input}) };
            like($exception, $test->{output}, "Parsing bad line: ".$test->{comment});
        } else {
            die("Unknown test type: " . $test->{expected});
        }
    }

    done_testing;
}

1;


