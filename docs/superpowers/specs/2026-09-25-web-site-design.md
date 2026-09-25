# Family Mafia як сайт (етап 1) — дизайн

**Дата:** 2026-09-25
**Статус:** погоджено в чаті, очікує рев'ю spec

## Мета

Сайт зі статистикою Family Mafia, яким легко поділитися: кидаєш посилання в
Telegram-чат, людина відкриває його в браузері на телефоні й читає статистику
без встановлення APK. Мобільний застосунок лишається як є.

**Критерії успіху**

1. `https://seezov.github.io/FamilyMafiaApp/` відкривається в мобільному
   браузері й показує ті самі дані, що й застосунок.
2. На сайті є вкладки Season, Players (+ профіль гравця), Dashboard, Records.
3. У веб-збірці немає жодного API-ключа.
4. Сайт оновлюється сам: при push у `feature/flutter_migration`, щоночі та
   кнопкою в GitHub Actions.
5. Посилання в Telegram показується карткою з назвою, описом і картинкою.

**Поза межами етапу 1**

- **Chat (Gemini).** Не переноситься взагалі, бо коштує грошей.
- **Debug.** Лишається тільки в застосунку.
- **Прямі посилання на гравця / URL-роутинг.** Етап 2.
- **Окрема десктопна верстка.**
- **Виправлення того, що `assets/.env.json` бандлиться в APK.** Проблему
  зафіксовано нижче, але в цьому етапі її не виправляємо.

## Підхід

Flutter Web з того самого коду (варіант A). Альтернативи, від яких відмовились:
- **Окремий HTML/JS-сайт.** Довелося б дублювати всі екрани.
- **Прямі запити до Sheets з браузера.** Публічний API-ключ.

## Архітектура

### Веб-таргет

- `flutter create --platforms=web .` додає теку `web/`.
- Поведінка вебу відрізняється від застосунку тільки там, де це потрібно:
  через `kIsWeb` або conditional imports. Жодного форку коду.

### Навігація

- У `lib/main.dart` список екранів і `NavigationDestination` будуються з
  одного списку вкладок.
- На вебі Chat і Debug виключаються. Імпорти `chat_screen.dart` /
  `debug_screen.dart` не повинні тягнути у веб-збірку `dart:io`, тому
  `debug_screen.dart` (імпортує `dart:io` і `path_provider`) підключається
  через conditional import або виноситься так, щоб веб-компіляція не
  ламалася.
- Індекс вкладки (`selectedTabProvider`) рахується відносно списку вкладок
  поточної платформи.

### Дані на вебі

Конвеєр завантаження лишається як є (`parsedConfigProvider` →
`appDataProvider` → `SeasonLoaderService`). Змінюється тільки джерело кешу.

- **Ключі.** У CI немає файлу `assets/.env.json`, тож `_loadEnvJson()` повертає
  `{}` і `sheetsApiKeyProvider` дає `null`. Пункт `assets/.env.json` у
  `pubspec.yaml` не повинен ламати збірку, коли файлу немає. Якщо Flutter
  падає на відсутньому асеті, CI створює порожній `{}` у цьому файлі.
- **Remote config.** Веб **не** ходить за live-конфігом, а читає знімок
  `assets/prefetched/remote_config.json`, зроблений у тій самій збірці, що й
  знімки сезонів. Так конфіг і дані завжди збігаються. Якби веб брав live-конфіг,
  а після збірки в ньому з'явився новий remote-сезон, цей сезон став би
  «останнім» без даних, і `initialLoadProvider` падав би з «Failed to load
  latest season», тобто сайт лежав би до наступної збірки. Для цього
  `parsedConfigProvider` читає кешований remote config і тоді, коли
  `REMOTE_CONFIG_URL` порожній (порядок: live URL, якщо задано → кеш/знімок →
  бандлений `season_config.json` → `Season.allConfigs()`). У веб-збірку
  `REMOTE_CONFIG_URL` не передається.
- **Remote-сезони.** Коли `SheetsService` дорівнює `null`,
  `SeasonDataService` уже читає `getCachedSeasonData`. На вебі
  `SeasonCacheService` отримує реалізацію, яка:
  - `getCachedSeasonData(id)` → `rootBundle.loadString('assets/prefetched/season$id.json')`,
    а якщо асету немає, повертає `null`;
  - `getCachedRemoteConfig()` → `assets/prefetched/remote_config.json` або `null`;
  - `getCachedRowCount` → `null`;
  - запис / інвалідація → no-op.
  Мобільна реалізація (`dart:io` + `path_provider`) лишається як є.
  `SeasonCacheService` стає інтерфейсом, а провайдер обирає реалізацію через
  `kIsWeb`. Імпорт `dart:io` компілюється під веб, падає лише виклик, тому
  conditional imports не потрібні. Задача 1 плану це перевіряє через
  `flutter build web`.
- **Тека `assets/prefetched/`.** У git лежить тільки `.gitkeep`, вміст
  ігнорується. Тека додається в `pubspec.yaml` assets. У мобільних збірках
  вона порожня, тож APK не росте.

