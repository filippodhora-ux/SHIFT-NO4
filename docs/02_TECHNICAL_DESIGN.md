# SHIFT №4 — Technical Design Document

## 1. Cíl architektury

Technické řešení musí umožnit rychle ladit a automaticky testovat propojenou elektrárenskou simulaci, aniž by pravidla žila v UI nebo 3D scénách. Stejný autoritativní model obsluhuje lokální prototyp, host-client multiplayer, ukládání a debug nástroje.

Priority:

1. deterministické a čitelné chování;
2. oddělení definice, runtime stavu a prezentace;
3. malý end-to-end vertical slice;
4. serverová autorita bez dvojí simulační logiky;
5. rychlá změna balancu přes data;
6. diagnostika a testovatelnost;
7. rozšiřitelnost pouze v místech známé variability.

## 2. Technologický baseline

- Godot 4.x; před zahájením implementace zapsat přesnou minor verzi z `project.godot`/CI.
- Typed GDScript jako výchozí jazyk.
- PC jako první platforma.
- Godot high-level multiplayer API s ENet pro vývojový host/client režim.
- Pevný autoritativní simulační krok: výchozích 10 Hz (`0.1 s`).
- Git; textové `.tres` a `.tscn` soubory, pokud to nástroje projektu dovolí.
- Test runner zvolit podle stavu repozitáře; čisté modely musí jít spustit bez renderované 3D mapy.

C# je přípustné pouze po doložení konkrétního profilačního nebo integračního důvodu. V jednom subsystému se nemíchají jazyky bez potřeby.

## 3. Navržená struktura projektu

```text
res://
├── app/
│   ├── game_flow.gd
│   └── composition_root.gd
├── simulation/
│   ├── plant_simulation.gd
│   ├── simulation_clock.gd
│   ├── plant_snapshot.gd
│   └── systems/
│       ├── heat_source_system.gd
│       ├── cooling_system.gd
│       ├── steam_system.gd
│       ├── turbine_system.gd
│       └── electrical_system.gd
├── equipment/
│   ├── definitions/
│   ├── runtime/
│   ├── pumps/
│   ├── valves/
│   ├── breakers/
│   └── sensors/
├── incidents/
│   ├── failure_definition.gd
│   ├── failure_runtime.gd
│   ├── failure_system.gd
│   └── alarm_system.gd
├── shifts/
│   ├── shift_manager.gd
│   ├── quota_system.gd
│   ├── economy_system.gd
│   └── maintenance_system.gd
├── interaction/
│   ├── interactable.gd
│   ├── interaction_command.gd
│   └── interaction_controller.gd
├── multiplayer/
│   ├── session_manager.gd
│   ├── authority_gateway.gd
│   └── replication/
├── persistence/
│   ├── save_service.gd
│   ├── save_game_dto.gd
│   └── migrations/
├── presentation/
│   ├── operator/
│   ├── technician/
│   ├── world_devices/
│   ├── menus/
│   └── shared/
├── debug/
│   ├── debug_panel.gd
│   ├── debug_commands.gd
│   └── session_metrics.gd
├── data/
│   ├── plant/
│   ├── equipment/
│   ├── incidents/
│   ├── quota/
│   └── economy/
├── levels/
├── tests/
│   ├── unit/
│   ├── simulation/
│   ├── integration/
│   └── multiplayer/
└── project.godot
```

Strukturu přizpůsob existujícím konvencím repozitáře. Nevytvářej prázdné adresáře ani soubory pro budoucí systémy.

## 4. Domény a vlastnictví stavu

| Doména | Vlastní | Nevlastní |
|---|---|---|
| `PlantSimulation` | simulační čas, agregovaný stav procesů, pořadí systémů | UI, síťové peer objekty, ceny |
| `EquipmentSystem` | runtime stav komponent a aplikaci commandů | alarmovou prezentaci, hráčský inventář |
| `FailureSystem` | aktivaci a vývoj poruch podle příčin | náhodné okamžité damage eventy |
| `AlarmSystem` | aktivní/historické symptomatické alarmy a acknowledge | skrytou diagnózu komponenty |
| `ShiftManager` | stavový automat směny a její hranice | výpočet fyzikálních hodnot |
| `QuotaSystem` | MWh, target, směny a výsledek kvótního cyklu | okamžitý MW |
| `EconomySystem` | společné kredity, nabídku a transakce | fyzickou opravu zařízení |
| `MaintenanceSystem` | povolené servisní operace a jejich výsledek | obecnou interakci hráče |
| `AuthorityGateway` | validaci a směrování hráčských commandů | vlastní kopii simulace |
| `SaveService` | serializaci, verzi a migraci | živé doménové rozhodování |
| Prezentace | zobrazení snapshotů, vstup a feedback | autoritativní gameplay stav |

