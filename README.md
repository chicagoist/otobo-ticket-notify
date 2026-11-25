# OTOBO Demo-Modul: Agenten-Benachrichtigung bei `TicketCreate`

[![Perl checks](https://github.com/chicagoist/otobo-ticket-notify/actions/workflows/ci.yml/badge.svg)](https://github.com/chicagoist/otobo-ticket-notify/actions/workflows/ci.yml)

Kleines OTOBO-Event-Modul in Perl, das den zustaendigen Agenten per E-Mail
benachrichtigt, sobald ein Ticket angelegt wird.

## Hintergrund

Das Modul entstand aus meiner OTOBO-Praxisaufgabe 2.6.3 (Weiterbildung
IT-Administration, Zukunftsmotor GmbH): OTOBO lief in Docker, SMTP/IMAP waren
mit MailCow verbunden, aber die Benachrichtigung des Agenten bei einem neuen
Ticket blieb offen. Dieses Modul loest genau diese Luecke auf der Ebene, auf der
OTOBO dafuer vorgesehen ist: als Event-Handler im `Ticket::EventModulePost`.

Wichtig zur Einordnung: Das ist ein Lern- und Demonstrationsmodul, kein
Bestandteil des offiziellen OTOBO-Codes.

## Funktionsweise

1. OTOBO ruft bei jedem Event alle in `Ticket::EventModulePost` registrierten
   Module auf.
2. `Kernel::System::Ticket::Event::TicketNotifyAgent::Run()` reagiert nur auf
   `TicketCreate` und prueft `TicketNotifyAgent::Enabled`.
3. Empfaenger ist der Besitzer des Tickets, ersatzweise der Verantwortliche.
4. Absender ist die Systemadresse der Queue (Fallback:
   `TicketNotifyAgent::From`).
5. Betreff und Text werden aus der Systemkonfiguration gelesen; Platzhalter wie
   `<OTOBO_TICKET>`, `<OTOBO_TITLE>`, `<OTOBO_QUEUE>`, `<OTOBO_URL>` werden
   ersetzt.
6. Versand ueber `Kernel::System::Email`, Ergebnis wird im OTOBO-Log
   protokolliert.

## Dateien

```
Kernel/System/Ticket/Event/TicketNotifyAgent.pm   Event-Handler (Perl)
Kernel/Config/Files/XML/TicketNotifyAgent.xml     Registrierung + Einstellungen
install.sh                                        Installation in den Container
t/00_compile.t                                    Syntax-Smoke-Test
```

## Installation

Voraussetzung: laufendes OTOBO 11 (z. B. aus `otobo-docker`).

```bash
./install.sh              # sucht den Web-Container automatisch
./install.sh otobo-web-1  # oder explizit
```

Das Skript kopiert Modul und XML-Konfiguration nach `/opt/otobo`, prueft die
Syntax, baut die Konfiguration neu auf (`Maint::Config::Rebuild --cleanup`),
loescht den Cache und startet den Container neu.

Anschliessend unter *Admin -> Systemkonfiguration -> Ticket -> Core::Ticket*
pruefen, ob `TicketNotifyAgent::*` vorhanden ist.

## Test

```bash
prove t
```

Im laufenden System: neues Ticket als Agent anlegen (Besitzer = eigener Agent)
und das Log beobachten:

```bash
docker exec otobo-web-1 tail -f /opt/otobo/var/log/otobo.log
```

Erwartete Zeile:

```
TicketNotifyAgent: notification for ticket 2026112410123456 sent to agent@example.com.
```

## Grenzen / moegliche Erweiterungen

- Benachrichtigt nur Besitzer/Verantwortlichen, keine ganzen Queues oder Gruppen.
- Kein Digest, keine Zusammenfassung mehrerer Tickets.
- Keine Uebersetzung der Texte (OTOBO-`Translate()` waere der naechste Schritt).
- Kein OPM-Paket; die Installation erfolgt per `install.sh`.

## Lizenz

GPL-3.0, passend zu OTOBO selbst – vollständiger Text in [`LICENSE`](LICENSE).
