# NovaEnglish - Project Overview

NovaEnglish is a dark-themed Flutter vocabulary trainer designed for Android and Web platforms. It allows users to study built-in dictionaries (such as CET4, CET6, Kaoyan, IELTS, TOEFL) and manage their own custom dictionaries, units, and words. The app relies on a local SQLite database for fast and reliable data persistence.

## Architecture & Tech Stack

*   **Framework:** Flutter / Dart
*   **State Management:** `provider` package. The app heavily relies on a central `NovaController` (a `ChangeNotifier`) to drive UI state.
*   **Local Storage:** `sqflite` for native platforms and `sqflite_common_ffi_web` for web support. All database interactions are encapsulated within `NovaRepository`.
*   **Data Models:** Core business entities like `BuiltinWord`, `LearningProgress`, `UserProfile`, and `CustomDictionarySummary` are defined in `lib/src/models/entities.dart`.
*   **Key Services:**
    *   `NovaController`: Manages application state, business logic, and coordinates between the UI and the repository.
    *   `NovaRepository`: The single source of truth for database operations (CRUD, stats calculation, import/export).
    *   `FileTransferService`: Provides platform-specific implementations (Web vs. IO) for handling JSON backups and imports.

## Building and Running

You can use standard Flutter CLI commands to build, run, and test the project.

*   **Run on Web (Chrome):**
    ```bash
    flutter run -d chrome
    ```
*   **Run on Android:**
    ```bash
    flutter run -d android
    ```
*   **Run Tests:**
    ```bash
    flutter test
    ```
*   **Static Analysis (Linting):**
    ```bash
    flutter analyze
    ```

## Development Conventions

*   **Dependency Injection & State Consumption:** `NovaController` is instantiated in `main.dart` and provided to the widget tree via `ChangeNotifierProvider.value`. UI components react to state changes using `Consumer<NovaController>` or `context.watch<NovaController>()`.
*   **Separation of Concerns:** 
    *   `lib/src/screens/`: Contains declarative UI code. Logic should be delegated to the controller.
    *   `lib/src/services/`: Contains core business logic, repository definitions, and platform integrations.
    *   `lib/src/models/`: Contains pure Dart data classes and entities.
*   **Theming:** The UI supports both light and dark modes, driven by `NovaController.prefersLightTheme`. Theme definitions are centralized in `lib/src/theme/nova_theme.dart`.
*   **Platform Adaptability:** Use conditional imports (like in the file transfer service) to handle differences between Web and Native (IO) platform capabilities gracefully.