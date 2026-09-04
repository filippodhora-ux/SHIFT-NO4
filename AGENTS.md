# SHIFT №4 — pravidla repozitáře

## Produktový kontrakt

- Projekt je kooperativní hra pro 1–4 hráče v Godot 4.x; první hratelný vertical slice je určen pro 2 hráče.
- Hlavní testovaná smyčka je `výkon → výroba MWh → opotřebení → symptomy → komunikace → zásah → přetrvávající následek → kvóta`.
- Herní elektrárna je fiktivní, abstraktní a nesmí vyžadovat ani reprodukovat reálné provozní postupy jaderných zařízení.
- Přesný produktový scope je v `docs/01_GAME_DESIGN_DOCUMENT.md`; hranice MVP jsou v `docs/03_MVP_VERTICAL_SLICE.md`.

## Technický kontrakt

- Používej Godot 4.x a typed GDScript, pokud existující projekt neprokazuje oprávněný důvod pro jinou volbu.
- Autoritativní stav simulace, komponent, směny, kvóty a ekonomiky vlastní host/server.
- Simulační logiku drž nezávislou na 3D scénách a vykreslování. Pevný simulační krok je výchozích 10 Hz; UI může interpolovat.
- Definice a tuning ukládej do typovaných Godot `Resource`; měnící se runtime stav drž odděleně a ukládej přes verzované save DTO.
- Skutečný stav zařízení a reportovaná senzorická hodnota jsou různé datové položky.
- Poruchy modeluj jako kauzální řetězec `příčina → symptomy → diagnóza → reakce → následek`.
- Preferuj malé doménové třídy, explicitní závislosti a Godot signals. Nepřidávej globální EventBus, singleton nebo abstraktní framework bez doložené potřeby.
- Zachovej stabilní `device_id` ve scéně, UI, alarmech, save datech, síťových zprávách a debug nástrojích.
- Detailní návrh je v `docs/02_TECHNICAL_DESIGN.md`.

## Pracovní postup

1. Před změnou prohlédni repozitář, `project.godot`, existující scény, autoloady, testy a necommitnuté změny.
2. Urči jediný aktivní milník z `docs/05_ROADMAP.md`. Neimplementuj následující milníky bez zadání.
3. Napiš krátký plán založený na existující architektuře a nejmenším smysluplném řezu.
4. Implementuj end-to-end chování, ne izolovanou kostru bez ověřitelného výsledku.
5. Spusť cílené testy, Godot parser/build kontrolu a minimální smoke test dotčeného toku.
6. Aktualizuj dokumentaci jen tehdy, když se změnil produktový nebo technický kontrakt. Zaznamenej vědomé odchylky.
7. Výstup uzavři souhrnem změn, ověřením, známými omezeními a stavem dotčených akceptačních kritérií.

Pokud rozhodnutí neblokuje aktuální milník, zvol nejmenší reverzibilní variantu a poznamenej předpoklad. Neprohlašuj funkčnost bez ověření.

## Kvalita a scope

- Nevytvářej obří manager třídy, kruhové závislosti, magická čísla nebo stav duplikovaný mezi modelem a prezentací.
- Nezačínej finálním artem, příběhem, monstry, komplexní fyzikou, craftingem, matchmakingem ani backendem.
- Nepřidávej reálnou reaktorovou fyziku, RBMK logiku, bezpečnostní procedury nebo návody použitelné pro skutečný provoz.
- Debug nástroje a deterministická simulace jsou součást funkce, nikoli volitelný polish.
- Komentáře vysvětlují důvod nebo invariant; názvy a struktura mají vysvětlit běžné chování samy.
- Každá změna musí respektovat `docs/06_VALIDATION_AND_ACCEPTANCE.md`.

