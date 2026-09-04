# SHIFT №4 — specifikace MVP vertical slice

## 1. Účel

MVP odpovídá na otázku:

> Je pro dva hráče zábavné řídit porouchávající se elektrárnu s asymetrickými informacemi, když musí vyvažovat výrobu energie, opotřebení, údržbu a vícesměnovou kvótu?

MVP není samostatně prodejná hra ani demonstrace množství obsahu. Je to robustní malý experiment s jedním úplným loopem.

## 2. Povinný rozsah

### 2.1 Hráči a session

- 2 hráči přes host/client vývojovou session;
- role Operátor a Technik;
- lobby s volbou role a ready stavem;
- 2 navazující směny v jednom kvótním cyklu;
- ruční ukončení každé směny;
- quota success/failure po druhé směně.

### 2.2 Mapa

- jeden malý velín;
- krátká spojovací chodba;
- jedna strojovna / field maintenance area;
- jasné dveře, orientace a označení zařízení;
- žádné nepoužité místnosti.

### 2.3 Zařízení

| ID | Zařízení | Funkce |
|---|---|---|
| `P-A` | hlavní nebo záložní chladicí pumpa | lokální start/stop, inspect, servis; průtok |
| `P-B` | hlavní nebo záložní chladicí pumpa | referenční bearing failure |
| `V-A` | izolační/regulační ventil větve A | actual vs reported position |
| `V-B` | izolační/regulační ventil větve B | actual vs reported position |
| `BR-A` | výstupní jistič generátoru | trip/reset po splnění prerequisite; při rozpojení se nedodává MWh |
| `PG-A` | lokální měřidlo tlaku/průtoku | terénní informace odlišná od centrální telemetrie |

Simulace také obsahuje jeden abstraktní zdroj tepla, chladicí okruh, parní systém, turbínu a generátor. Nemusí mít každý vlastní 3D zařízení.

### 2.4 Gameplay systémy

- requested load a actual electrical output v MW;
- akumulace MWh přes konfigurovatelný převod času;
- cooling effectiveness, coolant flow/temperature a plant stress;
- stav, condition, wear a efficiency obou pump;
- skutečný a reportovaný stav nejméně jednoho ventilu/senzoru;
- jistič a dostupnost napájení;
- symptomatické alarmy, historie a acknowledge;
- referenční `P-B bearing degradation`;
- jednoduchá zařízení-specifická inspekce a údržba;
- společné kredity a tři položky;
- výsledky směny a persistence do druhé směny;
- debug panel a lokální session metrics.

## 3. Konfigurovatelné výchozí podmínky

Konkrétní čísla jsou playtest preset, ne hardcoded pravidla:

- 2 směny;
- cílové trvání směny 10–15 minut pro rychlý interní test;
- kvóta nastavená tak, aby ji nebylo spolehlivě možné splnit dvěma směnami při trvale nízkém loadu;
- trvalý overload musí bez zásahu před koncem směny přivést P-B alespoň do významně degraded/failing stavu;
- normální load musí umožnit dokončit jednu směnu bez automatického selhání;
- počáteční kredity a ceny musí nutit k nejméně jedné volbě, nikoli koupit vše.

Tuning preset bude Resource a po prvních měřeních se upraví.

## 4. Povinný průchod

### 4.1 Směna 1

1. Host založí session, klient se připojí.
2. Hráči zvolí Operátora a Technika a potvrdí ready.
3. Briefing ukáže kvótu, dvě dostupné směny, počáteční stav a zásoby.
4. Operátor spustí/zvýší load; skutečný MW se ustálí a MWh rostou.
5. Vyšší load měřitelně zrychlí wear P-B.
6. P-B začne mít vyšší vibrace/teplotu a nižší účinnost.
7. Operátor uvidí pokles průtoku nebo výkonu, trend a symptomatické alarmy.
8. Technik u P-B získá kvalitativní lokální symptomy a odečet PG-A.
9. Hráči spolu rozhodnou: snížit load, přepnout pumpu, servisovat, riskovat nebo směnu ukončit.
10. Zásah změní simulaci a telemetrii v očekávaném směru.
11. Hráči ručně ukončí směnu.

### 4.2 Mezisměna

1. Debrief ukáže MWh, průměrný load, dobu v high/overload, alarmy, zásahy, kredity a stav zařízení.
2. Hráči mohou koupit Repair Kit, Spare Fuse nebo Diagnostic Tool.
3. Mohou provést dostupný servis za kredity/položku.
4. Potvrzený stav se uloží.

### 4.3 Směna 2

1. Načte se quota progress, kredity, zásoby, condition a přetrvávající závady.
2. Hráči znovu zvolí risk podle zbývajících MWh.
3. Výsledek první směny skutečně mění udržitelný výkon a rozhodnutí.
4. Po ručním nebo systémovém konci se vyhodnotí quota success/failure.
5. Run summary ukáže rozhodnutí a doporučí nový run, ne další neimplementovaný obsah.

## 5. Referenční porucha P-B

### 5.1 Příčina

Bearing condition klesá provozem. High/overload, vysoká teplota a předchozí poškození zrychlují pokles.

### 5.2 Fáze

