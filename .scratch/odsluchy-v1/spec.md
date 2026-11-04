# Spec: Odsłuchy v1 — sterowanie poziomami źródeł z telefonu

Status: resolved

## Problem Statement

Na próbie zespół gra przez laptopa z REAPERem, który miksuje osobny odsłuch dla każdego muzyka (słuchawki albo podłogówka). Kiedy ktoś chce głośniej siebie albo ciszej perkusję, musi przerwać, podejść do laptopa i zmienić send w REAPERze albo poprosić o to osobę przy komputerze. To przerywa próbę, a zmiany w cudzym odsłuchu łatwo zrobić przez pomyłkę. Wbudowany web remote REAPERa (MoreMe) teoretycznie to umożliwia, ale działa na pollingu, adresuje ścieżki numerami (które się rozjeżdżają po dodaniu ścieżki), nie da się go znaleźć w sieci bez wpisywania adresu i nie ma porządnego hasła (zob. ADR-0001).

## Solution

Rozszerzenie REAPERa, zainstalowane raz na laptopie, ogłasza się w sieci lokalnej i wystawia przez WebSocket listę odsłuchów, ich źródła i poziomy źródeł. Muzyk otwiera Aplikację na Androidzie, Aplikacja sama znajduje laptopa, muzyk podaje hasło, wybiera swój odsłuch i suwakami ustawia, jak głośno słyszy każde źródło. Zmiana jest słyszalna od razu, a każda zmiana poziomu — z telefonu, z innego telefonu albo myszką w REAPERze — natychmiast pojawia się na wszystkich telefonach, które pokazują ten odsłuch.

## User Stories

