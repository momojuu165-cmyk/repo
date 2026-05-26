class Warehouse {
  final int? id;
  final String name;
  final String? location;

  Warehouse({this.id, required this.name, this.location});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
      };

  factory Warehouse.fromMap(Map<String, dynamic> m) => Warehouse(
        id: m['id'] as int?,
        name: m['name'] as String,
        location: m['location'] as String?,
      );
}
