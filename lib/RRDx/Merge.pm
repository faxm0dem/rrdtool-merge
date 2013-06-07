#!/usr/bin/perl

package RRDx::Merge;

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

use XML::Twig;
use Getopt::Long;
use Term::ReadKey;
use RRDs qw/dump/;
use POSIX ":sys_wait_h";
use Carp;

use vars qw/@ISA @EXPORT_OK/;
use Exporter;
push @ISA, qw/Exporter/;

@EXPORT_OK = qw/merge/;

our $VERSION = "0.2";

sub capture_stdout (&) {
	my $pid;

	# fork callback
	my $handle;
	unless ($pid = open $handle, "-|") {
	  die "Can't fork: $!" unless defined $pid;
	  shift->();
	  exit 0;
	}

	#waitpid ($pid,0); # this hangs (RRDs probably does the call already)
	while (waitpid(-1, &WNOHANG) > 0) {
		sleep 1;
	}
	return $handle;
}

sub getdate
{
	my ($line) = @_;

#    print "$line\n";
	if ($line =~ /^\s*<!-- \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} (\w{4}|\w{3}) \/ (\d{10}) -->/) {
		return ($2);
	} else {
		return (-1);
	}
}



sub rra
{
	my ($twig, $new_rra, $old_twig) = @_;

	print "Start processing Round Robin DB\n";
	my $cf          = $new_rra->first_child( 'cf' )->text;
	my $pdp_per_row = $new_rra->first_child( 'pdp_per_row' )->text;
	my $xff         = $new_rra->first_child_text( 'xff' );

	print "  CF         : $cf\n";
	print "  Pdp x Row  : $pdp_per_row\n";

	my $cdp_prep    = $new_rra->first_child( 'cdp_prep' );
	my $ds          = $cdp_prep->first_child( 'ds' );
	my $ds_value    = $ds->first_child( 'value' )->text;
	my $ds_unkdatap = $ds->first_child( 'unknown_datapoints' )->text;

	$old_twig = $old_twig->first_child;
	while ( $old_twig )
	{
		if ($old_twig->tag =~ /rra/) {
			my $old_rra = $old_twig->first_child;
			my $cfOK;
			my $pdp_per_rowOK;
			my $done_rra;
			while ($old_rra && !($done_rra))
			{
				if (($old_rra->tag =~ /cf/) && ($old_rra->text =~ /$cf/)) {
					$cfOK = 1;
				}
				if (($old_rra->tag =~ /pdp_per_row/) && ($old_rra->text =~ /$pdp_per_row/)) {
					$pdp_per_rowOK = 1;
				}
				if (($cfOK && $pdp_per_rowOK) && ($old_rra->tag =~ /xff/)) {
					$old_rra->set_text ( $xff );
				}
				if (($cfOK && $pdp_per_rowOK) && ($old_rra->tag =~ /cdp_prep/)) {
					my $old_ds = $old_rra->first_child;
					while ($old_ds)
					{
						if ($old_ds->tag =~ /value/) {
							$old_ds->set_text( $ds_value );
						}
						$old_ds = $old_ds->next_sibling;
					}
				}
				if (($cfOK && $pdp_per_rowOK) && ($old_rra->tag =~ /database/)) {
					print "    Start processing DB rows\n";
# I am positioning at the start of the Rows DB in the new RRA
					my $database = $new_rra->first_child( 'database' );
					my $row = $database->first_child( 'row' );
# I am positioning at the end of the Rows DB in the OLD RRA
					my $old_row = $old_rra->last_child( 'row' );
					my $time = getdate($old_row->extra_data);
					while ($row)
					{
						if ($time < getdate($row->extra_data)) {
# Set new row to merge
							my $newrow   = new XML::Twig::Elt( 'row' );   # create the row
 							$newrow = $newrow->set_extra_data ( $row->extra_data );
							my $newvalue = new XML::Twig::Elt( 'v', $row->first_child( 'v' )->text );    # create the value
 							my $parent_row = $old_row->parent;
							$newrow->paste ( 'last_child', $parent_row );
							$newvalue->paste ( 'last_child', $parent_row->last_child( 'row' ) );
# FIFO: Oldest (first) row gets pushed out
							$parent_row->first_child( 'row' )->delete;
						}
						$row = $row->next_sibling;
					}
					print "    Finished processing DB rows\n";
					$done_rra = 1;
				}
 				$old_rra = $old_rra->next_sibling;
			}
		}
		$old_twig = $old_twig->next_sibling;
    }
	return;
}


