# Phase 4 — Fit / Hold Pose / Workshop Materials

این نسخه سه مشکل اصلی را اصلاح می‌کند:

1. قطعات جلویی بعد از برعکس شدن بدنه، با همان جهت قدیمی Snap می‌شدند و مارپیچ بیرون بدنه می‌ماند.
   - SnapPoint های Auger / Blade / Plate / LockRing اکنون 180 درجه حول Y چرخیده‌اند.
   - در نتیجه مارپیچ به داخل محفظه می‌رود و محور بیرونی برای Blade/Plate/Ring درست باقی می‌ماند.

2. قطعات تخت روی میز هنگام برداشتن همچنان کاملاً افقی دیده می‌شدند.
   - Blade / Plate / LockRing هنگام Grab فقط از نظر Visual حدود 65 درجه Tilt می‌شوند.
   - Collision بدنه دستکاری نمی‌شود تا Physics پایدار بماند.
   - قبل از Snap، Visual خودکار به Orientation واقعی بازمی‌گردد.

3. محیط و مدل‌ها Flat و بدون Texture بودند.
   - دیوار: Concrete PBR-style
   - کف: Industrial concrete
   - میز: Brushed steel
   - کمد / Rack / در کارگاه: Painted steel
   - تخته آموزشی: Chalkboard
   - بدنه و قطعات فلزی چرخ‌گوشت: Brushed stainless steel
   - Pusher: White plastic

همچنین مشکل باقی ماندن حلقه قرمز بعد از Snap سخت‌گیرانه‌تر اصلاح شده و حالت OFF/PLACED همیشه Visual guide را مخفی می‌کند.

## Material Sources

پروژه برای اجرا شدن بدون اینترنت، Textureهای سبک 512px داخلی دارد.
برای نسخه نهایی، فایل `MATERIAL_SOURCES.md` و اسکریپت اختیاری زیر را ببین:

    tools/download_polyhaven_cc0_1k.sh

این اسکریپت نسخه 1K چند Material رایگان CC0 از Poly Haven را روی Mac دانلود می‌کند.
