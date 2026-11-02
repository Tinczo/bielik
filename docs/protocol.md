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

- `project` — stan projektu REAPERa, na którym stoi serwer (fałszywy projekt w testach Rozszerzenia).
- `steps` — wiadomości w kolejności: `client` wysyła klient, `server` wysyła serwer. Krok `client` podany jako string jest wysyłany dosłownie (do przykładów z niepoprawnym JSON-em).
- Dopasowanie wiadomości: każde pole z przykładu musi wystąpić w prawdziwej wiadomości z tą samą wartością; obiekty mogą mieć dodatkowe pola (np. `message` w `error`), a tablice muszą mieć te same elementy w tej samej kolejności.
- Po ostatnim kroku serwer nie wysyła już nic, a połączenie zostaje otwarte.