### Скрипт знімка Sheets

`tool/prefetch_seasons.dart`, запуск `dart run tool/prefetch_seasons.dart`:

1. Читає `SHEETS_API_KEY` і `REMOTE_CONFIG_URL` з env.
2. Завантажує remote config і зберігає його в `assets/prefetched/remote_config.json`.
3. Для кожного сезону з `source: remote` викликає ту саму логіку, що й
   `SheetsService.fetchSeasonData`, і пише результат у
   `assets/prefetched/season<id>.json`.
4. Якщо хоч один remote-сезон не вдалося отримати, завершується з ненульовим
   кодом.

`SheetsService` імпортує `package:flutter/foundation.dart`, а для
`dart run` це не підходить. Тому або прибираємо цю залежність (наприклад,
`debugPrint` → ін'єктований логер), або виносимо чисту функцію
fetch/парсингу в окремий файл без Flutter-імпортів, який використовують і
сервіс, і скрипт. Формат JSON має бути ідентичним тому, що пише мобільний кеш.

### Вигляд вебу

- **`web/index.html`:**
  - `<title>` «Family Mafia — статистика», `lang="uk"`;
  - Open Graph-теги (`og:title`, `og:description`, `og:image` з абсолютним URL
    на іконку в `web/icons/`, `og:url`);
  - легкий inline splash (логотип + «Завантаження…»), який ховається, коли
    Flutter відрендерив перший кадр.
- **Широкі екрани.** На вебі контент обмежено колонкою ~600 px по центру
  (обгортка в `MaterialApp.builder`). На телефоні нічого не змінюється.
- **Манифест і іконки.** `web/manifest.json` отримує назву та іконки
  застосунку.

## Збірка та деплой

`.github/workflows/web.yml`:

- **Тригери:** `push` у `feature/flutter_migration`, `workflow_dispatch`,
  `schedule` (щоночі, `cron: '0 3 * * *'` UTC).
- **Гілка за замовчуванням у репо — `master`.** GitHub запускає `schedule` і
  показує кнопку `workflow_dispatch` лише для workflow-файлу з `master`, тому
  файл має бути на обох гілках (їх і так пушимо разом, fast-forward). Checkout
  завжди бере `ref: feature/flutter_migration`, тобто нічна збірка будує живу
  гілку.
- **Кроки:**
  1. checkout;
  2. Flutter `3.41.4` stable (`subosito/flutter-action`), з кешем;
  3. `flutter pub get` (згенеровані freezed/json файли закомічені, тож
     `build_runner` у CI не потрібен);
  4. `dart run tool/prefetch_seasons.dart` з `SHEETS_API_KEY` із Secrets;
  5. `flutter test`;
  6. `flutter build web --release --base-href /FamilyMafiaApp/ --dart-define=REMOTE_CONFIG_URL=<raw url>`;
  7. `actions/upload-pages-artifact` (`build/web`) → `actions/deploy-pages`.
- **Дозволи:** `pages: write`, `id-token: write`; `concurrency: pages`.
- **Якщо будь-який крок падає,** деплою немає, і на Pages лишається
  попередня версія.

**Разові дії власника репо**

1. Settings → Secrets and variables → Actions → додати `SHEETS_API_KEY`.
2. Settings → Pages → Source: «GitHub Actions».
3. Settings → Environments → `github-pages` → Deployment branches: додати
   `feature/flutter_migration`. За замовчуванням деплой дозволено лише з
   `master`, тож без цього збірка після push у живу гілку буде відхилена.
4. Для ключа Sheets у Google Cloud обмеження по HTTP-referrer не потрібне,
   бо він використовується тільки в CI.

## Обробка помилок

| Ситуація | Поведінка |
|---|---|
| Знімка конфігу немає (наприклад, локальний `flutter run -d chrome` без prefetch) | бандлений `season_config.json` → `Season.allConfigs()` |
| Новий remote-сезон додано в live-конфіг після збірки | веб його не бачить (читає знімок), сезон з'явиться після наступної збірки (не пізніше, ніж за ніч) |
| Sheets недоступні в CI | скрипт падає, деплою немає, лишається стара версія |
| Тести падають | деплою немає |

## Тестування

- Наявні `flutter test` запускаються в CI перед збіркою.
- Тест списку вкладок: для вебу 4 вкладки без Chat/Debug, для мобільного 6.
- Тест веб-реалізації `SeasonCacheService` на фейковому asset bundle:
  повертає знімок, якщо він є, і `null`, якщо немає; записи — no-op.
- Тест скрипта знімка: на фейковій відповіді Sheets пише JSON у тому ж
  форматі, що й мобільний кеш, а при помилці повертає ненульовий код.
- Ручна перевірка: `flutter run -d chrome`, потім реальне посилання на Pages з
  телефона, потім прев'ю посилання в Telegram.

## Відомий ризик (поза етапом 1)

`pubspec.yaml:83` бандлить `assets/.env.json` у кожну збірку, тож ключі
Sheets і Gemini можна витягти з APK. Веб-збірка цього уникає, бо в CI файлу
немає. Для APK потрібне окреме рішення.
