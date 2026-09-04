# SHIFT №4 — Game Design Document

## 1. Dokument

- Stav: pre-production baseline
- Cílový engine: Godot 4.x
- Platforma: PC
- Hráči: 1–4; hlavní balance pro 2–4, MVP pro 2
- Žánr: kooperativní asymetrický systémový thriller / provozní simulace
- Perspektiva: Operátor používá stanoviště a systémová UI; terénní role se pohybují z první osoby
- Pracovní název: `SHIFT №4`

Tento dokument určuje cílový hráčský zážitek. Přesný první rozsah je v `03_MVP_VERTICAL_SLICE.md`; technické řešení v `02_TECHNICAL_DESIGN.md`.

## 2. High concept

Posádka jedné směny musí z chátrající fiktivní elektrárny vyrobit předepsané množství energie. Vyšší výkon rychleji plní kvótu, zároveň přehřívá a opotřebovává zařízení. Operátor vidí soustavu přes alarmy a nedokonalé senzory. Technici vidí a slyší skutečný stav zařízení na místě. Posádka uspěje jen tehdy, když si přesně předává neúplné informace a vědomě rozhoduje, jak velký technický dluh unese příští směna.

Jednovětá fantazie:

> „Jsme jediná posádka, která dokáže tuhle starou elektrárnu udržet v chodu — a zároveň ti, kdo ji tlakem na kvótu pomalu ničí.“

## 3. Designová hypotéza

Hra je zábavná, pokud propojí těchto pět věcí do jedné zpětné vazby:

1. posádka si sama zvolí výrobní riziko;
2. simulace vytvoří čitelné, ale ne zcela jednoznačné symptomy;
3. role obdrží rozdílné části pravdy;
4. komunikace vede k několika legitimním zásahům;
5. důsledky rozhodnutí přetrvají dost dlouho, aby na nich záleželo.

Pokud maximum výkonu, rychlá univerzální oprava nebo ignorování komunikace představují stabilně nejlepší strategii, hypotéza selhala.

## 4. Designové pilíře

### 4.1 Elektrárnu opravdu provozujeme

Hráči nečekají na izolované hádanky. Neustále nastavují zatížení, konfigurují tok, zapínají a odstavují zařízení, čtou trendy a plánují okamžik ukončení směny.

### 4.2 Každý drží jinou část pravdy

Operátor zná globální důsledky, ale jeho údaje mohou být zpožděné, zkreslené nebo odpojené. Technik vidí fyzický projev a lokální přístroj, ale nevidí celý systém ani kvótní situaci. Informace se doplňují a někdy si odporují.

### 4.3 Výkon je dobrovolné riziko

Vyšší load zvyšuje MWh za čas, opotřebení, tepelné zatížení a zmenšuje prostor pro chybu. Optimální hodnota se mění podle stavu elektrárny, zásob, času a kvóty.

### 4.4 Dnešní zkratka je zítřejší problém

Opotřebení, poškození, zásoby a část konfigurace se přenášejí mezi směnami. Hráči mohou získat krátkodobou výhodu za technický dluh, který musí později splatit.

### 4.5 Krize je důsledek systému

Porucha má příčinu a pozorovatelný vývoj. Náhodnost může volit počáteční podmínky nebo skrývat přesné prahy, ale nesmí bez příčiny odebrat hráčům možnost reagovat.

## 5. Identita a inspirační hranice

- Z `Keep Talking and Nobody Explodes` přebíráme hodnotu přesné komunikace a rozdělených informací, nikoli manuálové bombové puzzly.
- Z `Lethal Company` přebíráme tlak kvóty, společné riskování a mezisměnové nákupy, nikoli sběr šrotu, monstra nebo strukturu expedic.
- Z `Barotrauma` přebíráme propojené systémy a lokální opravy, nikoli její konkrétní zařízení, prostředí nebo combat.
- Z `Papers, Please` přebíráme pocit instituce, směn a následků rozhodnutí, nikoli kontrolu dokumentů.

Jedinečný hák hry je dobrovolné přetěžování důvěryhodné systémové simulace pod informační asymetrií.

## 6. Cílový formát

### 6.1 Herní relace

