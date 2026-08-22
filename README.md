# What's for Dinner

What's on the menu tonight? Whether you want to cook more organized every week,
let your kids vote on their favorite dishes, or simply avoid a bit of chaos,
"What's for Dinner" gives you the perfect overview. Free. No ads. No hidden
costs. Just you and your meals.

- Easily track your dishes or set priorities instead of fixed days.
- Switch between days or numbers if you prefer.
- Plan together: invite your partner and you both see every change right away.
- See what you're eating today, right in a handy widget or on your Apple Watch.
- Emoji magic: hundreds of dishes are recognized automatically.

Got brilliant ideas? Or a dish without an emoji yet? Email us at:
whatsfordinnerappios@gmail.com!

## How the planning works

The list is the plan: the dish on top is tonight's dinner. With *days instead of
numbers* switched on, each dish also shows the day it is up.

The list does not shift by itself while the app runs. Instead the plan stores an
anchor date, and every part of the app — iPhone, Apple Watch, widget,
complication — works out from the calendar which dish is up today. That is why
the widget still turns the page at midnight when the app has not been opened for
a week.

## Project layout

| Folder | What lives there |
| --- | --- |
| `DinnerCore/` | The model, the day arithmetic, storage and emoji matching. Compiled into every target. |
| `DinnerCore/Sync/` | iCloud syncing and sharing (CKSyncEngine), iOS only. |
| `DinnerCoreTests/` | Unit tests for everything in `DinnerCore`. |
| `What's for dinner/` | The iPhone app. |
| `DinnerWidget/` | Home screen widget. |
| `Watch App/`, `AppleWatchWidget/` | Apple Watch app and complications. |
| `Tools/` | `generate-emoji-catalog.py`, which regenerates the emoji keyword table from Unicode CLDR. |

Run the tests with:

```
xcodebuild test -scheme "What's for dinner" -destination 'platform=iOS Simulator,name=iPhone 17'
```

See [`Documentatie/iCloud-opzet.md`](Documentatie/iCloud-opzet.md) for what has to
be configured in the Apple Developer portal before sharing works.

## Privacy Policy

**1. Introduction**

Welcome to What's For Dinner! Your privacy is important to us. This Privacy
Policy explains how we handle your data. In short: we run no servers and we
collect nothing about you.

**2. Information we collect**

We collect, process and store no personal data. Your dishes, preferences and
meal history live on your device. We operate no servers and receive no copy of
your data.

**3. iCloud**

If you use iCloud, your list is stored in **your own iCloud account**, managed by
Apple under Apple's privacy policy. We have no access to it.

If you invite someone to plan together, the list is shared through Apple's
iCloud sharing with the people you invite, and with nobody else. They can see and
change the list you shared with them. You can stop sharing at any time in
Settings, which immediately removes their access.

**4. Automatic emoji**

Dishes are matched to an emoji using a word list built into the app. On devices
with Apple Intelligence, dishes that the word list does not recognise may also be
looked at by the language model **on the device itself**. The name of your dish
is not sent anywhere.

**5. Data storage and security**

- Your data stays on your device and, if you use iCloud, in your own iCloud account.
- We do not sell, share, or use your data for analytics or advertising.
- You have full control over your data and can delete it at any time.

**6. Sharing and third parties**

We share nothing with third parties. Data leaves your device only when you choose
to invite someone to your list.

**7. Your rights and choices**

- Delete your data at any time by clearing the list, or by removing the app.
- No app permissions are required beyond what is needed for core functionality.

**8. Changes to this Privacy Policy**

If we ever make adjustments, they will be reflected here and in the app settings.

**9. Contact us**

Questions about this Privacy Policy? Contact us at: whatsfordinnerappios@gmail.com
