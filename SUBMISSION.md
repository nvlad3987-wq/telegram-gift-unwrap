# Как отправить работу в бот @designers

Каждое сообщение боту стоит ★1, поэтому всё помещается в **одно сообщение**: видео и подпись со
ссылками на код и Figma.

## Что отправить

1. Откройте чат с @designers.
2. Прикрепите видео `media/Gift_Unwrap_Telegram.mp4` (квадрат 1080 × 1080, 15 секунд, со звуком).
   Отправляйте как видео, не как файл.
3. Вставьте подпись: английскую или русскую, ниже. Обе короче лимита Telegram в 1024 символа.
4. Отправьте.

### English

```
Gift Unwrap — a collectible you unwrap with your finger.

A new collectible arrives as a gift message with a glass sphere tied in the gift's colours. Tap it: the sphere lifts up and a hint shows how to pull the ribbon. Pull, and the glass cracks and bursts, the gift's backdrop and symbol fill the screen, and the sheet shows its real attributes and rarity. "Show on Profile" flies it into the ring of collectibles around your avatar; closing keeps it private.

• Works for any collectible: model, symbol, backdrop, number, rarity
• Native iOS (UIKit + SceneKit) and Android (Views + Canvas), no dependencies
• Drops into Telegram-iOS and Telegram-Android with one script, using the real save request and toasts
• Telegram's springs, step haptics, sounds made in code

Code, Android APK, notes: https://github.com/nvlad3987-wq/telegram-gift-unwrap
Figma: https://www.figma.com/design/DrjvrVVzSh0kXpSdIzvAqJ?node-id=121-20479
```

### Русский

```
Gift Unwrap — коллекционный подарок, который распаковываешь пальцем.

Новый коллекционный подарок приходит сообщением со стеклянной сферой, перевязанной лентой в его цветах. Тапаешь — сфера поднимается, подсказка показывает, как тянуть ленту. Тянешь — стекло трескается и разлетается, фон и символ подарка заполняют экран, а карточка показывает его атрибуты и редкость. «Show on Profile» отправляет его в кольцо коллекционных подарков вокруг аватара; если закрыть — подарок остаётся скрытым.

• Работает с любым коллекционным подарком: модель, символ, фон, номер, редкость
• Нативно на iOS (UIKit + SceneKit) и Android (Views + Canvas), без зависимостей
• Встраивается в Telegram-iOS и Telegram-Android одним скриптом, с реальным запросом сохранения и тостами
• Пружины Telegram, вибрация, звуки из кода

Код, APK, инструкция: https://github.com/nvlad3987-wq/telegram-gift-unwrap
Figma: https://www.figma.com/design/DrjvrVVzSh0kXpSdIzvAqJ?node-id=121-20479
```

## Перед отправкой

- Откройте ссылку на GitHub в режиме инкогнито: репозиторий должен открываться без входа.
- В Figma нажмите **Share** и выберите «Anyone with the link → can view», иначе по ссылке
  попросят доступ.
- Отдельно слать видео Android-версии не нужно: оно лежит в репозитории
  (`media/GiftUnwrap_Android_render.mp4`), а каждое сообщение стоит ★1.

## Что где лежит

| Папка | Что внутри |
| --- | --- |
| `ios/` | проект Xcode: демо-приложение и Kit (сам эффект) |
| `android/` | проект Android Studio: библиотека `giftunwrap` и демо `app` |
| `TelegramIntegration/` | адаптеры и установщики для исходников Telegram-iOS и Telegram-Android |
| `media/` | видео для отправки, полноэкранная версия, видео Android, APK |
| `README.md`, `README.ru.md` | описание на английском и русском |
