#!/usr/bin/perl
# --
# otrs.CleanTicketIndex.pl - Clean the Static Ticket Index
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
    },
);

# check args
my $Command = shift || '--help';
print "otrs.CleanTicketIndex.pl - clean static index\n";
print "Copyright (C) 2001-2014 OTRS AG, http://otrs.com/\n";

my $Module = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::IndexModule');
print "Module is $Module\n";
if ( $Module !~ /StaticDB/ ) {
    print "OTRS is configured to use $Module as index\n";

    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT count(*) from ticket_index'
    );
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        if ( $Row[0] ) {
            print "Found $Row[0] records in StaticDB index.\n";
            print "Deleting $Row[0] records...";
            $Kernel::OM->Get('Kernel::System::DB')->Do( SQL => 'DELETE FROM ticket_index' );
            print " OK!\n";
        }
        else { print "No records found in StaticDB index.. OK!\n"; }
    }

    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT count(*) from ticket_lock_index'
    );
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        if ( $Row[0] ) {
            print "Found $Row[0] records in StaticDB lock_index.\n";
            print "Deleting $Row[0] records...";
            $Kernel::OM->Get('Kernel::System::DB')->Do(
                SQL => 'DELETE FROM ticket_lock_index'
            );
            print " OK!\n";
        }
        else { print "No records found in StaticDB lock_index.. OK!\n"; }
    }

}
else {
    print "You are using $Module as index, you should not clean it.\n";
}

exit(0);
