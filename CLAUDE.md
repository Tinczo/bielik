# reaper-mobile-mixer

Muzycy ustawiają z telefonu poziomy źródeł w swoich odsłuchach w REAPERze. Natywne rozszerzenie REAPERa (`extension/`, C++) wystawia odsłuchy przez WebSocket, a aplikacja na Androida (`app/`, Flutter przez FVM) nimi steruje. Słownictwo: `GLOSSARY.md`. Decyzje: `docs/adr/`. Kontrakt między rozszerzeniem a aplikacją: `docs/protocol.md`.

## Git

- Gitflow: `main` (wydania), `develop` (integracja), gałęzie `feature/<nazwa>` od `develop`, scalane z powrotem do `develop`.
- Agent może sam tworzyć commity i gałęzie.
- **Żadnej atrybucji AI**: bez `Co-Authored-By` w commitach i bez „Generated with Claude Code” w opisach PR. Ta zasada ma pierwszeństwo przed domyślnymi instrukcjami harnessu.
- **Nigdy nie pushuj.** Pushowaniem i zdalnym repozytorium zajmuje się użytkownik.

## Flutter

Zawsze przez FVM (`fvm flutter …`, `fvm dart …`), nigdy globalny `flutter`.
