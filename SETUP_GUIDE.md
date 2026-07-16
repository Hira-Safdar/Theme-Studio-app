# Theme Studio — Setup Guide

Ye app ek **non-launcher personalization app** hai: Wallpaper + Icon Changer (Shortcut method) + Widgets + Control Center. Launcher NAHI hai — bilkul jaisi humne discuss ki thi ("Themepack" jaisi apps ki tarah).

## Step 1 — Project banayein

```bash
flutter create theme_studio
cd theme_studio
```

Phir is package ke `lib/`, `pubspec.yaml`, aur `assets/` folders ko apne naye project ke andar copy kar dein (overwrite kar dein jo already hain).

## Step 2 — Dependencies install

```bash
flutter pub get
```

## Step 3 — Native Kotlin files copy karein

`android_native_files/kotlin/*.kt` — ye saari files apne project ke is path pe copy karein:

```
android/app/src/main/kotlin/com/example/theme_studio/
```

(agar aapka package name alag rakhna hai, to sabhi `.kt` files ke `package com.example.theme_studio` line ko aur `build.gradle` ka `applicationId` dono ko match karna hoga)

## Step 4 — XML resources copy karein

```
android_native_files/res/xml/*.xml        →  android/app/src/main/res/xml/
android_native_files/res/layout/*.xml     →  android/app/src/main/res/layout/
android_native_files/res/values/strings_additions.xml → apni strings.xml me merge karein
```

## Step 5 — AndroidManifest.xml update karein

`android_native_files/AndroidManifest_ADDITIONS.xml` kholein aur usme diye gaye permissions + service/receiver tags ko apni `android/app/src/main/AndroidManifest.xml` me **manually merge** karein (poori file overwrite NA karein).

## Step 6 — Apne assets daalein

- `assets/wallpapers/` → kam se kam 2 images: `classic_day.jpg`, `neon_night.jpg`
- `assets/icon_packs/classic/` → `whatsapp.png`, `facebook.png`, `instagram.png`, `youtube.png`
- `assets/icon_packs/neon/` → same 4 files, dusre style me

(placeholder .txt files already daali hain — unhe delete karke apni real images se replace karein)

## Step 7 — Full run (hot reload nahi chalega native changes ke liye)

```bash
flutter clean
flutter pub get
flutter run
```

## Testing checklist (Samsung SM-G985F + Infinix X6835 dono pe)

1. **Wallpaper** — Home tab se ek theme apply karein, dekhein Home + Lock dono screen change hui ya nahi
2. **Icon Changer** — "Apply" dabayein kisi app pe, system ka "Add to Home Screen" dialog confirm karein, dekhein Home Screen pe custom icon + chhota badge dikh raha hai
3. **Custom Icon** — gallery icon se koi ek app ke liye custom icon set karein, phir "Apply" dabayein
4. **Widgets** — "Add" dabayein Battery Widget pe, confirm karein, Home Screen pe percentage dikh raha hai ya nahi
5. **Control Center** — Accessibility Settings kholein, service ON karein, wapas app me aayein (status turant "ON" dikhna chahiye), phir screen ke top se swipe down karke overlay test karein

## Yaad rakhne wali baatein

- Icon Changer sirf **shortcut** banata hai — original app ka icon App Drawer mein wahi rahega, aur Home Screen wale custom icon ke corner par chhota badge aa sakta hai. Ye Android security policy hai, remove nahi ho sakta.
- Widgets purely native hain — Flutter sirf "add karne ka request" bhejta hai, actual drawing `RemoteViews` (Kotlin) karta hai.
- Control Center launcher ko replace nahi karta, sirf uske UPAR overlay dikhata hai — isliye Samsung One UI ho ya koi bhi launcher, sab ke sath kaam karega.
- `adb logcat -s ThemeStudio:E` jaisa tag laga kar Kotlin side se print/log karke debug karein agar koi native call fail ho.
