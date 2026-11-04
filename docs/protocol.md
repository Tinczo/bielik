# Protokół Rozszerzenie ↔ Aplikacja

Kontrakt między Rozszerzeniem (serwer) a Aplikacją Bielik (klient). Wersja protokołu: **1**.

## Transport

- WebSocket bez TLS (sieć lokalna), domyślny port **8790** (nie 8080, którego używa web remote REAPERa). Port i hasło zespołu ustawia się w REAPERze akcją „Mobile mixer: Settings (port, band password)...”; zapisują się w ExtState, a zmiana portu restartuje serwer bez restartu REAPERa.
- Każda wiadomość to jedna ramka tekstowa z obiektem JSON, który ma pole `type` (string). Ramki binarne są ignorowane.
- Identyfikatory odsłuchów i źródeł to GUID-y ścieżek w formacie REAPERa, np. `{1B6A2C10-0001-4A3E-9C1D-000000000001}`.
- Tekst jest w UTF-8.

## Wykrywanie (mDNS)

- Rozszerzenie ogłasza w sieci lokalnej usługę DNS-SD typu `_reaper-mixer._tcp` (domena `local`). Nazwa instancji to nazwa komputera (np. `STUDIO._reaper-mixer._tcp.local`), host `<nazwa komputera>.local`, port to aktualny port WebSocket. Bez rekordów TXT.
- Przy zmianie portu Rozszerzenie wycofuje ogłoszenie i ogłasza usługę od nowa; przy zamknięciu wycofuje je (rekord „goodbye” z TTL 0).
- Aplikacja przegląda `_reaper-mixer._tcp`, rozwiązuje instancje na adres i port i łączy się z wybranym laptopem jak z adresem wpisanym ręcznie. Ręczny adres zostaje jako awaryjna droga, gdy sieć blokuje multicast.

## Uzgadnianie

Klient po połączeniu wysyła `hello` z wersją protokołu i hasłem zespołu:

```json
{ "type": "hello", "protocolVersion": 1, "password": "próba2026" }
```

- `password` (string) to hasło zespołu ustawione w Rozszerzeniu. Brak pola znaczy to samo co pusty string; gdy w Rozszerzeniu nie ustawiono hasła, `hello` może je pominąć.
- Serwer najpierw sprawdza wersję, potem hasło. Inna wersja niż serwera → `error` `unsupported_version`, złe hasło → `error` `bad_password`; w obu przypadkach serwer zaraz potem zamyka połączenie.
- Zmiana hasła w Rozszerzeniu działa od następnego `hello`; połączenia już przyjęte zostają.

Serwer odpowiada `welcome` ze swoją wersją protokołu, a zaraz po nim wysyła `monitors`:

```json
{ "type": "welcome", "protocolVersion": 1 }
```

Każda inna wiadomość przed `welcome` dostaje `error` z kodem `handshake_required`, a połączenie zostaje otwarte.

## Lista odsłuchów

```json
{
  "type": "monitors",
  "monitors": [
    { "id": "{1B6A2C10-0001-4A3E-9C1D-000000000001}", "name": "Wokal" }
  ]
}
```

- Odsłuch to ścieżka aktywnego projektu, której nazwa zaczyna się od `Odsłuch:`. `name` to reszta nazwy bez prefiksu, przycięta z białych znaków.
- Kolejność jak w projekcie. Pusta lista, gdy projekt nie ma odsłuchów.
- Serwer wysyła `monitors` ponownie (zawsze pełną listę), gdy lista się zmieni: odsłuch dodany, usunięty, przemianowany, przestawiony albo przełączono projekt w REAPERze. Bez faktycznej różnicy nic nie wysyła.

## Subskrypcja odsłuchu

Klient wybiera odsłuch wiadomością `subscribe`:

```json
{ "type": "subscribe", "monitorId": "{1B6A2C10-0010-4A3E-9C1D-000000000010}" }
```

Serwer odpowiada pełnym stanem odsłuchu `monitor`:

```json
{
  "type": "monitor",
  "id": "{1B6A2C10-0010-4A3E-9C1D-000000000010}",
  "name": "Wokal",
  "sources": [
    { "id": "{1B6A2C10-0002-4A3E-9C1D-000000000002}", "name": "Gitara", "level": 0.5 },
    { "id": "{1B6A2C10-0003-4A3E-9C1D-000000000003}", "name": "Perkusja", "level": 0 }
  ]
}
```