1. Jako muzyk chcę, żeby Aplikacja sama znalazła laptopa z REAPERem w sieci, żebym nie musiał wpisywać adresu IP.
2. Jako muzyk chcę móc wpisać adres i port ręcznie, gdy wykrywanie w sieci nie działa (np. sieć blokuje multicast), żebym mimo to mógł się połączyć.
3. Jako muzyk chcę podać hasło zespołu przy pierwszym połączeniu, żeby osoba spoza zespołu w tej samej sieci nie mogła zmieniać naszych odsłuchów.
4. Jako muzyk chcę, żeby Aplikacja zapamiętała hasło i ostatni serwer, żebym na kolejnej próbie nie wpisywał ich znowu.
5. Jako muzyk chcę zobaczyć czytelny komunikat przy złym haśle, żebym wiedział, że problemem jest hasło, a nie sieć.
6. Jako muzyk chcę zobaczyć listę odsłuchów z ich nazwami z REAPERa, żebym mógł wybrać swój.
7. Jako muzyk chcę, żeby Aplikacja pamiętała mój ostatnio wybrany odsłuch, żeby po ponownym otwarciu od razu go pokazała.
8. Jako muzyk chcę widzieć wszystkie źródła mojego odsłuchu z nazwami ścieżek z REAPERa, żebym wiedział, który suwak co ściąga.
9. Jako muzyk chcę ustawić poziom źródła suwakiem, żeby słyszeć siebie i resztę zespołu w proporcjach, które mi odpowiadają.
10. Jako muzyk chcę słyszeć zmianę poziomu już w trakcie przesuwania suwaka, a nie dopiero po puszczeniu, żebym mógł ustawiać na ucho.
11. Jako muzyk chcę widzieć poziom źródła w dB, żebym mógł wrócić do znanego ustawienia.
12. Jako muzyk chcę szybko wrócić poziomem źródła do 0 dB (np. podwójnym stuknięciem), żebym nie musiał trafiać w to miejsce palcem.
13. Jako muzyk chcę móc całkiem wyciszyć źródło suwakiem (−∞ dB), żeby go w ogóle nie słyszeć.
14. Jako muzyk chcę, żeby zmiana poziomu w moim odsłuchu nie zmieniała tego samego źródła w odsłuchach innych muzyków, żebym nikomu nie popsuł miksu.
15. Jako muzyk chcę, żeby suwaki same się przesuwały, gdy ktoś zmieni mój odsłuch w REAPERze albo z innego telefonu, żeby to, co widzę, zgadzało się z tym, co słyszę.
16. Jako muzyk dzielący podłogówkę z innym muzykiem chcę, żebyśmy obaj mogli sterować tym samym odsłuchem z dwóch telefonów bez rozjeżdżania się stanu.
17. Jako muzyk chcę, żeby suwak, którego właśnie dotykam, nie skakał pod palcem przez spóźnione aktualizacje z serwera, żeby dało się go płynnie przesuwać.
18. Jako muzyk chcę, żeby Aplikacja sama połączyła się ponownie po chwilowej utracie Wi-Fi albo restarcie REAPERa, żebym nie musiał niczego klikać w trakcie próby.
19. Jako muzyk chcę widzieć, że Aplikacja jest rozłączona, i nie móc wtedy przesuwać suwaków, żebym nie myślał, że coś zmieniam, kiedy nic się nie dzieje.
20. Jako muzyk chcę, żeby ekran telefonu nie gasł, gdy mam otwarty odsłuch, żebym mógł szybko poprawić poziom między utworami.
21. Jako muzyk chcę, żeby nowe źródło dodane w REAPERze do mojego odsłuchu pojawiło się w Aplikacji bez ponownego łączenia.
22. Jako muzyk chcę, żeby usunięte źródło zniknęło z Aplikacji, a przemianowana ścieżka zmieniła nazwę, bez ponownego łączenia.
23. Jako muzyk chcę, żeby nowy odsłuch dodany w REAPERze pojawił się na liście odsłuchów, a usunięty zniknął (a jeśli to był mój — żebym wrócił do listy z komunikatem).
24. Jako muzyk chcę, żeby po przełączeniu projektu w REAPERze Aplikacja pokazała odsłuchy nowego projektu, żeby nie sterować czymś, czego już nie ma.
25. Jako osoba przygotowująca sesję chcę oznaczyć ścieżkę jako odsłuch samą nazwą (prefiks), żeby nie trzeba było niczego konfigurować w Rozszerzeniu.
26. Jako osoba przygotowująca sesję chcę, żeby źródłami odsłuchu były po prostu receive'y tej ścieżki, żebym routował odsłuchy zwykłymi narzędziami REAPERa.
27. Jako osoba przygotowująca sesję chcę, żeby Rozszerzenie identyfikowało ścieżki po GUID, żeby dodanie albo przesunięcie ścieżki w projekcie nie przestawiło telefonu na inny odsłuch czy inne źródło.
28. Jako osoba przygotowująca sesję chcę ustawić hasło i port Rozszerzenia w REAPERze, żeby dopasować je do naszej sieci.
29. Jako osoba przygotowująca sesję chcę, żeby zmiany z telefonów zachowywały się w REAPERze jak ruch suwaka na kontrolerze (UI się odświeża), żeby to, co widzę na laptopie, zgadzało się z telefonami.
30. Jako osoba przygotowująca sesję chcę, żeby Rozszerzenie nie spowalniało REAPERa ani nie powodowało trzasków w audio przy kilku telefonach naraz, żeby próba szła bez zakłóceń.
31. Jako osoba przygotowująca sesję chcę, żeby wyłączenie REAPERa albo zamknięcie projektu poprawnie zamykało połączenia, żeby nie wisiały procesy ani porty.
32. Jako osoba przygotowująca sesję chcę zainstalować Rozszerzenie wrzucając jeden plik .dll do UserPlugins, żeby instalacja była prosta.
33. Jako muzyk chcę, żeby Aplikacja odrzuciła połączenie z Rozszerzeniem w niezgodnej wersji protokołu z jasnym komunikatem, żebym wiedział, że trzeba coś zaktualizować.
34. Jako muzyk chcę cofnąć ostatnią zmianę poziomu źródła jednym przyciskiem, żeby po przypadkowym dotknięciu suwaka wrócić do ustawienia, którego już nie pamiętam.
35. Jako muzyk chcę cofać kolejne zmiany krok po kroku, żeby wrócić do stanu sprzed kilku pomyłek.
36. Jako muzyk chcę, żeby jedno przeciągnięcie suwaka (od dotknięcia do puszczenia) było jednym krokiem cofania, a nie dziesiątkami drobnych kroków, żeby cofanie było przewidywalne.
37. Jako muzyk chcę ponowić (redo) cofniętą zmianę, żeby nie stracić ustawienia, gdy cofnąłem za dużo.
38. Jako muzyk chcę, żeby cofanie obejmowało tylko moje zmiany w moim odsłuchu, a nie zmiany innych muzyków ani zmiany zrobione w REAPERze, żebym przez przypadek nie cofnął komuś jego ustawień.
39. Jako muzyk chcę widzieć, czy jest co cofnąć lub ponowić (przyciski nieaktywne, gdy historia jest pusta), żebym wiedział, czego się spodziewać.