## 5. Aplikační stavový automat

```text
BOOT
  → MAIN_MENU
  → LOBBY
  → BRIEFING
  → IN_SHIFT
  → DEBRIEF
  → MAINTENANCE
  → BRIEFING (další směna)
  → RUN_COMPLETE
  → MAIN_MENU
```

Pouze autorita mění stav. Přechod obsahuje důvod, identifikátor směny a monotónní revision. Klienti zobrazují stav z replikovaného snapshotu.

`IN_SHIFT` lze ukončit hráčským potvrzením, dosažením definované nestability nebo debug commandem. Dosažení kvóty samo přechod nevyvolá.

## 6. Pevný simulační krok

`SimulationClock` akumuluje čas z `_physics_process(delta)` nebo autoritativního loopu a volá `PlantSimulation.step(step_seconds)` po pevných krocích. Výchozí `step_seconds = 0.1`.

Pravidla:

- pořadí subsystémů je explicitní a testované;
- jeden step pracuje pouze s předchozím stavem a commandy připravenými pro daný tick;
- render frame nemění simulaci;
- při záseku se počet doháněných kroků omezuje konfigurovatelným `max_catch_up_steps` a zaznamená se diagnostika;
- UI dostává snapshoty a může interpolovat pouze prezentované hodnoty;
- stejný seed + počáteční stav + seřazené commandy + počet ticků dává stejný výsledek.

Doporučené pořadí MVP:

1. aplikovat validované commandy;
2. zařízení a elektrické napájení;
3. průtok/chlazení;
4. teplotní bilance a plant stress;
5. pára;
6. turbína a generátor;
7. opotřebení a poruchy;
8. senzory;
9. alarmy;
10. MWh, metriky a snapshot.

## 7. Abstraktní simulační model

Všechny fyzikální vztahy jsou záměrně herní aproximace. Tuning je v `PlantTuning` resource a výpočty mají explicitní clampy.

### 7.1 Normalizované vstupy

- `requested_load`: obvykle `0.0–1.05`, debug rozsah může být širší;
- `pump_speed`, `valve_position`, `condition`, `efficiency`: `0.0–1.0`;
- `cooling_factor`, `safe_capacity`: normalizované faktory;
- MW, MWh, teplota, tlak a průtok používají jednotky konzistentní v UI, ale nepředstírají reálný závod.

### 7.2 Kauzální výpočty

Konceptuální vztahy, ne povinný přesný kód:

```text
pump_effective_flow_i = rated_flow_i
                      × commanded_speed_i
                      × condition_efficiency_i
                      × power_available_i

coolant_flow = sum(pump_effective_flow_i) × valve_network_factor
cooling_capacity = coolant_flow × heat_exchange_efficiency

target_thermal_power = nominal_thermal_power × requested_load
thermal_power = approach(thermal_power, target_thermal_power, heat_ramp_rate × dt)

heat_imbalance = thermal_power - cooling_capacity
coolant_temperature += heat_imbalance / thermal_mass × dt

safe_capacity = f(coolant_flow, coolant_temperature, equipment_limits)
plant_stress = smooth_clamped(
    load_stress(requested_load, safe_capacity)
    + temperature_stress(coolant_temperature)
)

steam_available = f(thermal_power, coolant_state, steam_efficiency)
turbine_available = f(steam_available, turbine_condition, turbine_load)
electrical_power_mw = min(turbine_available, generator_capacity)
                    × generator_efficiency
                    × breaker_connected

simulated_hours = dt × simulated_hours_per_real_second
energy_produced_mwh += electrical_power_mw × simulated_hours
```

