# Phase 4.3 — Poly Haven PBR + Menu Grip Fix

## 1) نصب PBR واقعی Poly Haven

پروژه به صورت پیش‌فرض fallback map دارد تا هیچ dependency شکسته‌ای نداشته باشد.
برای جایگزین کردن با فایل‌های واقعی CC0 Poly Haven، فقط یک بار در Terminal از داخل پوشه پروژه اجرا کن:

```bash
./tools/download_polyhaven_cc0_1k.sh
```

این دستور برای سه سطح اصلی این سه map را دانلود می‌کند:

- Diffuse / Albedo
- Normal OpenGL
- ARM (AO / Roughness / Metallic)

Assetها:

- Concrete Wall 004
- Concrete Floor
- Green Metal Rust

Godot بعد از دانلود فایل‌ها را خودکار Reimport می‌کند. اگر Editor باز است چند ثانیه صبر کن.

## 2) منوی VR

منو دیگر با صرفاً وارد شدن دست فعال نمی‌شود.

روش صحیح:

1. دست را نزدیک دکمه موردنظر ببر.
2. نزدیک‌ترین دکمه کمی بزرگ می‌شود و برچسب `[U]` می‌گیرد.
3. کلید `U` را یک بار فشار بده.
4. U در Meta XR Simulator همان Grip است.

منو هم `grip` آنالوگ و هم `grip_click` را می‌خواند تا با Simulator و کنترلر واقعی سازگار باشد.

## 3) تست سریع

- Training: دست نزدیک «آموزش» → U
- Free Practice: دست نزدیک «تمرین آزاد» → U
- Reset: دست نزدیک «شروع مجدد» → U

