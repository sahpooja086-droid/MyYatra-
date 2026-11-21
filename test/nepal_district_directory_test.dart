import 'package:flutter_test/flutter_test.dart';
import 'package:myyatra/data/nepal_district_directory.dart';

void main() {
  test('canonical directory contains seven provinces and 77 districts', () {
    expect(NepalDistrictDirectory.provinces, hasLength(7));
    expect(NepalDistrictDirectory.districtsByProvince, hasLength(7));
    expect(NepalDistrictDirectory.districts, hasLength(77));
    expect(
      NepalDistrictDirectory.districtsByProvince.values
          .map((districts) => districts.length),
      [14, 8, 13, 11, 12, 10, 9],
    );
  });

  test('each district has a unique stable ID and matching province', () {
    final allNames = NepalDistrictDirectory.districtsByProvince.values
        .expand((districts) => districts)
        .toList();
    final allIds = NepalDistrictDirectory.districts.map((district) => district.id);

    expect(allNames.toSet(), hasLength(77));
    expect(allIds.toSet(), hasLength(77));

    for (final district in NepalDistrictDirectory.districts) {
      expect(
        NepalDistrictDirectory.districtsByProvince[district.province],
        contains(district.name),
      );
      expect(NepalDistrictDirectory.byId(district.id), same(district));
    }
  });

  test('recognizes both Nawalparasi aliases while preserving display names', () {
    final east = NepalDistrictDirectory.byName('Nawalparasi East');
    final west = NepalDistrictDirectory.byName('Nawalparasi West');

    expect(east?.name, 'Nawalpur');
    expect(east?.province, 'Gandaki');
    expect(east?.id, 'nawalparasi-east');
    expect(west?.name, 'Parasi');
    expect(west?.province, 'Lumbini');
    expect(west?.id, 'nawalparasi-west');
  });
}
