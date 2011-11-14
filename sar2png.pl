#!/usr/bin/perl
# sar2png - Draws a line chart with data from sar output.
#
# Copyright (C) 2010 Joachim "Joe" Stiegler <blablabla@trullowitsch.de>
#
# This program is free software; you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program;
# if not, see <http://www.gnu.org/licenses/>.
#
# --
#
# Successfully tested on Debian GNU/Linux 5.0 and Sun Solaris 5.10
#
# On Debian GNU/Linux systems you can find the sar utility in the sysstat package
# On Arch GNU/Linux systems the sysstat package is in the community repository
#
# Uses Chart::Lines from CPAN (http://search.cpan.org/~chartgrp/Chart-2.4.1/Chart.pod)
#
# Version: 1.1 - 14.11.2011
# See CHANGELOG for changes

use warnings;
use strict;
use Chart::Lines;
use Getopt::Std;
use Sys::Hostname;
use POSIX;

our ($opt_u, $opt_r, $opt_h, $opt_s, $opt_x, $opt_y, $opt_o, $opt_n);	# The commandline options

my @uname = uname();		# Like uname -a
my $sysname = $uname[0];	# Kind of system (Linux or SunOS)
my $hostname = hostname;	# The system hostname
my @data;		# Array which stores the array references of the usage items (e.g. idle stats)
my @current;	# Temporary data storage
my @input;		# sar output
my @legend;		# Legend labels of the chart
my $height = 320;	# default height of the png
my $width = 480;	# default width of the png
my $sar;		# predefinition only :-)

my @d = localtime(time);	# Time since The Epoch in a 9-element list 
my $year = $d[5] + 1900;
my $month = $d[4] + 1;
my $day = $d[3];

my $file = $hostname."-".$year."-".$month."-".$day.".png";	# Filename of output png

# If month or day are single digits add a 0 to the digit
if (length($month) < 2) {
	$month = "0".$month;
}

if (length($day) < 2) {
	$day = "0".$day;
}

# The usage message
sub usage {
	print "Usage: $0  -u | -r | -n <iface> | [ -s | -x | -y | -o | -h ]\n";
	print " -u: CPU, -r: RAM, -n: NET, -s: skip every x tick, -h: this message\n";
	print " -x: height, -y: width, -o outpath\n\n";
	print "Example; $0 -u -x 480 -y 640 -s 4 -o /home/stats/\n";
	exit (0);
}

# Initialize options or print usage message (also print the usage message if unknown options are given)
if ( (!(getopts("urhs:x:y:o:n:"))) || (defined($opt_h)) ) {
	usage();
}

# Checks if the options argument is digit only
sub is_numeric {
	my $num = shift(@_);
	if ($num =~ /[^\d]/) {
		die $num." is not numeric.\n"; 
	}   
	else {
		return 1;
	}   
}

# Where we can found the sar binary on the system
if ($sysname eq "Linux") {
	$sar = "/usr/bin/sar";
}
elsif ($sysname eq "SunOS") {
	$sar = "/usr/sbin/sar";
}
else {
	die "Your OS wasn't identified\n";
}

sub cpustat {
	@input = `$sar -u`;
	$file = "CPU-".$file;

	if ($sysname eq "Linux") {
		foreach my $line (@input) {
			chomp($line);

			next if ($line =~ /^$|^\D|\D$/);

			@current = split(' ', $line);

			push @{$data[0]}, $current[0];	# time
			push @{$data[1]}, $current[2];	# usr
			push @{$data[2]}, $current[4];	# sys
			push @{$data[3]}, $current[7];	# idle
		}
	}
	elsif ($sysname eq "SunOS") {
		foreach my $line (@input) {
			chomp($line);

			next if ($line =~ /^$|^\D|\D$/);

			@current = split(' ', $line);

			push @{$data[0]}, $current[0];	# time
			push @{$data[1]}, $current[1];	# usr
			push @{$data[2]}, $current[2];	# sys
			push @{$data[3]}, $current[4];	# idle
		}
	}
}

