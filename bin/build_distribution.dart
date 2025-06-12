import 'dart:async';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
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
      'Использование: build_distribution <apk_path> <build_name> <build_number> <flavor>',
    );
    exit(1);
  }

  final apkPath = args[0];
  final buildName = args[1];
  final buildNumber = args[2];
  final flavor = args[3];

  print('Путь к apk: $apkPath');
  print('Build Name: $buildName');
  print('Build Number: $buildNumber');

  final config = await loadConfig();

  final serviceAccountJson = config['service_account'] as Map<String, dynamic>;
  final folders = config['folders'] as Map<String, dynamic>;

  final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

  final httpClient = await clientViaServiceAccount(credentials, _scopes);

  final driveApi = drive.DriveApi(httpClient);
  final fileToUpload = File(apkPath);
  final fileLength = fileToUpload.lengthSync();
  if (!fileToUpload.existsSync()) {
    print("Файл не найден");
    return;
  }

  final fileName = '$buildName($buildNumber).apk';
  final folderId = getFolderIdFromFlavor(folders, flavor);

  final existingFiles = await driveApi.files.list(
    q: "name = '$fileName' and '$folderId' in parents and trashed = false",
    spaces: 'drive',
    $fields: 'files(id, name)',
  );

  if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
    throw Exception(
      "❌ Файл с именем '$fileName' уже существует в Google Drive папке.",
    );
  }

  final stream = fileToUpload.openRead();

  int uploadedBytes = 0;
  final monitoredStream = stream.transform(
    StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        uploadedBytes += data.length;
        final progress = (uploadedBytes / fileLength * 100).toStringAsFixed(2);
        stdout.write("\r📤 Загрузка: $progress%"); // \r — перезаписывает строку
        sink.add(data);
      },
      handleError: (error, stackTrace, sink) =>
          sink.addError(error, stackTrace),
      handleDone: (sink) => sink.close(),
    ),
  );

  final media = drive.Media(monitoredStream, fileToUpload.lengthSync());
  final driveFile = drive.File();
  driveFile.name = fileName;
  driveFile.parents = [folderId]; // <-- ID общей папки

  final uploadedFile = await driveApi.files.create(
    driveFile,
    uploadMedia: media,
  );

  print("✅ Загружено! ID файла: ${uploadedFile.id}");
  print("🔗 Ссылка: https://drive.google.com/file/d/${uploadedFile.id}/view");

  httpClient.close();
}
