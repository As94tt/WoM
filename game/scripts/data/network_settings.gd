class_name NetworkSettings
extends Resource
## Einstellungen der Netzwerk-Schicht als Daten (Ticket #30). Der Standardsatz
## liegt in res://data/network/network_settings.tres und wird vom Autoload
## „Network“ gelesen.

## Standard-Port für Hosten und Beitreten.
@export_range(1024, 65535) var default_port: int = 7777
## Höchstzahl Spieler einer Sitzung, Host eingerechnet (GDD: 1 bis 5).
@export_range(1, 5) var max_players: int = 5
## Wie oft pro Sekunde jede Figur Position, Drehung und Bewegungszustand sendet.
@export_range(1.0, 60.0) var sync_rate_hz: float = 20.0
## Puffer für die Darstellung anderer Spieler in Millisekunden: Sie werden so
## weit in der Vergangenheit gezeigt und zwischen zwei empfangenen Positionen
## weich interpoliert.
@export_range(0, 500) var interpolation_delay_ms: int = 100
## So lange wartet ein Beitretender auf die Verbindung und die Antwort des
## Hosts, bevor „Zeitüberschreitung“ gemeldet wird, in Sekunden.
@export var connect_timeout_s: float = 8.0
## So lange wartet der Host nach dem Verbinden auf die Anmeldung (Version,
## Charakter) eines Beitretenden, bevor er ihn trennt, in Sekunden.
@export var handshake_timeout_s: float = 10.0
## Abstand zwischen zwei automatischen Speicherungen des eigenen Charakters.
@export var autosave_interval_s: float = 60.0
## Wie oft der Host die Pings aller Spieler an alle sendet, in Sekunden.
@export var ping_interval_s: float = 1.0
## Obergrenze der künstlichen Verzögerung im Entwickler-Panel, in Millisekunden.
@export var max_artificial_delay_ms: int = 300
## Startparameter --join: so viele Versuche, falls der Host noch startet.
@export var quick_join_attempts: int = 10
