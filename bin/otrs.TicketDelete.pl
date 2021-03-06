#!/usr/bin/perl
# --
# bin/otrs.TicketDelete.pl - delete tickets by ticket number or ticket id
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use Getopt::Long;

use Kernel::System::ObjectManager;

# create common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'OTRS-otrs.TicketDelete.pl',
    },
);

my $Help            = '';
my @TicketNumbers   = ();
my @TicketIDs       = ();
my @DeleteTicketIDs = ();

GetOptions(
    'help'              => \$Help,
    'TicketNumber=s{,}' => \@TicketNumbers,
    'TicketID=s{,}'     => \@TicketIDs,
);

# delete listed tickets by ticket number
if (@TicketNumbers) {

    TICKETNUMBER:
    for my $TicketNumber (@TicketNumbers) {

        # lookup ticket id
        my $TicketID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketIDLookup(
            TicketNumber => $TicketNumber,
            UserID       => 1,
        );

        # error handling
        if ( !$TicketID ) {
            print "Unable to find ticket number $TicketNumber.\n";
            next TICKETNUMBER;
        }

        push @DeleteTicketIDs, $TicketID;
    }

    # delete tickets (if any valid number was given)
    if (@DeleteTicketIDs) {

        print "Deleting specified tickets...\n";

        DeleteTickets( TicketIDs => \@DeleteTicketIDs );
    }
}

# delete listed tickets by ticket ids
elsif (@TicketIDs) {

    TICKETID:
    for my $TicketID (@TicketIDs) {

        # lookup ticket number
        my $TicketNumber = $Kernel::OM->Get('Kernel::System::Ticket')->TicketNumberLookup(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # error handling
        if ( !$TicketNumber ) {
            print "Unable to find ticket id $TicketID.\n";
            next TICKETID;
        }

        push @DeleteTicketIDs, $TicketID;
    }

    # delete tickets (if any valid number was given)
    if (@DeleteTicketIDs) {

        print "Deleting specified tickets...\n";
        DeleteTickets( TicketIDs => \@DeleteTicketIDs );
    }
}

# show usage
else {
    print "\n";
    print "otrs.TicketDelete.pl - ";
    print "delete tickets by number.\n";
    print "Copyright (C) 2001-2014 OTRS AG, http://otrs.com/\n";
    print "\n";
    print "Usage: $0 [options] \n";
    print "\n  Options are as follows:\n";
    print "  --help                             display this option help\n";
    print "  --TicketNumber no1 no2 no3         delete listed tickets (by ticket number)\n";
    print "  --TicketID no1 no2 no3             delete listed tickets (by ticket id)\n";
    print "\n";

    exit 1;
}

exit(0);

sub DeleteTickets {
    my (%Params) = @_;

    # unpack the ticket ids
    my @TicketIDs = @{ $Params{TicketIDs} };

    my $DeletedTicketCount = 0;

    # delete specified tickets
    TICKETID:
    for my $TicketID (@TicketIDs) {

        # delete the ticket
        my $True = $Kernel::OM->Get('Kernel::System::Ticket')->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # error handling
        if ( !$True ) {
            print "Unable to delete ticket with id $TicketID\n";
            next TICKETID;
        }

        # increase the deleted ticket count
        $DeletedTicketCount++;
    }

    print "$DeletedTicketCount tickets have been deleted.\n\n";

    return 1;
}
