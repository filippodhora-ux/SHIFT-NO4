# Porovnání a syntéza původních Codex promptů

## Výsledek

Nejlepší základ nevzniká výběrem jednoho promptu. Prompt A je lepší technická specifikace systémové simulace. Prompt B je lepší produktová specifikace hratelného vertical slice. Výsledná dokumentace používá hloubku promptu A uvnitř scope a dokončovacích podmínek promptu B.

Sloučený přístup má tři vrstvy:

1. stručný produktový kontrakt a pevné zákazy v `AGENTS.md`,
2. samostatné designové a technické dokumenty jako zdroj pravdy,
3. krátký outcome-first Codex prompt s právě jedním aktivním milníkem.

Tím se odstraní opakování obou původních promptů a agent nemusí v každém kroku znovu interpretovat desítky stran instrukcí. Struktura odpovídá současnému doporučení v [oficiální OpenAI dokumentaci](https://developers.openai.com/api/docs/guides/latest-model): jasně definovat výsledek, kritéria úspěchu, omezení, ověření a podmínku zastavení.

## Srovnání

| Oblast | Prompt A | Prompt B | Výsledné rozhodnutí |
|---|---|---|---|
| Herní identita | Silný systémový thriller, jasný konflikt výroba–bezpečnost–stav. | Silná hráčská fantazie a konkrétní ukázka komunikace. | Zachovat obojí; hráčská komunikace je důsledek systémů, ne skriptovaný puzzle. |
| Simulace | Detailní kauzální řetězec teplo–chlazení–pára–turbína–generátor. | Jednodušší load–wear–performance model. | Dvouvrstvý abstraktní model: jednoduché veřejné chování, uvnitř kauzální řetězec bez realistické jaderné fyziky. |
| Poruchy | Výborné oddělení příčiny, symptomů, diagnózy a následků; senzory mohou lhát. | Správně požaduje degradaci místo náhodného game overu. | Převzít model A, ale pro MVP implementovat jedinou hlubokou poruchu z B-size scope. |
| MVP scope | Foundation prototyp, ale 3 pumpy a 8–12 ventilů jsou pro první řez široké. | Přesný malý prostor, 2 pumpy, 2 ventily, jistič a měřidlo. | MVP používá 2 pumpy, 2 ventily, 1 jistič a 1 lokální měřidlo. Architektura podporuje další obsah bez jeho předčasné výroby. |
| Hratelný cíl | První úkol ověřuje hlavně simulaci přes debug UI. | Popisuje kompletní dvouhráčovou, dvousměnovou cestu. | Vývoj začne headless simulací, ale MVP není hotové bez dvouhráčové dvousměnové smyčky. |
| Multiplayer | Správný host-authoritative model, multiplayer odložen. | Vyžaduje dva připojené hráče ve first playable. | Síťování je samostatný milník po ověření simulace; release MVP jej povinně obsahuje. |
| 1–4 hráči | Cíl 1–4, první fáze 2. | Výslovně 2 a zakazuje 3–4 v prototypu. | Stejně: produkt 1–4, MVP 2. Solo a 3–4 jsou navržené, neimplementované před validací. |
| Směny a persistence | Dobré dlouhodobé cíle, ale foundation je neověřuje. | Konkrétní dvě směny, výsledky, obchod a přenos stavu. | Povinný dvousměnový MVP s verzovaným save stavem a minimální ekonomikou. |
| Opravy | Správně odmítá univerzální „Hold E to repair“. | Prototyp navrhuje jednoduché držení interakce. | Jednoduché, ale zařízení-specifické sekvence: izolovat, použít správný prostředek, servisovat, znovu spustit. Žádná univerzální oprava všeho. |
| UX a feedback | Silné operator UI, alarmy a debug požadavky. | Silnější požadavek na čitelnost, zvuk a nepoužívání barvy jako jediného signálu. | Sloučit; zástupný art je přijatelný, informační design a audio feedback povinné. |
| Akceptace | Dobrá systémová kritéria. | Trasovatelná AC-001 až AC-018 a kompletní deliverables. | Jednotná číslovaná kritéria s automatickým nebo playtest ověřením. |
| Prompt ergonomie | Velmi podrobný, opakující se a náchylný k rozšiřování scope. | Lépe drží vertical slice, ale stále duplikuje velkou část GDD. | Master prompt odkazuje na dokumentaci a obsahuje pouze invarianty, workflow, DoD a aktuální úkol. |

## Co se zachovalo z promptu A

- konflikt výroby, bezpečnosti a technického stavu;
- výpočet MWh z okamžitého výkonu MW a simulovaného času;
- oddělení skutečného a reportovaného stavu senzoru;
- kauzální kaskády místo skriptované „havárie“;
- komponenty s data-driven definicí a odděleným runtime stavem;
- pevný simulační tick, testování bez 3D scény a interpolované UI;
- symptomatické alarmy, které neprozrazují diagnózu;
- povinné debug ovládání a logování významných změn;
- Godot 4.x, typed GDScript a host-authoritative multiplayer;
- první referenční závada pumpy s růstem vibrací, teploty a poklesem průtoku.

## Co se zachovalo z promptu B

- jedna přesně formulovaná gameplay hypotéza;
- nejmenší dvouhráčový vertical slice;
- jasná hráčská fantazie Operátora a Technika;
- dvousměnový průchod s výsledky, kredity, údržbou a persistencí;
- ruční ukončení směny jako strategické rozhodnutí;
- konkrétní first-playable scénář a číslovaná akceptační kritéria;
- jednoduchý společný rozpočet a tři prototypové položky;
- UX, audio feedback a metriky playtestu;
- zákaz monster, boje, realistické fyziky a předčasného obsahu;
- dokončení jednoho milníku včetně build/test/ověření před dalším.

## Vyřešené rozpory

### Detailní elektrárna vs. abstraktní model

Simulace zachová čitelnou cestu `zdroj tepla → chlazení → pára → turbína → generátor`, ale její hodnoty jsou herní abstrakce. Názvy, rozsahy ani postupy nemají představovat reálný jaderný provoz.

### Foundation vs. hratelný prototyp

Foundation je první implementační milník, nikoli výsledný MVP. Každý milník má vlastní exit kritéria; agent se po jejich splnění zastaví. Celkový MVP končí až po síťové dvousměnové smyčce.

### Dvě vs. tři pumpy

Dvě pumpy stačí k rozhodnutí „provozovat poškozenou / přepnout na záložní“. Třetí pumpa by v prvním řezu přidala stav a UI bez nové hypotézy. Datový model přidání dalších pump umožní později.

### Obecná vs. specifická oprava

MVP nepoužije minihru, ale ani globální opravu jedním tlačítkem. Pumpa vyžaduje odstavení a správný servisní prostředek; jistič vyžaduje odstranění příčiny a reset; ventil manuální manipulaci nebo servis aktuátoru.

### 1–4 hráči vs. dvouhráčový MVP

Dva hráči jsou nejmenší konfigurace, která čistě ověří informační asymetrii. Solo režim a rozdělení odpovědností pro 3–4 hráče jsou navržené v dokumentaci, jejich implementace následuje až po úspěšném MVP playtestu.

## Odstraněné nebo odložené části

- detailní RBMK terminologie a reálné provozní procedury;
- 8–12 ventilů, komplexní potrubní síť a více typů elektrárny v MVP;
- Incident Director před existencí dostatečného katalogu poruch;
- kampaň, reputace, příběhové cutscény, monstra, combat a procedural generation;
- voice backend, matchmaking, dedikované servery, host migration a reconnect pro první prototyp;
- univerzální frameworky, ECS přepis a singleton pro každý systém;
- pokyn implementovat neurčené další systémy „pokud zbývá čas“.

