# Open Beslissingen

Deze keuzes hoeven het plan niet te blokkeren, maar moeten voor of tijdens fase 1 bewust gemaakt worden.

## 1. Storage provider

Opties:
- Supabase Storage
- Cloudflare R2

Advies MVP:

Kies de provider die het snelst werkend is met signed upload URLs. Houd de backend abstract via `STORAGE_PROVIDER`, zodat wisselen later mogelijk blijft.

## 2. Authenticatie

Opties:
- eigen FastAPI JWT-auth
- Supabase Auth
- Auth0/Clerk

Advies MVP:

Start met eigen JWT-auth als eenvoud en controle belangrijk zijn. Kies externe auth als social login, magic links of enterprise security snel nodig zijn.

## 3. Admin-CMS techniek

Opties:
- Flutter Web binnen dezelfde codebase
- aparte webapp
- tijdelijke admin via backend/forms

Advies MVP:

Flutter Web is logisch als het team vooral Flutter bouwt. Houd admin-API los genoeg, zodat later alsnog een aparte webapp kan worden gebouwd.

## 4. Bijbelvertaling en licentie

Niet zomaar volledige Bijbelteksten opslaan of tonen zonder licentie.

Keuzes:
- alleen referenties opslaan
- externe Bijbel-API gebruiken
- licentie regelen voor specifieke vertaling
- korte citaten binnen toegestane grenzen gebruiken

Advies MVP:

Sla references op en maak tekstvelden optioneel. Vul volledige teksten pas in nadat licentie/bron helder is.

## 5. Leeftijd en toestemming

Als minderjarigen meedoen, moeten privacy en toestemming zorgvuldig worden ingericht.

Keuzes:
- minimumleeftijd
- ouder/verzorger-toestemming
- kerk/gemeente als organisator
- bewaartermijnen

Advies MVP:

Leg minimaal vast dat persoonlijke reflecties standaard prive zijn en dat groepscontent alleen zichtbaar is voor groepsleden.

## 6. App distributie

Opties:
- eerst web/PWA
- daarna iOS/Android
- meteen native mobile

Advies MVP:

Begin met Flutter die web en mobile aankan, maar release eerst intern/web als testversie.

