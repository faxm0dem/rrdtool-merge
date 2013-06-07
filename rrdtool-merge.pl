#!/usr/bin/perl

#############################################################################
#                                LICENSE                                    #
#                                                                           #
# Copyright (c) 2005 by Ivan Pintori <ivan@pintori.it>                      #
#                                                                           #
# This program is free software; you can redistribute it and/or modify      #
# it under the terms of the GNU General Public License as published by      #
# the Free Software Foundation; either version 2 of the License, or         #
# (at your option) any later version.                                       #
#                                                                           #
# This program is distributed in the hope that it will be useful,           #
# but WITHOUT ANY WARRANTY; without even the implied warranty of            #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
# GNU General Public License for more details.                              #
#                                                                           #
# You should have received a copy of the GNU General Public License         #
# along with this program; if not, write to the Free Software               #
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA #
#############################################################################


use strict;

use Getopt::Long;
use Term::ReadKey;
use RRDx::Merge qw/merge/;

our $VERSION = "0.2";

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#              DEFAULTS
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# defaults for command line options
my %optctl = (
				tmppath    => '/tmp',
			 );


sub printhelp
{
	my (%optctl) = @_;

	print "RRD Merger v0.2 (1 may 2005)\n";
	print "Copyright (c) 2005 by Ivan Pintori <ivan\@pintori.it>\n";
	print "\nUsage: rrdmerger.pl  --oldrrd=<file.rrd> --newrrd=<file.rrd>\n";
	print "                      [--mergedrrd=<file.rrd>] [--tmppath=<directory>]\n";
	print "\nOptions:\n";
	print "  --oldrrd=file.rrd      : old RRD file to merge with new one\n";
	print "  --newrrd=file.rrd      : new RRD file to merge with old one\n";
	print "  --mergedrrd=file.rrd   : resulting file. If not specified will take the\n";
	print "                           name of the new file with added a timestamp\n";
	print "  --tmppath=directory    : directory where to store temporary XML file.\n";
	print "                           Default --> $optctl{tmppath}\n";
	print "\n\nRRD Merger is distributed under the Terms of the GNU General\n";
    print "Public License Version 2. (www.gnu.org/copyleft/gpl.html)\n";
	exit;
}

sub ynquery
{
	my ($question) = @_;
	my $key = "";

	while (!($key =~ /(y|Y|n|N)/))
	{
		print $question;
		ReadMode 4; # Turn off controls keys
		while (not defined ($key = ReadKey(-1)))
		{
			# No key yet
		}
		ReadMode 0; # Reset tty mode before exiting
		print "\n";
	}
	return($key);
}

sub parseargs
{
	my (%options) = @_;

	if (($options{oldrrd}) && (-e ($options{oldrrd})))
	{
		if (($options{newrrd}) && (-e ($options{newrrd})))
		{
			if ($options{mergedrrd})
			{
				if (-e ($options{mergedrrd}))
				{
					if (ynquery("File $options{mergedrrd} exists. Do you want to overwrite it? (Y/N) ") =~ /(n|N)/) {
						exit;
					}
					print "\nOverwriting $options{mergedrrd}\n";
				}
			}
		} else {
			print "Fatal error: missing new RRD file to merge!\n\n";
			printhelp(%options);
			exit;
		}
	} else {
		print "Fatal error: missing old RRD file to merge!\n\n";
		printhelp(%options);
		exit;
	}
}


# Reading command line options
GetOptions(\%optctl, "help", "oldrrd=s", "newrrd=s", "mergedrrd:s", "tmppath:s", );

if ($optctl{help}) {
	printhelp(%optctl);
	exit;
}

parseargs(%optctl);

merge (
	oldrrd => $optctl{oldrrd},
	newrrd => $optctl{newrrd},
	mergedrrd => $optctl{mergedrrd},
);