Používej exponenciální nebo rychlostně omezené přiblížení namísto okamžitých skoků tam, kde trend tvoří gameplay. Každá dělící hodnota má spodní mez, každý normalizovaný faktor clamp a test hranic.

### 7.3 Opotřebení

```text
wear_delta = base_wear_per_sim_hour
           × load_curve(load_ratio)
           × temperature_curve(temperature_ratio)
           × stress_curve(plant_stress)
           × existing_damage_multiplier
           × simulated_hours

condition = clamp(condition - wear_delta, 0.0, 1.0)
```

Křivky jsou Resources nebo `Curve`, ne větvení rozeseté po kódu. Stavový label je odvozený z definovaných prahů, ale přechod do `FAILED` může vyžadovat konkrétní failure condition.

## 8. Datový model zařízení

### 8.1 Definice

`ComponentDefinition : Resource` obsahuje neměnná designová data:

- `definition_id: StringName`
- `display_name: String`
- `component_type: StringName` nebo úzký enum
- nominální kapacitu/spotřebu a provozní limity;
- condition thresholds a výkonové křivky;
- podporované failure definition ID;
- servisní operace a vizuální/audio prezentační klíče.

Specializované definice (`PumpDefinition`, `ValveDefinition`, `SensorDefinition`) přidávají pouze typově specifická pole.

### 8.2 Runtime stav

`ComponentState` je živý autoritativní model:

- `device_id: StringName` — unikátní instance, např. `P-A`;
- `definition_id`, `location_id`;
- `operational_state`;
- `condition`, `wear`, `temperature`, `pressure`, `vibration` podle relevance;
- typově specifický stav;
- aktivní failure instance ID;
- revision/tick poslední změny.

Runtime stav neodkazuje na `Node3D`. World presenter mapuje `device_id` na scénový uzel.

### 8.3 Snapshot

`PlantSnapshot` je read-only pohled vytvořený autoritou pro UI, replikaci a debug. Běžný klientský snapshot neobsahuje skrytou diagnózu ani data, na která role nemá oprávnění. Debug snapshot může být úplný.

## 9. Senzory a pravda

Pipeline:

```text
skutečná veličina
  → převod senzoru
  → bias/noise/delay/failure state
  → reported value
  → alarmové pravidlo a operator UI
```

`actual_value` zůstává vlastnictvím simulace. Sensor uchovává buffer pro zpoždění a vlastní stav. Noise musí být deterministický ze seedu nebo předem připravené sekvence.

Lokální měřidlo může používat jiný senzor než centrální telemetrie. Tím lze vytvořit smysluplný rozpor, aniž by se přepisovala pravda v simulaci.

## 10. Poruchový model

`FailureDefinition : Resource`:

- stabilní `failure_id`;
- povolené typy komponent;
- prerequisites a activation thresholds;
- fáze a rychlosti progrese;
- mutace skutečného stavu;
- lokální symptom descriptors;
- alarm rule references;
- podporované mitigation/repair action ID;
- persistent flag a save data;
- debug label a testovací seed.

`FailureRuntime` uchovává fázi, závažnost, čas aktivace a zdroj. `FailureSystem` vyhodnocuje předpoklady a postup, ale nevytváří UI texty.

MVP nepotřebuje obecný grafový engine. Jedna explicitní implementace ložiska pumpy je vhodnější než univerzální DSL, pokud rozhraní umožní později přidat další failure definition.

## 11. Alarmový model

Alarm instance obsahuje:

- `alarm_instance_id`, `alarm_rule_id`;
- autoritativní tick/timestamp;
- priority;
- source `device_id` nebo system ID;
- lokalizační message key a parametry;
- `active`, `acknowledged`, `cleared_at_tick`;
- revision.

Alarmové pravidlo pracuje s reportovanými hodnotami, pokud jde o centrální telemetrii. Hystereze zabraňuje blikání u prahu. Acknowledge nemění zdrojovou veličinu ani `active`.

## 12. Command model a interakce

Všechny gameplay změny vstupují do autority jako command:

```text
Command {
  command_id
  actor_peer_id
  actor_role
  target_device_id
  action_id
  parameters
  requested_tick
}
```

Autorita ověří:

- správný stav hry;
- roli a oprávnění;
- existenci a aktuální revision cíle;
- vzdálenost/line of sight u fyzické interakce;
- provozní prerequisites;
- parametry, cooldown a dostupný prostředek.

