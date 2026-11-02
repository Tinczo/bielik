# Protokół Rozszerzenie ↔ Aplikacja

Kontrakt między Rozszerzeniem (serwer) a Aplikacją Bielik (klient). Wersja protokołu: **1**.

## Transport

- WebSocket bez TLS (sieć lokalna), domyślny port **8790** (nie 8080, którego używa web remote REAPERa).
- Każda wiadomość to jedna ramka tekstowa z obiektem JSON, który ma pole `type` (string). Ramki binarne są ignorowane.
- Identyfikatory odsłuchów i źródeł to GUID-y ścieżek w formacie REAPERa, np. `{1B6A2C10-0001-4A3E-9C1D-000000000001}`.
- Tekst jest w UTF-8.

## Uzgadnianie

Klient po połączeniu wysyła `hello`:

```json
{ "type": "hello", "protocolVersion": 1 }
```

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

## Zmiany struktury na żywo

- Gdy w subskrybowanym odsłuchu zmieni się lista źródeł (receive dodany lub usunięty, ścieżka-źródło usunięta) albo nazwa odsłuchu lub źródła, serwer wysyła ponownie pełny `monitor`. Sama zmiana poziomów nie powoduje wysłania `monitor`.
- Odsłuchy i źródła są identyfikowane po GUID, więc przesunięcie ścieżek w projekcie niczego nie zmienia (poza kolejnością w `monitors`, jeśli przesunięto odsłuch).
- Gdy subskrybowany odsłuch przestaje istnieć (ścieżka usunięta, nazwa zmieniona na taką bez prefiksu, przełączenie projektu), serwer wysyła najpierw nowe `monitors`, a potem:

```json
{ "type": "monitor_removed", "id": "{1B6A2C10-0010-4A3E-9C1D-000000000010}" }
```

  Subskrypcja się kończy; żeby znów oglądać odsłuch, klient wysyła `subscribe`.

## Błędy

```json
{ "type": "error", "code": "unknown_type", "message": "unknown message type: make_coffee" }
```

`code` jest dla programu, `message` dla człowieka (do logów, bez gwarancji treści). Błąd nie zamyka połączenia.

| `code` | Kiedy |
|---|---|
| `handshake_required` | wiadomość inna niż `hello` przed `welcome` |
| `invalid_message` | tekst, który nie jest obiektem JSON ze stringowym `type`, albo brakujące lub złego typu pola (np. `hello` bez całkowitego `protocolVersion`) |
| `unknown_type` | nieznany `type` po `welcome` |
| `not_found` | nieznany GUID odsłuchu (np. w `subscribe`) |

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

- `project` — stan projektu REAPERa, na którym stoi serwer (fałszywy projekt w testach Rozszerzenia). Ścieżka może mieć opcjonalne `receives`: `[{ "source": "<GUID ścieżki-źródła>", "level": 0.5 }]` w kolejności receive'ów.
- `steps` — wiadomości w kolejności: `client` wysyła klient, `server` wysyła serwer. Krok `client` podany jako string jest wysyłany dosłownie (do przykładów z niepoprawnym JSON-em).
- Krok `project` (obiekt jak `project` wyżej) to zmiana w REAPERze: od tego miejsca projekt ma dokładnie taki stan (np. dodana ścieżka, zmieniona nazwa, inny projekt). Test Rozszerzenia podmienia fałszywy projekt i zgłasza zmianę; fałszywy serwer Aplikacji czeka w tym miejscu, aż test pozwoli mu iść dalej.
- Dopasowanie wiadomości: każde pole z przykładu musi wystąpić w prawdziwej wiadomości z tą samą wartością; obiekty mogą mieć dodatkowe pola (np. `message` w `error`), a tablice muszą mieć te same elementy w tej samej kolejności.
- Po ostatnim kroku serwer nie wysyła już nic, a połączenie zostaje otwarte.
