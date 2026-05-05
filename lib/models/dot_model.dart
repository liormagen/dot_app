class DotModel {
  const DotModel({
    required this.id,
    required this.x,
    required this.y,
  });

  final int id;
  final double x;
  final double y;

  factory DotModel.fromJson(Map<String, dynamic> json) {
    return DotModel(
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
      };
}
