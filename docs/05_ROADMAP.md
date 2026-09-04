# SHIFT №4 — implementační roadmapa

## 1. Zásada

Vždy je aktivní právě jeden milník. Následující milník nezačíná, dokud současný nesplní exit kritéria a jeho stav není zaznamenán. Roadmapa je seřazená podle rizika: nejdřív ověřit kauzální simulaci, potom informační gameplay, potom síťový a mezisměnový celek.

Stavy: `NOT STARTED`, `IN PROGRESS`, `BLOCKED`, `DONE`.

| Milník | Název | Stav |
|---|---|---|
| M0 | Repository baseline | DONE |
| M1 | Headless plant simulation | DONE |
| M2 | Equipment, sensors a referenční failure | DONE |
| M3 | Lokální playable slice | NOT STARTED |
| M4 | Dvouhráčový host/client | NOT STARTED |
| M5 | Dvě směny, persistence a ekonomika | NOT STARTED |
| M6 | MVP validace a balance | NOT STARTED |
| M7 | Rozhodnutí po MVP | NOT STARTED |

## 2. M0 — Repository baseline

### Cíl

Získat spustitelný Godot 4 projekt, ověřené konvence a nejmenší composition root pro další práci.

### Práce

- prohlédnout repozitář, branch/status, Godot verzi, pluginy, autoloady, scény a testy;
- zachovat funkční existující architekturu a uživatelské změny;
- pokud projekt neexistuje, založit minimální Godot 4 projekt a main scene;
- přidat jen adresáře potřebné pro M1;
- určit způsob parser/build/headless testu;
- přidat stručný development launch postup.

### Exit kritéria

- projekt se otevře/spustí bez parser error;
- main scene bezpečně skončí nebo zobrazí minimální shell;
- je známa přesná Godot verze a ověřovací příkazy;
- nebyl vytvořen budoucí gameplay skeleton bez použití;
- report uvádí existující stav, změny a jediný další milník M1.

## 3. M1 — Headless plant simulation

### Stav dílčích řezů

- M1a — fixed-step clock a `requested_load → MW → MWh`: `DONE` (2026-09-04).
- M1b — pumpy a downstream plant simulation: `DONE` (2026-09-04).
- Celý M1 je `DONE`; všechny jeho exit podmínky byly ověřeny headless testy a runnerem.

### Cíl

Dokázat deterministický řetězec `requested load → cooling/thermal state → turbine/generator MW → MWh` a vliv dvou pump bez 3D mapy.

### Práce

- `SimulationClock`, `PlantSimulation`, `PlantTuning`;
- minimální heat, cooling, steam, turbine a electrical kroky;
- P-A/P-B definition a runtime state v rozsahu nutném pro průtok;
- quota accumulation;
- debug panel nebo headless runner: load, pump enable, snapshot, reset;
- unit/simulation testy a stabilitní clampy.

### Exit kritéria

- zvýšení loadu zvýší ustálený MW a MWh;
- vypnutí aktivní pumpy sníží průtok a ovlivní downstream hodnoty;
- stejné vstupy dávají stejný výsledek;
- minimální, maximální a dlouhý běh neprodukují NaN/INF;
- UI/render nejsou zdrojem gameplay stavu;
- projdou AC-001, AC-002, AC-004, AC-011 a AC-023; AC-003 je ověřeno alespoň pro nulový výkon, plně se dokončí s BR-A v M2.

## 4. M2 — Equipment, sensors a referenční failure

### Cíl

Ověřit `load → wear → performance → symptoms` a oddělení skutečné a reportované informace.

### Práce

- ComponentDefinition/State a condition thresholds;
- P-B bearing degradation s fázemi;
- V-A/V-B, BR-A a PG-A v modelu;
- Sensor pipeline s normal/bias/frozen/delay minimum;
- alarm rules s hysterezí a acknowledge;
- zařízení-specifické commandy a debug ovládání;
- deterministické testy failure timeline.

### Exit kritéria

- high/overload prokazatelně zrychlí wear proti normal loadu;
- P-B failure postupně ovlivní vibrace, teplotu, efficiency, flow a stress;
- actual a reported hodnoty lze záměrně rozpojit;
- alarmy popisují symptomy a neprozrazují skrytou příčinu;
- alespoň tři reakce mají měřitelně odlišný dopad;
- projdou AC-003, AC-005 až AC-012, AC-016, AC-017 a AC-023.

## 5. M3 — Lokální playable slice

### Cíl

Na jednom počítači ověřit role-specific UX, fyzickou cestu a celý incident bez síťového rizika.

### Práce

