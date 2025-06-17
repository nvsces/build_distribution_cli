import 'dart:async';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

final _scopes = [drive.DriveApi.driveFileScope];

Future<Map<String, dynamic>> loadConfig() async {
  final configFile = File(
    p.join(Directory.current.path, 'build_distribution_config.json'),
  );
  if (!configFile.existsSync()) {
    print(
      'Ошибка: Конфиг build_distribution_config.json не найден в корне проекта.',
    );
    exit(1);
  }

  final content = await configFile.readAsString();
  return json.decode(content) as Map<String, dynamic>;
}

String getFolderIdFromFlavor(Map<String, dynamic> folders, String flavor) {
  return folders[flavor] ?? folders['test'];
}

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    print(
      'Использование: build_distribution <apk_path> <build_name> <build_number> <flavor> [description]',
    );
    exit(1);
  }

  final apkPath = args[0];
  final buildName = args[1];
  final buildNumber = args[2];
  final flavor = args[3];
  final description = args.length >= 5 ? args[4] : null;

  print('Путь к apk: $apkPath');
  print('Build Name: $buildName');
  print('Build Number: $buildNumber');
  if (description != null) {
    print('Описание: $description');
  }

  final config = await loadConfig();

  final serviceAccountJson = config['service_account'] as Map<String, dynamic>;
  final folders = config['folders'] as Map<String, dynamic>;

  final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  final httpClient = await clientViaServiceAccount(credentials, _scopes);

  final driveApi = drive.DriveApi(httpClient);
  final apkFile = File(apkPath);
  // final fileLength = apkFile.lengthSync();
  if (!apkFile.existsSync()) {
    print("Файл не найден");
    return;
  }

  final apkFileName = '$buildName($buildNumber).apk';
  final folderId = getFolderIdFromFlavor(folders, flavor);

  final existingApk = await driveApi.files.list(
    q: "name = '$apkFileName' and '$folderId' in parents and trashed = false",
    spaces: 'drive',
    $fields: 'files(id, name)',
  );

  if (existingApk.files != null && existingApk.files!.isNotEmpty) {
    throw Exception(
      "❌ Файл с именем '$apkFileName' уже существует в Google Drive папке.",
    );
  }

  final apkStream = apkFile.openRead();

  final apkMedia = drive.Media(
    apkStream.transform(progressMonitor(apkFile.lengthSync())),
    apkFile.lengthSync(),
  );
  final apkDriveFile = drive.File()
    ..name = apkFileName
    ..parents = [folderId]; // <-- ID общей папки

  final uploadedApk = await driveApi.files.create(
    apkDriveFile,
    uploadMedia: apkMedia,
  );
  print("\n✅ APK загружен! ID: ${uploadedApk.id}");
  print("🔗 https://drive.google.com/file/d/${uploadedApk.id}/view");

  // 📄 Если есть description — создаём и загружаем TXT
  if (description != null) {
    final txtFileName = '$buildName($buildNumber).txt';

    final tmpDir = Directory.systemTemp;
    final tmpTxtPath = p.join(tmpDir.path, txtFileName);
    final txtFile = File(tmpTxtPath)..writeAsStringSync(description);

    final existingTxt = await driveApi.files.list(
      q: "name = '$txtFileName' and '$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (existingTxt.files != null && existingTxt.files!.isNotEmpty) {
      throw Exception("❌ Описание '$txtFileName' уже существует в папке.");
    }

    final txtMedia = drive.Media(txtFile.openRead(), txtFile.lengthSync());
    final txtDriveFile = drive.File()
      ..name = txtFileName
      ..parents = [folderId];

    final uploadedTxt = await driveApi.files.create(
      txtDriveFile,
      uploadMedia: txtMedia,
    );

    print("✅ Описание загружено! ID: ${uploadedTxt.id}");
    print("🔗 https://drive.google.com/file/d/${uploadedTxt.id}/view");
  }

  httpClient.close();
}

StreamTransformer<List<int>, List<int>> progressMonitor(int totalSize) {
  int uploadedBytes = 0;
  return StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (data, sink) {
      uploadedBytes += data.length;
      final progress = (uploadedBytes / totalSize * 100).toStringAsFixed(2);
      stdout.write("\r📤 Загрузка: $progress%");
      sink.add(data);
    },
    handleDone: (sink) => sink.close(),
  );
}
