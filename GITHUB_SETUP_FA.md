# اتصال پروژه به GitHub Private Repository

نام پیشنهادی ریپازیتوری: `vr-training-room`

## روش سریع با GitHub CLI

در Terminal وارد پوشه پروژه شو و اجرا کن:

```bash
git init
git add .
git commit -m "Initial VR meat grinder training prototype"
git branch -M main
gh repo create vr-training-room --private --source=. --remote=origin --push
```

اگر `gh` نصب یا Login نیست:

```bash
brew install gh
gh auth login
```

## اگر ریپازیتوری را از سایت GitHub ساختی

برای اکانت `amirasadirahmani`:

```bash
git init
git add .
git commit -m "Initial VR meat grinder training prototype"
git branch -M main
git remote add origin git@github.com:amirasadirahmani/vr-training-room.git
git push -u origin main
```

برای Commitهای بعدی:

```bash
git add .
git commit -m "Describe the change"
git push
```
