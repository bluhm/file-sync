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

use constant NAME_MAX => 255;

sub usage {
    print STDERR <<'EOF';
usage: file-recv [-qv] [-D dir] receiver-port
    -D dir  Directory to fill, defaults to current directoy
    -q      be quiet
    -v      be verbose
EOF
    exit(2);
}

my %opts;
getopts("D:qv", \%opts) or usage();
@ARGV == 1 or usage();

if ($opts{D}) {
    chdir $opts{D}
	or die "chdir to '$opts{D}' failed: $!\n";
}

my $ls = IO::Socket::INET->new(
    LocalPort => $ARGV[0],
    Proto     => "tcp",
    Listen    => 1000,
) or die "tcp listen failed: $!\n";
while (1) {
    my $file;
    eval {
	accept(my $s, $ls) or
	    die "accept failed: $!\n";
	my $buf;
	my $len = 0;
	do {
	    my $n = sysread($s, $buf, NAME_MAX + 1 - $len, $len);
	    defined($n) or
		die "read from socket failed: $!\n";
	    $n > 0 or
		die "end of file in file name\n";
	    $len += $n;
	} until $buf =~ s/^(.+)\0//s;
	$file = $1;
	unlink("$file.part");
	open(my $fh, '>', "$file.part") or
	    die "open '$file.part' for writing failed: $!";
	print $fh $buf or
	    die "write buffer to file failed: $!";
	copy($s, $fh) or
	    die "copy socket to file failed: $!\n";
	close($fh) or
	    die "close file failed: $!\n";
	rename("$file.part", $file) or
	    die "rename file to '$file' failed: $!\n";
	close($s) or
	    die "close socket failed: $!\n";
    };
    if ($@) {
	warn $@ unless $opts{q};
	sleep 1;
	next;
    }
    warn "transferred file '$file' successfully\n" if $opts{v};
}