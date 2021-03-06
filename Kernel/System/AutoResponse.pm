# --
# Kernel/System/AutoResponse.pm - lib for auto responses
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AutoResponse;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::SystemAddress',
);

=head1 NAME

Kernel::System::AutoResponse - auto response lib

=head1 SYNOPSIS

All auto response functions. E. g. to add auto response or other functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AutoResponseObject = $Kernel::OM->Get('Kernel::System::AutoReponse');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item AutoResponseAdd()

add auto response with attributes

    $AutoResponseObject->AutoResponseAdd(
        Name        => 'Some::AutoResponse',
        ValidID     => 1,
        Subject     => 'Some Subject..',
        Response    => 'Auto Response Test....',
        Charset     => 'utf8',
        ContentType => 'text/plain',
        AddressID   => 1,
        TypeID      => 1,
        UserID      => 123,
    );

=cut

sub AutoResponseAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name ValidID Response ContentType AddressID TypeID Charset UserID Subject)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # check if a autoresponse with this name already exits
    return if !$Self->_NameExistsCheck( Name => $Param{Name} );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # insert into database
    return if !$DBObject->Do(
        SQL => 'INSERT INTO auto_response '
            . '(name, valid_id, comments, text0, text1, type_id, system_address_id, '
            . 'charset, content_type,  create_time, create_by, change_time, change_by)'
            . 'VALUES '
            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},    \$Param{ValidID}, \$Param{Comment},   \$Param{Response},
            \$Param{Subject}, \$Param{TypeID},  \$Param{AddressID}, \$Param{Charset},
            \$Param{ContentType}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get id
    return if !$DBObject->Prepare(
        SQL => 'SELECT id FROM auto_response WHERE name = ? AND type_id = ? AND'
            . ' system_address_id = ? AND charset = ? AND content_type = ? AND create_by = ?',
        Bind => [
            \$Param{Name}, \$Param{TypeID}, \$Param{AddressID}, \$Param{Charset},
            \$Param{ContentType}, \$Param{UserID},
        ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=item AutoResponseGet()

get auto response with attributes

    my %Data = $AutoResponseObject->AutoResponseGet(
        ID => 123,
    );

=cut

sub AutoResponseGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => 'Need ID!' );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # select
    return if !$DBObject->Prepare(
        SQL => 'SELECT name, valid_id, comments, text0, text1, type_id, system_address_id, '
            . ' charset, content_type, create_time, create_by, change_time, change_by'
            . ' FROM auto_response WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {

        # convert body
        $Data[3] = $EncodeObject->Convert(
            Text  => $Data[3],
            From  => $Data[7],
            To    => 'utf-8',
            Force => 1,
        );

        # convert subject
        $Data[4] = $EncodeObject->Convert(
            Text  => $Data[4],
            From  => $Data[7],
            To    => 'utf-8',
            Force => 1,
        );

        # set new charset
        $Data[7] = 'utf-8';

        %Data = (
            ID          => $Param{ID},
            Name        => $Data[0],
            Comment     => $Data[2],
            Response    => $Data[3],
            ValidID     => $Data[1],
            Subject     => $Data[4],
            TypeID      => $Data[5],
            AddressID   => $Data[6],
            Charset     => $Data[7],
            ContentType => $Data[8] || 'text/plain',
            CreateTime  => $Data[9],
            CreateBy    => $Data[10],
            ChangeTime  => $Data[11],
            ChangeBy    => $Data[12],

        );
    }

    my %Types = $Self->AutoResponseTypeList();
    $Data{Type} = $Types{ $Data{TypeID} };

    return %Data;
}

=item AutoResponseUpdate()

update auto response with attributes

    $AutoResponseObject->AutoResponseUpdate(
        ID          => 123,
        Name        => 'Some::AutoResponse',
        ValidID     => 1,
        Subject     => 'Some Subject..',
        Response    => 'Auto Response Test....',
        Charset     => 'utf8',
        ContentType => 'text/plain',
        AddressID   => 1,
        TypeID      => 1,
        UserID      => 123,
    );

=cut

sub AutoResponseUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name ValidID Response AddressID Charset ContentType UserID Subject)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # check if a autoresponse with this name already exits
    return if !$Self->_NameExistsCheck(
        Name => $Param{Name},
        ID   => $Param{ID},
    );

    # update the database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE auto_response SET '
            . 'name = ?, text0 = ?, comments = ?, text1 = ?, type_id = ?, '
            . 'system_address_id = ?, charset = ?, content_type = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ? '
            . 'WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Response}, \$Param{Comment}, \$Param{Subject}, \$Param{TypeID},
            \$Param{AddressID}, \$Param{Charset}, \$Param{ContentType}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
        ],
    );

    return 1;
}

=item AutoResponseGetByTypeQueueID()

