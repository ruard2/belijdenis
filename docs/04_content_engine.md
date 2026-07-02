# Content Engine

## Kernregel

Alle lessen bestaan uit blocks.

Een hoofdstuk is geen scherm in Flutter. Een hoofdstuk is een lijst blocks in de database.

## Entiteiten

```text
Course
  Chapter
    Block
```

## Block contract

Elke block heeft:
- id
- chapter_id
- type
- title
- order
- xp
- required
- content
- created_at
- updated_at

## Content JSON

De `content` kolom wordt opgeslagen als JSONB.

Voordelen:
- flexibel
- snel uitbreidbaar
- geschikt voor verschillende blocktypes
- minder migrations bij kleine contentvelden

Nadeel:
- validatie moet serieus genomen worden

Daarom:
- backend valideert per blocktype
- admin toont velden per blocktype
- tests controleren geldige en ongeldige content

## MVP blocktypes

- hero
- text
- reflection
- bible
- quiz
- slider
- sorting
- video
- audio
- gallery
- deep_dive
- tradition
- personal
- group_discussion
- challenge
- prayer
- promise

## Progress

Een block kan:
- not_started
- in_progress
- completed

Een hoofdstuk is afgerond wanneer alle verplichte blocks completed zijn.

## XP

XP wordt opgeslagen als event, niet alleen als totaal.

Reden:
- auditbaar
- later analytics mogelijk
- dubbele toekenning voorkomen
- herstel mogelijk

## Publicatie

Contentstatus:
- draft
- published
- archived

Leerlingen krijgen alleen published content.

Admins kunnen draft content previewen.

