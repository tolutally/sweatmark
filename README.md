# SweatMark 🏋️

> **Maintainer handoff:** Read [CLAUDE_HANDOFF.md](CLAUDE_HANDOFF.md) before continuing work. It contains the current product scope, design rules, architecture, persistence guarantees, release state, verification status, and working-tree warnings. This README predates the current logging-first rewrite and should not be used as the implementation specification.

A high-fidelity mobile workout application built with Flutter featuring an ultra-modern dark mode design.

## Features

- 🎨 **Ultra-Modern Dark Mode** - Pure black backgrounds with neon mint accents
- 💪 **Active Workout Logger** - Track exercises, sets, reps, and weight in real-time
- 🗺️ **Muscle Recovery Visualization** - Interactive SVG body map showing muscle status
- 📚 **Exercise Library** - 20+ exercises with search and filter capabilities
- ⏱️ **Smart Recovery Tracking** - Time-based muscle recovery status (< 24hrs = Fatigued, 24-48hrs = Recovering, > 48hrs = Recovered)

## Tech Stack

- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **SVG Rendering**: flutter_svg
- **Typography**: Google Fonts (Inter)
- **Icons**: Phosphor Flutter

## Project Structure

```
lib/
├── main.dart                 # Entry point, theme setup
├── models/                   # Data structures
│   ├── exercise_model.dart
│   └── workout_model.dart
├── services/                 # Future Firebase/API integration
│   ├── firebase_service.dart
│   └── ai_coach_service.dart
├── state/                    # State management
│   ├── workout_notifier.dart
│   └── recovery_notifier.dart
├── screens/                  # Full-screen widgets
│   ├── home_screen.dart
│   ├── recovery_screen.dart
│   ├── library_screen.dart
│   ├── active_workout_screen.dart
│   ├── workout_screen.dart
│   └── profile_screen.dart
├── widgets/                  # Reusable components
│   ├── app_shell.dart
│   ├── body_map_svg.dart
│   ├── exercise_card.dart
│   └── library_item.dart
└── data/                     # Static data
    ├── muscle_assets.dart
    └── exercise_data.dart
```

## Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Android Studio (for Android emulator) or Xcode (for iOS simulator)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/sweatmark.git
   cd sweatmark
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

For detailed setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md) and [EMULATOR_SETUP.md](EMULATOR_SETUP.md).

## Design System

### Colors
- **Background**: `#000000` (Pure Black)
- **Surface/Cards**: `#1C1C1E` (Dark Grey)
- **Primary Accent**: `#2BD4BD` (Neon Mint)
- **Secondary Accent**: `#3B82F6` (Blue)
- **Fatigue**: `#EF4444` (Red)
- **Recovery**: `#EAB308` (Yellow)

### Typography
- **Font Family**: Inter (Google Fonts)
- **Headings**: Bold/Heavy
- **Body**: Regular/Medium

## Usage

1. **Start a Workout**: Tap the "Workout" tab and click "Start Workout"
2. **Add Exercises**: Browse the exercise library and add to your workout
3. **Log Sets**: Enter weight and reps for each set, check off when complete
4. **Finish Workout**: Tap "Finish" to save and update muscle recovery status
5. **View Recovery**: Check the "Recovery" tab to see which muscles are fatigued/recovered

## Screenshots

_Coming soon..._

## Roadmap

- [ ] Firebase integration for workout history
- [ ] AI Coach powered by Gemini API
- [ ] Workout templates and programs
- [ ] Progress charts and analytics
- [ ] Social features and sharing

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- SVG body map assets
- Exercise data compilation
- Phosphor Icons for beautiful iconography
