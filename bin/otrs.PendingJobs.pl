#!/usr/bin/perl
# --
# bin/otrs.PendingJobs.pl - check pending tickets
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

use Kernel::System::ObjectManager;

# common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'OTRS-otrs.PendingJobs.pl',
    },
);

# check args
my $Command = shift || '--help';
print "otrs.PendingJobs.pl - check pending tickets\n";
print "Copyright (C) 2001-2014 OTRS AG, http://otrs.com/\n";

my @PendingAutoStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
    Type   => 'PendingAuto',
    Result => 'ID',
);

if ( !@PendingAutoStateIDs ) {
    print STDOUT " No pending auto StateIDs found - skipping script!\n";
    exit 0;
}

# do ticket auto jobs
my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
    Result   => 'ARRAY',
    StateIDs => [@PendingAutoStateIDs],
    UserID   => 1,
);

TICKETID:
for my $TicketID (@TicketIDs) {

    # get ticket data
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $TicketID,
        UserID        => 1,
        DynamicFields => 0,
    );

    next TICKETID if $Ticket{UntilTime} >= 1;

    my %States = %{ $Kernel::OM->Get('Kernel::Config')->Get('Ticket::StateAfterPending') };

    # error handling
    if ( !$States{ $Ticket{State} } ) {
        print STDERR
            "ERROR: No Ticket::StateAfterPending found for '$Ticket{State}' in Kernel/Config.pm!\n";
        next TICKETID;
    }

    print STDOUT
        " Update ticket state for ticket $Ticket{TicketNumber} ($TicketID) to '$States{$Ticket{State}}'...";

    # set new state
    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->StateSet(
        TicketID => $TicketID,
        State    => $States{ $Ticket{State} },
        UserID   => 1,
    );

    # error handling
    if ( !$Success ) {
        print STDOUT " failed.\n";
        next TICKETID;
    }

    # get state type for new state
    my %State = $Kernel::OM->Get('Kernel::System::State')->StateGet(
        Name => $States{ $Ticket{State} },
    );
    if ( $State{TypeName} eq 'closed' ) {

        # set new ticket lock
        $Kernel::OM->Get('Kernel::System::Ticket')->LockSet(
            TicketID     => $TicketID,
            Lock         => 'unlock',
            UserID       => 1,
            Notification => 0,
        );
    }
    print STDOUT " done.\n";
}

# do ticket reminder notification jobs
@TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
    Result    => 'ARRAY',
    StateType => 'pending reminder',
    UserID    => 1,
);

TICKETID:
for my $TicketID (@TicketIDs) {

    # get ticket data
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $TicketID,
        UserID        => 1,
        DynamicFields => 0,
    );

    next TICKETID if $Ticket{UntilTime} >= 1;

    # check if it is during business hours, then send reminder
    my $CountedTime = $Kernel::OM->Get('Kernel::System::Time')->WorkingTime(
        StartTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime() - ( 30 * 60 ),
        StopTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime(),
    );

    # error handling
    if ( !$CountedTime ) {
        next TICKETID;
    }

    # send the reminder to the ticket owner, if ticket is locked
    my @UserID;
    if (
        $Kernel::OM->Get('Kernel::Config')->Get('Ticket::PendingNotificationOnlyToOwner')
        || $Ticket{Lock} eq 'lock'
        )
    {
        @UserID = ( $Ticket{OwnerID} );
    }

    # send the reminder to all queue subscribers and owner, if ticket is unlocked
    else {
        @UserID = $Kernel::OM->Get('Kernel::System::Ticket')->GetSubscribedUserIDsByQueueID(
            QueueID => $Ticket{QueueID},
        );
        push @UserID, $Ticket{OwnerID};
    }

    # add the responsible agent to the notification list
    if (
        !$Kernel::OM->Get('Kernel::Config')->Get('Ticket::PendingNotificationNotToResponsible')
        && $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Responsible')
        && $Ticket{ResponsibleID} ne 1
        )
    {
        push @UserID, $Ticket{ResponsibleID};
    }

    # send the reminder notification
    print STDOUT " Send reminder notification (TicketID=$TicketID)\n";

    my %AlreadySent;
    USERID:
    for my $UserID (@UserID) {

        # remember if reminder got already sent
        next USERID if $AlreadySent{$UserID};
        $AlreadySent{$UserID} = 1;

        # get user data
        my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $UserID,
        );

        # check if a reminder has already been sent today
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year )
            = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2Date(
            SystemTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime(),
            );

        # get ticket history
        my @Lines = $Kernel::OM->Get('Kernel::System::Ticket')->HistoryGet(
            TicketID => $Ticket{TicketID},
            UserID   => 1,
        );

        my $Sent = 0;
        for my $Line (@Lines) {
            if (
                $Line->{Name} =~ /PendingReminder/
                && $Line->{Name} =~ /\Q$Preferences{UserEmail}\E/i
                && $Line->{CreateTime} =~ /$Year-$Month-$Day/
                )
            {
                $Sent = 1;
            }
        }

        next USERID if $Sent;

        # send agent notification
        $Kernel::OM->Get('Kernel::System::Ticket')->SendAgentNotification(
            TicketID              => $Ticket{TicketID},
            Type                  => 'PendingReminder',
            RecipientID           => $UserID,
            CustomerMessageParams => {
                TicketNumber => $Ticket{TicketNumber},
            },
            UserID => 1,
        );
    }
}

exit;
