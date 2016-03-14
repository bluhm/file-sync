#!/usr/bin/perl

# Copyright (c) 2016 Alexander Bluhm <bluhm@genua.de>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
use File::Copy;
use Getopt::Std;
use IO::Socket::INET;

sub usage {
    print STDERR <<'EOF';
usage: file-send [-qv] -D dir receiver-addr receiver-port
    -D dir  Directory to scan
    -q      be quiet
    -v      be verbose
EOF
    exit(2);
}

my %opts;
getopts("D:qv", \%opts) or usage();
@ARGV == 2 or usage();

$opts{D} or
    die "no working directory given\n";
chdir $opts{D}
    or die "chdir to '$opts{D}' failed: $!\n";

$SIG{PIPE} = 'IGNORE';

while (1) {
    foreach my $file (<*>) {
	# Do not print untrusted characters in error messages.
	(my $filename = $file) =~ s,[^\w./_-],_,g;
	next if $file =~ /\.part$/;
	eval {
	    -f $file or
		die "ignoring non regular file '$filename'\n";
	    open(my $fh, '<', $file) or
		die "open '$filename' for reading failed: $!\n";
	    my $s = IO::Socket::INET->new(
		PeerAddr => $ARGV[0],
		PeerPort => $ARGV[1],
		Proto    => "tcp",
	    ) or die "tcp connect to @ARGV failed: $!\n";
	    setsockopt($s, SOL_SOCKET, SO_KEEPALIVE, 1) or
		die "set socket keepalive failed: $!";
	    select($s);
	    $| = 1;
	    print $s "$file\0" or
		die "write file name to socket failed: $!\n";
	    copy($fh, $s) or
		die "copy file to socket failed: $!\n";
	    close($fh) or
		die "close file failed: $!\n";
	    shutdown($s, 1) or
		die "shutdown write to socket failed: $!\n";
	    defined sysread($s, my $buf, 1) or
		die "transfer file '$filename' failed\n";
	    close($s) or
		die "close socket failed: $!\n";
	};
	if ($@) {
	    warn $@ unless $opts{q};
	    next;
	}
	warn "transferred file '$filename' successfully\n" if $opts{v};
	unlink($file) || $opts{q} or
	    warn "remove '$filename' failed: $!\n";
    }
    sleep 1;
}