| Fáze | Skutečný stav | Operátor | Technik |
|---|---|---|---|
| Latentní wear | mírný pokles condition | bez alarmu, možný slabý trend | téměř běžný zvuk |
| Worn | vyšší teplota/vibrace | drobný pokles efficiency | hrubší zvuk, mírná vibrace |
| Degraded | nižší flow, vyšší current | `P-B CURRENT HIGH`, flow trend | jasná vibrace, lokální teplota |
| Failing | rychlý pokles flow, růst stress | `COOLANT FLOW LOW`, `COOLANT ΔT HIGH` | silný projev, servis rizikový za chodu |
| Failed | nulový/zanedbatelný přínos | systémový pokles a critical alarm | pumpa stojí nebo běží bez účinku |

Prahy a tempo jsou data-driven. Alarmy používají hysterezi.

### 5.3 Reakce

- snížení requested load: méně MWh, pokles stress a pomalejší degradace;
- start P-A a odstavení P-B: spotřeba/konfigurace se změní, ale průtok se obnoví;
- izolace a `service_bearing` se správným prostředkem: čas a zdroj za částečnou obnovu;
- vědomé pokračování: vyšší krátkodobá výroba, riziko major failure a horší další směna;
- ruční konec směny: zachová stav za cenu zbývající kvóty.

## 6. Interakce Technika

Minimum:

- pohyb, rozhlížení a mapovatelné ovládání;
- zaměření a identifikace zařízení;
- `inspect` s krátkým kvalitativním výstupem;
- ruční změna V-A/V-B;
- start/stop nebo lokální přepnutí pumpy podle jejího režimu;
- reset BR-A pouze po odstranění příčiny;
- servis P-B: `stop/isolate → consume Repair Kit or maintenance allocation → timed service → restart`;
- přerušení servisu při odchodu, změně stavu nebo poškození prerequisite.

Interakce poskytne konkrétní reason code, pokud není povolená. Univerzální `Hold E to repair anything` není součástí.

## 7. Operator UI

Jedna funkční průmyslová obrazovka nebo malá sada panelů:

- requested load control s bezpečným rozsahem a zřetelným overload pásmem;
- actual MW, MWh/target, číslo směny a zbývající čas/status;
- flow, coolant temperature, cooling efficiency a plant stress s trendy;
- P-A/P-B command/status podle reportované telemetrie;
- V-A/V-B reported position;
- BR-A status;
- active alarms, historie, priority a acknowledge;
- tlačítko/sekvence pro ruční end shift s potvrzením obou hráčů nebo jasným host pravidlem.

UI nesmí ukazovat skrytou bearing condition.

## 8. Ekonomika a předměty

| Položka | MVP účel | Omezení |
|---|---|---|
| Repair Kit | umožní jednu definovanou polní servisní akci | spotřební; nevrací zařízení automaticky na 100 % |
| Spare Fuse | umožní obnovit BR-A po odstranění příčiny | spotřební; reset během přetížení znovu selže |
| Diagnostic Tool | poskytne přesnější stav jedné podporované komponenty | omezené použití nebo cena; neodhalí globální řešení |

Všechny ceny, odměny, restore amount a počet použití jsou data-driven.

## 9. Debug minimum

- přesný úplný autoritativní stav;
- set load a time scale;
- nastavit wear/condition P-A/P-B;
- aktivovat/posunout/ukončit P-B failure;
- měnit stav senzoru a ventil actual/reported mismatch;
- trip/reset BR-A;
- přidat MWh, kredity a položky;
- start/end shift, uložit/načíst a resetovat run;
- zobrazit seed, tick, revisions a připojené role.

## 10. Co v MVP není

- třetí a čtvrtá role, solo automatizace;
- další typ poruchy jako povinný obsah;
- Incident Director;
- velká mapa a více provozních okruhů;
- reálné postupy, neutronová fyzika, radiace a detailní bezpečnostní systémy;
- komplexní inventář, crafting nebo repair minihry;
- vlastní voice chat, matchmaking, dedicated server, reconnect a host migration;
- příběhové mise, monstra, combat, procedural generation;
- final art, platformní služby a release optimalizace.

## 11. Definition of Done MVP

MVP je hotové pouze tehdy, když:

1. dva samostatné herní klienty lze připojit k jednomu hostiteli;
2. oba hráči dokončí popsaný dvousměnový průchod bez debug zásahu;
3. MW vzniká ze stavu simulace a MWh se akumulují pouze na autoritě;
4. load mění produkci, stress a rychlost opotřebení;
5. degradace P-B ovlivní průtok a downstream stav;
6. Operátor a Technik dostanou rozdílné, společně užitečné informace;
7. nejméně tři různé reakce na stejnou poruchu mají odlišné důsledky;
8. ruční end shift, debrief, nákup/servis a druhá směna fungují;
9. quota success i failure lze dosáhnout běžnou hrou;
10. save/load zachová povinný stav mezi směnami;
11. parser/build, cílené testy, simulační soak a multiplayer smoke test projdou;
12. nebyl přidán obsah z explicitních non-goals;
13. playtest data umožní rozhodnout o gameplay hypotéze.

Podrobná trasovatelná kritéria jsou v `06_VALIDATION_AND_ACCEPTANCE.md`.
