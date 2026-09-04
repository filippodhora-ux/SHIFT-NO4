# SHIFT №4 — validace a akceptační kritéria

## 1. Účel

Akceptace odděluje „kód existuje“ od „herní hypotéza je ověřitelná“. Každé kritérium má metodu, důkaz a stav. Finální report používá `PASS`, `PARTIAL`, `FAIL` nebo `NOT TESTED`.

Povinný důkaz je jeden nebo více z:

- název automatického testu a jeho výsledek;
- reprodukovatelný manuální postup;
- log/metric se seedem a tuning presetem;
- screenshot/video pro UX stav;
- save fixture nebo síťový trace bez citlivých údajů.

## 2. Funkční akceptační kritéria

| ID | Kritérium | Ověření |
|---|---|---|
| AC-001 | Zvýšení requested load při zdravé elektrárně zvýší po ustálení actual MW. | Simulation test se stejným seedem. |
| AC-002 | MWh se akumulují jako `MW × simulated hours`, ne jako samostatné body. | Unit test více kroků a nulového výkonu. |
| AC-003 | MWh se při rozpojeném BR-A nebo nulovém výkonu nezvyšují. | Unit/simulation test. |
| AC-004 | Změna P-A/P-B dostupnosti změní coolant flow a nejméně jednu downstream veličinu. | Simulation test + debug smoke. |
| AC-005 | High/overload způsobí za stejný čas významně větší wear než normal load. | A/B simulation test se shodným stavem. |
| AC-006 | Snížení loadu sníží stress nebo jeho růst v očekávaném čase. | Simulation trend assertion. |
| AC-007 | Condition P-B ovlivní její efficiency a skutečný průtok. | Unit + integration test. |
| AC-008 | Referenční bearing failure postupuje přes čitelné fáze, ne okamžitě z healthy do failed. | Deterministická timeline. |
| AC-009 | Failure vyvolá více symptomů: mechanický, tepelný/elektrický a systémový. | Timeline + role view kontrola. |
| AC-010 | Nejméně tři zásahy mají odlišný systémový nebo ekonomický následek. | Scenario test pro reduce/switch/service-or-risk. |
| AC-011 | Simulace zůstane v definovaných mezích bez NaN/INF a nekontrolovaného driftu. | Boundary test + soak. |
| AC-012 | Actual valve/sensor value může být odlišná od reported value. | Unit + debug demonstration. |
| AC-013 | Operátor během běžné hry nevidí přesnou bearing condition ani skryté failure ID. | View-model test + UI inspection. |
| AC-014 | Technik nevidí plnou globální telemetrii a quota dashboard v terénním HUD. | View-model test + UI inspection. |
| AC-015 | Operátor obdrží globální symptom, Technik relevantní lokální symptom stejné poruchy. | Role-specific scenario test. |
| AC-016 | Alarm sděluje symptom a acknowledge neodstraní aktivní příčinu. | Unit + UI smoke. |
| AC-017 | Zařízení používají shodné ID ve světě, UI, alarmech, logu a debug panelu. | Content validation test. |
| AC-018 | Technician action změní autoritativní zařízení a následně plant performance. | Lokální integration smoke. |
| AC-019 | Host a klient se připojí, vyberou unikátní role a vstoupí do stejné směny. | Two-process smoke test. |
| AC-020 | PlantSimulation, wear a MWh se počítají jen na hostiteli. | Instrumented multiplayer test. |
| AC-021 | Neoprávněný, vzdálený nebo prerequisitem zakázaný command je odmítnut. | Negativní command tests. |
| AC-022 | Oba klienti vidí konzistentní důsledek stejné autoritativní změny bez přepsání novější revision. | Replication tests. |
| AC-023 | Stejný počáteční stav, seed a command log dávají stejný konečný snapshot. | Deterministic replay hash. |
| AC-024 | Hráči mohou směnu ručně ukončit; dosažení kvóty ji automaticky neukončí. | End-to-end scenario. |
| AC-025 | Debrief zobrazí MWh, load/stress metriky, významné alarmy, zásahy, kredity a stav. | UI/manual test. |
| AC-026 | Mezi směnami lze koupit alespoň jednu ze tří položek ze společných kreditů. | Economy integration test. |
| AC-027 | Neplatná nebo příliš drahá transakce stav nezmění. | Unit/integration test. |
| AC-028 | Quota progress, kredity, zásoby a equipment condition přetrvají do směny 2. | Save/load round trip + e2e. |
| AC-029 | Přetrvávající poškození ze směny 1 mění výkon nebo rozhodnutí ve směně 2. | End-to-end A/B scenario. |
| AC-030 | Po druhé směně lze dosáhnout quota success běžnou hrou. | Balanced success run. |
| AC-031 | Po druhé směně lze dosáhnout quota failure bez technické chyby. | Balanced failure run. |
| AC-032 | Trvalý maximální load má smysluplnou nevýhodu proti řízenému provozu. | Balance A/B + playtest. |
| AC-033 | Povinný dvousměnový průchod funguje s placeholder artem. | Release-candidate e2e. |

