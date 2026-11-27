/// Shared definitions for the in-app data-use explanation.
///
/// The insight services and the data-use page both read these values so the
/// page cannot drift away from the inputs that are actually used.
enum DataUsePurpose { journeyDna, gapAnalysis, recommendations }

const List<String> journeyExperienceTypes = [
  'Nature',
  'Adventure',
  'Culture',
  'History',
  'Food',
  'Photography',
];

class DataUseInput {
  const DataUseInput({
    required this.title,
    required this.description,
    required this.purposes,
    required this.isPrivate,
  });

  final String title;
  final String description;
  final List<DataUsePurpose> purposes;
  final bool isPrivate;
}

const List<DataUseInput> dataUseInputs = [
  DataUseInput(
    title: 'Visits',
    description:
        'The places and districts you mark as visited, the date, your rating, '
        'and any notes you add.',
    purposes: [
      DataUsePurpose.journeyDna,
      DataUsePurpose.gapAnalysis,
      DataUsePurpose.recommendations,
    ],
    isPrivate: true,
  ),
  DataUseInput(
    title: 'Journal entries',
    description:
        'The title, text, date, and linked place or district of every entry '
        'you write.',
    purposes: [
      DataUsePurpose.journeyDna,
      DataUsePurpose.gapAnalysis,
      DataUsePurpose.recommendations,
    ],
    isPrivate: true,
  ),
  DataUseInput(
    title: 'Photos',
    description:
        'Your photo captions and the district or place they are linked to. '
        'Images stay in your private storage folder.',
    purposes: [
      DataUsePurpose.journeyDna,
      DataUsePurpose.gapAnalysis,
      DataUsePurpose.recommendations,
    ],
    isPrivate: true,
  ),
  DataUseInput(
    title: 'District experience types',
    description:
        'Public categories such as Nature, Adventure, Culture, History, Food, '
        'and Photography attached to districts you have visited or may visit.',
    purposes: [
      DataUsePurpose.journeyDna,
      DataUsePurpose.gapAnalysis,
      DataUsePurpose.recommendations,
    ],
    isPrivate: false,
  ),
  DataUseInput(
    title: 'Your reviews',
    description:
        'The display name and review text you post publicly. Only your display '
        'name is shown next to a review; your email is never attached.',
    purposes: [DataUsePurpose.journeyDna],
    isPrivate: false,
  ),
  DataUseInput(
    title: 'Visited-district coverage',
    description:
        'Which districts you have recorded a visit for, compared with all '
        'published districts.',
    purposes: [DataUsePurpose.gapAnalysis, DataUsePurpose.recommendations],
    isPrivate: true,
  ),
];
