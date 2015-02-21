#!/usr/bin/env perl
## Fri Feb 10 00:41:24 PST 2010 by epixoip
## shows essential information about network daemons in
## a formatted tree view. it's like pstree for netstat!

use strict 'refs';

my %daemons;
my ($len, $plen, $toffset);

die "error: nstree is for linux!\n" if $^O ne 'linux';
die "error: you are not root.\n" if $<;
die "error: could not run netstat?\n" unless open NETSTAT, 'LC_ALL=C netstat -pant |';

while (defined ($_ = <NETSTAT>))
{
    if (m[^tcp6?\s+[0-9]+\s+[0-9]+\s+(.*)\:([0-9]+)\s+(.*)\:([0-9]+|\*)+\s+([A-Z]+)\s+([0-9]+)/.*$])
    {
        my ($cmd, $euid, $egid);

        open CMDLINE, "/proc/$6/cmdline";
        {
            $cmd = join (' ', split (/\000/, join (' ', <CMDLINE>), 0));
        }
        close CMDLINE;

        open STATUS, "/proc/$6/status";
        {
            while (defined ($_ = <STATUS>))
            {
                $euid = $1 if /^Uid:\s+[0-9]+\s+([0-9]+).*/;
                $egid = $1 if /^Gid:\s+[0-9]+\s+([0-9]+).*/;
            }
        }
        close STATUS;

        if ($5 eq 'LISTEN')
        {
            $daemons{$1}{$2} = { 'args', $cmd, 'pid', $6, 'euid', $euid, 'egid', $egid };
        }
        elsif ($5 eq 'ESTABLISHED')
        {
            if (ref $daemons{$1}{$2} eq 'HASH')
            {
                push @{$daemons{$1}{$2}{'connections'}}, { 'laddr', $1, 'raddr', $3, 'what', $cmd };
            }
            elsif (ref $daemons{'0.0.0.0'}{$2} eq 'HASH')
            {
                push @{$daemons{'0.0.0.0'}{$2}{'connections'}}, { 'laddr', $1, 'raddr', $3, 'what', $cmd };
            }
        }
    }
}

foreach my $addr (keys %daemons)
{
    if (length $addr > $plen)
    {
        $len = length $addr;
    }

    $plen = length $addr;
}

for (my $i = 0; $i <= $len + 1; ++$i)
{
    $toffset = $toffset . ' ';
}

print "\n";

foreach my $addr (sort keys %daemons)
{
    my ($offset, $ioffset);

    $offset = $len - length ($addr);

    for (my $i = 0; $i <= $offset; ++$i)
    {
        $ioffset = $ioffset . '-';
    }

    print "$addr$ioffset-+\n";

    foreach my $port (sort {$a <=> $b} keys %{$daemons{$addr}})
    {
        print "$toffset|-- tcp/$port\n";
        print "$toffset|   |-- cmd: " . $daemons{$addr}{$port}{'args'} . "\n";
        print "$toffset|   |-- pid: " . $daemons{$addr}{$port}{'pid'} . ' (euid=' . $daemons{$addr}{$port}{'euid'} . ', egid=' . $daemons{$addr}{$port}{'egid'} . ")\n";
        print "$toffset|   |-- connections: " . (defined @{$daemons{$addr}{$port}{'connections'};} ? @{$daemons{$addr}{$port}{'connections'}} : '0') . "\n";

        foreach my $conn (@{$daemons{$addr}{$port}{'connections'}})
        {
            print "$toffset|\t   |-- " . ${$conn;}{'raddr'} . ' => ' . ${$conn;}{'laddr'} . ' (' . ${$conn;}{'what'} . ")\n";
        }

        print "$toffset|\n";
    }
}

print "\n\n";

