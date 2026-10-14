# 地圖頁（真的地圖）

`/story-map` 現在開的是 `lib/pages/story_route_map_page.dart`：上列和下面的導覽列是 App 原本的，中間是這個資料夾的 `TreasureMap`。原本手繪的那一頁還在 `lib/pages/story_map_page.dart`，沒有刪，只是不再被用到。

## 這個資料夾是什麼

從路線展示專案（`play_taiwan_demo`）搬過來的地圖頁。除了 `api.dart`、`pages/treasure_map.dart`、`widgets/place_ticket.dart`，其他檔案跟展示專案一模一樣，之後那邊有更新，直接把同名的檔案蓋過來就好。

這兩支在這邊改過，從展示專案蓋過來時要留著：

- `pages/treasure_map.dart`：為了「做任務」多一個參數 `onDoTasks`、面板上抵達後多一顆「做任務」；關卡選單旁邊「地圖回到這一關」的圓形按鈕拿掉了。
- `widgets/place_ticket.dart`：卡片照片下面那一行「照片：Wikimedia Commons（點此看作者與授權）」拿掉了。

| 檔案 | 內容 |
|---|---|
| `pages/treasure_map.dart` | 地圖頁本身 `TreasureMap`：迷霧、路線規劃與切換、景點卡片、順路、提醒、隊友位置 |
| `widgets/` | 迷霧、車票卡片、對話泡泡、地圖共用的小元件、景點卡片打開的面板（周邊好去、查看任務、回顧劇情） |
| `models.dart`、`route_follow.dart`、`theme.dart` | 後端資料的模型、「路線跟著位置走」的計算、地圖頁的配色 |
| `api.dart` | **這一支是這個 App 自己的**：網址用 `.env` 的 `API_BASE_URL`，token 用 `AppSession.token`；多一個上傳檔案的 `upload`（作答交照片、影片用） |

## 跟 App 接在一起的地方

- **玩哪一個劇本**：後端說正在進行的那一個（`GET /api/Story/CurrentPlaying`）；沒有進行中的就用自己最新的一個。
- **上列的「地點探索度」**：地圖頁回報破了幾關、總共幾關（`onProgress`）。「明信片收集」是這份劇本拿到幾張、總共幾張（`onPostcards`），後端跟著地圖進度一起給（`GET /api/Map/{story_id}` 的 `postcard_unlocked_count`、`postcard_total_count`）。
- **右下角的貓**（`AiTalkButton`）當地圖上的 NPC：天氣和用餐的提醒從牠旁邊跳出泡泡，點牠一樣是開 AI 對話。要不要提醒由後端決定（`GET /api/Map/Reminders`）。
- **確認抵達**用定位（面板上的「我到了」，`POST /api/Map/Node/{id}/Arrive`）。
- **做任務**：抵達後面板上的「做任務」開 `lib/pages/story_task_page.dart`（`onDoTasks`），這一關的題目在那裡作答：題目是 `GET /api/Task/Node/{id}`、送出是 `POST /api/Task/Answer`（帶地圖正在追蹤的位置，後端檢查人在景點 200 公尺內）、提示是 `GET /api/Task/{id}/Hint`，照片和影片先傳 `POST /api/Upload`。全部通過就破關：答題頁不用按什麼，自己關掉，回來地圖會再問一次進度、開下一關。
- **破關後的明信片**：破關時自動跳出來，不用按「領取」。判斷破關的是地圖：後端的進度說這一關過了（自己做完任務、隊友做完、示範模式直接破關都算），`TreasureMap` 就叫 `onStageCleared`，地圖頁（`story_route_map_page.dart` 的 `_makePostcard`）開 `lib/pages/story_postcard_page.dart`，帶這一關的景點名稱、劇本和節點代號。答題頁開著的時候地圖不檢查進度，等它關掉才處理，明信片才不會跳在答題頁上面。後端要一張照片才做得出明信片（`POST /api/PostcardCatalog/GenerateAi`）：用這一次拍照任務交的那張（答題頁關掉時回給地圖頁的 `StoryTaskResult`）；沒有的話先問玩家要拍一張、從相簿選，還是先不要。明信片頁原本寫死的測試資料還在，沒帶照片進去時才會用到。網頁版（`flutter run -d chrome`）要注意：線上的後端回的圖片網址是 AI 服務的檔案連結，那邊沒有開放跨網域讀取，瀏覽器會擋掉下載；明信片頁遇到下載不了就改用網址直接顯示（`Image.network` 的 `webHtmlElementStrategy: fallback`），不當成生成失敗。
- **配色**：地圖頁包在自己的 `Theme` 裡（`buildTheme`），字型用 App 的。
- **展示工具**（比賽展示用，`story_route_map_page.dart` 裡的 `demoTools: true`）：面板上這一關的路線下面多了「模擬沿路線走」「故意走偏」「模擬隊友」，不用後端開示範模式。模擬沿路線走會讓我的位置一路走到景點，走到後按「我到了」、再「做任務」，送給後端的都是這個模擬的位置；故意走偏會觸發自動重新規劃；模擬隊友是在地圖上多三個假的隊友沿著路線走。按地圖右上的「重新定位」換回真的定位。**正式上線前把 `demoTools: true` 那一行拿掉**，不然任何人不用到現場就能確認抵達。

## 還沒接的

- 景點卡片的「周邊好去」「查看任務」「回顧劇情」開的是這個資料夾自己的簡易版（`widgets/node_sheets.dart`），資料是真的。App 原本的周邊頁、答題頁、劇情頁內容還是寫死的，等它們能收 `node_id` 再改成開那幾頁。（卡片上的「查看任務」只能看；要作答是面板上的「做任務」。）
- 做任務的錄音：`audio_or_video` 的題目現在只能交影片，App 還沒有錄音的套件。
- 用 QR Code 確認抵達：後端還沒有這支 API。

## 為了這一頁改到的其他地方

- `pubspec.yaml`：加了 `flutter_map`、`latlong2`。
- `android/app/src/main/AndroidManifest.xml`：加了 `INTERNET` 權限（正式版連網要用）和開 https 連結的宣告。
- `ios/Runner/Info.plist`：加了定位用途的說明文字（沒有的話 iOS 一要定位就會閃退）。
- `test/route_map/`：這一頁的測試，後端用假的。`flutter test test/route_map`