- Jedna směna: cílově 15–25 minut po ověření balancu.
- Jeden kvótní cyklus: 2–4 směny.
- Krátká briefing a maintenance fáze mezi směnami: 2–5 minut.
- Plný run: přibližně 45–90 minut podle počtu směn a obtížnosti.

Časy jsou playtestové cíle, nikoli závazné konstanty.

### 6.2 Cílové emoce

- zpočátku kompetence a rutina;
- postupně podezření, že údaje nedávají úplný obraz;
- tlak času a kvóty;
- společné rozhodnutí „ještě chvíli to vydrží“;
- uspokojení z diagnózy a stabilizace;
- lítost nebo hrdost nad následky v další směně.

Horor vychází z prostředí, zvuku, nejistoty a systémové ztráty kontroly. Monstrum není potřeba.

## 7. Herní smyčky

### 7.1 Kvótní cyklus

`zadání kvóty → směna → výsledky → údržba/nákup → přenos stavu → další směna → vyhodnocení kvóty`

Kvóta se měří v MWh, tedy v energii dodané během simulovaného času. Okamžitý výkon se zobrazuje v MW.

### 7.2 Směna

`briefing → kontrola stavu → rozběh → volba loadu → výroba → degradace → symptomy → diagnóza → zásah → nové provozní optimum → ruční ukončení`

Směna nekončí automaticky splněním kvóty. Posádka může pokračovat kvůli bonusu, rezervě do dalšího cyklu nebo záměrně skončit a šetřit zařízení.

### 7.3 Krizová mikrosmyčka

`odchylka → alarm/trend/lokální projev → potvrzení mezi rolemi → pracovní hypotéza → zásah → odezva systému → potvrzení nebo nová diagnóza`

Zásahy zahrnují snížení výkonu, změnu konfigurace, přepnutí na zálohu, izolaci komponenty, servis, bypass, vědomé pokračování a ukončení směny.

## 8. Role a škálování posádky

Detailní matice je v `04_MULTIPLAYER_AND_ROLES.md`.

### 8.1 Operátor

Pracuje primárně ve velínu. Nastavuje requested load, spravuje vzdáleně ovladatelná zařízení, sleduje trendy, alarmy, MW/MWh, rezervu chlazení a kvótu. Umí rychle ovlivnit celou soustavu, ale neumí na dálku potvrdit skutečný mechanický stav.

### 8.2 Technik

Pohybuje se v provozu. Identifikuje zařízení podle stabilních ID, čte lokální měřidla, poslouchá a pozoruje projevy, ručně ovládá ventily a jističe, izoluje zařízení a provádí specifické servisní úkony. Nevidí úplný systémový obraz.

### 8.3 Další specializace

Pro 3–4 hráče se odpovědnosti dělí na mechanickou, elektrickou/instrumentační a druhou operátorskou stanici. Obsah a souběžné incidenty škálují s počtem rolí; číselné zdraví nepřátel ani prosté násobení práce se nepoužívá.

### 8.4 Solo

Solo je podpůrný režim. Jeden hráč přepíná mezi velínem a terénem; omezená automatizace drží poslední bezpečné nastavení. Některé alarmy a časování jsou shovívavější. Design se nebalancuje tak, aby solo mělo stejnou komunikační intenzitu jako co-op.

## 9. Informační asymetrie

Každý důležitý incident musí přidělit nejméně dvě relevantní informace různým rolím.

| Informace | Operátor | Technik |
|---|---:|---:|
| Celkový MW, MWh a kvóta | úplná | nepřímá / na vybraných displejích |
| Systémové trendy | úplné, podle senzorů | omezené lokální hodnoty |
| Skutečná poloha ventilu | pouze hlášená | vizuálně ověřitelná |
| Mechanická vibrace a zvuk | odvozená nebo žádná | přímá kvalitativní informace |
| Skutečné opotřebení | skryté | skryté, odhad podle symptomů/nástroje |
| Alarmová historie | úplná | jen lokální majáky nebo rádio |
| Fyzická dostupnost zařízení | neúplná | přímá |
| Zbývající zásoby a kredity | úplné mezi směnami | sdílené mezi směnami |

