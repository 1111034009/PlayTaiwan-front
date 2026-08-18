# PlayTaiwan-front
##  確認無錯誤
```bash
flutter doctor
```

如果 `flutter doctor` 沒有重大錯誤，即可開始執行專案。

##  安裝 Flutter 套件

進入 Flutter 專案根目錄後，執行：

```bash
flutter pub get
```


##  啟動專案

套件安裝完成後，執行：

```bash
flutter run
```

即可啟動 Flutter 專案。

如果電腦上有多個裝置，可以先查看目前可用的裝置：

```bash
flutter devices
```

再指定裝置執行：

```bash
flutter run -d <device_id>
```

例如：

```bash
flutter run -d chrome
```

