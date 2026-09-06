# Phase 1.1 - Auto Magnetic Snap

تغییرات این نسخه:

- Auto Snap بر اساس فاصله واقعی Pivot قطعه تا SnapPoint
- پیش‌فرض: 10 سانتی‌متر
- Snap حتی وقتی Auger هنوز در دست است
- رها شدن خودکار قطعه هنگام ورود به محدوده
- +10 امتیاز بعد از Snap
- تنظیمات مرکزی در `scripts/assembly/assembly_settings.gd`
- UI کوچک‌تر شده تا جلوی دید را نگیرد
- حالت Manual release-based همچنان با `AUTO_SNAP_ENABLED=false` قابل استفاده است

تست:

1. Meta XR Simulator را Active کن.
2. پروژه را Run کن.
3. Auger را با Grip بگیر (`U` در Keyboard bindings فعلی Simulator).
4. لازم نیست دقیق داخل سوراخ قرار بدهی؛ Pivot آن را تا حدود 10cm محل نصب ببر.
5. سیستم باید خودش قطعه را بگیرد، Snap کند و Score را 10 کند.
