# Natywne rozszerzenie REAPERa z WebSocketami zamiast web remote

REAPER ma wbudowany web remote z gotową stroną MoreMe, która już pozwala ustawiać receive'y szyny z telefonu. Mimo to piszemy własne rozszerzenie C++ (tylko Windows x64) z serwerem WebSocket. Web remote działa wyłącznie na pollingu, adresuje ścieżki numerem i nie ogłasza się w sieci. Rozszerzenie daje push zmian do telefonów, identyfikację ścieżek po GUID, wykrywanie przez mDNS i własne hasło.

## Consequences

- API REAPERa wolno wołać tylko z głównego wątku. Serwer WebSocket działa na osobnym wątku i przekazuje polecenia przez kolejkę, którą opróżnia timer zarejestrowany w REAPERze (zob. `docs/research/reaper-control-options.md`).
- Budujemy i dystrybuujemy plik .dll ręcznie (MSVC + CMake). Wsparcie macOS albo Linuxa wymagałoby osobnych buildów.
