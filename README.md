# CleanSpace — iOS Storage Cleaner App

<p align="center">
  <strong>An elegant, native, privacy-first iOS cleaner app built with SwiftUI.</strong><br>
  Designed & Developed with ❤️ by <strong><a href="https://github.com/Avinash11-AK11">Avinash Chavda</a></strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Author-Avinash%20Chavda-10B981?style=for-the-badge&logo=github&logoColor=white" alt="Author" />
  <img src="https://img.shields.io/badge/Platform-iOS%2017.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%205.9%20%7C%206-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Language" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI-007AFF?style=for-the-badge&logo=swift&logoColor=white" alt="Framework" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
</p>

---

## 👨‍💻 Author & Creator

- **Developer**: **Avinash Chavda**
- **GitHub**: [@Avinash11-AK11](https://github.com/Avinash11-AK11)
- **Repository**: [https://github.com/Avinash11-AK11/CleanSpace](https://github.com/Avinash11-AK11/CleanSpace)
- **Email**: [avinashchavda11@gmail.com](mailto:avinashchavda11@gmail.com)

---

## 📖 Overview

**CleanSpace** is a comprehensive, production-grade iOS storage manager built natively in **SwiftUI**. It empowers users to safely audit and reclaim gigabytes of storage by identifying duplicate and similar photos, blurry or poor-quality shots, screenshots, large videos, duplicate contacts, and expired calendar clutter — all with **100% on-device local processing**.

---

## 🌟 Key Features

### 1. 📊 Storage Dashboard
- Real-time disk meter showing total, used, and free storage using Foundation volume APIs.
- Real-time cleanable space projection aggregating potential savings across all categories.
- One-tap storage scan with interactive progress tracking.

### 2. 📸 Similar & Duplicate Photos
- **Two-Pass Scanning Architecture**:
  1. *Candidate clustering*: Groups bursts taken in close time intervals or matching dimensions.
  2. *Perceptual Fingerprinting*: 768-dimensional RGB perceptual downsampling to detect duplicate and near-duplicate shots with strict false-positive prevention.
- **Smart "Best Photo" Selection**: Automatically identifies and marks the highest quality, favorite, or sharpest shot with a ⭐ badge, allowing 1-tap selection of redundant copies.
- Complete support for photo deletion and keeping both copies.

### 3. 🌫️ AI-Powered Blurry Photo Detection
- Dual-metric sharpness analysis:
  1. **Laplacian gradient variance** to detect camera shake and defocus blur.
  2. **Vision framework face landmark crop analysis** to ensure faces are in focus.
- Grid browser with individual inspect, multi-select, and safe batch deletion.

### 4. 🎬 Video Compression Studio & Large Videos
- Automatically locates the largest videos consuming device storage.
- Interactive AVPlayer preview sheet.
- **Dynamic Resolution-Aware Presets**: Presets intelligently adapt to source resolutions (4K, 1080p, 720p, SD).
- Bitrate modeling aligned with AVFoundation export presets (`AVAssetExportPreset...`).
- Synchronized savings estimation showing exact before/after file sizes and reclaim percentages.
- Automatic fallback protection guaranteeing compressed videos are always smaller than the source.

### 5. 🃏 Swipe Photo Cleaner
- Tinder-style interactive gesture card stack.
- Swipe right to **Keep**, swipe left to **Delete**.
- Undo button, haptic feedback, and a summary batch deletion screen.

### 6. 🛡️ Secret Photo & Video Vault
- Biometric **Face ID / Touch ID** authentication with fallback PIN passcode.
- Stores private media securely in sandboxed application documents isolated from Photos library.
- Zero cloud sync or external leakage.

### 7. 👥 Duplicate Contacts Cleaner & Merger
- High-performance local scan of address book using `CNContactStore`.
- Normalizes phone numbers (stripping country codes, formatting, and whitespace) and emails.
- Groups duplicates by matching phone, email, or exact full name.
- Highlights primary contact cards and enables one-tap merge or safe deletion.

### 8. 🗓️ Calendar Event Cleanup
- Queries `EventKit` to discover expired past events and clutter.
- Batch selection and deletion directly on-device.

### 9. 🗑️ Safe Review & Deletion Flow
- Centralized `CleanupManager` aggregates selections across all modules.
- **Review Screen**: Displays item breakdown and exact total reclaimable storage before taking destructive actions.
- System confirmation prompts through `PHPhotoLibrary.performChanges` and `CNContactStore.execute(CNSaveRequest)`.
- **Celebration Screen**: Confirms successful cleanup with celebratory animations and exact space freed.

---

## 🔒 Privacy & Security

- **100% On-Device**: Photos, videos, contacts, and calendars are processed purely on your device.
- **Zero Third-Party Tracking**: No analytics, no advertising SDKs, no external network calls.
- **Permission Lifecycle**: Full support for `.authorized`, `.limited`, and `.denied` photo and contact permission states with graceful fallback banners and triggers.

---

## 🛠️ Architecture & Tech Stack

- **Language**: Swift 5.9 / Swift 6 compatible
- **UI Framework**: SwiftUI (iOS 17.0+)
- **Design System**: Custom Apple Design System (`AppTheme`, card styles, bounce interactions, haptics)
- **Architecture**: MVVM-S (Model - View - ViewModel - Service)
- **Frameworks Used**: `Photos`, `PhotosUI`, `AVFoundation`, `AVKit`, `Vision`, `Contacts`, `EventKit`, `LocalAuthentication`
- **Build System**: XcodeGen & standard Xcode (`CleanSpace.xcodeproj`)

### Directory Structure

```
CleanSpace/
├── App/
│   └── CleanSpaceApp.swift
├── Models/
│   ├── StorageInfo.swift
│   ├── PhotoItem.swift
│   ├── PhotoGroup.swift
│   ├── VideoItem.swift
│   ├── ContactItem.swift
│   ├── ContactGroup.swift
│   └── CleanupSelection.swift
├── Services/
│   ├── StorageService.swift
│   ├── PermissionManager.swift
│   ├── PhotoScanner.swift
│   ├── PhotoSimilarityService.swift
│   ├── BlurDetectionService.swift
│   ├── VideoCompressionService.swift
│   ├── VideoScanner.swift
│   ├── ContactScanner.swift
│   ├── CalendarService.swift
│   ├── VaultManager.swift
│   └── CleanupService.swift
├── ViewModels/
│   ├── CleanupManager.swift
│   └── DashboardViewModel.swift
├── Views/
│   ├── Common/ (AppTheme, PHAssetThumbnailView, BounceButtonStyle)
│   ├── Dashboard/ (DashboardView, StorageGaugeView, CategoryCardView, AboutAppView)
│   ├── Permissions/ (PermissionBannerView, PermissionRequestSheet)
│   ├── SimilarPhotos/ (SimilarPhotosView)
│   ├── BlurryPhotos/ (BlurryPhotosView)
│   ├── SwipeCleaner/ (SwipeCleanerView)
│   ├── Screenshots/ (ScreenshotsView)
│   ├── LargeVideos/ (LargeVideosView, VideoCompressorView)
│   ├── Contacts/ (DuplicateContactsView)
│   ├── Calendar/ (CalendarCleanupView)
│   ├── Vault/ (VaultView)
│   ├── Review/ (ReviewView)
│   └── SpaceFreed/ (SpaceFreedView)
└── Resources/
    └── Info.plist
```

---

## 🚀 Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/Avinash11-AK11/CleanSpace.git
   cd CleanSpace
   ```
2. Open `CleanSpace.xcodeproj` in Xcode (or run `xcodegen generate` if generating fresh).
3. Select your connected iPhone (or iOS 17+ Simulator) as the destination.
4. Press `Cmd + R` to build and run!

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

Copyright © 2026 **Avinash Chavda**. All rights reserved.
