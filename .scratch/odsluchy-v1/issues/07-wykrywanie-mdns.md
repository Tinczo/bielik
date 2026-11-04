# 07: Wykrywanie laptopa przez mDNS

**What to build:** Bielik sam pokazuje laptopy z REAPERem w sieci lokalnej, więc muzyk nie wpisuje adresu IP. Ręczny adres zostaje jako awaryjna droga, gdy sieć blokuje multicast.

**Blocked by:** 01

**Status:** resolved

- [ ] Rozszerzenie ogłasza usługę `_reaper-mixer._tcp` z nazwą komputera i aktualnym portem, a przy zamknięciu ją wycofuje.
- [ ] Bielik przegląda usługę i pokazuje listę wykrytych laptopów oraz opcję ręcznego adresu.
- [ ] Wykrywanie w Aplikacji jest za interfejsem. Testy podają adres wprost albo fałszywe wyniki wykrywania.
- [ ] Ręczna weryfikacja w prawdziwej sieci Wi-Fi.
