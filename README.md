# Acadova Mobile App 📱

**Acadova** is a modern, cross-platform mobile application built with **Flutter**. Designed as an interactive academic workspace, it empowers students and faculty members with seamless quiz taking, real-time results, academic profile setup, and streamlined course allocations.

---

## 🌟 Key Features

- 🔑 **Instant Authentication**:
  - Email & Password Login / Signup.
  - **Google One-Tap / OAuth Sign-In** with instant silent authentication fallback (`signInSilently()`).

- 🎓 **Dynamic Academic Profiles**:
  - Dynamic enrollment setup with dynamic selection of **Semesters**, **Branches**, **Subjects**, and **Sections** fetched directly from backend DB APIs.
  - Guided setup for incomplete profiles.

- 👨‍🏫 **Faculty & Student Workspaces**:
  - **Student View**: Timed quiz participation, instant scorecards, attempt history, and progress analytics.
  - **Faculty View**: Quiz management, assigned allocations, subject & section overviews.

- ⚡ **Performance & UX**:
  - High-performance glassmorphic UI with vibrant modern color palette and smooth micro-animations.
  - Custom non-blocking Toast notifications and instant network error diagnostics.

---

## 🏗️ Architecture & Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | Flutter 3.x / Dart 3.x |
| **State Management** | Stateful Widgets / Reactive Services |
| **Authentication** | `google_sign_in` plugin & Sanctum API Tokens |
| **HTTP Client** | `http` package with custom interceptors & error handlers |
| **Design System** | Custom Theme, Material 3, Modern Glassmorphism |

---

## ⚙️ Getting Started

### Prerequisites
- Flutter SDK `>= 3.13.2`
- Dart SDK `>= 3.1`
- Android Studio / VS Code with Flutter extension
- Connected Android/iOS device or emulator

### Installation & Run Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/neodyit/Acadova-app.git
   cd Acadova-app
   ```

2. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Code Quality**:
   ```bash
   flutter analyze
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```

---

## 📁 Directory Structure

```
lib/
├── config/           # App themes, constants, and color palette
├── models/           # Data models (User, Quiz, Question, Academic Data)
├── screens/          # App views (Login, Home, Profile, Quiz, Faculty Dashboard)
├── services/         # API Service, HTTP requests, local storage handlers
├── widgets/          # Reusable UI components (Custom Toast, Glass Cards)
└── main.dart         # Entry point & global navigator handlers
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

This project is licensed under the **MIT License**.
