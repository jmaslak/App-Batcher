#!/usr/bin/perl

#
# Copyright (C) 2017 Joelle Maslak
# All Rights Reserved - See License
#

package Parallel::WorkUnit::Batcher;
use strict;

use Parallel::WorkUnit;
use Parallel::WorkUnit::Batcher::Command::Async;

use Parallel::WorkUnit::Batcher::Boilerplate 'class';

has debug => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has 'number_lines' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'commands' => (
    is      => 'rw',
    isa     => 'ArrayRef[Parallel::WorkUnit::Batcher::Command]',
    default => sub { [] },
);

has 'wu' => (
    is      => 'rw',
    isa     => 'HashRef[Parallel::WorkUnit]',
    default => sub {
        return { default => Parallel::WorkUnit->new() },;
    },
);

sub run($self) {
    my $task_config = $self->read_task_config();

    foreach my $command ( $self->commands->@* ) {
        if ( $command->type eq 'async' ) {
            $self->exec_async($command);
        } else {
            my $line = $command->{line};
            $self->ABORT( "Line $line - unknown type for command: ",
                $command->line_number, $command->type );
        }
    }

    foreach my $wu ( keys $self->wu->%* ) {
        $self->wu->{$wu}->waitall();
    }

    return;
}

sub read_task_config($self) {

    my $line;
    while ( $line = <<>> ) {

        chomp $line;
        $line =~ s/ ^ \s+ //gismxx;
        $line =~ s/ \s+ $ //gismxx;

        $self->number_lines( $self->number_lines + 1 );

        # /i = case insensitive
        # /s = treat as a single line
        # /m = . match newline
        # /n = ignore captures
        # /xx = pretty
        if ( $line !~ m/ ^ \S+ \b /ismnxx ) {
            $self->ABORT( "Line ", $self->number_lines, ": improperly formatted line" );
        }

        my (@args) = $self->split_line( $self->number_lines, $line );

        my $command = '';
        if (@args) { $command = fc( shift @args ); }

        if ( $command eq '' ) {
            # Blank line, skip
        } elsif ( $command eq 'async' ) {
            # We parse options
            if ( !scalar(@args) ) {
                $self->ABORT( "Line ", $self->number_lines, ": No command line provided" );
            }
            my $cmdline = pop(@args);

            my $options = $self->parse_options( $self->number_lines, \@args );
            if ( scalar(@args) ) {
                $self->ABORT( "Line ", $self->number_lines,
                    ": Must not have more than one command on line" );
            }

            # Don't read any more batch file
            my $cmd = Parallel::WorkUnit::Batcher::Command::Async->new(
                line_number  => $self->number_lines,
                command_line => $cmdline,
                options      => $options,
            );
            push $self->commands->@*, $cmd;
        } elsif ( $command eq 'done' ) {
            # Don't read any more batch file
            $self->DEBUG("encountered 'done', skipping rest of batch file");
            last;
        } elsif ( $command eq 'newpool' ) {
            if ( scalar(@args) != 1 ) {
                $self->ABORT( "Line ", $self->number_lines, ": Must provide pool name" );
            }
            if ( defined( $self->wu->{ $args[0] } ) ) {
                $self->ABORT( "Line ", $self->number_lines, ": Pool (", $args[0],
                    ") already exists" );
            }
            $self->wu->{ $args[0] } = Parallel::WorkUnit->new();
        } elsif ( $command eq 'noop' ) {
            # No Operation
        } elsif ( $command eq 'rem' ) {
            # Remark, skip line
        } else {
            $self->ABORT( "Line ", $self->number_lines, ": Unknown command: $command" );
        }
    }

    $self->DEBUG("done reading batch file");

    return;
}

=method split_line

    my (@parts) = $self->split_line($line_number, $line);

Takes an input line and splits the line into parts.

There should be no line breaks in the line passed in as C<$line>.

The line number is used for diagnostics that are thrown.

Leading and trailing whitespace is removed.

Each line is split appart in two ways.  At first, the line is split at
whitespace boundaries, where the whitespace is not within a quoted string.
Within a double quoted string, two escape codes are recognized:

  \\  Escaping a backslash
  \"  Escaping double quotes

If, outside of a quoted string, two colons (C<::>) are found, preceeded by
whitespace, everything following the collons is consider a single part and
is returned as a unit.

An example:

  ABC FOO="ABC DEF" ::ls /dev

Returns:

  ABC
  FOO=ABC DEF
  ls /dev

=cut

