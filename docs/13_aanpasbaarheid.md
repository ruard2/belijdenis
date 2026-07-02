# Aanpasbaarheid

Dit project moet makkelijk te veranderen en uit te breiden blijven.

## Ontwerpregels

1. Content staat in database, niet in code.
2. Blocktypes hebben een duidelijk contract.
3. Nieuwe content mag geen migration vereisen.
4. Nieuwe blocktypes mogen bestaande content niet breken.
5. Admin-formulieren volgen het blocktype.
6. Publiceren is gescheiden van bewerken.
7. Soft delete waar gebruikersdata of contenthistorie relevant is.
8. Configuratie staat in environment variables.

## Wat makkelijk aanpasbaar moet zijn

- cursustitel
- cursusbeschrijving
- cursusafbeelding
- hoofdstukken
- hoofdstukvolgorde
- blockvolgorde
- blockinhoud
- quizvragen
- reflectievragen
- XP-waarden
- badges
- media
- zichtbaarheid van responses
- groepsinstellingen

## Wat bewust codewerk mag zijn

- nieuw blocktype
- nieuwe schermflow
- nieuw permissiemodel
- nieuwe storageprovider
- nieuwe authprovider
- nieuwe analyticslaag

## Versiebeheer van content

Bij publicatie wordt een snapshot opgeslagen in `content_versions`.

Daardoor kan later:
- een oude versie bekeken worden
- een publicatie worden teruggedraaid
- verschil tussen draft en published worden getoond
- getest worden welke content een leerling gezien heeft

## Configuratie

Gebruik environment variables voor:
- database
- JWT secret
- storage
- CORS
- environment
- uploadlimieten

Gebruik database/admininstellingen voor:
- XP-regels
- badge-regels
- cursusstatus
- groepsinstellingen

## Migrations

Gebruik Alembic voor schemawijzigingen.

Regel:

Kleine contentwijzigingen horen niet in migrations. Alleen structurele datamodelwijzigingen horen in migrations.

