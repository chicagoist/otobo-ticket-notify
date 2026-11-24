#!/usr/bin/env bash
#
# Installiert das Demo-Modul in einen laufenden OTOBO-Docker-Container.
#
#   ./install.sh                 # Container automatisch suchen
#   ./install.sh otobo-web-1     # Container explizit angeben
#
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CONTAINER="${1:-}"
if [ -z "$CONTAINER" ]; then
    CONTAINER="$( docker ps --format '{{.Names}}' | grep -E '(^|-)web(-|_|$)' | head -n 1 || true )"
fi

if [ -z "$CONTAINER" ]; then
    echo "FEHLER: Kein OTOBO-Web-Container gefunden. Namen aus 'docker ps' als Argument uebergeben." >&2
    exit 1
fi

echo "Ziel-Container: $CONTAINER"

docker cp "$ROOT/Kernel/System/Ticket/Event/TicketNotifyAgent.pm" \
    "$CONTAINER:/opt/otobo/Kernel/System/Ticket/Event/TicketNotifyAgent.pm"
docker cp "$ROOT/Kernel/Config/Files/XML/TicketNotifyAgent.xml" \
    "$CONTAINER:/opt/otobo/Kernel/Config/Files/XML/TicketNotifyAgent.xml"

echo "Syntaxpruefung im Container:"
docker exec "$CONTAINER" perl -c /opt/otobo/Kernel/System/Ticket/Event/TicketNotifyAgent.pm

echo "Konfiguration neu aufbauen:"
docker exec "$CONTAINER" /opt/otobo/bin/otobo.Console.pl Maint::Config::Rebuild --cleanup
docker exec "$CONTAINER" /opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete

echo "Container neu starten:"
docker restart "$CONTAINER" >/dev/null

echo
echo "Fertig. Pruefen unter Admin -> Systemkonfiguration -> Ticket -> Core::Ticket:"
echo "  TicketNotifyAgent::Enabled / ::Subject / ::Body"
echo "Test: neues Ticket im Agenten-Interface anlegen und das OTOBO-Log beobachten:"
echo "  docker exec $CONTAINER tail -f /opt/otobo/var/log/otobo.log"
