# GuildRecruiterTest

**GuildRecruiterTest** — отдельный in‑game аддон для **World of Warcraft**, предназначенный для автоматического тестирования основного аддона [GuildRecruiter](https://github.com/aadunin/GuildRecruiter).

## 📦 Возможности
- Автоматический прогон тестов для ключевых функций GuildRecruiter.
- Перехват `SendChatMessage` для предотвращения спама в игровой чат.
- Цветной вывод результатов (`PASS`, `FAIL`, `SKIP`) прямо в игре.
- Итоговая сводка и экспорт в **JUnit XML** в SavedVariables.

## 📂 Структура репозитория
```
GuildRecruiterTest/
 ├ GuildRecruiterTest.toc        # метаданные аддона
 ├ GuildRecruiterTest_Core.lua   # тестовый фреймворк и раннер
 └ GuildRecruiterTest_Spec.lua   # набор тестов
```

## 🔧 Установка
1. Скачайте или клонируйте репозиторий.
2. Поместите папку `GuildRecruiterTest` в директорию `Interface/AddOns/` вашего клиента WoW.
3. Убедитесь, что основной аддон **GuildRecruiter** установлен и включён.
4. На экране выбора персонажа включите аддон **GuildRecruiterTest**.

## ▶️ Использование
В игре доступны команды:
```
/grutest run [filter]    # Запуск всех тестов или фильтрованных по имени
/grutest list            # Показать список тестов
/grutest junit           # Экспорт результатов в JUnit XML
```

**Примеры:**
```
/grutest run
/grutest run Smoke
/grutest junit
```

JUnit‑отчёт сохраняется в:
```
WTF/Account/<AccountName>/SavedVariables/GuildRecruiterTest.lua
```
в переменной `GuildRecruiterTest_JUnit`.

## 📜 Лицензия
[MIT](LICENSE)
