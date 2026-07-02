# Houvast

Professioneel projectplan voor een content-driven catechese-app.

Werknaam:

> Samen God leren kennen

Doel van deze map:
- een compleet bouwplan bewaren
- Codex duidelijke context geven voor implementatie
- inhoud, techniek en planning makkelijk aanpasbaar houden
- voorkomen dat lessen hardcoded in de app komen

## Korte kern

Houvast is een generieke christelijke leer-, vormings- en community-engine. De app toont cursussen, hoofdstukken en blocks die door een admin/catecheet beheerd worden via een CMS. Hoofdstuk 1 en 2 zijn seed-content, geen vaste schermen in Flutter.

Technische keuzes:
- Frontend: Flutter
- Backend: FastAPI
- Database: PostgreSQL
- Backend hosting: Railway
- Storage: Supabase Storage of Cloudflare R2

## Mapstructuur

```text
houvast/
  README.md
  CODEX_BUILD_PROMPT.md
  docs/
    00_samenvatting.md
    01_productvisie.md
    02_mvp_scope.md
    03_architectuur.md
    04_content_engine.md
    05_admin_cms.md
    06_datamodel.md
    07_api_contract.md
    08_ux_schermen.md
    09_security_privacy.md
    10_railway_deployment.md
    11_roadmap_backlog.md
    12_open_beslissingen.md
    13_aanpasbaarheid.md
  content-seeds/
    course_belijdenis.json
    chapter_001_ik_geloof_in_god.json
    chapter_002_de_wereld_is_van_god.json
  templates/
    block.schema.json
```

## Belangrijkste bouwregel

De app mag geen hoofdstukken, lessen, vragen, quizzen, XP-waarden of media hardcoded bevatten.

Wat wel in code zit:
- schermen
- navigatie
- authenticatie
- block-renderers
- validatie per blocktype

Wat niet in code zit:
- lesinhoud
- hoofdstukvolgorde
- vragen
- media
- quizopties
- XP per block
- publicatiestatus

## Aanbevolen werkwijze

1. Lees `docs/00_samenvatting.md`.
2. Gebruik `CODEX_BUILD_PROMPT.md` als startprompt voor implementatie.
3. Bouw eerst de backend, database en contentvalidatie.
4. Bouw daarna de Flutter leerling-app.
5. Bouw daarna admin-CMS en publicatieflow.
6. Voeg seed-content toe via de database, niet via hardcoded schermen.

## Nog te kiezen voor bouwstart

Zie `docs/12_open_beslissingen.md`.

De belangrijkste keuzes zijn:
- opslagprovider: Supabase Storage of Cloudflare R2
- auth-aanpak: eigen JWT of externe provider
- Bijbelvertaling en licenties
- admin-CMS als Flutter Web of aparte webapp
