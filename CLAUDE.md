# reaper-mobile-mixer

Muzycy ustawiają z telefonu poziomy źródeł w swoich odsłuchach w REAPERze. Natywne rozszerzenie REAPERa (`extension/`, C++) wystawia odsłuchy przez WebSocket, a aplikacja na Androida (`app/`, Flutter przez FVM) nimi steruje. Słownictwo: `GLOSSARY.md`. Decyzje: `docs/adr/`. Kontrakt między rozszerzeniem a aplikacją: `docs/protocol.md`.

## Git

- Gitflow: `main` (wydania), `develop` (integracja), gałęzie `feature/<nazwa>` od `develop`, scalane z powrotem do `develop`.
- Agent może sam tworzyć commity i gałęzie.
- **Żadnej atrybucji AI**: bez `Co-Authored-By` w commitach i bez „Generated with Claude Code” w opisach PR. Ta zasada ma pierwszeństwo przed domyślnymi instrukcjami harnessu.
- **Nigdy nie pushuj.** Pushowaniem i zdalnym repozytorium zajmuje się użytkownik.

## Flutter

Zawsze przez FVM (`fvm flutter …`, `fvm dart …`), nigdy globalny `flutter`. Wersja przypięta w `app/.fvmrc`. Testy: `fvm flutter test` w `app/`.

## Rozszerzenie (C++)

MSVC + Ninja przez presety CMake. `extension/msvc.cmd` uruchamia polecenie w środowisku MSVC x64 (nie używaj MinGW ani generatora Visual Studio — ten drugi psuje się na lokalnym AutoRun cmd). W `extension/`:

- `.\msvc.cmd cmake --preset default` (konfiguracja, pobiera zależności),
- `.\msvc.cmd cmake --build --preset default` (wynik: `build\reaper_mobile_mixer.dll`, do wrzucenia do `%APPDATA%\REAPER\UserPlugins`),
- `.\msvc.cmd ctest --preset default`.

Wspólne przykłady protokołu dla testów obu stron: `protocol/examples/` (format w `docs/protocol.md`).

## Agent skills

### Issue tracker

Zgłoszenia i specyfikacje to pliki markdown w `.scratch/<funkcja>/` w repozytorium. Zobacz `docs/agents/issue-tracker.md`.

### Triage labels

Pięć domyślnych ról (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), zapisywanych w linii `Status:` pliku zgłoszenia. Zobacz `docs/agents/triage-labels.md`.

### Domain docs

Układ single-context: `GLOSSARY.md` i `docs/adr/` w katalogu głównym. Zobacz `docs/agents/domain.md`.