Výsledek vrátí accepted/rejected, reason code a novou revision. Klient může okamžitě zobrazit animaci vstupu, ale stav zařízení mění až potvrzený výsledek.

Generické rozhraní interakce nabízí `get_options(context)`, `begin`, `commit`, `cancel`. Konkrétní zařízení definuje dostupné akce. Pumpa nemá akci `repair`; má například `inspect`, `isolate`, `service_bearing`, `start` a `stop` s vlastními prerequisites.

## 13. Události a závislosti

Používej úzce zaměřené Godot signals na vlastnících domén:

- `component_state_changed(device_id, revision)`
- `failure_phase_changed(failure_instance_id, phase)`
- `alarm_created(alarm_instance_id)`
- `alarm_cleared(alarm_instance_id)`
- `shift_state_changed(previous, current)`
- `quota_progress_changed(mwh)`
- `authoritative_snapshot_ready(snapshot)`

Signál oznamuje dokončenou změnu; nemá být skrytým command busem. Přímé explicitní volání je vhodné pro deterministickou posloupnost systémů. Globální EventBus se přidá jen po vzniku skutečného many-to-many problému.

## 14. Multiplayer

### 14.1 Autorita

Host/server vlastní:

- SimulationClock a PlantSimulation;
- všechna ComponentState a FailureRuntime;
- ShiftManager, QuotaSystem, EconomySystem a persistence;
- role assignment a command validation;
- autoritativní RNG seed.

Klienti vlastní vstup, kameru, lokální presentation a predikci čistě kosmetického pohybu. Neintegrují MWh, wear ani failure progression.

### 14.2 Replikace

- Spolehlivé RPC: role, stavové přechody, command výsledky, alarm create/clear/ack, transakce, důležité komponentové změny.
- Periodický snapshot: výkon, telemetrie a průběžné hodnoty vhodné k interpolaci.
- Role-filtered payload: Operátor a Technik nemusí dostat stejná pole. Skrytí pouze v UI nestačí, pokud má být informace skutečně asymetrická.
- Každý stav nese revision; starší update se ignoruje.
- Late join/reconnect nejsou v MVP, ale snapshot nesmí předpokládat přehrání celé historie.

### 14.3 Síťový vývojový cíl

Jeden hráč založí ENet session, druhý se připojí adresou v lokální síti nebo localhostem. Role se zvolí v lobby; server odmítne duplicitní povinnou roli pro 2-player MVP.

## 15. Persistence

Save DTO obsahuje pouze data potřebná mezi směnami:

```text
SaveGameDTO
  schema_version
  run_id
  rng_seed
  quota_cycle_state
    current_shift
    allowed_shifts
    target_mwh
    produced_mwh
  economy_state
    crew_credits
    inventory_counts
  component_states[]
    device_id
    definition_id
    condition/wear/damage
    major operational flags
    persistent failures[]
  selected difficulty/tuning IDs
```

Do not serializovat scény nebo Node reference. Načtení probíhá `parse → schema validation → migration → domain reconstruction → invariant validation`. Zápis je atomický přes dočasný soubor a nahrazení cíle. Uložená hra není bezpečnostní hranice; neplatná data se odmítnou s čitelnou chybou.

MVP ukládá při přechodu do maintenance a před startem další směny. Manuální save během aktivního ticku není potřeba.

## 16. UI architektura

UI čte role-specific snapshot/view model a posílá commandy. Nečte ani nemění ComponentState přímo.

Operator minimum:

- requested load control a actual MW;
- MWh/target, směna a zbývající čas;
- cooling performance a plant stress trend;
- stavy P-A/P-B a jističe podle telemetrie;
- klíčové teploty/tlaky/průtoky;
- aktivní alarmy, historie a acknowledge;
- ruční žádost o ukončení směny.

Technician minimum:

- first-person controller;
- focus prompt s `device_id`, názvem akce a prerequisite;
- lokální gauge/indicator;
- kvalitativní inspect výsledek;
- stav probíhající servisní akce;
- jasný potvrzovací a chybový feedback.

Každý status má text/symbol vedle barvy. Telemetrické grafy používají fixní časové okno a konzistentní měřítko.