get a hash with data from Auto Response and it's corresponding System Address

    my %QueueAddressData = $AutoResponseObject->AutoResponseGetByTypeQueueID(
        QueueID => 3,
        Type    => 'auto reply/new ticket',
    );

Return example:

    %QueueAddressData(
        #Auto Response Data
        'Text'            => 'Your OTRS TeamOTRS! answered by a human asap.',
        'Subject'         => 'New ticket has been created! (RE: <OTRS_CUSTOMER_SUBJECT[24]>)',
        'Charset'         => 'iso-8859-1',
        'ContentType'     => 'text/plain',
        'SystemAddressID' => '1',

        #System Address Data
        'ID'              => '1',
        'Name'            => 'otrs@localhost',
        'Address'         => 'otrs@localhost',  #Compatibility with OTRS 2.1
        'Realname'        => 'OTRS System',
        'Comment'         => 'Standard Address.',
        'ValidID'         => '1',
        'QueueID'         => '1',
        'CreateTime'      => '2010-03-16 21:24:03',
        'ChangeTime'      => '2010-03-16 21:24:03',
    );

=cut

sub AutoResponseGetByTypeQueueID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(QueueID Type)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # SQL query
    return if !$DBObject->Prepare(
        SQL => 'SELECT ar.text0, ar.text1, ar.charset, ar.content_type, ar.system_address_id FROM '
            . 'auto_response_type art, auto_response ar, queue_auto_response qar '
            . 'WHERE qar.queue_id = ? AND art.id = ar.type_id AND '
            . 'qar.auto_response_id = ar.id AND art.name = ?',
        Bind => [
            \$Param{QueueID}, \$Param{Type},
        ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{Text}            = $Row[0];
        $Data{Subject}         = $Row[1];
        $Data{Charset}         = $Row[2];
        $Data{ContentType}     = $Row[3] || 'text/plain';
        $Data{SystemAddressID} = $Row[4];
    }

    # return if no auto response is configured
    return if !%Data;

    # get sender attributes
    my %Address = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
        ID => $Data{SystemAddressID},
    );

    # COMPAT: 2.1
    $Data{Address} = $Address{Name};

    # return both, sender attributes and auto response attributes
    return ( %Address, %Data );
}

=item AutoResponseList()

get a list of the Auto Responses

    my %AutoResponse = $AutoResponseObject->AutoResponseList();

Return example:

    %AutoResponse = (
        '1' => 'default reply (after new ticket has been created) ( 1 )',
        '2' => 'default reject (after follow up and rejected of a closed ticket) ( 2 )',
        '3' => 'default follow up (after a ticket follow up has been added) ( 3 )',
    );

=cut

sub AutoResponseList {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Kernel::System::DB')->GetTableData(
        What  => 'id, name, id',
        Valid => 0,
        Clamp => 1,
        Table => 'auto_response',
    );
}

=item AutoResponseTypeList()

get a list of the Auto Response Types

    my %AutoResponseType = $AutoResponseObject->AutoResponseTypeList();

Return example:

    %AutoResponseType = (
        '1' => 'auto reply',
        '2' => 'auto reject',
        '3' => 'auto follow up',
        '4' => 'auto reply/new ticket',
        '5' => 'auto remove',
    );

=cut

sub AutoResponseTypeList {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Kernel::System::DB')->GetTableData(
        What  => 'id, name',
        Valid => 1,
        Clamp => 1,
        Table => 'auto_response_type',
    );
}

=item AutoResponseQueue()

assigns a list of autoresponses to a queue

    my @AutoResponseIDs = (1,2,3);

    $AutoResponseObject->AutoResponseQueue (
        QueueID         => 1,
        AutoResponseIDs => \@AutoResponseIDs,
        UserID          => 1,
    );

=cut

sub AutoResponseQueue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(QueueID AutoResponseIDs UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # store queue:auto response relations
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM queue_auto_response WHERE queue_id = ?',
        Bind => [ \$Param{QueueID} ],
    );

    NEWID:
    for my $NewID ( @{ $Param{AutoResponseIDs} } ) {

        next NEWID if !$NewID;

        $DBObject->Do(
            SQL => 'INSERT INTO queue_auto_response (queue_id, auto_response_id, '
                . 'create_time, create_by, change_time, change_by) VALUES '
                . '(?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{QueueID}, \$NewID, \$Param{UserID}, \$Param{UserID},
            ],
        );
    }

    return 1;
}

=begin Internal:

=item _NameExistsCheck()

return if another autoresponse with this name already exits

    $AutoResponseObject->_NameExistsCheck(
        Name => 'Some::AutoResponse',
        ID   => 1, # optional
    );

=cut

sub _NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM auto_response WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{ID} || $Param{ID} ne $Row[0] ) {
            $Flag = 1;
        }
    }

    if ($Flag) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "An Auto-Response with name '$Param{Name}' already exists!",
        );
        return;
    }

    return 1;
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
