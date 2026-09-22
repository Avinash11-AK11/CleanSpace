# CleanSpace — iOS Storage Cleaner App

An elegant, privacy-first iOS app built with native SwiftUI to help users safely free up storage on their iPhones by finding duplicate and similar photos, screenshots, large videos, and duplicate contacts.

Built for the **App Builder Intern Selection Task (App Factory)** following the provided assignment brief and requirements.

---

## 🌟 Key Features

### 1. Storage Dashboard
- Real-time disk capacity meter showing total, used, and free device storage via Foundation volume APIs.
- Cleanable space projection highlighting how much space can be safely recovered across all categories.
- One-tap storage scan with a live progress indicator.

### 2. Similar & Duplicate Photos
- **Two-pass scanning architecture**:
  1. *Candidate clustering*: Groups photos taken in close proximity (time-window bursts) or matching aspect ratios.
  2. *Perceptual fingerprinting*: Generates downsampled grayscale feature vectors and compares perceptual difference ratios.
- **Smart "Best Photo" scoring**: Considers resolution (pixels), favorite status, and recency to mark the recommended photo to keep with a ⭐ badge, allowing one-tap selection of redundant extras.

### 3. Screenshot Cleaner
- Swiftly queries `.photoScreenshot` media subtypes.
- Grid layout with individual selection, batch selection ("Select All"), and exact file size indicators.

### 4. Large Videos
- Discovers video assets and sorts them from largest to smallest.
- Displays resolution badges (`4K`, `1080p HD`, `720p HD`), file size, and duration.
- Built-in video player preview sheet using `AVKit` / `AVPlayer`.

### 5. Duplicate Contacts
- Local scan of address book using `CNContactStore` on background dispatch queues.
- Normalizes phone numbers (stripping country codes and formatting) and emails.
- Identifies duplicates by phone, email, or exact full name.
- Highlights primary contact cards and allows selecting redundant duplicates.

### 6. Review Before Delete & Safe Deletion (Zero accidental data loss)
- Centralized `CleanupManager` aggregates selected items from all categories.
- **Review Screen**: Displays item counts, category breakdown, and total reclaimable storage.
- **Destructive Confirmation Alert**: Double-checks user intent before initiating any deletion.
- Securely interfaces with `PHPhotoLibrary.performChanges` and `CNContactStore.execute(CNSaveRequest)` for system-level safety.
- **Space Freed Celebration Screen**: Confirms successful cleanup and displays total MBs/GBs freed.

### 7. Robust Permission Handling
- Clear, privacy-first onboarding explaining why Photos and Contacts access is required.
- Full support for both `.authorized` and **`.limited` photo library access** with an in-app trigger to present the system picker (`presentLimitedLibraryPicker`).
- Graceful banners for `.denied` access directing users directly to iOS Settings.

---

## 🔒 Privacy & On-Device Processing

- **100% On-Device**: Zero external API calls, zero analytics, zero cloud dependencies. Photos and contacts never leave the phone.
- Uses Apple native frameworks only: `SwiftUI`, `Photos`, `PhotosUI`, `Contacts`, `AVFoundation`, `AVKit`, and `Vision`.

---

## 🛠️ Tech Stack & Architecture

- **Language**: Swift 5.9 / Swift 6 compatible
- **UI Framework**: SwiftUI (iOS 17.0+)
- **Architecture**: MVVM-S (Model - View - ViewModel - Service)
- **Concurrency**: Swift Concurrency (`async/await`, `@MainActor`, `Sendable`)
- **Project Generation**: XcodeGen (`project.yml`)

### Project Structure
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
│   ├── ScreenshotScanner.swift
│   ├── VideoScanner.swift
│   ├── ContactScanner.swift
│   └── CleanupService.swift
├── ViewModels/
│   ├── CleanupManager.swift
│   └── DashboardViewModel.swift
├── Views/
│   ├── Common/ (AppTheme, PHAssetThumbnailView)
│   ├── Dashboard/ (DashboardView, StorageGaugeView, CategoryCardView)
│   ├── Permissions/ (PermissionBannerView, PermissionRequestSheet)
│   ├── SimilarPhotos/ (SimilarPhotosView)
│   ├── Screenshots/ (ScreenshotsView)
│   ├── LargeVideos/ (LargeVideosView)
│   ├── Contacts/ (DuplicateContactsView)
│   ├── Review/ (ReviewView)
│   └── SpaceFreed/ (SpaceFreedView)
└── Resources/
    ├── Info.plist
    └── Assets.xcassets
```

---

## 🚀 How to Run

1. Open `CleanSpace.xcodeproj` in Xcode (or run `xcodegen generate` if generating fresh).
2. Select your connected iPhone (or iOS 17+ Simulator) as the run destination.
3. In **Signing & Capabilities**, select your Apple Developer Team.
4. Press `Cmd + R` to run!

---

## 📝 Submission Note (Under 150 words)

> I built CleanSpace, a native SwiftUI iOS storage cleaner focused on safe, on-device cleanup. I used Swift, SwiftUI, Photos, PhotosUI, Contacts, AVFoundation, and Vision, structured under an MVVM-Service architecture.
>
> The working core loop includes device storage scanning, similar/duplicate photo clustering, screenshot discovery, large video previews, duplicate contact grouping, cross-category selection, review before deletion, system confirmation, and a celebratory space-freed summary.
>
> The hardest technical problem was optimizing photo similarity scanning across large libraries without triggering memory spikes: I resolved this with a two-pass strategy combining timestamp clustering and lightweight perceptual grayscale downsampling rather than loading full-resolution images.
>
> All processing is strictly local with complete support for full, limited, and denied permission states.
