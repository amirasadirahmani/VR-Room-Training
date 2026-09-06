# تنظیم آسانی / سختی Snap

برای تغییر سختی فقط این فایل را باز کن:

`res://scripts/assembly/assembly_settings.gd`

مهم‌ترین خط:

```gdscript
const SNAP_RADIUS_M: float = 0.10
```

واحد متر است:

- `0.15` = آسان، 15 سانتی‌متر
- `0.10` = متوسط، 10 سانتی‌متر (پیش‌فرض فعلی)
- `0.06` = سخت، 6 سانتی‌متر

در نسخه فعلی:

```gdscript
const AUTO_SNAP_ENABLED: bool = true
```

یعنی لازم نیست Grip را دقیقاً روی سوراخ رها کنی. وقتی Pivot قطعه وارد شعاع تعیین‌شده شود:

1. اگر در دست باشد خودکار رها می‌شود.
2. به SnapPoint کشیده می‌شود.
3. قفل می‌شود.
4. +10 امتیاز می‌گیرد.
5. آموزش به مرحله بعد می‌رود.

برای برگشت به رفتار قبلی (Snap فقط بعد از رها کردن)، مقدار زیر را `false` کن:

```gdscript
const AUTO_SNAP_ENABLED: bool = false
```

## نکته تست Phase 1

فعلاً فقط Auger به صورت کامل پیاده شده است. اگر Auto Snap انجام شد باید در Output Godot ببینی:

```text
AUTO SNAP: auger -> socket_auger ...
ASSEMBLY OK: auger +10 score=10
```
