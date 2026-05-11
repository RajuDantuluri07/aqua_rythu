enum TrayRequirement {
  notRequired,
  optional,
  mandatory,
}

extension TrayRequirementX on TrayRequirement {
  String get displayName {
    switch (this) {
      case TrayRequirement.notRequired:
        return 'Not required';
      case TrayRequirement.optional:
        return 'Optional';
      case TrayRequirement.mandatory:
        return 'Mandatory';
    }
  }

  String get dbValue {
    switch (this) {
      case TrayRequirement.notRequired:
        return 'not_required';
      case TrayRequirement.optional:
        return 'optional';
      case TrayRequirement.mandatory:
        return 'mandatory';
    }
  }

  static TrayRequirement fromDb(String? value) {
    switch (value) {
      case 'optional':
        return TrayRequirement.optional;
      case 'mandatory':
        return TrayRequirement.mandatory;
      case 'not_required':
      case 'notRequired':
      case 'not-required':
        return TrayRequirement.notRequired;
      default:
        return TrayRequirement.notRequired;
    }
  }
}
