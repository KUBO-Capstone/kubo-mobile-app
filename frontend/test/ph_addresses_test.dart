import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/data/ph_addresses.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

// Edit Profile chooses from the same lists as sign-up, and maps an older
// address's spellings onto them so the dropdowns show it as chosen.
void main() {
  test('regions are found however an address spells them', () {
    expect(PhAddresses.findRegion('REGION III')?.regionName, 'REGION III');
    expect(PhAddresses.findRegion('Region III')?.regionName, 'REGION III');
    expect(PhAddresses.findRegion('National Capital Region')?.regionName, 'NCR');
    expect(PhAddresses.findRegion('ncr')?.regionName, 'NCR');
    expect(PhAddresses.findRegion('MIMAROPA')?.regionName, 'REGION IV-B');
    expect(PhAddresses.findRegion('Atlantis'), isNull);
    expect(PhAddresses.findRegion(''), isNull);
  });

  test('towns match with or without "City"', () {
    final region = PhAddresses.findRegion('Region III')!;
    final bulacan = PhAddresses.findByName(region.provinces, 'Bulacan', (Province p) => p.name)!;
    final towns = PhAddresses.townsOf(region, bulacan);
    String? town(String name) => PhAddresses.findByName(towns, name, (Municipality t) => t.name)?.name;

    expect(town('Malolos'), 'MALOLOS CITY');
    expect(town('City of Malolos'), 'MALOLOS CITY');
    expect(town('Balagtas'), 'BALAGTAS (BIGAA)');
  });

  test('NCR lists every city across its districts', () {
    final ncr = PhAddresses.findRegion('NCR')!;
    final names = PhAddresses.townsOf(ncr, null).map((t) => t.name).toList();
    expect(names, contains('QUEZON CITY'));
    expect(names, contains('CITY OF MAKATI'));
    expect(names.length, greaterThan(16));
  });

  test('comparable spelling', () {
    expect(PhAddresses.comparable('  City of  Las Piñas '), 'las pinas');
    expect(PhAddresses.comparable('Bacoor City'), 'bacoor');
  });
}
