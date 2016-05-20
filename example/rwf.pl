#!/usr/bin/env perl
use Applify;
use Mojo::IOLoop::ReadWriteFork;

option bool => flush => 'Flush response to screen as soon as possible';

app {
  my ($self, $command, @hosts) = @_;
  my $delay = Mojo::IOLoop->delay;
  my @rwf;

  for my $host (@hosts) {
    $delay->pass($host);
    my $rwf = Mojo::IOLoop::ReadWriteFork->new;
    my $cb  = $delay->begin;
    my $buf = '';

    if ($self->flush) {
      $rwf->on(
        read => sub {
          $buf .= $_[1];
          print "$host: $1\n" while $buf =~ s!^(.*)[\n\r]!!m;
        }
      );
    }
    else {
      $rwf->on(read => sub { $buf .= $_[1] });
    }

    $rwf->on(error => $cb);
    $rwf->on(
      close => sub {
        my ($rwf, $exit_value, $signal) = @_;
        return $rwf->$cb($buf || "Could not execute $command: $exit_value") if $exit_value;
        warn "--- $host\n" unless $self->flush;
        $buf =~ s!\n$!!;
        print $self->flush ? "$host: $buf\n" : "$buf\n" if length $buf;
        $rwf->$cb("");
      }
    );

    $rwf->run(ssh => $host => $command);
    push @rwf, $rwf;
    warn "+++ ssh $host $command\n";
  }

  $delay->wait;

  return 0;
};

=head1 NAME

rwf.pl - Example for running commands on multiple hosts

=head1 SYNOPSIS

  $ rwf.pl [command] [server] <server2> ...
  $ rwf.pl "ls -l /" some.server.com example2.org localhost

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen@cpan.org

=cut