sub ramstat {
	@input = `$sar -r`;
	$file = "RAM-".$file;

	if ($sysname eq "Linux") {
		foreach my $line (@input) {
			chomp($line);

			next if ($line =~ /^$|^\D|\D$/);

			@current = split(' ', $line);

			push @{$data[0]}, $current[0];	# time
			push @{$data[1]}, $current[3];	# mem
			push @{$data[2]}, $current[8];	# swap
		}
	}
	elsif ($sysname eq "SunOS") {
		# You can do the same with 7 lines of code on GNU/Linux :-)

		my $pagesize = `/usr/bin/pagesize`;

		my @prtinput = `/usr/sbin/prtconf`;
		my $memsize;
		my $memfree;
		my $memused;

		my @swapinput = split(' ', `/usr/sbin/swap -s`);
		my $swapsize = $swapinput[1];
		$swapsize =~ tr/[0-9]//cd;
		$swapsize = int($swapsize / (1024 ** 2));	# GByte

		my $swapfree;
		my $swapused;

		my @tmp;

		foreach my $memline (@prtinput) {
			if ($memline =~ /Memory size/) {
				@tmp = split(' ', $memline);
				$memsize = int($tmp[2] / 1024);	# GByte
			}
		}

		foreach my $line (@input) {
			chomp($line);

			next if ($line =~ /^$|^\D|\D$/);

			@current = split(' ', $line);

			$memfree = ($current[1] * $pagesize) / (1024 ** 3);
			$memused = int($memsize - $memfree);
			
			$swapfree = ($current[2] * $pagesize) / (1024 ** 5);
			$swapused = int($swapsize - $swapfree);

			my $memusedpt = int((100 / $memsize) * $memused);

			my $swapusedpt = int((100 / $swapsize) * $swapused);

			push @{$data[0]}, $current[0];	# time
			push @{$data[1]}, $memusedpt;	# mem
			push @{$data[2]}, $swapusedpt;	# swap
		}
	}
}

sub netstat {
	@input = `$sar -n DEV`;
	$file = "$opt_n-".$file;

	if ($sysname eq "Linux") {
		foreach my $line (@input) {
			chomp($line);

			if (($line =~ /$opt_n/) and ($line =~ /^\d/)) {
				@current = split(' ', $line);

				push @{$data[0]}, $current[0];  # time
				push @{$data[1]}, $current[2];  # rxpck/s
				push @{$data[2]}, $current[3];  # txpck/s
				push @{$data[3]}, $current[4];  # rxkB/s
				push @{$data[4]}, $current[5];  # txkB/s
				push @{$data[5]}, $current[6];  # rxcmp/s
				push @{$data[6]}, $current[7];  # txcmp/s
				push @{$data[7]}, $current[8];  # rxmcst/s
			}
		}
	}
	else {
		die "Sorry, net statistics are working only for GNU/Linux at the moment...\n";
	}
}

if (defined($opt_u)) {
	@legend = ('Usr', 'Sys', 'Idle');
	cpustat();
}
elsif (defined($opt_r)) {
	@legend = ('RAM', 'Swap');
	ramstat();
}
elsif (defined($opt_n)) {
	@legend = ('rxpck/s', 'txpck/s', 'rxkB/s', 'txkB/s', 'rxcmp/s', 'txcmp/s', 'rxmcst/s');
	netstat();
}
else {
	usage();
}


if ( (defined($opt_x)) && (defined($opt_y)) ) {
	if ( (is_numeric($opt_x)) && (is_numeric($opt_y)) ) {
		$height = $opt_x;
		$width = $opt_y;
	}
}

my $LineDiagram = Chart::Lines->new($width,$height);

$LineDiagram->set('title' => $hostname.": ".$year."-".$month."-".$day);
$LineDiagram->set('legend' => 'right');
$LineDiagram->set('colors' => { 'background' => [255,255,255], 'text' => [000,000,000], 'grid_lines' => [190,190,190] });
$LineDiagram->set('grid_lines' => 'true');
$LineDiagram->set('x_ticks' => 'vertical');
$LineDiagram->set('brush_size' => 1);
$LineDiagram->set('precision' => 1);
$LineDiagram->set('legend_labels' => \@legend);

if (defined($opt_s)) {
	if (is_numeric($opt_s)) {
		$LineDiagram->set('skip_x_ticks' => $opt_s);
	}
}

if (defined($opt_o)) {
	$file = $opt_o.$file;
}

$LineDiagram->png($file, \@data) or die "Error: $!\n";	# build the png