UI nesmí zobrazovat přesné `condition = 0.37` během běžné hry. Používá stavy, trendy, zvuk, symboly a přibližné diagnostické výsledky. Debug režim přesná čísla zobrazit smí.

## 10. Model elektrárny

Elektrárna používá abstraktní kauzální řetězec:

`zdroj tepla → chladicí okruh → tvorba páry → turbína → generátor → síťový výkon`

Hráčsky významné veličiny:

- requested load a skutečný výkon;
- průtok a teplota chladiva;
- účinnost chlazení a plant stress;
- tlak/tvorba páry;
- zatížení a dostupný výkon turbíny;
- stav generátoru a jističe;
- okamžitý MW a akumulované MWh.

Model je deterministický při stejném seedu, vstupech a simulačních krocích. Hodnoty jsou laditelné a stabilní. Vztahy musí být pro hráče vysvětlitelné bez znalosti reálné jaderné fyziky.

## 11. Zařízení

### 11.1 Společné vlastnosti

Každá významná komponenta má ID, typ, lokaci, provozní stav, condition, wear, teplotu a seznam podporovaných poruch. Stavový slovník:

`OFF → STARTING → RUNNING → DEGRADED → FAILING → FAILED`, vedlejší stav `MAINTENANCE`.

Přechody jsou výsledkem hodnot a zásahů. Prahy jsou data-driven.

### 11.2 Pumpa

Pumpa převádí elektrické napájení a mechanickou kondici na průtok. Sleduje stav ložiska, motoru, těsnění, teplotu, vibrace, odběr a účinnost. Zhoršení ložiska postupně zvyšuje vibrace a teplotu, snižuje účinnost a může zvýšit proud.

### 11.3 Ventil

Ventil má `actual_position`, `target_position`, průtokový koeficient a stav aktuátoru. `reported_position` pochází ze senzoru a může se lišit. Závady zahrnují zaseknutí, selhání aktuátoru, chybu polohového snímače a netěsnost.

### 11.4 Jistič

Jistič `BR-A` v MVP připojuje generátor k výstupní síti. Při rozpojení je exportovaný výkon a přírůstek MWh nulový, i když vnitřní části elektrárny mohou dál běžet a vytvářet stress. Může vypadnout při přetížení nebo poruše. Reset bez odstranění příčiny vede k opakovanému vybavení; to učí posádku diagnostikovat místo bezmyšlenkovitého spamování. Pozdější pomocné napájecí větve dostanou vlastní zařízení a ID.

### 11.5 Senzor a lokální měřidlo

Senzor přijímá skutečnou hodnotu a vytváří report pomocí přesnosti, biasu, noise, zpoždění a provozního stavu. Režimy zahrnují `NORMAL`, `BIASED`, `FROZEN`, `NOISY`, `INTERMITTENT`, `OFFLINE` a `DELAYED`.

## 12. Degradace, poruchy a alarmy

### 12.1 Degradace

Základní pravidlo:

`wear_rate = base_wear × load_multiplier × temperature_multiplier × stress_multiplier × damage_multiplier`

Opotřebení je při běžném provozu pomalé, při overloadu nelineárně roste. Odpočinek opotřebení nevrátí; servis jej částečně nebo plně řeší podle typu zásahu.

### 12.2 Porucha

Každá porucha obsahuje:

- příčinu a podmínky aktivace;
- latentní a aktivní fázi;
- skutečné změny komponenty;
- systémové a lokální symptomy;
- možné způsoby potvrzení;
- nejméně dvě rozumné reakce;
- důsledky ignorování, bypassu a opravy;
- stav persistence mezi směnami.

### 12.3 Alarm

Alarm popisuje pozorovaný symptom, ne skrytou příčinu. Správné příklady: `COOLANT FLOW LOW`, `P-B CURRENT HIGH`, `COOLANT ΔT HIGH`. Nevhodný alarm: `P-B BEARING FAILURE`, pokud tuto diagnózu žádný systém přímo nepotvrdil.

Priority: advisory, warning, critical. Acknowledge umlčí opakované zvukové upozornění, ale nezruší aktivní stav.

### 12.4 Incident Director

