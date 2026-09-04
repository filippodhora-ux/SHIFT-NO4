# SHIFT №4 — development baseline

## Stav M0

- Roadmap status: `DONE`.
- Ověřeno: 2026-09-04.
- Repozitář byl při zahájení M0 nový Git repository bez commitů na větvi `master`.
- Před M0 obsahoval pouze dokumentaci; všechny její soubory byly untracked.
- `project.godot`, scény, skripty, autoloady, pluginy a testovací infrastruktura neexistovaly.
- M0 přidává pouze minimální Godot projekt, jednu pasivní main scénu a `.gitignore` pro import cache.
- Gameplay, simulace, síťování a budoucí adresářová struktura nejsou součástí M0.

## Ověřený toolchain

Přesná lokálně ověřená verze:

```text
Godot 4.7.2.stable.official.ed1daf0bf
```

Godot není v systémovém `PATH`. Pro reprodukovatelné PowerShell příkazy na tomto stroji:

```powershell
$godotConsole = 'C:\Users\demen\AppData\Local\BlackstartToolchain\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$godotGui = 'C:\Users\demen\AppData\Local\BlackstartToolchain\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe'
$projectPath = 'C:\Users\demen\Documents\ChatGPT\SHIFT-NO4'
```

Alternativní instalace stejné verze je dostupná přes WinGet cache. Dokumentované příkazy používají BlackstartToolchain cestu, protože byla nalezena a ověřena jako první stabilní lokální instalace.

## Kontrola verze

```powershell
& $godotConsole --version
```

Očekávaný výstup:

```text
4.7.2.stable.official.ed1daf0bf
```

## Parser/editor kontrola

Godot v headless editor režimu načte projekt, importuje zdroje, zkontroluje projektovou konfiguraci a parsuje scény a skripty:

```powershell
& $godotConsole --headless --editor --path $projectPath --quit
```

Úspěch znamená exit code `0` bez `ERROR` nebo parser chyb v konzoli. Import vytvoří lokální `.godot/` cache, která je ignorovaná Gitem.

## Spuštění projektu

Přímé spuštění main scény:

```powershell
& $godotGui --path $projectPath
```

Otevření projektu v editoru:

```powershell
& $godotGui --editor --path $projectPath
```

Main scéna pouze zobrazí název projektu a text `Repository baseline`. Nemá gameplay ani skryté budoucí systémy.

## Headless smoke kontrola

Současný projekt nemá test framework ani test suites. Minimální automatizovatelná kontrola spustí main scénu headless a po dvou main-loop iteracích ji ukončí:

```powershell
& $godotConsole --headless --path $projectPath --quit-after 2
```

Úspěch znamená exit code `0` bez runtime `ERROR`. Tento smoke test nenahrazuje testovací infrastrukturu plánovanou pro M1; pouze dokazuje, že projekt lze bez GUI načíst a spustit.

## Aktuální projektová struktura

```text
SHIFT-NO4/
├── .gitignore
├── AGENTS.md
├── README.md
├── project.godot
├── main.tscn
└── docs/
    ├── 00_PROMPT_COMPARISON.md
    ├── 01_GAME_DESIGN_DOCUMENT.md
    ├── 02_TECHNICAL_DESIGN.md
    ├── 03_MVP_VERTICAL_SLICE.md
    ├── 04_MULTIPLAYER_AND_ROLES.md
    ├── 05_ROADMAP.md
    ├── 06_VALIDATION_AND_ACCEPTANCE.md
    ├── 07_DEVELOPMENT.md
    └── CODEX_MASTER_PROMPT.md
```

## Autoloady, pluginy a testy

- Autoloady: žádné.
- Editor pluginy: žádné.
- GDExtension/moduly třetích stran: žádné.
- Test framework: žádný.
- Export presets: žádné.

Tyto položky se v M0 nepřidávají. M1 smí přidat pouze testovací způsob nutný pro headless simulační základ.

