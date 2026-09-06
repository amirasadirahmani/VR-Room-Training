# Phase 5 — Mechanical Fit / Legal Collision

این نسخه روی اتصال مکانیکی قطعات تمرکز دارد.

## ترتیب دقیق نهایی
مقادیر SnapPoint بر اساس anchorهای مدل Blender حفظ شده‌اند و بعد از برعکس شدن بدنه mirrored شده‌اند:

- Auger: X = +0.182 m
- Blade: X = +0.210 m
- Plate: X = +0.228 m
- Lock Ring: X = +0.246 m
- Hopper: Y = +0.599 m
- Pusher: Y = +0.585 m (کمی داخل ورودی)

## Snap دو مرحله‌ای
هر اتصال حالا این رفتار را دارد:

1. Align روبروی محور صحیح
2. Insert روی محور مکانیکی
3. Lock در Transform نهایی

در نتیجه Auger به جای ظاهر شدن روی دهانه، واقعاً از جلو داخل بدنه Slide می‌شود.
Blade/Plate/Ring نیز به ترتیب روی محور جلویی Slide می‌شوند.

## Collision مجاز
در محدوده اتصال، Collision دیگر به صورت کلی خاموش نمی‌شود.
قطعه مرحله فعلی فقط با این موارد exception موقت می‌گیرد:

- GrinderBase
- قطعاتی که قبلاً صحیح نصب شده‌اند

Collision با موارد زیر همچنان فعال می‌ماند:

- میز
- دیوار
- بدن بازیکن
- قطعات نصب‌نشده/اشتباه

بنابراین سوراخ Plate یا Ring فقط هنگام اتصال صحیح می‌تواند روی محور مجاز عبور کند.

## تنظیم سرعت
res://scripts/assembly/assembly_settings.gd

- SNAP_ALIGN_DURATION_S
- SNAP_INSERT_DURATION_S
- SNAP_RADIUS_M
- READY_RADIUS_M