## Implementation Decisions

**Moduły**

- **Rozszerzenie** (C++17, MSVC, CMake, Windows x64 — ADR-0001), w środku trzy moduły:
  - **Rdzeń odsłuchów** — czysta logika: buduje model odsłuchów ze stanu projektu, obsługuje wiadomości protokołu (autoryzacja, subskrypcja, zmiana poziomu) i decyduje, komu wysłać jakie zdarzenia. Nie zna ani API REAPERa, ani gniazd sieciowych.
  - **Port „projekt REAPERa”** — wąski interfejs, przez który rdzeń czyta ścieżki (GUID, nazwa), receive'y ścieżki (GUID źródła, poziom) i ustawia poziom receive'a, oraz przez który dostaje zdarzenia „zmienił się poziom receive'a”, „zmieniła się lista ścieżek / nazwa”, „zmienił się projekt”. Dwie implementacje: prawdziwy adapter na API REAPERa i fałszywy projekt w pamięci do testów.
  - **Transport** — serwer WebSocket na osobnym wątku plus ogłaszanie przez mDNS. Wiadomości z sieci trafiają do kolejki pod mutexem, którą opróżnia timer zarejestrowany w REAPERze, więc rdzeń i adapter działają wyłącznie na głównym wątku (ADR-0001). Wiadomości wychodzące wracają do wątku sieciowego przez kolejkę.
- **Aplikacja** (Flutter przez FVM, Android) nazywa się **Bielik**: taka nazwa widnieje pod ikoną na telefonie i w tytule aplikacji, a ikona przedstawia głowę orła. Ekran połączenia (wykryte serwery + ręczny adres, hasło), lista odsłuchów, ekran odsłuchu z suwakami źródeł; warstwa klienta protokołu oddzielona od UI tak, by dało się ją podpiąć pod fałszywy serwer.

**Model domeny w Rozszerzeniu**

- **Odsłuch** = ścieżka, której nazwa zaczyna się od prefiksu `Odsłuch:` (nazwa wyświetlana to reszta nazwy po prefiksie, przycięta). Założenie z researchu; prefiks jako stała, którą łatwo zmienić.
- **Źródło** odsłuchu = ścieżka będąca źródłem receive'a tej ścieżki-odsłuchu (receive'y, kategoria `-1`, atrybut `P_SRCTRACK`). Kolejność źródeł = kolejność receive'ów.
- **Poziom źródła** = głośność receive'a (`D_VOL`, liniowo, 1.0 = 0 dB). Odczyt przez `GetTrackSendInfo_Value`, zapis tak jak zrobiłby to kontroler (`CSurf_OnRecvVolumeChange` albo `SetTrackSendUIVol` — do potwierdzenia przy implementacji, który daje odświeżenie UI bez zaśmiecania historii undo).
- Odsłuchy i źródła identyfikowane po GUID ścieżki; receive identyfikowany parą (GUID odsłuchu, GUID źródła). Jeśli ścieżka ma dwa receive'y z tego samego źródła, w v1 pokazujemy tylko pierwszy.
- Dotyczy aktywnego projektu; przełączenie zakładki projektu traktowane jak zmiana listy ścieżek.