- `id` i `name` jak w liście odsłuchów.
- Źródła to receive'y ścieżki-odsłuchu w kolejności receive'ów. `id` to GUID ścieżki, z której przychodzi receive, `name` to pełna nazwa tej ścieżki.
- `level` to głośność receive'a, liniowo jak `D_VOL` w REAPERze: `1.0` = 0 dB, `0` = −∞, może być większe od 1. Konwersję na dB robi Aplikacja.
- Jeśli ścieżka-odsłuch ma kilka receive'ów z tego samego źródła, pokazywany jest tylko pierwszy z nich.
- Klient subskrybuje naraz jeden odsłuch; kolejny `subscribe` zastępuje poprzedni.
- Nieznany `monitorId` (także GUID ścieżki, która nie jest odsłuchem) → `error` z kodem `not_found`. Brak `monitorId` albo nie-string → `invalid_message`.

## Zmiana poziomu źródła

Klient ustawia poziom źródła w odsłuchu wiadomością `set_level`:

```json
{
  "type": "set_level",
  "monitorId": "{1B6A2C10-0010-4A3E-9C1D-000000000010}",
  "sourceId": "{1B6A2C10-0002-4A3E-9C1D-000000000002}",
  "level": 0.5
}
```

- `level` liniowo jak w `monitor` (`1.0` = 0 dB, `0` = −∞), liczba skończona ≥ 0. Krzywą suwaka i konwersję na dB robi Aplikacja.
- Zmienia się głośność jednego receive'a: pierwszego receive'a ścieżki `monitorId` ze ścieżki `sourceId`. To samo źródło w innych odsłuchach się nie zmienia.
- Serwer nie odpowiada na udane `set_level`; nowy poziom widać w kolejnym stanie odsłuchu.
- Klient nie musi subskrybować odsłuchu, któremu zmienia poziom.
- Serwer zlewa wiele `set_level` dla tego samego receive'a, które przyszły w jednym takcie timera, i zapisuje tylko ostatnią wartość. Inna wiadomość klienta widzi już wszystkie poziomy zmienione przed nią.
- Aplikacja wysyła w trakcie gestu najwyżej ~25 `set_level` na sekundę i zawsze wysyła wartość końcową po puszczeniu suwaka.
- Brak lub zły typ `monitorId`, `sourceId`, `level`, a także `level` ujemny → `invalid_message`. Nieznany odsłuch albo źródło, którego ten odsłuch nie ma → `not_found`.

Zapis w REAPERze idzie przez `SetTrackSendUIVol(track, -1 - indeksReceive'a, level, 0)`, czyli jak ruch suwaka na kontrolerze: UI miksera się odświeża. Wybrane zamiast `CSurf_OnRecvVolumeChange`, bo tak samo robi wbudowany web remote REAPERa (`csurf_www.cpp`), a argument `isend` pozwala jawnie powiedzieć „ruch w trakcie” (`0`). Łącze nie ma końca gestu, więc Rozszerzenie nigdy nie wysyła „koniec edycji” (`1`), który tworzy punkt undo — dzięki temu wiadomości z telefonów nie zaśmiecają historii undo. Do potwierdzenia ręcznie w REAPERze 7.24.

## Zmiany struktury na żywo

- Gdy w subskrybowanym odsłuchu zmieni się lista źródeł (receive dodany lub usunięty, ścieżka-źródło usunięta) albo nazwa odsłuchu lub źródła, serwer wysyła ponownie pełny `monitor`. Sama zmiana poziomów nie powoduje wysłania `monitor`.
- Odsłuchy i źródła są identyfikowane po GUID, więc przesunięcie ścieżek w projekcie niczego nie zmienia (poza kolejnością w `monitors`, jeśli przesunięto odsłuch).
- Gdy subskrybowany odsłuch przestaje istnieć (ścieżka usunięta, nazwa zmieniona na taką bez prefiksu, przełączenie projektu), serwer wysyła najpierw nowe `monitors`, a potem:

```json
{ "type": "monitor_removed", "id": "{1B6A2C10-0010-4A3E-9C1D-000000000010}" }
```

  Subskrypcja się kończy; żeby znów oglądać odsłuch, klient wysyła `subscribe`.

## Zerwane połączenie i zamknięcie

