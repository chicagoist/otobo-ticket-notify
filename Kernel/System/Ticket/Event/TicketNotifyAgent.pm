# --
# Kernel/System/Ticket/Event/TicketNotifyAgent.pm - benachrichtigt den Agenten
# per E-Mail, sobald ein Ticket angelegt wird (OTOBO Event-Modul).
#
# Demo-Implementierung zum OTOBO-Event-Mechanismus:
#   * Registrierung erfolgt ueber Kernel/Config/Files/XML/TicketNotifyAgent.xml
#   * Aufruf durch den EventHandler bei Event "TicketCreate"
#   * Empfaenger: Besitzer des Tickets, sonst Verantwortlicher
# --

package Kernel::System::Ticket::Event::TicketNotifyAgent;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Email',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed (qw(Event TicketID Config)) {
        next if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!",
        );
        return;
    }

    # dieses Modul reagiert nur auf TicketCreate
    return 1 if $Param{Event} ne 'TicketCreate';

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return 1 if !$ConfigObject->Get('TicketNotifyAgent::Enabled');

    my $UserID = $Param{UserID} || 1;

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        UserID        => $UserID,
    );

    if ( !%Ticket ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "TicketNotifyAgent: Ticket $Param{TicketID} not found!",
        );
        return;
    }

    # Empfaenger bestimmen: Besitzer, sonst Verantwortlicher
    my $RecipientID = $Ticket{OwnerID} || $Ticket{ResponsibleID};

    if ( !$RecipientID ) {
        $LogObject->Log(
            Priority => 'info',
            Message  => "TicketNotifyAgent: Ticket $Ticket{TicketNumber} has no owner/responsible, no notification sent.",
        );
        return 1;
    }

    my $Recipient = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $RecipientID,
        Result => 'HASH',
    );

    if ( !$Recipient || !$Recipient->{UserEmail} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "TicketNotifyAgent: no email address for user $RecipientID.",
        );
        return;
    }

    # Absender: Systemadresse der Queue, sonst konfigurierte Fallback-Adresse
    my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
        ID => $Ticket{QueueID},
    );

    my $From = $Queue{SystemAddress} || $ConfigObject->Get('TicketNotifyAgent::From');

    if ( !$From ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "TicketNotifyAgent: no sender address for queue $Ticket{Queue}.",
        );
        return;
    }

    # Link auf das Ticket im Agenten-Interface
    my $BasePath  = $ConfigObject->Get('Frontend::BasePath') || '';
    my $Scheme    = $ConfigObject->Get('HttpType') || 'http';
    my $FQDN      = $ConfigObject->Get('FQDN') || 'localhost';
    my $TicketURL = $Scheme . '://' . $FQDN . $BasePath
        . 'index.pl?Action=AgentTicketZoom;TicketID=' . $Ticket{TicketID};

    # Platzhalter ersetzen
    my %Replace = (
        '<OTOBO_TICKET>'      => $Ticket{TicketNumber},
        '<OTOBO_TITLE>'       => $Ticket{Title},
        '<OTOBO_QUEUE>'       => $Ticket{Queue},
        '<OTOBO_STATE>'       => $Ticket{State},
        '<OTOBO_PRIORITY>'    => $Ticket{Priority},
        '<OTOBO_OWNER>'       => $Recipient->{UserFullname},
        '<OTOBO_CUSTOMER_ID>' => $Ticket{CustomerID},
        '<OTOBO_URL>'         => $TicketURL,
    );

    my $Subject = $ConfigObject->Get('TicketNotifyAgent::Subject')
        || 'Neues Ticket <OTOBO_TICKET>: <OTOBO_TITLE>';

    my $Body = $ConfigObject->Get('TicketNotifyAgent::Body');

    if ( !$Body ) {
        $Body = "Guten Tag <OTOBO_OWNER>,\n\n"
            . "Ihnen wurde soeben ein neues Ticket zugewiesen.\n\n"
            . "Ticket:     <OTOBO_TICKET>\n"
            . "Titel:      <OTOBO_TITLE>\n"
            . "Queue:      <OTOBO_QUEUE>\n"
            . "Status:     <OTOBO_STATE>\n"
            . "Prio:       <OTOBO_PRIORITY>\n"
            . "Kunde:      <OTOBO_CUSTOMER_ID>\n\n"
            . "Zum Ticket: <OTOBO_URL>\n\n"
            . "Diese Nachricht wurde automatisch von OTOBO erzeugt.\n";
    }

    for my $Key ( sort keys %Replace ) {
        my $Value = defined $Replace{$Key} ? $Replace{$Key} : '';
        $Subject =~ s/\Q$Key\E/$Value/g;
        $Body    =~ s/\Q$Key\E/$Value/g;
    }

    my $Sent = $Kernel::OM->Get('Kernel::System::Email')->Send(
        From        => $From,
        To          => $Recipient->{UserEmail},
        Subject     => $Subject,
        Body        => $Body,
        ContentType => 'text/plain; charset=utf-8',
        UserID      => $UserID,
    );

    if ( !$Sent ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "TicketNotifyAgent: could not send notification for ticket $Ticket{TicketNumber} to $Recipient->{UserEmail}.",
        );
        return;
    }

    $LogObject->Log(
        Priority => 'info',
        Message  => "TicketNotifyAgent: notification for ticket $Ticket{TicketNumber} sent to $Recipient->{UserEmail}.",
    );

    return 1;
}

1;
