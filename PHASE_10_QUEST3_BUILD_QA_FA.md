# Phase 10 — Quest 3 Final Build & QA

این فاز پروژه‌ی تأییدشده‌ی Phase 9 را برای Export واقعی Android/OpenXR روی خانواده Meta Quest 3 آماده می‌کند، بدون اینکه Textureهای Poly Haven یا منطق مونتاژ دوباره جایگزین شوند.

## تصمیم‌های Build

- Godot 4.7.x / OpenXR
- Renderer فعلی `Mobile` حفظ شده تا ظاهر تأییدشده در Simulator عوض نشود.
- Android Gradle Build فعال است.
- ABI فقط `arm64-v8a` است.
- `minSdk = 32`
- `targetSdk = 34`
- OpenXR Vendors نسخه `5.1.0-stable` به صورت reproducible با Script نصب می‌شود.
- Meta vendor plugin فعال است و Target اصلی Quest 3 / Quest 3S است.
- هیچ permission اضافی مثل Camera/Microphone/Location درخواست نمی‌شود؛ فقط Vibrate برای Haptic مجاز است.

## یک بار برای آماده‌سازی Mac

از ریشه پروژه:

```bash
./tools/quest3_prepare.sh
```

این Script:
1. Godot را پیدا می‌کند.
2. OpenXR Vendors 5.1.0 را در `addons/godotopenxrvendors/` نصب می‌کند.
3. Android Gradle build template را در `android/build/` ایجاد می‌کند.
4. Android SDK و API 34 و Java را بررسی می‌کند.

`android/` و OpenXR Vendors downloaded binary عمداً Git-track نمی‌شوند و در هر زمان با Script قابل بازسازی‌اند.

## Preflight

```bash
./tools/quest3_preflight.sh
```

تا وقتی خروجی `Preflight PASSED` نگرفته‌ای APK نهایی نساز.

## Debug APK

```bash
./tools/build_quest3_debug.sh
```

خروجی:

`builds/quest3/vr-training-room-quest3-debug.apk`

Script اندازه و SHA-256 فایل را هم چاپ می‌کند.

## Release APK

```bash
./tools/build_quest3_release.sh
```

Release واقعی به keystore شخصی و تنظیم Signing نیاز دارد. هیچ کلید خصوصی داخل Project یا Git قرار نمی‌گیرد.

## QA — Simulator Regression

قبل از هر Build:

- Manual: ترتیب کامل و Handle درست.
- Electric: Motor جای Handle.
- Sausage: `Plate → Lock Ring → Sausage Attachment`.
- Timed: شمارش 90 ثانیه و Timeout Fail.
- GREEN = Auto-Snap فوری؛ release لازم نیست.
- فقط یک دکمه Hover شود.
- Hover و Click صدا داشته باشند.
- Result: PASS/FAIL + Grade + Quality + Accuracy.
- Accuracy منصفانه VR: Completion + First Try.
- Drop تکراری یک مرحله Mistake را باد نکند.
- رکورد پایه و Best Passing Record ذخیره شوند.
- Result record چندخطی و خوانا باشد.

## QA — روی Quest 3 واقعی

این بخش تا زمانی که سخت‌افزار در دسترس نباشد قابل تأیید نهایی نیست:

- App Launch / Resume / Quit
- Tracking سر و دو Controller
- Grip/U interaction mapping
- Haptic feedback
- عدم لرزش یا penetration غیرطبیعی قطعات
- Auto-Snap تمام Socketها
- خوانایی متن فارسی در فاصله طبیعی
- Audio level مناسب
- Comfort در 72/90 Hz
- افت فریم هنگام گرفتن/رهاکردن و Snap
- دمای دستگاه در Session طولانی
- Sleep/Resume بدون شکستن Session state

## Gate نهایی

Phase 10 زمانی Ready-for-Device است که:

1. `quest3_preflight.sh` پاس شود.
2. Debug APK بدون خطا ساخته شود.
3. Regression Simulator پاس شود.

Ready-for-Store فقط بعد از تست Quest 3 واقعی، Release signing و تست requirements انتشار Meta اعلام می‌شود.
