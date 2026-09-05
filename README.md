# SHIFT №4

`SHIFT №4` je pracovní název kooperativního systémového thrilleru pro 1–4 hráče. Posádka řídí stárnoucí fiktivní elektrárnu, plní výrobní kvótu a rozhoduje, které technické problémy vyřešit, obejít nebo vědomě odložit. Základní napětí vzniká ze vztahu:

> výroba × bezpečnost × technický stav

Projekt je navržen pro Godot 4.x a typed GDScript. První ověřovací verze je malý dvouhráčový vertical slice: Operátor ve velínu a Technik v provozu, dvě navazující směny, přetrvávající poškození a jedna srozumitelná kaskáda poruch.

## Dokumentace

| Dokument | Účel |
|---|---|
| [Porovnání promptů](docs/00_PROMPT_COMPARISON.md) | Co bylo převzato z obou zadání, co bylo změněno a proč. |
| [Game Design Document](docs/01_GAME_DESIGN_DOCUMENT.md) | Vize, pilíře, role, herní smyčky, systémy, obsah a cílový zážitek. |
| [Technical Design Document](docs/02_TECHNICAL_DESIGN.md) | Architektura Godot projektu, simulační model, data, síťování, persistence a testovatelnost. |
| [MVP vertical slice](docs/03_MVP_VERTICAL_SLICE.md) | Přesný rozsah prvního hratelného prototypu a Definition of Done. |
| [Multiplayer a role 1–4](docs/04_MULTIPLAYER_AND_ROLES.md) | Škálování posádky, informační asymetrie a host-authoritative pravidla. |
| [Roadmapa](docs/05_ROADMAP.md) | Implementační milníky, pořadí práce a výstupní podmínky. |
| [Validace a akceptace](docs/06_VALIDATION_AND_ACCEPTANCE.md) | Automatické testy, playtesty, metriky a akceptační kritéria. |
| [Development baseline](docs/07_DEVELOPMENT.md) | Ověřená Godot verze, aktuální struktura a reprodukovatelné launch/headless příkazy. |
| [Codex master prompt](docs/CODEX_MASTER_PROMPT.md) | Sjednocený prompt pro následnou implementaci po malých milnících. |
| [AGENTS.md](AGENTS.md) | Trvalá pravidla pro coding agenta v tomto repozitáři. |

## Pevná rozhodnutí

- Cílová hra podporuje 1–4 hráče; designový základ a první síťový MVP jsou optimalizované pro 2 hráče.
- Solo režim je podporovaný pomocí přepínání stanovišť a omezené automatizace. Není měřítkem balancu MVP.
- Elektrárna je fiktivní a její model je záměrně abstraktní. Projekt neimplementuje reálné postupy řízení jaderného reaktoru.
- Poruchy vznikají primárně z provozního zatížení, opotřebení a stavu komponent, nikoli z náhodného okamžitého trestu.
- Operátor pracuje s telemetrií; Technik s lokálním fyzickým stavem. Pravdivá hodnota a report senzoru jsou oddělené.
- Autoritativní simulace běží pouze na hostiteli/serveru v pevném simulačním kroku 10 Hz.
- Parametry balancu jsou v Godot `Resource` datech, ne jako magická čísla v gameplay kódu.
- První cíl je malý, nehezký a měřitelný vertical slice, který ověří zábavnost rozhodování a komunikace.

## Jak dokumentaci používat

Před implementací konkrétního milníku přečti GDD, technický návrh, MVP specifikaci a příslušnou část roadmapy. Potom spusť coding agenta s [master promptem](docs/CODEX_MASTER_PROMPT.md) a nahraď blok `AKTUÁLNÍ ÚKOL` jediným vybraným milníkem. Nespouštěj celý vývoj jedním promptem.

## M4 rychlé spuštění

Výchozí main scéna otevře malou ENet dev lobby. Host zvolí `HOST`, druhý proces se připojí přes localhost/LAN IP, každý obsadí jinou roli a oba potvrdí `READY`. Alternativně lze role a ready nastavit z příkazové řádky:

```powershell
& $godotGui --path $projectPath -- --host --port=7004 --role=OPERATOR --ready
& $godotGui --path $projectPath -- --join=127.0.0.1 --port=7004 --role=TECHNICIAN --ready
```

Úplné ovládání, automatické testy a dvouprocesový smoke jsou v [development dokumentaci](docs/07_DEVELOPMENT.md#m4--dvouhráčový-hostclient).