Director je post-MVP. Vybírá pouze incidenty, jejichž technické předpoklady odpovídají stavu elektrárny, tempu směny, zatížení a již aktivním problémům. Nesmí vytvářet nečitelný trest nebo rušit rozehranou diagnózu bez designového důvodu.

## 13. První referenční incident

`P-B bearing degradation`:

1. vysoké zatížení zrychluje pokles bearing condition;
2. pumpa se zahřívá a více vibruje;
3. účinnost klesá a proud může růst;
4. průtok chlazení klesá;
5. teplotní rozdíl a plant stress rostou;
6. Operátor vidí kombinaci trendů a symptomatických alarmů;
7. Technik slyší hrubší chod, vidí vibraci a odečte lokální teplotu/tlak;
8. posádka sníží load, odstaví P-B a zapne P-A, provede omezený servis, nebo riskuje pokračování.

Žádná jednotlivá informace nemá automaticky prozradit celé řešení.

## 14. Kvóta, odměny a maintenance

### 14.1 Kvóta

- `MW` je okamžitý elektrický výkon.
- `MWh` je energie dodaná do kvóty.
- Kvótní cíl, počet směn a převod herního času jsou konfigurovatelné.
- Splnění cíle neukončí aktuální směnu automaticky.
- Nesplnění cíle se vyhodnotí po poslední povolené směně.

### 14.2 Ekonomika

Posádka používá společné kredity. Příjem vychází zejména z dodané energie, dokončení směny a volitelných provozních bonusů; přesné vzorce patří do tuning dat. Ekonomika vytváří volbu mezi preventivním servisem, spotřebním materiálem a rezervou.

MVP položky:

- Repair Kit: umožní omezený mechanický servis;
- Spare Fuse: obnoví elektrický prvek po odstranění příčiny;
- Diagnostic Tool: zpřesní nebo urychlí jednu lokální diagnózu.

### 14.3 Maintenance fáze

Po směně hráči vidí dodané MWh, dobu v provozních pásmech, nové závady, odhad stavu a náklady. Rozhodují o servisu a nákupu. Nemají mít dost zdrojů na úplné obnovení všeho.

## 15. Výhra, selhání a pokračování

- Soft failure: komponenta funguje hůře, ale systém lze provozovat.
- Major failure: komponenta je nedostupná a posádka musí rekonfigurovat nebo snížit výkon.
- Shift failure: posádka směnu ukončí, nebo elektrárna nedokáže udržet minimální stabilní stav.
- Quota success: po povolených směnách je dosažen cílový počet MWh.
- Quota failure: po poslední směně je MWh pod cílem.

Game over nemá vznikat z jediné skryté náhodné události. Kritický konec musí mít čitelnou eskalaci a příležitost k rozhodnutí, pokud hráči předtím vědomě nepřijali riziko.

## 16. Obtížnost a férovost

Obtížnost může měnit kvótu, počáteční stav, rychlost opotřebení, informační šum, dostupné kredity a souběh incidentů. Nemá měnit význam stejných přístrojů nebo tajně porušovat kauzalitu.

Férový incident splňuje:

- alespoň jeden včasný symptom před nevratným následkem;
- alespoň dvě role mohou přispět relevantní informací nebo zásahem;
- hráči mohou zpětně vysvětlit, proč nastal;
- existuje bezpečná, pomalejší reakce a riskantní, produktivnější reakce;
- selhání zanechá užitečnou lekci, ne dojem libovůle.

## 17. UX a přístupnost

- Stav se nikdy nesděluje pouze barvou; používá text, ikonu/tvar, zvuk a případně pohyb.
- Každé zařízení má stejné ID ve světě, UI, alarmech a komunikaci.
- Operátor do několika sekund pozná výkon, kvótu a trend stability.
- Technik snadno rozezná interaktivní části bez permanentního vizuálního šumu.
- Alarmy mají titulky a rozlišitelné priority; důležité zvuky mají vizuální ekvivalent.
- Nastavitelné titulky, hlasitosti, citlivost, FOV a mapování ovládání jsou cílové minimum pro release.
- Voice chat je vhodný pozdější doplněk. MVP lze testovat přes externí hlasovou komunikaci.

