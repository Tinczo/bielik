# 01: Szkielet — lista odsłuchów z REAPERa w Bieliku

**What to build:** Osoba przygotowująca sesję wrzuca .dll Rozszerzenia do UserPlugins i uruchamia REAPERa. Muzyk otwiera Aplikację Bielik, wpisuje ręcznie adres i port laptopa i widzi listę odsłuchów aktywnego projektu, czyli ścieżek z prefiksem `Odsłuch:` w nazwie, z nazwami wyświetlanymi bez prefiksu. To pierwszy przejazd przez cały system i powstaje przy nim infrastruktura, na której stoją kolejne tickety.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [ ] Rozszerzenie (C++17, MSVC, CMake, Windows x64) buduje się do jednego .dll, ładuje się w REAPERze 7.24, a funkcje API ładuje dynamicznie i sprawdza ich obecność.
- [ ] Serwer WebSocket działa na osobnym wątku. Wiadomości trafiają na główny wątek przez kolejkę opróżnianą timerem REAPERa, a odpowiedzi wracają kolejką do wątku sieciowego (ADR-0001).
- [ ] Rdzeń odsłuchów nie zna API REAPERa ani gniazd. Stan projektu czyta przez port „projekt REAPERa”, który ma prawdziwy adapter i fałszywy projekt w pamięci.
- [ ] Uzgadnianie `hello` (z wersją protokołu) → `welcome`, a potem `monitors` z listą odsłuchów (`id` = GUID, `name`). Wiadomości przed `welcome` są odrzucane, a nieznane `type` dostają `error` bez rozłączenia.
- [ ] Powstaje `docs/protocol.md` z tymi wiadomościami i wspólne przykładowe wymiany wiadomości, z których korzystają testy obu stron (test kontraktu).
- [ ] Testy Rozszerzenia (doctest albo Catch2 przez CTest) łączą się prawdziwym klientem WebSocket z serwerem stojącym na fałszywym projekcie, a timer pompują ręcznie.
- [ ] Aplikacja we Flutterze (przez FVM) ma nazwę Bielik pod ikoną i w tytule, ekran ręcznego adresu i ekran listy odsłuchów.
- [ ] Testy Aplikacji (`fvm flutter test`) działają przeciw fałszywemu serwerowi protokołu uruchomionemu w procesie testu.
- [ ] Ręczna weryfikacja: REAPER z dwiema ścieżkami `Odsłuch: …` i telefon z Androidem pokazujący obie.
