# Security en Privacy

## Waarom dit belangrijk is

De app werkt mogelijk met jongeren, persoonlijke reflecties, foto's, groepsgesprekken en geloofsvragen. Privacy en veiligheid moeten vanaf het begin in de architectuur zitten.

## MVP-eisen

- JWT-authenticatie
- wachtwoorden gehashed opslaan
- rollen afdwingen in backend
- groepslidmaatschap controleren bij elke groepsresource
- prive-reflecties niet tonen aan groep
- soft delete voor community-content
- media type en grootte valideren
- CORS beperken tot bekende origins
- secrets via environment variables
- geen secrets in Git
- rate limiting op login en upload endpoints

## Zichtbaarheid

Block responses en ontdekkingen gebruiken visibility:
- private
- catechist
- group

Default voor persoonlijke reflectie:

```text
private
```

Default voor ontdekking:

```text
group
```

## Moderatie

Admin/catecheet kan:
- content verbergen
- vragen sluiten
- reacties verwijderen via soft delete
- rapportages bekijken

## AVG/GDPR aandachtspunten

Later uitwerken met juridisch advies:
- toestemming voor minderjarigen
- dataverwerkingsovereenkomst
- bewaartermijnen
- export persoonsgegevens
- verwijderverzoek
- logging van adminacties