## 18. Audiovizuální směr

Pozdní 80. léta, průmyslový brutalismus, opotřebený kov, analogové a raně digitální prvky. Prostředí působí věrohodně jako fikční zařízení, ale neprezentuje se jako přesná kopie reálné elektrárny.

Zvuk je herní informace:

- stabilní chod má čitelný základní rytmus;
- vibrace, kavitace, jiskření, netěsnost a přetížení mají odlišné projevy;
- vzdálenost, dveře a okolní hluk ovlivňují slyšitelnost;
- control room alarmy a terénní projevy nesou různé části informace.

Placeholder vizuály jsou pro MVP přijatelné, stavový a zvukový feedback povinný.

## 19. Narativní rámec

Příběh podporuje směny, kvótu a institucionální tlak. Briefingy, formuláře, hlášení a změny požadavků mohou vytvářet kontext. Narativ nesmí zastínit systémovou hru ani vyžadovat cutscény v MVP.

Obsah používá fiktivní zemi, organizaci, technologii a názvosloví. Inspirace dobovou estetikou nesmí sklouznout k historickému tvrzení nebo výukovému simulátoru.

## 20. Metriky a balance cíle

Pro každou směnu zaznamenáváme lokálně:

- průměrný a maximální requested/actual load;
- čas v low/normal/high/overload pásmu;
- vyrobené MWh;
- počet a typ alarmů;
- čas od prvního symptomu k pracovní diagnóze a zásahu;
- přepnutí zařízení, servisní akce a spotřebované položky;
- důvod a okamžik ukončení směny;
- přenesené opotřebení a výsledek kvóty.

Playtest sleduje, zda hráči komunikovali spontánně, zda chápali příčinu a následek a zda alespoň jednou debatovali o riziku namísto mechanického následování jediné správné odpovědi.

## 21. Non-goals pro MVP

- reálná jaderná fyzika nebo provozní procedury;
- monstra, boj, zbraně a survival metry;
- velká elektrárna, procedural generation a více typů závodů;
- komplexní inventář, crafting a desítky repair miniher;
- příběhová kampaň, NPC, skill tree a kosmetika;
- matchmaking, dedikované servery, host migration, reconnect a vlastní voice backend;
- finální art, pokročilé animace, achievementy, Steam integrace a konzole;
- implementace 3–4 player obsahu před validací dvouhráčového MVP.

## 22. Hlavní produktová rizika

| Riziko | Signál | Reakce |
|---|---|---|
| Simulace je neprůhledná | Hráči hádají bez pracovní hypotézy. | Zlepšit trendy, lokální symptomy a konzistenci, ne odhalit skryté procento. |
| Jedna strategie dominuje | Vždy maximum nebo vždy bezpečný low load. | Upravit kvótu, nelineární wear, odměny a počáteční stav. |
| Operátor hraje sám | Technik jen vykonává přesné příkazy. | Přidat kvalitativní lokální informaci a zásahy, které operátor nemůže provést. |
| Technik čeká | Málo fyzických rozhodnutí mezi incidenty. | Krátké inspekční trasy, preventivní kontroly a souběžná příprava. |
| Opravy jsou rutina | Vždy stejná univerzální interakce. | Zařízení-specifické předpoklady a volby bez přidání dexterity miniher. |
| Síťování diktuje design pozdě | Offline model vlastní stav v UI/scéně. | Od začátku oddělit autoritu, stav, commandy a prezentaci. |
| Scope roste | Přibývá obsah před celým loopem. | Milníkové exit podmínky a explicitní non-goals. |

## 23. Otevřené otázky k playtestu

Tyto položky nejsou blokátory první implementace:

- optimální délka směny a kvótního cyklu;
- zda je příjem kreditů navázaný čistě na MWh, nebo i na stav elektrárny;
- kolik přesnosti má poskytovat Diagnostic Tool;
- zda při splnění kvóty existuje bonus za bezpečný stav, za přebytek, nebo obojí;
- zda se role volí na celý run, nebo se mohou mezi směnami měnit;
- jak velkou automatizaci potřebuje solo režim;
- kolik souběžných incidentů je čitelných pro 3–4 hráče.
