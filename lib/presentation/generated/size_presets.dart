/// Portrait size presets for the procedural generator configurator.
/// Every entry is inside AspectBand (front#101); the shapes span small→large.
typedef SizePreset = ({String label, int cols, int rows});

const List<SizePreset> kSizePresets = [
  (label: 'S', cols: 6, rows: 10), // 0.600
  (label: 'M', cols: 9, rows: 16), // 0.5625 (target)
  (label: 'L', cols: 14, rows: 25), // 0.560
  (label: 'XL', cols: 19, rows: 34), // 0.559
];
