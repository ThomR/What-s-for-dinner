# iCloud instellen voor het delen van een lijst

De code voor het delen staat er, maar CloudKit werkt pas als de container in het
Apple Developer-portaal bestaat en het schema is aangemaakt. Dit is het deel dat
niet in de repository kan staan en dat jij één keer moet doen.

Alles hieronder is **niet gecontroleerd op een echt apparaat** — de simulator
heeft geen iCloud-account en er is geen tweede account om mee te testen. Reken op
een ronde bijschaven bij de eerste echte test.

## 0. Eerst: mag je account dit wel?

Loopt Xcode vast op

> Cannot create a iOS App Development provisioning profile for
> "nl.whatsfordinner.app". Personal development teams, including "Thom Rietberg",
> do not support the Push Notifications and iCloud capabilities.

dan is dit vastgesteld (2026-08-21):

- Het team `G6QPW9QY9Q` signeert de app **wel** gewoon voor een echt toestel,
  zolang iCloud en push niet in de entitlements staan. Team en certificaat zijn
  dus in orde.
- De profielen die dat team uitgeeft hebben `TimeToLive = 365`, wat hoort bij een
  betaald account; een gratis personal team krijgt 7 dagen.
- Toch weigert Apple een profiel zodra iCloud of push erin zit, en noemt het team
  daarbij "personal".

Dat wijst op iets aan de accountkant, niet aan de projectkant. Kijk op
[developer.apple.com/account](https://developer.apple.com/account):

1. Staat het **membership** nog actief, of is het verlopen? Een verlopen
   Developer Program-lidmaatschap valt terug op het gratis niveau, en dat
   ondersteunt precies deze twee capabilities niet. Dat zou meteen verklaren
   waarom de app uit de App Store verdwenen is.
2. Staat er een **openstaande overeenkomst** klaar ("Review Agreement")? Zolang
   die niet geaccepteerd is, weigert het portaal wijzigingen aan capabilities.
3. Let op dat er twee teams op deze Mac staan die allebei "Thom Rietberg" heten:
   `G6QPW9QY9Q` (dit project) en `XA392BM9XT` (het personal team, gebruikt door
   Vermogen). In de teamkiezer van Xcode staat achter de gratis variant
   "(Personal Team)".

### Intussen doorwerken zonder iCloud

Er staat een tweede entitlements-bestand klaar zonder iCloud en push. Omzetten
kan zonder het project te verbouwen, via de instelling `DINNER_ENTITLEMENTS`:

```
xcodebuild -scheme "What's for dinner" -destination 'generic/platform=iOS' \
  DINNER_ENTITLEMENTS="WhatsForDinner-Lokaal.entitlements" build
```

In Xcode: *Build Settings* → zoek op `DINNER_ENTITLEMENTS` → zet de waarde op
`WhatsForDinner-Lokaal.entitlements`.

De app werkt daarmee volledig; alleen het delen blijft uit. `CloudSync` ziet dat
er geen iCloud-account beschikbaar is en zet zichzelf uit, dus er gaat niets
kapot. Zet de waarde terug op `What's for dinner.entitlements` zodra het account
weer in orde is.

## 1. Capabilities in Xcode

Open het project, selecteer het target **What's for dinner** → *Signing &
Capabilities*, en voeg toe:

- **iCloud** → vink *CloudKit* aan → container `iCloud.nl.whatsfordinner.app`.
  Bestaat die nog niet, klik dan op `+` en typ hem exact zo.
- **Push Notifications**.
- **Background Modes** → *Remote notifications*.

De entitlements staan al goed in
`What's for dinner/What's for dinner.entitlements`; Xcode moet ze alleen nog aan
je account koppelen. Bij het uploaden naar de App Store hoort `aps-environment`
op `production` te staan — Xcode regelt dat zelf bij een archive.

## 2. Het schema aanmaken

CloudKit maakt recordtypes in de *development*-omgeving vanzelf aan zodra de app
ze voor het eerst wegschrijft. Doe dus dit, in deze volgorde:

1. Draai de app op een echt toestel met een iCloud-account.
2. Voeg een paar gerechten toe en streep er één af.
3. Open het [CloudKit-dashboard](https://icloud.developer.apple.com/) en
   controleer of de recordtypes `Dish`, `ServedMeal` en `Plan` in de zone
   `MealPlan` staan.

Het schema dat de app gebruikt:

| Recordtype | Velden |
| --- | --- |
| `Dish` | `name` (String), `emoji` (String), `addedAt` (Date) |
| `ServedMeal` | `name` (String), `emoji` (String), `servedOn` (Date) |
| `Plan` | `anchorDate` (Date), `order` (List of String) — één per zone, recordnaam `plan` |

De recordnaam van een `Dish` en een `ServedMeal` is de UUID van het gerecht. Zo
kan hetzelfde gerecht op twee toestellen tegelijk bestaan zonder te verdubbelen.

4. Zet het schema daarna over naar productie met **Deploy Schema Changes** in het
   dashboard. Zonder die stap werkt delen wel in een debug-build en niet in
   TestFlight of de App Store.

## 3. Testen met z'n tweeën

1. Installeer de app op twee toestellen met **verschillende** iCloud-accounts.
2. Op toestel A: *Instellingen* → *Samen plannen* → **Nodig iemand uit**. Stuur de
   uitnodiging via Berichten.
3. Open de uitnodiging op toestel B. De app hoort te openen en de lijst van A over
   te nemen.
4. Voeg op B een gerecht toe. Op A hoort dat binnen enkele seconden te verschijnen,
   ook als de app daar op de achtergrond staat.

Werkt stap 3 niet, controleer dan `CKSharingSupported` in `InfoApp.plist` (staat
er) en of de bundle-id in het portaal dezelfde container heeft.

## 4. Wat bewust nog niet gebeurt

- **De Apple Watch praat niet zelf met iCloud.** De Watch krijgt de lijst van de
  iPhone via WatchConnectivity. Wijzigt je partner iets terwijl jouw iPhone dicht
  is, dan wekt de pushmelding je iPhone, die het meteen doorstuurt. De Watch
  rekent de dagwissel wél zelf uit, dus daarvoor is de iPhone niet meer nodig.
  CloudKit rechtstreeks op de Watch is de volgende stap; die kon hier niet getest
  worden omdat er geen watchOS-simulator geïnstalleerd is.
- **Eén gedeelde lijst tegelijk.** Ben je uitgenodigd voor andermans lijst, dan is
  dat de lijst die de app toont. Je kunt niet tegelijk je eigen lijst delen én
  meedoen aan die van een ander; dat zou betekenen dat er twee lijsten zijn en
  dat is precies de verwarring die we willen vermijden.
- **Het logboek wordt meegedeeld.** Wie meedoet ziet ook wat er eerder gegeten is.