## Výsledky M0 kontrol

| Kontrola | Výsledek | Důkaz |
|---|---|---|
| Godot verze | PASS | `4.7.2.stable.official.ed1daf0bf` |
| Headless editor/parser | PASS | Dokumentovaný příkaz skončil exit code `0`, bez `ERROR` nebo parser chyby. |
| Main-scene start s rendererem | PASS | Projekt se spustil přes OpenGL Compatibility renderer a po dvou iteracích skončil exit code `0`. |
| Headless main-scene smoke | PASS | Dokumentovaný příkaz skončil exit code `0`, bez runtime `ERROR`. |
| Autoload/plugin audit | PASS | Žádné autoload sekce, addon pluginy ani GDExtension. |
| Scope audit | PASS | Žádné gameplay skripty, systémy, síťování ani budoucí prázdné adresáře. |

Samostatný test runner není součástí výchozího repozitáře, proto M0 používá reprodukovatelný headless smoke test. Zavedení simulačních testů patří do M1.

## M1a — headless simulační základ

M1a přidává pouze deterministický řetězec `requested_load → actual_power_mw → produced_mwh`. Neobsahuje pumpy, cooling, wear, poruchy, kvótní cyklus ani multiplayer.

Implementované části:

- `PlantTuning`: typed Resource s fixed stepem, limity loadu, nominálním výkonem, rampou a převodem reálného času na simulované hodiny;
- `PlantSimulation`: autoritativní stav, clampovaný requested load, deterministická power rampa, integrace MWh a reset;
- `PlantSnapshot`: malý snapshot tick/load/MW/MWh pro test a debug výstup;
- `SimulationClock`: fixed-step akumulátor, omezený catch-up, přesné tickování a reset;
- headless runner a osm cílených automatických testů bez third-party frameworku.

### Spuštění M1a testů

Po nastavení PowerShell proměnných z úvodu dokumentu:

```powershell
& $godotConsole --headless --path $projectPath --script 'res://tests/run_tests.gd'
```

Test failure vrací nenulový exit code. Úspěšný ověřený běh:

```text
[TEST] PASS zero_load_produces_zero_power_and_energy
[TEST] PASS higher_load_produces_higher_settled_power
[TEST] PASS mwh_uses_power_times_simulated_hours
[TEST] PASS deterministic_replay_matches_snapshot
[TEST] PASS requested_load_boundaries_are_clamped
[TEST] PASS long_soak_stays_finite_and_bounded
[TEST] PASS clock_advances_only_fixed_steps
[TEST] PASS reset_clears_clock_and_simulation
[TEST] SUMMARY passed=8 failed=0
```

### Headless debug runner

Příklad pro load `0.8`, 50 ticků a následný reset:

```powershell
& $godotConsole --headless --path $projectPath --script 'res://debug/simulation_runner.gd' -- --load=0.8 --ticks=50 --reset
```

Ověřený výstup:

```text
[SIM] result {"actual_power_mw":800.0,"produced_mwh":27.6,"requested_load":0.8,"tick":50}
[SIM] after_reset {"actual_power_mw":0.0,"produced_mwh":0.0,"requested_load":0.0,"tick":0}
```

Runner podporuje `--load=<float>`, `--ticks=<non-negative int>`, `--reset` a `--help`. Hodnoty mimo konfigurovaný load rozsah se explicitně clampují; neplatný argument vrátí exit code `2`.

### M1a stav akceptace

| ID | Stav | Důkaz |
|---|---|---|
| AC-001 | PASS | Test `higher_load_produces_higher_settled_power`. |
| AC-002 | PASS | Testy `mwh_uses_power_times_simulated_hours` a `zero_load_produces_zero_power_and_energy`. |
| AC-011 | PARTIAL | M1a boundary test a 100 000tickový soak proběhly bez NaN/INF nebo driftu. Celé AC vyžaduje nové soak pokrytí po přidání downstream subsystémů. |
| AC-023 | PARTIAL | Dva M1a běhy se shodným tuningem, command sekvencí a 220 ticky vytvořily shodný snapshot. Celé AC vyžaduje replay rozšířeného plant stavu. |