## 3. Nefunkční kritéria

| ID | Kritérium | Ověření |
|---|---|---|
| NFR-001 | Projekt nemá Godot parser/build chyby. | Headless editor/build check. |
| NFR-002 | Povinný průchod nevytváří nové error logy nebo orphaned node/resource warnings. | E2E log review. |
| NFR-003 | 30min autoritativní soak udrží stabilní číselný stav. | Seeded soak test. |
| NFR-004 | Jeden 10Hz sim step MVP má dostatečnou rezervu k 100ms budgetu. | Profiler capture v debug/release-template buildu. |
| NFR-005 | Balance hodnoty MVP lze upravit v Resources bez zásahu do gameplay zdrojáku. | Inspector/data review. |
| NFR-006 | Save data mají schema version, validaci a úspěšný round trip. | Persistence tests. |
| NFR-007 | Stav simulace lze testovat bez načtení 3D levelu. | Headless simulation suite. |
| NFR-008 | Stav není sdělován pouze barvou a klíčové zvuky mají vizuální/textový ekvivalent. | Accessibility checklist. |
| NFR-009 | Běžný role snapshot neobsahuje skrytá data druhé role. | Serialized payload test. |
| NFR-010 | Dokumentace a launch/debug postup odpovídají skutečnému buildu. | Fresh-clone verification. |

## 4. Doporučené automatické scénáře

### S-001 Nominal shift

- preset healthy, normal load, P-B active;
- běh definovaný počet ticků;
- očekávat stabilní teplotu/stress, kladný MW/MWh a nízký wear;
- žádný critical alarm.

### S-002 Overload degradation

- dva shodné snapshoty a seed;
- jeden běží normal, druhý overload;
- po stejném simulovaném čase má overload vyšší MWh i wear/stress;
- nevznikne okamžitý arbitrary failure v prvním ticku.

### S-003 Pump loss cascade

- ustálený systém, vypnutí aktivní pumpy;
- flow klesne před růstem temperature/stress;
- downstream MW se změní podle modelu;
- alarmy se aktivují v definovaném pořadí/toleranci.

### S-004 Lying sensor

- ventil actual closed, reported open;
- operator snapshot ukáže reported open;
- technician inspect ukáže fyzicky closed;
- alarmy vycházejí z příslušného reportovaného kanálu.

### S-005 Bearing choices

- stejný degraded snapshot větvit na reduce load, switch pump, service a continue;
- každá větev uloží MWh, condition, stress, item cost a konečný stav;
- výsledky musí být rozdílné a kauzálně vysvětlitelné.

### S-006 Persistence

- konec směny 1 s poškozenou P-B, MWh, kredity a nákupem;
- serialize/deserialize;
- směna 2 začne se shodnými povinnými hodnotami a bez Node referencí.

