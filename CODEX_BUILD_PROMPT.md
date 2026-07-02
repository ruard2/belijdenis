# Codex Build Prompt

Gebruik deze prompt als startpunt wanneer Codex de app echt moet bouwen.

## Opdracht

Bouw Houvast: een content-driven catechese-app met Flutter frontend, FastAPI backend, PostgreSQL database en Railway deployment.

## Absolute uitgangspunten

- Backend draait op Railway.
- Database is PostgreSQL.
- De app mag geen lessen of hoofdstukken hardcoded bevatten.
- Alle cursusinhoud wordt beheerd via database en admin-CMS.
- Hoofdstuk 1 en 2 uit `content-seeds/` zijn seed-content.
- Flutter bevat alleen generieke block-renderers.
- Admins kunnen cursussen, hoofdstukken, blocks, vragen, media, XP en publicatie aanpassen zonder codewijziging.
- Leerlingen zien alleen gepubliceerde content.
- Groepscontent is alleen zichtbaar voor groepsleden.

## Eerste implementatiefase

1. Scaffold FastAPI project.
2. Voeg SQLAlchemy/SQLModel en Alembic toe.
3. Maak database-tabellen uit `docs/06_datamodel.md`.
4. Voeg auth, rollen en groepstoegang toe.
5. Maak content-API en admin-API uit `docs/07_api_contract.md`.
6. Maak contentvalidatie voor blocktypes uit `templates/block.schema.json`.
7. Voeg seed-data toe uit `content-seeds/`.
8. Voeg `/health` endpoint toe.
9. Maak Railway-compatible configuratie.
10. Scaffold Flutter app met lesson renderer.
11. Bouw admin-CMS voor beheer van course/chapter/block.
12. Schrijf tests voor contentvalidatie, permissies en publicatieflow.

## Acceptatiecriteria

- Admin kan een cursus aanmaken.
- Admin kan hoofdstuk 1 en 2 aanpassen zonder code te wijzigen.
- Admin kan een nieuw hoofdstuk toevoegen zonder code te wijzigen.
- Admin kan blocks drag-and-drop ordenen.
- Leerling kan een gepubliceerd hoofdstuk doorlopen.
- Leerling kan voortgang en XP krijgen.
- Leerling kan een ontdekking plaatsen binnen eigen groep.
- Leerling kan een vraag stellen bij een block.
- Catecheet kan een vraag beantwoorden.
- Backend draait lokaal.
- Backend is deploybaar op Railway.
- Secrets staan niet in Git.