Historicky po M1a zůstal celý M1 `IN PROGRESS`; M1b a AC-004 tehdy nebyly součástí řezu.

## M1b — pumpy a downstream plant simulation

M1b dokončuje headless milník M1. Přidává dvě konkrétní pumpy `P-A` a `P-B` a kauzální abstraktní řetězec:

```text
requested_load
→ thermal_demand_units
→ P-A/P-B effective flow
→ coolant flow a cooling capacity
→ coolant temperature a plant stress
→ steam availability a available power
→ actual MW
→ produced MWh
```

Pumpa obsahuje pouze `device_id`, enabled/available stav, rated/effective flow a konfigurovatelnou konstantní efficiency. Wear, ložiska, motor, teplota pumpy, failure phases a obecný component framework nejsou implementované.

V jednom fixed ticku probíhá explicitně:

1. thermal demand z aktuálního requested loadu;
2. plynulé přiblížení průtoku obou pump k cílovému stavu;
3. součet coolant flow a výpočet cooling capacity;
4. plynulá coolant temperature podle cooling deficitu;
5. plynulý normalizovaný plant stress;
6. steam/downstream availability omezená cooling, teplotou a stress;
7. power rampa k available MW;
8. integrace MWh z actual MW.

### Testy celého M1

```powershell
& $godotConsole --headless --path $projectPath --script 'res://tests/run_tests.gd'
```

Ověřený výsledek:

```text
[TEST] PASS zero_load_produces_zero_power_and_energy
[TEST] PASS higher_load_produces_higher_settled_power
[TEST] PASS pump_flow_combines_enabled_available_pumps
[TEST] PASS pump_loss_causes_downstream_cascade
[TEST] PASS no_cooling_extreme_stays_bounded
[TEST] PASS mwh_uses_power_times_simulated_hours
[TEST] PASS deterministic_replay_matches_snapshot
[TEST] PASS requested_load_boundaries_are_clamped
[TEST] PASS long_soak_stays_finite_and_bounded
[TEST] PASS clock_advances_only_fixed_steps
[TEST] PASS reset_clears_clock_and_simulation
[TEST] SUMMARY passed=11 failed=0
```

Soak test provede 100 000 ticků v každé ze tří stabilních konfigurací: obě pumpy, jedna pumpa a žádné chlazení.

### Pump-loss runner

```powershell
& $godotConsole --headless --path $projectPath --script 'res://debug/simulation_runner.gd' -- --load=0.8 --pump-a=on --pump-b=on --ticks=200 --disable-after=P-B --after-ticks=100
```

Naměřené klíčové hodnoty:

| Stav | Flow | Teplota | Stress | Available/actual MW |
|---|---:|---:|---:|---:|
| Obě pumpy, tick 200 | 120 | 60 °C | 0.000 | 800 / 800 |
| P-B vypnuta, tick 300 | 60 | 80 °C | 0.233 | 600 / 600 |

První tick po commandu sníží pouze rozbíhající se průtok; pokud je cooling capacity ještě dostatečná, MW se nezmění okamžitou skriptovanou penalizací. Pokles výkonu vznikne až z následného cooling deficitu a downstream omezení.

Runner navíc podporuje `--pump-a=on|off`, `--pump-b=on|off`, `--disable-after=P-A|P-B`, `--after-ticks=<int>` a dřívější load/ticks/reset argumenty.

### Finální stav M1 akceptace

