# DalaCarbon AI — мобильді қосымша (Flutter)

Ағын: **заставка** (спутник алқаптардың үстінен ұшады, камера бұрылады, өткен алқаптар NDVI түсімен боялады,
сосын логотип шығады) → **кіру** (далалық иллюстрация + форма) → **жүктелу** (бұлдыр фон, орбитадағы спутник)
→ **басты бет** (табыс, секвестрация, қызметтер, төменгі мәзір). Логотип — сайттағы `mark-color.svg`-нің
дәл көшірмесі (`lib/widgets/brand_logo.dart`).

| Файл | Не істейді |
|---|---|
| `lib/screens/splash_screen.dart` | Заставка, 4,7 с (экранды басса — бірден өтеді) |
| `lib/widgets/field_scan.dart` | Алқаптар картасы, спутник маршруты, камера айналымы |
| `lib/screens/login_screen.dart` | Кіру формасы, тексеру, «Демо режимде көру» |
| `lib/widgets/scan_loading.dart` | Жүктелу анимациясы |
| `lib/screens/home_screen.dart` | Басты бет және төменгі мәзір |

## 1. Орнату (бір рет)

1. **Android Studio** — <https://developer.android.com/studio>
   - Орнатқан соң: *More Actions → SDK Manager → SDK Tools* → **Android SDK Command-line Tools** белгілеп, *Apply*.
   - *More Actions → Virtual Device Manager* → **Create device** (мысалы, Pixel 8) → іске қосыңыз.
2. **Flutter SDK** — <https://docs.flutter.dev/get-started/install/windows/mobile>
   - Беттегі zip-ті жүктеп, `C:\src\flutter` папкасына ашыңыз (бос орынсыз жол, `Program Files` емес).
   - `C:\src\flutter\bin` папкасын **Path** айнымалысына қосыңыз
     (Пуск → «Изменение переменных среды» → Path → Создать).
3. Жаңа PowerShell терезесінде:
   ```powershell
   flutter doctor
   flutter doctor --android-licenses
   ```
   Барлық сұраққа `y` деп жауап беріңіз. `flutter doctor` жасыл белгілермен шықса — дайын.

## 2. Іске қосу

```powershell
cd C:\Users\TechHub\Desktop\dalacarbon\mobile
flutter create . --org kz.dalacarbon --project-name dalacarbon_mobile --platforms android
flutter pub get
flutter run
```

`flutter create .` тек жетіспейтін `android/` папкасын жасайды, `lib/` ішіндегі кодқа тимейді.
Эмулятор ашық болса, қосымша соның ішінде іске қосылады. Нақты телефонда: *Параметрлер → Телефон туралы →
Құрастыру нөмірін 7 рет басу* → *Әзірлеуші опциялары → USB арқылы жөндеу* қосып, USB-мен жалғаңыз.

Android Studio әлі орнатылмаса да, қосымшаны **Chrome-да** көруге болады (телефон өлшемін
DevTools → Device Toolbar арқылы қойыңыз):
```powershell
flutter run -d chrome
```

Тексеру:
```powershell
flutter analyze
flutter test
```

## Әзірге демо

Кіру формасы тексеріледі, бірақ сайттың аккаунтына әлі қосылмаған — кез келген логин мен 8+ таңбалы
құпиясөз басты бетке өткізеді. Сандар сайттағы пилоттық сценарийден (5 000 га, 3 188 т CO₂e, $38 250).
Нақты кіру үшін Flask-қа JSON API қосу керек (келесі қадам).
