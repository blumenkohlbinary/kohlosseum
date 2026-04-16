# CLAUDE.md Templates by Project Type

Reference templates for the `/mind:generate` skill. Each template is a skeleton with placeholder comments. The generate skill fills in actual values from the project-scanner report.

---

## web_app

```markdown
## Project Overview
<!-- 1-2 sentences: app name, frontend framework, backend, purpose -->

## Commands
- Build: `<!-- build command -->`
- Dev: `<!-- dev server command -->`
- Test: `<!-- test suite command -->`
- Test (single): `<!-- single test command --> <file>`
- Lint: `<!-- lint command -->`

## Architecture
- `src/` -- <!-- frontend source -->
- `server/` -- <!-- backend source -->
- `public/` -- <!-- static assets -->
<!-- 2-4 more key directories -->

## Conventions
<!-- non-linter rules: state management, API call patterns, component structure -->

## Gotchas
<!-- env vars, CORS, SSR quirks, hot reload issues -->
```

---

## api

```markdown
## Project Overview
<!-- 1-2 sentences: API name, framework, protocol (REST/GraphQL), purpose -->

## Commands
- Build: `<!-- build command -->`
- Dev: `<!-- dev server command -->`
- Test: `<!-- test suite command -->`
- Test (single): `<!-- single test command --> <file>`
- Lint: `<!-- lint command -->`
- Migrate: `<!-- migration command -->`

## Architecture
- `src/routes/` -- <!-- route handlers -->
- `src/models/` -- <!-- data models / ORM -->
- `src/middleware/` -- <!-- middleware chain -->
- `src/services/` -- <!-- business logic -->
<!-- additional key directories -->

## Conventions
<!-- error handling, auth patterns, validation, response format -->

## Gotchas
<!-- env vars, DB connection, migration order, rate limits -->
```

---

## cli

```markdown
## Project Overview
<!-- 1-2 sentences: CLI name, language, purpose -->

## Commands
- Build: `<!-- build command -->`
- Test: `<!-- test suite command -->`
- Test (single): `<!-- single test command --> <file>`
- Lint: `<!-- lint command -->`
- Run locally: `<!-- local execution command -->`

## Architecture
- `src/commands/` -- <!-- command implementations -->
- `src/utils/` -- <!-- shared utilities -->
<!-- additional key directories -->

## Conventions
<!-- flag naming, output formatting, exit codes, error messages -->

## Gotchas
<!-- stdin/stdout handling, cross-platform paths, permission issues -->
```

---

## library

```markdown
## Project Overview
<!-- 1-2 sentences: package name, language, purpose, target consumers -->

## Commands
- Build: `<!-- build command -->`
- Test: `<!-- test suite command -->`
- Test (single): `<!-- single test command --> <file>`
- Lint: `<!-- lint command -->`
- Publish (dry run): `<!-- dry run publish command -->`

## Architecture
- `src/` -- <!-- library source -->
- `tests/` -- <!-- test files -->
<!-- additional key directories -->

## Conventions
<!-- exports structure, semver policy, breaking change handling, public API surface -->

## Gotchas
<!-- bundling (CJS/ESM), peer deps, type declarations, publish checklist -->
```

---

## fullstack

```markdown
## Project Overview
<!-- 1-2 sentences: project name, monorepo tool, frontend + backend stack, purpose -->

## Commands
- Build (all): `<!-- build all packages -->`
- Dev: `<!-- dev command for full stack -->`
- Test: `<!-- test suite command -->`
- Test (single): `<!-- single test command --> <file>`
- Lint: `<!-- lint command -->`

## Architecture
- `apps/web/` -- <!-- frontend app -->
- `apps/api/` -- <!-- backend app -->
- `packages/shared/` -- <!-- shared types/utils -->
<!-- additional workspaces -->

## Conventions
<!-- cross-package imports, shared types, workspace dependency rules -->

## Gotchas
<!-- workspace hoisting, build order, shared env vars, port conflicts -->
```

---

## mobile