- placeholder velín, chodba a strojovna;
- Operator UI nad operator view modelem;
- first-person Technician a interaction focus;
- world presenters pro P-A/P-B/V-A/V-B/BR-A/PG-A;
- inspect, valve, breaker a pump actions;
- jednoduchý zařízení-specifický servis;
- role swap/debug přepnutí pro lokální test;
- audio/visual status feedback a accessibility minimum.

### Exit kritéria

- tester může odehrát incident přepínáním rolí;
- UI a svět používají stejná device ID;
- Operátor nemá skrytou bearing condition a Technik nemá plnou telemetrii;
- změny v poli se projeví v jedné autoritativní simulaci;
- žádný stav zařízení není současně vlastněn modelem i scénou;
- projdou AC-013 až AC-018 a příslušný manuální smoke test.

## 6. M4 — Dvouhráčový host/client

### Cíl

Odehrát jednu směnu ve dvou samostatných procesech se skutečnou informační asymetrií.

### Práce

- dev lobby, host/join, role assignment a ready;
- authority gateway, command envelope a validace;
- role-specific snapshots a interpolace UI;
- synchronizace pohybu a fyzických interakcí v minimálním rozsahu;
- end shift request/confirmation;
- disconnect behavior a síťové debug informace;
- multiplayer smoke a negativní command testy.

### Exit kritéria

- jeden host a jeden klient dokončí celou směnu;
- plant tick, wear a MWh běží pouze na hostiteli;
- neplatné field commandy jsou odmítnuty;
- obě role vidí správně rozdílné informace a stejné následky;
- end shift lze koordinovaně potvrdit;
- projdou AC-019 až AC-022 a multiplayer testy.

## 7. M5 — Dvě směny, persistence a ekonomika

### Cíl

Dokončit celý MVP kvótní cyklus a ověřit, že první rozhodnutí mění druhou směnu.

### Práce

- briefing, debrief, maintenance a run complete states;
- dvousměnový QuotaSystem;
- kredity, Repair Kit, Spare Fuse a Diagnostic Tool;
- maintenance transakce a omezený restore;
- verzovaný SaveGameDTO, validace a atomický zápis;
- přenos quota, kreditu, zásob, condition a persistent failure;
- success/failure a nový run/reset.

### Exit kritéria

- dva hráči dokončí dvě směny bez debug zásahu;
- poškození a nákup z první směny změní druhou;
- ruční konec funguje před i po dosažení kvóty;
- quota success a failure mají ověřenou cestu;
- save round trip zachová přesně povinný stav;
- projdou AC-024 až AC-033.

## 8. M6 — MVP validace a balance

### Cíl

Rozhodnout o gameplay hypotéze na základě stabilního buildu a opakovaných playtestů.

### Práce

- automatizovaný parser/build/test pipeline;
- 30min+ simulation soak a opakované deterministické replaye;
- nejméně 5 dvojic testerů, pokud jsou dostupné;
- session metrics a krátký post-test dotazník;
- opravy blockerů a maximálně několik cílených balance iterací;
- finální AC report `PASS/PARTIAL/FAIL` s důkazem;
- seznam zjištění a rozhodnutí go/iterate/stop.

### Exit kritéria

- žádná kritická parser/runtime/network chyba v povinném průchodu;
- všechna MUST akceptační kritéria jsou PASS;
- většina testovacích dvojic správně vysvětlí vazbu load–wear–performance;
- většina dvojic spontánně sdílí role-specific informace;
- existují pozorované rozdílné strategie, ne jediná dominantní odpověď;
- tým rozhodl, zda hypotéza obstála.

## 9. M7 — Rozhodnutí po MVP

Tento milník není automatické rozšíření scope. Vybere se jedna větev:

- `GO`: navrhnout 3–4 player content slice, druhou poruchovou rodinu a širší kvótní cyklus;
- `ITERATE`: opravit konkrétní selhání komunikace, čitelnosti nebo balancu a zopakovat M6;
- `PIVOT`: změnit jednu klíčovou část smyčky a vytvořit nový omezený experiment;
- `STOP`: archivovat zjištění bez další produkce.

Teprve po `GO` lze plánovat Incident Director, větší mapu, integrovaný voice, kampaň, final art nebo platformní integrace.

## 10. Doporučené první tři vývojové úkoly

Pokud je repozitář stále prázdný:

1. M0: vytvořit a ověřit minimální Godot projekt s přesnou verzí a testovacím příkazem.
2. M1a: implementovat `SimulationClock`, `PlantTuning` a headless requested-load → MW → MWh test.
3. M1b: přidat P-A/P-B a ověřit, že změna dostupného průtoku mění celý downstream řetězec.

Každý úkol má skončit ověřeným výsledkem; Codex nemá v jednom běhu automaticky pokračovat na další bod.
