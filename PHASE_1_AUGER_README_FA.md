# Phase 1 — Auger Grab + Magnetic Snap + Score

این نسخه روی همان پروژه XR قبلی ساخته شده و مدل‌های اصلاح‌شده Blender داخل خودش دارد.

## اجرا
1. فولدر قبلی را نگه دار یا Rename کن.
2. این ZIP را Extract کن.
3. `project.godot` را با Godot 4.7.2 باز کن.
4. Meta XR Simulator را Active کن.
5. Run Project را بزن.

## تست مورد انتظار
- مدل واقعی GrinderBase روی میز دیده شود.
- Auger سمت راست دستگاه روی میز باشد.
- با Grip بتوانی Auger را بگیری.
- آن را به دهانه جلویی دستگاه نزدیک کن.
- در محدوده حدود 11 سانتی‌متر، Grip را رها کن.
- Auger طی حدود 0.2 ثانیه روی Socket خودش Snap شود و قفل شود.
- Score از 0 به 10 برود.
- Tutorial به «حالا تیغه را نصب کن» تغییر کند.

## Scope این نسخه
فقط Loop اول (Auger) فعال شده است. مدل‌های همه قطعات دیگر داخل `assets/models/grinder/` هستند اما هنوز Grab/Snap آنها فعال نشده است.
