/// Canonical administrative divisions used by MyYatra district features.
///
/// District IDs are stable slugs suitable for Firestore document IDs. The
/// display names follow the requested MyYatra dataset; alternate names make
/// the two Nawalparasi districts unambiguous without changing their display
/// labels.
class NepalDistrict {
  const NepalDistrict({
    required this.id,
    required this.name,
    required this.province,
    this.alternateNames = const [],
  });

  final String id;
  final String name;
  final String province;
  final List<String> alternateNames;
}

class NepalDistrictDirectory {
  NepalDistrictDirectory._();

  static const Map<String, List<String>> districtsByProvince = {
    'Koshi': [
      'Bhojpur',
      'Dhankuta',
      'Ilam',
      'Jhapa',
      'Khotang',
      'Morang',
      'Okhaldhunga',
      'Panchthar',
      'Sankhuwasabha',
      'Solukhumbu',
      'Sunsari',
      'Taplejung',
      'Terhathum',
      'Udayapur',
    ],
    'Madhesh': [
      'Bara',
      'Dhanusha',
      'Mahottari',
      'Parsa',
      'Rautahat',
      'Saptari',
      'Sarlahi',
      'Siraha',
    ],
    'Bagmati': [
      'Bhaktapur',
      'Chitwan',
      'Dhading',
      'Dolakha',
      'Kathmandu',
      'Kavrepalanchok',
      'Lalitpur',
      'Makwanpur',
      'Nuwakot',
      'Ramechhap',
      'Rasuwa',
      'Sindhuli',
      'Sindhupalchok',
    ],
    'Gandaki': [
      'Baglung',
      'Gorkha',
      'Kaski',
      'Lamjung',
      'Manang',
      'Mustang',
      'Myagdi',
      'Nawalpur',
      'Parbat',
      'Syangja',
      'Tanahun',
    ],
    'Lumbini': [
      'Arghakhanchi',
      'Banke',
      'Bardiya',
      'Dang',
      'Gulmi',
      'Kapilvastu',
      'Parasi',
      'Palpa',
      'Pyuthan',
      'Rolpa',
      'Rukum East',
      'Rupandehi',
    ],
    'Karnali': [
      'Dailekh',
      'Dolpa',
      'Humla',
      'Jajarkot',
      'Jumla',
      'Kalikot',
      'Mugu',
      'Rukum West',
      'Salyan',
      'Surkhet',
    ],
    'Sudurpashchim': [
      'Achham',
      'Baitadi',
      'Bajhang',
      'Bajura',
      'Dadeldhura',
      'Darchula',
      'Doti',
      'Kailali',
      'Kanchanpur',
    ],
  };

  static const List<String> provinces = [
    'Koshi',
    'Madhesh',
    'Bagmati',
    'Gandaki',
    'Lumbini',
    'Karnali',
    'Sudurpashchim',
  ];

  static const List<String> experienceCategories = [
    'Nature',
    'Adventure',
    'Culture',
    'History',
    'Food',
    'Photography',
  ];

  static final List<NepalDistrict> districts = [
    for (final province in provinces)
      for (final name in districtsByProvince[province]!)
        NepalDistrict(
          id: _stableId(name),
          name: name,
          province: province,
          alternateNames: switch (name) {
            'Nawalpur' => const ['Nawalparasi East'],
            'Parasi' => const ['Nawalparasi West'],
            _ => const [],
          },
        ),
  ];

  static String _stableId(String name) {
    return switch (name) {
      'Nawalpur' => 'nawalparasi-east',
      'Parasi' => 'nawalparasi-west',
      _ => name.toLowerCase().replaceAll(' ', '-'),
    };
  }

  static NepalDistrict? byId(String id) {
    for (final district in districts) {
      if (district.id == id) return district;
    }
    return null;
  }

  static NepalDistrict? byName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final district in districts) {
      if (district.name.toLowerCase() == normalized ||
          district.alternateNames
              .any((alias) => alias.toLowerCase() == normalized)) {
        return district;
      }
    }
    return null;
  }
}
