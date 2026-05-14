class MasterCategory {
  final String id;
  final String name;
  final String displayName;
  final String defaultApplicationType; // 'feed_mix', 'water_mix', 'both'
  final int sortOrder;
  final bool active;

  const MasterCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.defaultApplicationType,
    this.sortOrder = 0,
    this.active = true,
  });

  bool supportsType(String applicationType) =>
      defaultApplicationType == applicationType ||
      defaultApplicationType == 'both';

  factory MasterCategory.fromJson(Map<String, dynamic> json) {
    return MasterCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      defaultApplicationType: json['default_application_type'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'default_application_type': defaultApplicationType,
        'sort_order': sortOrder,
        'active': active,
      };

  @override
  String toString() =>
      'MasterCategory(id: $id, name: $name, displayName: $displayName, type: $defaultApplicationType)';
}
