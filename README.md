<p align="center">
  <img src="app/assets/logo/bielik.png" alt="Logo Bielika: głowa bielika z wielkim żółtym dziobem" width="240">
</p>

<h1 align="center">Bielik</h1>

Pilot do odsłuchów zespołu. Każdy muzyk ustawia z telefonu, jak głośno słyszy poszczególne źródła w swoim odsłuchu, który REAPER miksuje na laptopie podczas próby. Nikt nie musi przerywać grania ani podchodzić do komputera.

> **Status:** wczesna wersja. Testy automatyczne przechodzą, a Rozszerzenie ładuje się w REAPERze 7.24, ale całość nie została jeszcze sprawdzona na próbie z telefonami.

## Pobieranie

Najnowsza wersja jest w [Releases](https://github.com/Tinczo/bielik/releases):

- `bielik-….apk`: aplikacja na telefony z Androidem 7.0 lub nowszym. Telefon może poprosić o zgodę na instalację spoza Sklepu Play.
- `reaper_mobile_mixer.dll`: Rozszerzenie dla REAPERa na Windows x64, instalowane tylko na laptopie. Zamknij REAPERa, skopiuj plik do `%APPDATA%\REAPER\UserPlugins` i uruchom go ponownie.

## Jak to działa

System ma dwie części:

- **Rozszerzenie** to natywna wtyczka REAPERa (C++, Windows x64). Ogłasza się w sieci lokalnej i udostępnia odsłuchy przez WebSocket.
- **Bielik** to aplikacja na Androida (Flutter). Znajduje laptopa w sieci i steruje poziomami.

## Co potrafi

- Własny miks dla każdego muzyka: zmiana w jednym odsłuchu nie wpływa na inne.
- Suwaki reagują na bieżąco, a zmiany z REAPERa i innych telefonów pojawiają się od razu na wszystkich telefonach z tym samym odsłuchem.
- Cofanie i ponawianie własnych zmian poziomów, gdy przez przypadek przesuniesz suwak.
- Automatyczne wykrywanie laptopa w sieci (mDNS), z ręcznym adresem jako awaryjną drogą.
- Hasło zespołu, żeby nikt spoza zespołu nie zmieniał odsłuchów.
- Nowe ścieżki, zmiany nazw i przełączenie projektu widać bez ponownego łączenia.
- Po utracie Wi-Fi albo restarcie REAPERa Bielik sam łączy się ponownie, a po uruchomieniu wraca do ostatniego laptopa i odsłuchu.

## Przygotowanie sesji w REAPERze

1. Utwórz dla każdego muzyka ścieżkę z prefiksem `Odsłuch:` w nazwie, np. `Odsłuch: Basia`. Działa też zapis `Odsluch:`, bo wpisywanie „ł” może wywołać skrót REAPERa.
2. Do tej ścieżki dodaj receive'y ze ścieżek, które muzyk ma słyszeć, np. gitary i wokalu. To są jej źródła.
3. Skieruj ścieżkę na wyjście interfejsu, do którego podłączone są słuchawki albo monitor.
4. Hasło i port ustawisz akcją `Mobile mixer: Settings (port, band password)...`. Domyślny port to `8790`.

Telefon i laptop muszą być w tej samej sieci. Przy pierwszym uruchomieniu zapora Windows może poprosić o zgodę na dostęp REAPERa do sieci.

## Budowanie

### Rozszerzenie

Wymaga Visual Studio 2022 z narzędziami C++ oraz CMake. Polecenia uruchom w `extension/`:

```powershell
.\msvc.cmd cmake --preset default
.\msvc.cmd cmake --build --preset default
```

Skopiuj `extension\build\reaper_mobile_mixer.dll` do `%APPDATA%\REAPER\UserPlugins` i uruchom REAPERa ponownie.

### Aplikacja

Wymaga [FVM](https://fvm.app). Wersja Fluttera jest przypięta w `app/.fvmrc`. Polecenia uruchom w `app/`:

```powershell
fvm flutter pub get
fvm flutter run
```

Na emulatorze Androida laptop jest pod adresem `10.0.2.2`.

## Testy

```powershell
# w extension/
.\msvc.cmd ctest --preset default

# w app/
fvm flutter test
```

Obie strony korzystają ze wspólnych przykładów wiadomości z `protocol/examples/`, które pilnują zgodności z protokołem.

## Dokumentacja

- [Protokół](docs/protocol.md): kontrakt między Rozszerzeniem a aplikacją.
- [Słownik](GLOSSARY.md): pojęcia używane w projekcie.
- [Ręczna weryfikacja](docs/reczna-weryfikacja.md): lista sprawdzeń w prawdziwym REAPERze z telefonem.
- [Decyzje architektoniczne](docs/adr/): dlaczego własne rozszerzenie, a nie wbudowany web remote.
