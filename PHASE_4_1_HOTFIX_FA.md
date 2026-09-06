# Phase 4.1 — Material Load Hotfix

خطای `Failed loading resource ... concrete_wall_normal.png` رفع شده است.

در این نسخه Normal Map dependency از Materialهای Workshop حذف شده تا Godot 4.7 روی اولین Import بدون Broken Dependencies بالا بیاید.

- Albedo textures همچنان فعال هستند.
- رنگ/roughness/metallic Materialها حفظ شده است.
- PNGهای normal داخل assets باقی مانده‌اند، اما فعلاً به Materialها متصل نیستند.
- Warning مربوط به Jolt custom solver bias بحرانی نیست و مانع اجرای پروژه نمی‌شود.

بعداً وقتی pipeline متریال تثبیت شد، normal maps را با Import settings کنترل‌شده دوباره فعال می‌کنیم.