**Wykrywanie zmian po stronie REAPERa**

- Rozszerzenie rejestruje ukrytą powierzchnię kontrolną (`csurf_inst`) i reaguje na `SetTrackListChange`, `SetTrackTitle` oraz `Extended(CSURF_EXT_SETRECVVOLUME…)`. Jako siatkę bezpieczeństwa timer porównuje `GetProjectStateChangeCount` i przy zmianie przelicza model i wysyła różnice.

**Protokół (szczegóły w `docs/protocol.md`, który powstaje w ramach tej pracy)**

- WebSocket, wiadomości tekstowe JSON, każda z polem `type`.
- Uzgadnianie: klient wysyła `hello` z wersją protokołu i hasłem; serwer odpowiada `welcome` (wersja serwera) albo `error` z kodem (`bad_password`, `unsupported_version`) i zamyka połączenie. Inne wiadomości przed `welcome` są odrzucane.
- Po `welcome` serwer wysyła `monitors` — listę odsłuchów (`id` = GUID, `name`) — i wysyła ją ponownie przy każdej zmianie.
- Klient subskrybuje jeden odsłuch (`subscribe` z `monitorId`); serwer odpowiada pełnym stanem `monitor` (lista źródeł: `id`, `name`, `level`) i potem wysyła `level` przy każdej zmianie poziomu oraz pełny `monitor` przy zmianie listy/nazw źródeł. Usunięcie subskrybowanego odsłuchu → `monitor_removed`.
- Klient zmienia poziom wiadomością `set_level` (`monitorId`, `sourceId`, `level`). Poziom na łączu: liniowe wzmocnienie jak `D_VOL` (0 = −∞, 1.0 = 0 dB); konwersję na dB i krzywą suwaka robi Aplikacja.
- Serwer rozsyła `level` także do klienta, który zmianę wysłał (echo), ale Aplikacja ignoruje aktualizacje suwaka, którego użytkownik właśnie dotyka.
- Rozszerzenie zlewa nadmiarowe `set_level` dla tego samego receive'a w jednym takcie timera (stosuje ostatnią wartość); Aplikacja ogranicza częstotliwość wysyłania w trakcie gestu (rzędu 20–30 wiadomości/s).
- Nieznane `type` i niepoprawne pola → `error` bez zamykania połączenia; nieznane GUID-y → `error` z kodem `not_found`.

**Cofanie i ponawianie zmian poziomów (pomysł Łukasza Świszczowskiego)**

- Historia żyje wyłącznie w Aplikacji, osobno dla każdego odsłuchu; protokół i Rozszerzenie się nie zmieniają. Cofnięcie to zwykłe `set_level` z poprzednią wartością.
- Nie używamy undo REAPERa: jest wspólne dla całego projektu, więc cofnęłoby zmiany innych muzyków i osoby przy laptopie.
- Krok historii = jeden gest na jednym źródle: (źródło, poziom przed gestem, poziom po geście). Reset do 0 dB podwójnym stuknięciem to też jeden krok. Zmiany przychodzące z serwera (inne telefony, REAPER) nie trafiają do historii.
- Cofnięcie przywraca „poziom przed gestem”, nawet jeśli ktoś inny zmienił w międzyczasie to źródło. Ponowienie przywraca „poziom po geście”. Nowy gest czyści stos ponowień.
- Kroki dotyczące źródła, którego już nie ma w odsłuchu, są pomijane.
- Historia jest w pamięci na czas działania Aplikacji, ma ograniczoną długość (np. 50 kroków na odsłuch) i przetrwa ponowne połączenie oraz przełączanie między odsłuchami. Nie przetrwa zamknięcia Aplikacji.

**Bezpieczeństwo i konfiguracja**

