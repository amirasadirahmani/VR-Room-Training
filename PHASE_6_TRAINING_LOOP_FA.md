# Phase 6 — Training Loop

این نسخه چرخه کامل آموزش را روی پایه مکانیکی Phase 5 اضافه می‌کند.

## شروع
پروژه در «منوی اصلی» شروع می‌شود. تا وقتی Training یا Free Practice را انتخاب نکنی، قطعات قابل برداشتن نیستند.

در Meta XR Simulator:
- دست را نزدیک دکمه ببر.
- وقتی `[U]` ظاهر شد، یک بار U را بزن.

## حالت‌ها

### آموزش مرحله‌ای
ترتیب اجباری:
1. Auger
2. Blade
3. Plate
4. Lock Ring
5. Hopper Tray
6. Pusher

امتیاز:
- نصب صحیح: +10
- اولین تلاش در همان مرحله: +5
- تکمیل کل مونتاژ: +25
- برداشتن قطعه اشتباه: -2
- رها کردن اشتباه: -1
- حداکثر امتیاز: 115

### تمرین آزاد
- ترتیب اجباری خاموش است.
- هر قطعه‌ای که برداشته شود Socket خودش فعال می‌شود.
- امتیاز و جریمه محاسبه نمی‌شود.
- Snap مکانیکی و Collisionهای مجاز همچنان فعال‌اند.

## سختی
- آسان: Ready=22cm / Snap=15cm
- معمولی: Ready=16cm / Snap=10cm
- سخت: Ready=10cm / Snap=6cm

## پایان جلسه
بعد از نصب 6 قطعه، پنل نتیجه نمایش داده می‌شود:
- امتیاز
- زمان
- دقت
- خطاها
- تعداد نصب‌های First Try
- تکرار
- بازگشت به منوی اصلی

## Reset
Reset کامل شامل:
- Transform و Rotation اولیه قطعات
- Velocity صفر
- Score صفر
- Time صفر
- Mistakes صفر
- First Try صفر
- Guides reset
- Socket state reset
- Result panel reset

## Audio / Haptic
Audio:
- pickup
- move
- drop
- ready
- snap
- score
- error
- complete
- menu click

Haptic پایه برای Quest:
- pickup
- ورود به Ready
- snap صحیح
- خطا
- پایان
- فشردن منو

در Simulator ممکن است Haptic فیزیکی قابل احساس نباشد.
