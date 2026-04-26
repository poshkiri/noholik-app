# Universal Link для VK ID (Vercel)

Статический сайт: отдаёт `apple-app-site-association` и страницу-заглушку по пути `/vk_id_redirect/`.

## 1. Задеплойте на Vercel

```bash
cd vercel-vkid-link
npx vercel
```

Или подключите репозиторий к [Vercel Dashboard](https://vercel.com) и укажите **Root Directory**: `vercel-vkid-link`.

После деплоя вы получите URL вида `https://<имя-проекта>.vercel.app`.

## 2. Проверьте AASA

В браузере откройте:

`https://<имя-проекта>.vercel.app/.well-known/apple-app-site-association`

Должен открыться JSON **без** редиректа, с заголовком `Content-Type: application/json`.

Проверка Apple (опционально): [Branch AASA Validator](https://branch.io/resources/aasa-validator/) или аналог.

## 3. Укажите Universal Link в кабинете VK ID

В поле **Universal link** вставьте:

`https://<имя-проекта>.vercel.app/vk_id_redirect`

(без слэша в конце или со слэшем — как требует форма VK; чаще используют путь без завершающего слэша, но у нас есть и `/vk_id_redirect/`).

## 4. Синхронизируйте iOS

В Xcode в файле **`GestureApp/GestureApp.entitlements`** замените домен в `Associated Domains` на ваш реальный хост:

`applinks:<имя-проекта>.vercel.app`

Пересоберите приложение. Team ID и Bundle ID в `apple-app-site-association` уже совпадают с проектом GestureApp; если вы меняете bundle id — обновите JSON в `public/.well-known/apple-app-site-association` и задеплойте снова.

## Файлы

| Путь | Назначение |
|------|------------|
| `public/.well-known/apple-app-site-association` | Файл для Universal Links (Apple) |
| `public/vk_id_redirect/index.html` | Fallback, если приложение не установлено |
| `vercel.json` | Правильный `Content-Type` для AASA |