### S-007 Authority rejection

- klient odešle start/repair command mimo dosah, se špatnou rolí a duplicitním command ID;
- autorita všechny nepovolené varianty odmítne bez změny revision stavu;
- platný command projde jednou.

## 5. Manuální MVP smoke test

1. Spusť hostitele a druhý klientský proces.
2. Zvol různé role, ready a spusť nový run.
3. Zvyš load na normal a potvrď růst MW/MWh.
4. Zvyš load do high/overload a sleduj časový vývoj P-B bez otevřeného debug stavu hráčům.
5. Operátor oznámí telemetrický symptom; Technik nezávisle provede inspect a nahlásí lokální symptom.
6. Přepni na P-A nebo sniž load a potvrď systémovou odezvu.
7. Vyzkoušej zařízení-specifický servis nebo vědomě nech problém přetrvat.
8. Ručně ukonči směnu a zkontroluj debrief.
9. Kup jednu položku/proveď maintenance a spusť druhou směnu.
10. Potvrď přenesený stav a dohraj success nebo failure.
11. Zkontroluj logy, metrics, save a stav obou klientů.

Smoke test se provede také s jinou reakcí na failure, aby jediný šťastný průchod nezakryl chybu.

## 6. Playtest protokol

### 6.1 Vzorek

Pro rozhodnutí M6 cílit alespoň na 5 dvojic. Ideálně smíchat dvojice se zkušeností v co-op hrách a bez ní. Vývojář zasahuje jen při technickém blockeru.

### 6.2 Pozorované momenty

- první pochopení MW vs. MWh;
- první dobrovolné zvýšení rizika;
- první symptom a kdo jej pojmenoval;
- zda druhá role přinesla novou informaci;
- zda posádka vytvořila pracovní hypotézu;
- diskutované možnosti a vybraný zásah;
- okamžik a důvod end shift;
- maintenance rozhodnutí;
- reakce na přenesený stav ve směně 2.

### 6.3 Otázky po runu

Hodnocení 1–5 a krátké vysvětlení:

1. Chápal/a jsi, jak load ovlivňuje výrobu a riziko?
2. Potřeboval/a jsi informace druhého hráče?
3. Dokázal/a jsi odhadnout příčinu problémů z dostupných symptomů?
4. Měl tým více rozumných možností?
5. Záleželo na rozhodnutí z první směny ve druhé?
6. Byl konečný úspěch/neúspěch férový a vysvětlitelný?
7. Který okamžik vyvolal největší napětí?
8. Která informace nebo interakce byla nejasná?
9. Chtěl/a bys okamžitě zkusit jinou strategii?

### 6.4 Go/iterate kritéria

`GO`, pokud:

- nejméně 4 z 5 dvojic správně popíší load–wear–performance vztah;
- nejméně 4 z 5 spontánně vymění rozdílné informace potřebné pro zásah;
- nejméně 3 z 5 diskutují dvě nebo více legitimních reakcí;
- průměr u otázek 2, 4 a 5 je alespoň 4/5;
- technické chyby nezkreslí většinu runů.

`ITERATE`, pokud je základní loop čitelný, ale selže jedna měřitelná oblast. Iterace musí cílit na konkrétní symptom a zopakovat stejný protokol.

`PIVOT/STOP`, pokud komunikace nepřináší rozhodovací hodnotu ani po cílené iteraci, nebo pokud je dominantní strategie strukturálním důsledkem modelu.

## 7. Akceptační report šablona

```text
Build/commit:
Godot version:
Tuning preset:
Date/tester:

ID | Status | Evidence | Notes/follow-up
AC-001 | PASS | test_load_increases_output | ...

Automated checks:
- parser/build:
- unit/simulation:
- integration:
- multiplayer:
- soak:

Known limitations:
Gameplay hypothesis result: GO / ITERATE / PIVOT / STOP / NOT YET DECIDED
Next single milestone:
```

