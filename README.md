# Build Distribution CLI

`build_distribution_cli` — это утилита для удобной и быстрой загрузки Android-сборок (.apk) в Google Drive, используемая вместе с Build Distribution App (BDA).

---

## Настройка

1. Создайте сервисный аккаунт в Google Cloud и скачайте JSON-ключ.

2. В корень своего flutter проекта поместите файл build_distribution_config.json:

```json
{
    "service_account": {
        "type": "service_account",
        "project_id": "your-project-id",
        "private_key_id": "your-private-key-id",
        "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
        "client_email": "your-service-account-email@project.iam.gserviceaccount.com",
        "client_id": "your-client-id",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account-email@project.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com"
    },
    "folders": {
    "test": "folder-id-for-test",
    "staging": "folder-id-for-staging",
    "predprod": "folder-id-for-predprod"
  }
}
```
Поля `project_id`, `private_key_id`, `private_key`, `client_email`, `client_id` и другие берутся из JSON-ключа сервисного аккаунта.

В объекте `"folders"` ключи — это flavor (например, `test`, `staging`, `predprod`), значения — id соответствующих папок Google Drive (id можно получить из URL папки).

## Установка

Установите CLI глобально из Git:
```
dart pub global activate --source git https://github.com/nvsces/build_distribution_cli.git
```
## Использование

Вы можете использовать `build_distribution_cli` для загрузки сборок как вручную, так и автоматизированно. Ниже приведены все доступные варианты.

---

### 🔹 Вариант 1: Ручной запуск из терминала

```bash
flutter build apk --release \
  --build-name=1.0.0 \
  --build-number=42 \
  --flavor staging \
  --target lib/main_staging.dart

dart pub global run build_distribution \
  build/app/outputs/flutter-apk/app-staging-release.apk \
  1.0.0 \
  42 \
  staging
```

---

### 🔹 Вариант 2: Использование Makefile (если есть)

Добавьте следующую цель в `Makefile`:

```makefile
publish:
	@FLAVOR=$(word 2,$(MAKECMDGOALS)); \
	BUILD_NAME=$(word 3,$(MAKECMDGOALS)); \
	BUILD_NUMBER=$(word 4,$(MAKECMDGOALS)); \
	APK_PATH=build/app/outputs/flutter-apk/app-$$FLAVOR-release.apk; \
	echo "FLAVOR=$$FLAVOR BUILD_NAME=$$BUILD_NAME BUILD_NUMBER=$$BUILD_NUMBER"; \
	flutter build apk --release --build-name=$$BUILD_NAME --build-number=$$BUILD_NUMBER --flavor $$FLAVOR --target lib/main_$$FLAVOR.dart; \
	dart pub global run build_distribution $$APK_PATH $$BUILD_NAME $$BUILD_NUMBER $$FLAVOR
```

Запуск:

```bash
make publish staging 1.0.0 42
```

---

### 🔹 Вариант 3: Вручную без сборки (если сборка уже есть)

```bash
dart pub global run build_distribution \
  path/to/your_build.apk \
  1.0.0 \
  42 \
  staging
```

---

Где:

`<путь_к_файлу.apk>` — путь к собранному APK или AAB файлу.  
`<build_name>` — версия сборки (например, `1.0.0`).  
`<build_number>` — номер сборки (например, `42`).  
`<flavor>` — имя flavor (например, `staging`).


