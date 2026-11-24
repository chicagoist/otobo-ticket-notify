use strict;
use warnings;
use Test::More;

my $Module = 'Kernel/System/Ticket/Event/TicketNotifyAgent.pm';

ok( -f $Module, 'Moduldatei vorhanden' );

my $Output = `$^X -c $Module 2>&1`;
my $Exit   = $? >> 8;

is( $Exit, 0, 'Modul kompiliert (perl -c)' ) or diag $Output;

done_testing();
