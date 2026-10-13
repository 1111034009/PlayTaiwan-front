# 地圖頁（真的地圖）

`/story-map` 現在開的是 `lib/pages/story_route_map_page.dart`：上列和下面的導覽列是 App 原本的，中間是這個資料夾的 `TreasureMap`。原本手繪的那一頁還在 `lib/pages/story_map_page.dart`，沒有刪，只是不再被用到。

## 這個資料夾是什麼

從路線展示專案（`play_taiwan_demo`）搬過來的地圖頁。除了 `api.dart`，其他檔案跟展示專案一模一樣，之後那邊有更新，直接把同名的檔案蓋過來就好。

| 檔案 | 內容 |
|---|---|
| `pages/treasure_map.dart` | 地圖頁本身 `TreasureMap`：迷霧、路線規劃與切換、景點卡片、順路、提醒、隊友位置 |
| `widgets/` | 迷霧、車票卡片、對話泡泡、地圖共用的小元件、景點卡片打開的面板（周邊好去、查看任務、回顧劇情） |
| `models.dart`、`route_follow.dart`、`theme.dart` | 後端資料的模型、「路線跟著位置走」的計算、地圖頁的配色 |
| `api.dart` | **只有這一支是這個 App 自己的**：網址用 `.env` 的 `API_BASE_URL`，token 用 `AppSession.token` |

## 跟 App 接在一起的地方

- **玩哪一個劇本**：後端說正在進行的那一個（`GET /api/Story/CurrentPlaying`）；沒有進行中的就用自己最新的一個。
- **上列的「地點探索度」**：地圖頁回報破了幾關、總共幾關（`onProgress`）。「明信片收集」跟原本一樣還是固定的數字。
- **右下角的貓**（`AiTalkButton`）當地圖上的 NPC：天氣和用餐的提醒從牠旁邊跳出泡泡，點牠一樣是開 AI 對話。要不要提醒由後端決定（`GET /api/Map/Reminders`）。
- **確認抵達**用定位（面板上的「我到了」，`POST /api/Map/Node/{id}/Arrive`）。
- **配色**：地圖頁包在自己的 `Theme` 裡（`buildTheme`），字型用 App 的。

## 還沒接的

- 景點卡片的「周邊好去」「查看任務」「回顧劇情」開的是這個資料夾自己的簡易版（`widgets/node_sheets.dart`），資料是真的。App 原本的周邊頁、答題頁、劇情頁內容還是寫死的，等它們能收 `node_id` 再改成開那幾頁。
- 用 QR Code 確認抵達：後端還沒有這支 API。

## 為了這一頁改到的其他地方

- `pubspec.yaml`：加了 `flutter_map`、`latlong2`。
- `android/app/src/main/AndroidManifest.xml`：加了 `INTERNET` 權限（正式版連網要用）和開 https 連結的宣告。
- `ios/Runner/Info.plist`：加了定位用途的說明文字（沒有的話 iOS 一要定位就會閃退）。
- `test/route_map/`：這一頁的測試，後端用假的。`flutter test test/route_map`
