# SHIFT №4 — multiplayer a role 1–4 hráčů

## 1. Záměr

Cílová hra podporuje 1–4 hráče, ale její role nejsou čtyři povolání s oddělenými schopnostmi. Jsou to informační a provozní odpovědnosti. S počtem hráčů se mění jejich rozdělení, souběh práce a prostor; nemění se základní pravidla elektrárny.

Dvouhráčová konfigurace je designový střed a MVP. Je nejmenším testem skutečné mezilidské informační asymetrie.

## 2. Pravidla škálování

- Každá konfigurace musí pokrýt velín, fyzický provoz a schopnost ukončit/stabilizovat směnu.
- Přidání hráče dělí odpovědnost a dovolí více souběžných úloh; nesmí pouze násobit počet stejných oprav.
- Kritický incident nemá vyžadovat konkrétní počet hráčů bez odpovídajícího difficulty/content presetu.
- Základní simulační parametry a význam zařízení zůstávají stejné.
- Počet/tempo incidentů, velikost aktivní zóny, dostupnost vzdáleného ovládání a detail telemetrie mohou používat crew-size preset.
- Hráčská role určuje view model a povolené commandy, ne vlastnictví autoritativního stavu.

## 3. Konfigurace posádky

| Počet | Rozdělení | Zážitek |
|---:|---|---|
| 1 | Shift Lead se přepíná mezi velínem a terénem; omezená automatizace drží poslední bezpečný režim | podpůrný solo/training režim, nižší časový tlak |
| 2 | Control Operator + Field Technician | základní asymetrie a MVP |
| 3 | Control Operator + Mechanical Technician + Electrical/Instrumentation Technician | paralelní terénní diagnóza a opravy |
| 4 | Process Operator + Turbine/Electrical Operator + Mechanical Technician + Instrumentation Technician | dvě stanoviště velínu, dvě terénní specializace, více souběžných rozhodnutí |

Názvy specializací jsou pracovní. Před implementací 3–4 player obsahu se ověří srozumitelnost a vytížení v playtestu.

## 4. Odpovědnosti rolí

### 4.1 Control / Process Operator

- requested load a celkový tepelný/procesní stav;
- cooling/steam trendy, system alarms a kvóta;
- vzdálené pumpy a ventily, pokud mají funkční napájení/aktuátor;
- koordinace priorit a žádost o konec směny;
- nevidí skutečný mechanický stav ani fyzickou dostupnost.

### 4.2 Turbine / Electrical Operator

Pouze pro čtyři hráče nebo rozšířený obsah:

- turbine load, generator output, breaker/switchgear a elektrické alarmy;
- balancing odběru pomocných systémů a dodávky do sítě;
- spolupráce s Process Operátorem při změně loadu;
- nevidí detailní stav chlazení ani lokální elektrické projevy.

### 4.3 Mechanical Technician

- pumpy, ventily, netěsnosti, vibrace a mechanické izolace;
- lokální měřidla, zvuk a fyzická konfigurace;
- zařízení-specifický mechanický servis;
- omezený globální přehled.

### 4.4 Electrical/Instrumentation Technician

- jističe, napájecí větve, aktuátory, senzory a kalibrace;
- porovnávání lokálních a centrálních odečtů;
- reset/pojistka/diagnostika až po odstranění příčiny;
- omezený procesní a kvótní přehled.

## 5. Solo režim

Solo nezkouší simulovat konverzaci s AI. Zachová přepínání kontextu a rozhodovací tlak:

- hráč může u definovaných terminálů opustit velín a převzít terénní avatar;
- při odchodu se requested load uzamkne a automatizace provádí pouze předem zvolenou bezpečnostní reakci, například snížení loadu při critical alarmu;
- přenosný pager sdělí prioritu alarmu, ne plnou telemetrii;
- pause je volitelný accessibility/training preset; standardní solo běží dál;
- incident tempo, servisní čas a kvóta používají solo preset;
- žádná informace není úplně ztracená, ale získání obou stran stojí čas a cestu.

Solo se implementuje až po dvouhráčovém MVP, protože může maskovat chyby v co-op informačním designu.

## 6. Informační kontrakt

### 6.1 Serverový interní stav

Autorita zná úplnou pravdu: actual values, condition, failures, sensor pipelines, role a command history.

### 6.2 Role-specific view

Server nebo autoritativní view-model builder vytváří pro každou roli povolený snapshot:

- Operátor dostane centrální reported telemetry, alarmy a globální produkci.
- Terénní role dostanou pouze data z aktuálně pozorovaného/interagovaného zařízení a sdílené minimum.
- Debug role dostane úplný stav pouze v development buildu.

Skryté hodnoty se neposílají běžnému klientu jen s příznakem `hidden`; tím se omezuje náhodné odhalení UI kódem a cheaty. Release bezpečnost však není cílem MVP.

### 6.3 Pravidlo incidentu

Každá schválená porucha musí mít informační mapu:

| Pole | Příklad |
|---|---|
| Globální symptom | průtok klesá, proud roste |
| Lokální symptom | vibrace, zvuk, teplota |
| Konflikt/nejistota | centrální sensor je opožděný nebo ventil reportuje nesprávnou polohu |
| Potvrzovací akce | lokální gauge, inspect, Diagnostic Tool |
| Koordinovaný zásah | Operátor sníží load, Technik izoluje a přepne pumpu |

Incident bez rozdělené užitečné informace neověřuje hlavní pilíř a nepatří do první obsahové sady.

## 7. Komunikace

MVP předpokládá externí voice chat. Herní design podporuje i text/ping:

- stabilní a krátká device ID;
- ping s ID, lokací a obecným záměrem, nikoli automatickou diagnózou;
- repeatable inspect text;
- timestamps/trendy ve velínu;
- subtitle/caption pro významné lokální zvuky.

Pozdější proximity/radio voice nesmí být prerequisite gameplaye bez dostupné textové alternativy.

## 8. Lobby a role

MVP lobby:

1. host otevře session a zobrazí adresu/port pro dev připojení;
2. klient se připojí;
3. každý zvolí jednu z rolí;
4. server ověří právě jednoho Operátora a jednoho Technika;
5. oba označí ready;
6. server vytvoří run seed, loadne nebo založí autoritativní stav a přejde do briefingu.

Odpojení v MVP může ukončit session s čitelnou zprávou. Reconnect a převzetí role jsou post-MVP.

## 9. End shift rozhodnutí

Výchozí pravidlo pro 2-player MVP: Operátor zahájí žádost a oba hráči ji potvrdí do konfigurovatelného okna. Při critical nestabilitě může autorita směnu ukončit sama. Pokud je druhý hráč odpojen, session se řeší podle disconnect pravidla, ne čekáním bez konce.

Pro solo potvrzuje hráč sám. Pro 3–4 hráče se později playtestuje většina vs. Shift Lead, ale systém musí vždy zobrazit, kdo konec navrhl a potvrdil.

## 10. Síťové akceptační minimum

- plant simulation běží jednou na hostiteli;
- klientské commandy jsou validované a idempotentní podle `command_id`;
- role nemůže provést zakázanou nebo vzdálenou field interakci;
- obě role vidí konzistentní důsledky jednoho autoritativního ticku;
- role-specific data neobsahují skryté diagnosis fields;
- kvóta, kredity a persistence mají jediného vlastníka;
- UI zvládne krátké zpoždění bez změny gameplay hodnot na klientu;
- disconnect je detekován a srozumitelně ukončí nebo pozastaví dev session.

