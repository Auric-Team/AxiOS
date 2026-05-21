class PresetGame {
  final String package;
  final String name;

  const PresetGame({
    required this.package,
    required this.name,
  });
}

class AppConfig {
  // Hardcoded Connection URL of the server (cannot be customized by normal users)
  static const String defaultBackendUrl = 'http://193.70.34.101:20028';
  
  // Game relative installation paths
  static const String defaultSubpath = 'files/res/arm64-v8a';

  // Last Island of Survival targets configuration
  static const List<PresetGame> presets = [
    PresetGame(
      package: 'com.herogame.gplay.lastdayrulessurvival',
      name: 'Last Island of Survival',
    ),
  ];
}