| ID | Stav | Důkaz |
|---|---|---|
| AC-001 | PASS | Healthy-load test zachoval monotónní a ustálený requested load → MW vztah. |
| AC-002 | PASS | Izolovaný test ověřil `MW × simulated hours`; zero-power scénáře nepřidávají MWh. |
| AC-003 | PARTIAL | Nulový výkon → nulový přírůstek MWh je ověřen. BR-A ještě podle scope neexistuje. |
| AC-004 | PASS | Pump flow test a pump-loss cascade ověřily flow i downstream dopad; runner jej reprodukuje. |
| AC-011 | PASS | Boundary/no-cooling testy a tři 100 000tickové soak konfigurace zůstaly v clampech bez NaN/INF nebo driftu. |
| AC-023 | PASS | Replay zahrnuje shodnou sekvenci load i P-A/P-B commandů a porovnává celý M1 snapshot. |

M1 je `DONE`; následující část zaznamenává navazující implementaci M2.

## M2 — equipment, sensors a referenční failure

Roadmap status: `DONE` (2026-09-04).

M2 rozšiřuje fixed-step simulaci bez závislosti na scéně nebo UI. Autoritativní pořadí jednoho kroku je:

```text
requested load
→ P-B bearing wear a failure phase
→ condition/efficiency a průtok P-A/P-B přes skutečné polohy V-A/V-B
→ cooling, teplota a plant stress
→ interní generated MW
→ export přes BR-A a integrace MWh
→ sensor pipelines
→ alarm rules nad reported hodnotami
```

### Datový a runtime model

- `ComponentDefinition` a `PumpDefinition` jsou typované Resources. Šest MVP zařízení používá stabilní ID `P-A`, `P-B`, `V-A`, `V-B`, `BR-A`, `PG-A`; jejich definice jsou v `data/equipment/`.
- `ComponentState` drží `device_id`, `definition_id`, operational state, condition, wear a revision. `PumpState`, `ValveState`, `BreakerState` a `SensorState` přidávají pouze typově specifická data.
- `EquipmentSystem` vlastní runtime zařízení, senzorické kanály a malé zařízení-specifické command API. Neodkazuje na `Node` ani UI.
- `BearingIncidentSystem` je explicitní implementace jediného M2 incidentu. `BearingFailureDefinition` v `data/incidents/p_b_bearing_failure.tres` drží wear funkci, prahy fází a parametry symptomů.
- P-B prochází `HEALTHY → LATENT → WORN → DEGRADED → FAILING → FAILED`. Condition průběžně snižuje efficiency a flow a zvyšuje vibration, bearing temperature a current proxy.
- `SensorState` odděluje `actual_value` a `reported_value` a podporuje deterministické režimy `NORMAL`, `BIASED`, `FROZEN` a `DELAYED` s omezenou historií.
- `AlarmSystem` vyhodnocuje datové rules nad reported centrální telemetrií, používá hysterezi a zachovává historii. Acknowledge mění pouze `acknowledged`, nikoli symptom nebo `active`.
- `actual_power_mw` ve snapshotu znamená výkon exportovaný přes BR-A. `generated_power_mw` je interní výkon; při `OPEN`/`TRIPPED` BR-A může zůstat kladný, ale MWh se neintegrují.

### Autoritativní commandy M2

| Cíl | Action ID | Výsledek |
|---|---|---|
| `P-A`, `P-B` | `start`, `stop`, `inspect` | Změna provozu nebo kvalitativní lokální inspekce. |
| `V-A`, `V-B` | `set_position` | Nastaví target i actual pozici; reported pozici vytváří vlastní sensor pipeline. |
| `BR-A` | `open`, `reset` | Odpojí nebo připojí export. Debug cesta navíc umí `trip`. |

Generická akce `repair` neexistuje. `service_bearing`, prerequisites prostředků a ekonomika patří do pozdějšího scope a v M2 nejsou potřeba pro tři povinné reakce.

### Headless debug runner M2

Úplný autoritativní snapshot včetně komponent, actual/reported senzorů, failure runtime a alarmové historie:

