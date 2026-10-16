class StampSettings {
  bool showCoordinates;
  bool showAddress;
  bool showDateTime;
  bool showAccuracy;
  bool showQr;
  bool pixelEmbeddedStamps;
  String customText;

  StampSettings({
    this.showCoordinates = true,
    this.showAddress = true,
    this.showDateTime = true,
    this.showAccuracy = true,
    this.showQr = true,
    this.pixelEmbeddedStamps = true,
    this.customText = '',
  });

  StampSettings copy({
    bool? showCoordinates,
    bool? showAddress,
    bool? showDateTime,
    bool? showAccuracy,
    bool? showQr,
    bool? pixelEmbeddedStamps,
    String? customText,
  }) => StampSettings(
    showCoordinates: showCoordinates ?? this.showCoordinates,
    showAddress: showAddress ?? this.showAddress,
    showDateTime: showDateTime ?? this.showDateTime,
    showAccuracy: showAccuracy ?? this.showAccuracy,
    showQr: showQr ?? this.showQr,
    pixelEmbeddedStamps: pixelEmbeddedStamps ?? this.pixelEmbeddedStamps,
    customText: customText ?? this.customText,
  );

  Map<String, dynamic> toJson() => {
    'showCoordinates': showCoordinates,
    'showAddress': showAddress,
    'showDateTime': showDateTime,
    'showAccuracy': showAccuracy,
    'showQr': showQr,
    'pixelEmbeddedStamps': pixelEmbeddedStamps,
    'customText': customText,
  };

  factory StampSettings.fromJson(Map<String, dynamic> json) => StampSettings(
    showCoordinates: json['showCoordinates'] as bool? ?? true,
    showAddress: json['showAddress'] as bool? ?? true,
    showDateTime: json['showDateTime'] as bool? ?? true,
    showAccuracy: json['showAccuracy'] as bool? ?? true,
    showQr: json['showQr'] as bool? ?? true,
    pixelEmbeddedStamps: json['pixelEmbeddedStamps'] as bool? ?? true,
    customText: json['customText'] as String? ?? '',
  );
}