sub lastupdate
{
	my ($twig, $lastupdate, $old_twig) = @_;

	print "Last Update: " . $lastupdate->text . "\n";

	$old_twig = $old_twig->first_child('lastupdate');
	if ($old_twig->tag =~ /lastupdate/) {
		$old_twig->set_text($lastupdate->text);
	}
}


sub rrd
{
	my ($twig, $rrd, $old_twig) = @_;

	print "Start processing header\n";

	$old_twig = $old_twig->first_child ( 'ds' );
	$rrd = $rrd->first_child ( 'ds' );
	print "DB Service Name: " . $rrd->first_child( 'name' )->text . "\n";
	$old_twig->set_extra_data( $rrd->extra_data );
	$old_twig = $old_twig->first_child;
	while ( $old_twig )
	{
		my $twigtag = $old_twig->tag;
		my $tempdstext = $rrd->first_child ( $twigtag )->text;
		if ( !($tempdstext =~ /NaN/) ) {
			$old_twig->set_text( $tempdstext );
		}
		$old_twig = $old_twig->next_sibling;
	}
	print "Finished updating header\n";
 }

sub merge
{
	my %optctl;
	if (@_ % 2) {
		croak 'Usage: merge(%hash)';
		return;
	}
	%optctl = @_;

	# validate parameters
	$optctl{tmppath} ||= $ENV{TMPDIR} || "/tmp";

	# Set timer
	my $timer = time();

	# Dump oldrrd in XML
	$optctl{oldrrd} =~ /([a-zA-Z0-9\_\-\. ]*)$/;

	my $old_xml_fh = capture_stdout { RRDs::dump ($optctl{oldrrd}) };

	# Dump newrrd in XML
	$optctl{newrrd} =~ /([a-zA-Z0-9\_\-\. ]*)$/;

	my $new_xml_fh = capture_stdout { RRDs::dump $optctl{newrrd} };

	# Parsing old XML in memory
	print "Parsing $optctl{oldrrd} XML...";
	my $old_twig = new XML::Twig;
	$old_twig -> parse($old_xml_fh);

	print "...parsing completed\n";

	# Parsing new XML and create a merged version
	print "Parsing $optctl{newrrd} XML...\n";
	my $twig = new XML::Twig
	( TwigHandlers =>
		{
			rrd        => sub { rrd        (@_, $old_twig->root) },
			lastupdate => sub { lastupdate (@_, $old_twig->root) },
			rra        => sub { rra        (@_, $old_twig->root) }
		}
	);
	$twig->parse($new_xml_fh);
	print "...parsing completed\n";

	# Writing merged XML on to disk
	$old_twig->set_pretty_print( 'indented');
	print "Outputing to $optctl{mergedrrd}\n";
	$optctl{mergedrrd} =~ /([a-zA-Z0-9\_\-\. ]*)$/;
	my $temp_xml = "$optctl{tmppath}/$1_merged_$$.xml";
	open TEMPXML, ">", $temp_xml or die;
	$old_twig->print ( \*TEMPXML );
	close TEMPXML;

	# Restore merged XML in RRD
	if (-e $optctl{mergedrrd})
	{
		unlink $optctl{mergedrrd};
	}
	print "Restoring from XML to RRD: $optctl{mergedrrd}\n";
	RRDs::restore $temp_xml, $optctl{mergedrrd};

	# Delete xml file in temporary directory
	print "File clean up\n";
	unlink $temp_xml;

	print "Processing complete. It took " . (time() - $timer) . " seconds\n";
}

1;