```powershell
& $godotConsole --headless --path $projectPath --script 'res://debug/simulation_runner.gd' -- --load=1.0 --ticks=30 --failure-phase=DEGRADED --sensor=S-COOLANT-FLOW:BIASED:8:0 --valve-mismatch=V-A:0:1 --breaker=trip --alarms
```

Nové argumenty:

- `--condition=P-A|P-B:<0..1>` a `--wear=P-A|P-B:<0..1>`;
- `--failure-phase=HEALTHY|LATENT|WORN|DEGRADED|FAILING|FAILED`;
- `--sensor=<sensor-id>:NORMAL|BIASED|FROZEN|DELAYED[:bias][:delay_ticks]`;
- `--valve-mismatch=V-A|V-B:<actual>:<reported>`;
- `--breaker=open|trip|reset`, `--ack-alarm=<instance-id>` a `--alarms`.

Původní M1 argumenty zůstávají podporované.

### M2 automatické ověření

Stejný příkaz jako pro M1 nyní spouští 11 zachovaných M1 testů a 13 M2 testů:

```powershell
& $godotConsole --headless --path $projectPath --script 'res://tests/run_tests.gd'
```

Ověřený výsledek: `passed=24 failed=0`. Významné deterministické metriky výchozího tuningu:

| Scénář | MWh | P-B wear | Plant stress | Flow |
|---|---:|---:|---:|---:|
| S-002 normal, 1500 ticků | 1114.125 | 0.015940 | 0.000 | — |
| S-002 overload, 1500 ticků | 1480.500 | 0.141888 | 0.150 | — |
| Reduce load z condition 0.55, 800 ticků | 434.225 | 0.459225 | 0.000 | 100.067 |
| Switch P-B z condition 0.55, 800 ticků | 458.583 | 0.454728 | 0.617 | 60.000 |
| Continue/risk z condition 0.55, 800 ticků | 759.197 | 0.578551 | 0.218 | 94.131 |

Akcelerovaný timeline test zachytil všechny fáze v pořadí `HEALTHY@10`, `LATENT@40`, `WORN@127`, `DEGRADED@318`, `FAILING@543`, `FAILED@710`. Replay hash úplného M2 snapshotu byl v obou shodných bězích `6ac229c739ea971de8709bf73ce46d8ec797f89ffc28d2d6d0555be9b1a87a20`.

### M2 akceptace

| ID | Stav | Automatický důkaz |
|---|---|---|
| AC-003 | PASS | `open_breaker_stops_export_not_internal_simulation` |
| AC-005 | PASS | `overload_degrades_p_b_faster_than_normal` |
| AC-006 | PASS | `bearing_choices_have_distinct_consequences` |
| AC-007 | PASS | `p_b_condition_reduces_efficiency_and_flow` |
| AC-008 | PASS | `p_b_failure_timeline_has_ordered_phases_and_symptoms` |
| AC-009 | PASS | Stejný timeline ověřuje mechanical, thermal/electrical a system symptomy. |
| AC-010 | PASS | `bearing_choices_have_distinct_consequences` |
| AC-011 | PASS | M1 boundary/soak testy a `m2_failure_soak_stays_finite_and_bounded` |
| AC-012 | PASS | Sensor unit test, `lying_valve_sensor_does_not_change_physical_flow` a PG-A divergence |
| AC-016 | PASS | Alarm acknowledge, hystereze a test použití reported hodnoty |
| AC-017 | PASS | `device_ids_and_commands_are_specific` + debug snapshot; mapování do budoucí 3D scény zůstává scope M3. |
| AC-023 | PASS | `deterministic_replay_matches_snapshot` porovnává celý M2 snapshot a hash. |

M2 záměrně neobsahuje 3D/UI, role, multiplayer, persistence, ekonomiku ani servis spotřebním předmětem. BR-A reset v M2 nemá fuse/prerequisite; takové pravidlo je volitelné pro tento řez a souvisí až s fyzickou interakcí a ekonomikou pozdějších milníků.
