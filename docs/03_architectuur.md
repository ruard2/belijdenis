# Architectuur

## Overzicht

```text
Flutter app
  -> REST API via FastAPI
    -> PostgreSQL
    -> Storage provider
```

## Componenten

### Flutter leerling-app

Verantwoordelijk voor:
- login
- cursusoverzicht
- hoofdstukoverzicht
- lesson player
- block rendering
- progress UI
- groep/community UI
- vragen UI

### Flutter admin-CMS

Kan als Flutter Web adminomgeving binnen dezelfde repo starten.

Verantwoordelijk voor:
- cursusbeheer
- hoofdstukbeheer
- blockbeheer
- media kiezen/uploaden
- preview
- publiceren
- groepsbeheer
- basis moderatie

### FastAPI backend

Verantwoordelijk voor:
- authenticatie
- autorisatie
- contentvalidatie
- publicatieflow
- voortgang
- XP-events
- communitydata
- vragen/antwoorden
- media metadata
- Railway healthcheck

### PostgreSQL

Verantwoordelijk voor:
- content
- versies
- gebruikers
- groepen
- voortgang
- community
- vragen
- XP

### Storage

Verantwoordelijk voor:
- afbeeldingen
- audio
- video
- thumbnails
- uploads

De database bewaart alleen metadata en verwijzingen.

## Content-rendering

De frontend vraagt een gepubliceerd hoofdstuk op:

```text
GET /chapters/{chapter_id}
```

De API retourneert:
- chapter metadata
- ordered blocks
- block content JSON
- progress status
- toegestane acties

Flutter kiest per `block.type` de juiste renderer.

## Uitbreidbaarheid

Nieuwe content:
- via CMS toevoegen
- geen codewijziging nodig

Nieuwe blocktypes:
- backend-validatie toevoegen
- Flutter-renderer toevoegen
- admin-editor toevoegen
- bestaande content blijft werken