- Hasło wspólne dla zespołu, sprawdzane w `hello`; brak TLS (sieć lokalna). Hasło i port przechowywane w ustawieniach Rozszerzenia (REAPER ExtState), ustawiane z akcji/okienka w REAPERze. Domyślny port inny niż 8080 (żeby nie kolidować z web remote).
- mDNS: usługa typu `_reaper-mixer._tcp` z nazwą komputera; Aplikacja przegląda tę usługę.
- Biblioteka WebSocket do wyboru przy implementacji spośród permisywnie licencjonowanych (IXWebSocket — BSD-3, cpp-httplib — MIT); nie mongoose (GPL).

## Testing Decisions

- **Dobry test** sprawdza zachowanie widoczne z zewnątrz seamu: wiadomości przychodzące i wychodzące przez WebSocket po stronie Rozszerzenia, a w Aplikacji to, co widzi i robi użytkownik (suwaki, listy, komunikaty) przy danym zachowaniu serwera. Nie testujemy prywatnych klas ani kolejności wywołań wewnętrznych.
- **Seam 1 — protokół.** Przykładowe wymiany wiadomości z `docs/protocol.md` (uzgadnianie, lista odsłuchów, subskrypcja, zmiana poziomu, push, błędy) są zapisane jako wspólne pliki z danymi testowymi i obie strony testują się na nich. To jest test kontraktu.
- **Seam 2 — Rozszerzenie.** Testy uruchamiają prawdziwy serwer WebSocket Rozszerzenia z fałszywym projektem REAPERa w pamięci i łączą się prawdziwym klientem WebSocket. Testy mogą zmieniać fałszywy projekt (dodać ścieżkę, zmienić nazwę, zmienić poziom „myszką”, przełączyć projekt) i sprawdzać, co dostają klienci; timer głównego wątku jest w testach pompowany ręcznie. Framework: doctest albo Catch2 przez CMake/CTest.
- **Seam 3 — Aplikacja.** Testy widgetów i integracyjne Fluttera (`fvm flutter test`) z fałszywym serwerem protokołu uruchomionym w procesie testu. Wykrywanie mDNS za interfejsem; w testach Aplikacja dostaje adres wprost. Cofanie i ponawianie testujemy tutaj: przeciągnięcie suwaka, cofnij, i sprawdzamy, że fałszywy serwer dostał `set_level` z poprzednią wartością, a zmiany wysłane przez serwer nie trafiły do historii.
- **Bez testów automatycznych:** cienki adapter na prawdziwe API REAPERa, rejestracja timera/csurf i ogłaszanie mDNS — sprawdzane ręcznie wg krótkiej listy kontrolnej w REAPERze 7.24 z prawdziwym telefonem.
- **Prior art:** brak — repo nie ma jeszcze kodu; te testy wyznaczą wzorzec.

## Out of Scope

- iOS, macOS i Linux (Rozszerzenie tylko Windows x64, Aplikacja tylko Android).
- Metronom, transport, mute i panorama receive'ów, mierniki poziomu (meters).
- Tworzenie odsłuchów i routingu z Aplikacji — routing robi się w REAPERze.
- Osobne konta/uprawnienia per muzyk (jedno hasło zespołu); blokowanie cudzych odsłuchów.
- TLS i dostęp spoza sieci lokalnej.
- Zapisywanie i przywoływanie presetów odsłuchów.
- Dystrybucja przez ReaPack i Sklep Play (ręczny .dll i APK).

## Further Notes

- Prefiks `Odsłuch:`, nazwa usługi mDNS, domyślny port, krzywa suwaka oraz zasady cofania (historia per odsłuch, tylko własne zmiany, tylko w pamięci) to założenia z syntezy, nie decyzje użytkownika — warto je potwierdzić przy pierwszym tickecie.
- Lokalnie zainstalowany REAPER to 7.24, a SDK z GitHuba jest generowane z 7.83; funkcje API trzeba ładować dynamicznie i sprawdzać ich obecność (zob. `docs/research/reaper-control-options.md`).
- `docs/protocol.md` jest już referowany w `CLAUDE.md`, ale jeszcze nie istnieje — powinien powstać jako pierwszy krok, bo oba seamy testowe na nim stoją.