- Serwer nie pamięta klientów między połączeniami: każde nowe połączenie zaczyna się od `hello`, a subskrypcja kończy się razem z połączeniem.
- Bielik po utracie połączenia łączy się ponownie sam, z narastającym odstępem (0,5 s, potem dwa razy dłużej, najwyżej 5 s). Po `welcome` czeka na `monitors`: jeśli oglądany odsłuch nadal jest na liście, wysyła dla niego `subscribe`; jeśli nie (np. REAPER wrócił z innym projektem), wraca do listy odsłuchów. W czasie rozłączenia pokazuje ostatni znany stan z zablokowanymi suwakami.
- Bielik wysyła ping WebSocket co 3 s; brak pong w tym czasie traktuje jak zerwane połączenie (zniknięte Wi-Fi nie zawsze zamyka TCP).
- Przy rozładowaniu Rozszerzenia (zamknięcie REAPERa) serwer zamyka wszystkie połączenia, zatrzymuje wątki sieciowe i zwalnia port, więc REAPER uruchomiony ponownie od razu nasłuchuje na tym samym porcie.

## Błędy

```json
{ "type": "error", "code": "unknown_type", "message": "unknown message type: make_coffee" }
```

`code` jest dla programu, `message` dla człowieka (do logów, bez gwarancji treści). Błąd nie zamyka połączenia, z wyjątkiem odmowy w uzgadnianiu (`unsupported_version`, `bad_password`).

| `code` | Kiedy |
|---|---|
| `handshake_required` | wiadomość inna niż `hello` przed `welcome` |
| `invalid_message` | tekst, który nie jest obiektem JSON ze stringowym `type`, albo brakujące lub złego typu pola (np. `hello` bez całkowitego `protocolVersion` albo z `password`, które nie jest stringiem) |
| `unsupported_version` | `protocolVersion` w `hello` inny niż wersja serwera; serwer zamyka połączenie |
| `bad_password` | złe hasło w `hello`; serwer zamyka połączenie |
| `unknown_type` | nieznany `type` po `welcome` |
| `not_found` | nieznany GUID odsłuchu (np. w `subscribe`) albo źródło, którego odsłuch nie ma (`set_level`) |

## Wspólne przykłady (test kontraktu)

Przykładowe wymiany wiadomości leżą w `protocol/examples/*.json` i testują się na nich obie strony: Rozszerzenie (`extension/tests/protocol_examples_test.cpp`) i Aplikacja (`app/test/protocol_examples_test.dart`). Zmiana protokołu zaczyna się od zmiany tego dokumentu i przykładów.

Format pliku:

```json
{
  "description": "co pokazuje ten przykład",
  "project": { "tracks": [{ "guid": "{…}", "name": "Odsłuch: Wokal" }] },
  "steps": [
    { "client": { "type": "hello", "protocolVersion": 1 } },
    { "server": { "type": "welcome", "protocolVersion": 1 } }
  ]
}
```

- `settings` (opcjonalne) — ustawienia Rozszerzenia, np. `{ "password": "próba2026" }`. Bez tego pola hasło jest puste.
- `project` — stan projektu REAPERa, na którym stoi serwer (fałszywy projekt w testach Rozszerzenia). Ścieżka może mieć opcjonalne `receives`: `[{ "source": "<GUID ścieżki-źródła>", "level": 0.5 }]` w kolejności receive'ów.
- `steps` — wiadomości w kolejności: `client` wysyła klient, `server` wysyła serwer. Krok `client` podany jako string jest wysyłany dosłownie (do przykładów z niepoprawnym JSON-em). Krok `{ "closed": true }` znaczy, że serwer zamyka połączenie.
- Krok `project` (obiekt jak `project` wyżej) to zmiana w REAPERze: od tego miejsca projekt ma dokładnie taki stan (np. dodana ścieżka, zmieniona nazwa, inny projekt). Test Rozszerzenia podmienia fałszywy projekt i zgłasza zmianę; fałszywy serwer Aplikacji czeka w tym miejscu, aż test pozwoli mu iść dalej.
- Dopasowanie wiadomości: każde pole z przykładu musi wystąpić w prawdziwej wiadomości z tą samą wartością; obiekty mogą mieć dodatkowe pola (np. `message` w `error`), a tablice muszą mieć te same elementy w tej samej kolejności.
- Po ostatnim kroku serwer nie wysyła już nic, a połączenie zostaje otwarte (chyba że przykład kończy się krokiem `closed`).