## 17. Debug a observabilita

Debug panel je dostupný jen v debug buildu nebo explicitním dev flagu. Povinné commandy:

- set requested load;
- pause/step/time scale simulace;
- nastavit/add condition nebo wear zařízení;
- změnit sensor mode/bias;
- fail/clear konkrétní failure;
- zapnout/vypnout pumpu, nastavit ventil a jistič;
- přidat MWh/kredity/položku;
- start/end shift a reset run;
- zobrazit úplný snapshot, seed, tick a revisions.

Log kategorie: `[SIM]`, `[DEVICE]`, `[FAILURE]`, `[ALARM]`, `[SHIFT]`, `[QUOTA]`, `[NET]`, `[SAVE]`. Loguj přechody a odchylky, ne každý tick. Každý incident lze filtrovat podle `device_id` a ticku.

Session metrics jsou lokální strukturovaný JSON nebo CSV v user data, bez externí telemetrie v MVP.

## 18. Testovací strategie

Podrobnosti a akceptace jsou v `06_VALIDATION_AND_ACCEPTANCE.md`.

### 18.1 Unit

- křivky condition → efficiency;
- MW × simulated hours → MWh;
- prahy, hystereze a alarm acknowledge;
- sensor bias/frozen/delay;
- command validation;
- save round trip a migrace.

### 18.2 Simulace

- deterministický replay;
- stabilita při min/max vstupech;
- vypnutí pumpy sníží průtok a ovlivní downstream výkon;
- overload zrychlí wear;
- referenční failure vytvoří očekávanou posloupnost symptomů;
- dlouhý soak nezpůsobí NaN, INF ani nekontrolovaný drift.

### 18.3 Integrace

- kompletní jedna směna;
- ruční end shift;
- nákup/maintenance a druhá směna se zachovaným stavem;
- quota success i failure;
- role-specific informační pohled.

### 18.4 Multiplayer

- klient nezmění autoritativní stav bez commandu;
- neplatná role/target/range/prerequisite je odmítnuta;
- dva klientské pohledy odpovídají jednomu serverovému stavu;
- MWh a wear se neintegrují dvakrát;
- pozdní nebo přeházený snapshot nepřepíše novější revision.

## 19. Výkonové rozpočty MVP

- Autoritativní simulační step v cílové mapě: měřitelně pod 10 ms na běžném vývojovém PC; cílem je výrazná rezerva k 100ms kroku.
- Žádná alokace velkých kolekcí v každém ticku bez profilačního důvodu.
- Snapshot rate se ladí odděleně od 10Hz simulation ticku.
- Historie trendů používá kruhové buffery s pevnou kapacitou.
- Počet aktivních MVP zařízení a senzorů je malý; předčasná optimalizace nebo ECS nejsou opodstatněné.

## 20. Konvence

- Soubory a proměnné: `snake_case`; class names: `PascalCase`; stabilní content IDs: uppercase krátký kód s pomlčkou (`P-A`, `V-A`, `BR-A`).
- Signály popisují minulou změnu (`alarm_created`), commandy záměr (`request_set_load`).
- `delta` vždy uvádí, zda jde o real seconds, simulation seconds nebo simulated hours.
- Každá Resource hodnota má jednotku v názvu nebo inspector hintu (`rated_power_mw`, `delay_seconds`).
- Clamp, fallback a failure reason nejsou tiché; významná korekce se loguje.
- Komentáře vysvětlují invariant, záměr nebo neobvyklý kompromis.

## 21. Technická Definition of Done změny

Změna je hotová, pokud:

1. implementuje chování aktivního milníku bez rozšíření scope;
2. nemá parser/build chyby a neprodukuje nové runtime error logy v dotčeném toku;
3. má relevantní automatické testy nebo zdokumentovaný důvod, proč je ověření manuální;
4. respektuje autoritu, determinismus a oddělení model/prezentace;
5. tuning není skrytý v magických číslech;
6. debug nástroj dovolí nový stav bezpečně vyvolat a pozorovat, pokud jde o simulační systém;
7. jsou aktualizována dotčená AC a pouze nezbytná dokumentace;
8. výsledný report uvádí soubory, ověření, omezení a následující jediný logický krok.