```markdown
## Project Overview
<!-- 1-2 sentences: app name, framework (RN/Flutter), platforms, purpose -->

## Commands
- Dev (iOS): `<!-- iOS dev command -->`
- Dev (Android): `<!-- Android dev command -->`
- Test: `<!-- test suite command -->`
- Test (single): `<!-- single test command --> <file>`
- Lint: `<!-- lint command -->`
- Build (release): `<!-- release build command -->`

## Architecture
- `src/screens/` -- <!-- screen components -->
- `src/navigation/` -- <!-- navigation config -->
- `src/services/` -- <!-- API and device services -->
<!-- additional key directories -->

## Conventions
<!-- navigation patterns, platform-specific code, asset handling -->

## Gotchas
<!-- native modules, simulator vs device, deep linking, push notifications -->
```

---

## default

```markdown
## Project Overview
<!-- 1-2 sentences: project name, language/tech, purpose -->

## Commands
- Build: `<!-- build command -->`
- Test: `<!-- test suite command -->`
- Lint: `<!-- lint command -->`

## Architecture
- `src/` -- <!-- source code -->
<!-- additional key directories -->

## Conventions
<!-- key project-specific rules -->

## Gotchas
<!-- non-obvious pitfalls -->
```

---

## workspace

```markdown
## Projekt-Übersicht
<!-- 1-2 Sätze: Was ist dieses Projekt, welchen Zweck hat es -->

## Ordner-Struktur
<!-- Für jeden Ordner: Was liegt dort und warum -->
- `Ordner1/` -- <!-- Beschreibung -->
- `Ordner2/` -- <!-- Beschreibung -->

## Wichtige Dateien
<!-- Schlüssel-Dateien die man kennen muss -->

## Arbeitsweise
<!-- Wie wird mit diesem Projekt gearbeitet? Was sind typische Aufgaben? -->
```

---

## scripts

```markdown
## Projekt-Übersicht
<!-- 1-2 Sätze: Was machen diese Scripts -->

## Scripts
<!-- Für jedes Script: Name, was es tut, wie man es aufruft -->
| Script | Zweck | Aufruf |
|---|---|---|
| `script.sh` | <!-- Beschreibung --> | `./script.sh [args]` |

## Voraussetzungen
<!-- Was muss installiert sein damit die Scripts laufen -->

## Konventionen
<!-- Naming, Error-Handling, Logging -->
```

---

## data

```markdown
## Projekt-Übersicht
<!-- 1-2 Sätze: Welche Daten, wozu -->

## Datenformate
<!-- Für jedes Format: Felder, Typen, Beispiele -->

## Verarbeitung
<!-- Wie werden die Daten verarbeitet/transformiert -->

## Quellen
<!-- Woher kommen die Daten -->
```

---

## config

```markdown
## Übersicht
<!-- Was wird konfiguriert, welches System -->

## Konfigurationsdateien
<!-- Für jede Datei: Zweck, wichtige Einstellungen -->

## Anwendung
<!-- Wie wird die Konfiguration angewendet/deployed -->
```

---

## desktop_app

```markdown
## Project Overview
<!-- 1-2 sentences: app name, GUI framework, purpose -->

## Commands
- Build: `<!-- build command -->`
- Run: `<!-- run command -->`
- Test: `<!-- test suite command -->`
- Package: `<!-- packaging/installer command -->`

## Architecture
- `src/` -- <!-- source code -->
- `ui/` or `views/` -- <!-- GUI components -->
<!-- additional directories -->

## Conventions
<!-- UI patterns, event handling, data binding -->

## Gotchas
<!-- platform-specific issues, packaging quirks, native deps -->
```

---

## game_mod

```markdown
## Project Overview
<!-- 1-2 sentences: game, mod framework, purpose -->

## Commands
- Build: `<!-- build command -->`
- Install: `<!-- how to install the mod -->`
- Test: `<!-- how to test in-game -->`

## Architecture
<!-- mod structure, hooks, patches -->

## Conventions
<!-- naming, Harmony patches, BepInEx patterns -->

## Gotchas
<!-- game version compatibility, load order, IL2CPP issues -->
```