sub split_line ( $self, $line_number, $line ) {
    $line =~ s/ ^ \s+ //gismxx;
    $line =~ s/ \s+ $ //gismxx;

    my @tokens;

    my (@chars) = split //, $line;
    my $token = "";
    my $quote_flag;
    my $backslash_flag;
    my $doublecolon_flag;
    foreach my $char (@chars) {
        if ($doublecolon_flag) {
            # We are in a double colon string
            $token .= $char;
            next;    # Don't process any more.
        } elsif ($backslash_flag) {
            # Last character is a backslash
            if ( $char eq "\\" ) {
                # We are happy with contents of char
                $backslash_flag = undef;
            } elsif ( $char eq "\"" ) {
                # We are also happy with contents of char
                $backslash_flag = undef;
            } else {
                $self->ABORT("Line ${line_number}: Unknown character following escape character");
            }
        } elsif ($quote_flag) {
            if ( $char eq "\\" ) {
                $backslash_flag = 1;
                next;    # We don't process this, we need the next character.
            } elsif ( $char eq "\"" ) {
                # End of quoted section
                $quote_flag = undef;
                next;    # Next character!
            }
        } elsif ( $char eq "\"" ) {
            # Begin quoted section
            $quote_flag = 1;
            next;        # Start of quoted string, we don't process this
        } elsif ( $char =~ m/ ^ \s $ /msxx ) {
            # New token
            if ( $token ne "" ) {
                # We have a good token
                push @tokens, $token;
                $token = "";
                next;    # Go to next token
            }
        } elsif ( ( $token eq ':' ) && ( $char eq ':' ) ) {
            # We know we aren't in a quote of any type
            $token            = "";
            $doublecolon_flag = 1;
            next;        # Next character, please!
        }

        $token .= $char;
    }
    if ($backslash_flag) {
        $self->ABORT("Line ${line_number}: Escape character not followed by a character");
    }
    if ($quote_flag) {
        $self->ABORT("Line ${line_number}: Double quoted string not terminated");
    }

    if ( $token ne "" ) {
        # Add remaining token to token list.
        push @tokens, $token;
    }

    return @tokens;
}

=method parse_options() {

    my $options = $self->parse_options($line_number, $tokens);

Takes token reference (from the tokens passed back from C<split_line>),
and removes tokens that representing options, returning them as a hash
reference.

The C<$line_number> parameter is used for debugging output.

Options are defined as word characters (I.E. character class C<\w>)
followed by an equal sign (C<=>), followed by zero or more characters.
The piece before the first equal sign is the variable name, while the
piece after the first equal sign is the value.

An example, the tokens:

  ABC
  FOO=ABC DEF
  ls /dev

Returns:

  { FOO => 'ABC DEF' }

It also replaces the tokens with:

  ABC
  ls /dev

Note that this modifies the value passed in as C<$tokens>, removing the
tokens taht represent values.

=cut

sub parse_options ( $self, $line_number, $tokens ) {
    my @new_tokens;
    my %options;

    foreach my $token (@$tokens) {
        if ( $token =~ m/^ (\w*) \= (.*) $/msxx ) {
            my ( $option, $value ) = $token =~ m/ ^ (\w*) \= (.*) $ /msxx;
            if ( defined( $options{$option} ) ) {
                $self->ABORT( "Line ", $line_number, ": Option defined more than once (",
                    $option, ")" );
            }
            $options{$option} = $value;
        } else {
            push @new_tokens, $token;
        }
    }

    (@$tokens) = @new_tokens;
    return \%options;
}

sub exec_async ( $self, $command ) {
    if ( !exists( $self->wu->{ $command->pool() } ) ) {
        $self->ABORT( "Pool doesn't exist: " . $command->pool() );
    }
    my $wu = $self->wu->{ $command->pool() };

    $self->DEBUG( "queuing (queue: ", $command->pool(), ") command: ", $command->command_line );
    $wu->queue( sub() { $self->do_system( $command->command_line ); }, sub($r) { }, );

    return;
}

sub do_system ( $self, $command ) {
    return system($command);
}

sub ABORT ( $self, @args ) {
    $self->logit( "ABORT", @args );
    return; # Not reached, but to satisfy Critic
}

sub DEBUG ( $self, @args ) {
    if ( !$self->debug ) { return; }

    $self->logit( "DEBUG", @args );
    return;
}

sub logit ( $self, $type, @args ) {
    if ( $type eq 'ABORT' ) {
        die( join( '', $type, ': ', @args, "\n" ) );
    } else {
        say $type, ': ', @args;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;

