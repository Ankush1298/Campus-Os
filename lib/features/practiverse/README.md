# PractiVerse: Multi-Subject Practical Simulation Platform

PractiVerse is the interactive practical learning and simulation platform for CampusOS, engineered to transform theoretical syllabuses into hands-on experimental laboratories across academic disciplines.

---

## 1. Architectural Overview & Pedagogical Pillars

PractiVerse bridges textbook learning with real-world simulation, structured around 5 interconnected pillars:

```
┌────────────────────────────────────────────────────────┐
│               AI Syllabus Intake Engine                │
│  (Course Notes / Chapter Text / 1-Tap Curated Presets) │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│           Multi-Subject Practical Catalogue            │
│   • Physics: Ohm's Law & DC Circuits                   │
│   • Math/Stats: Central Tendency & Outliers            │
│   • Chemistry: Solution Dilution & Molarity            │
│   • CS/Logic: Algorithm Challenges                     │
│   • Biology: Cell Osmosis & External Virtual Labs      │
│   • Economics: Market Equilibrium Lab Links            │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│             Interactive Simulation Engine              │
│   • Real-Time Parameter Sliders (Voltage, Resistance)  │
│   • Live Visual Schematic & Canvas Painters            │
│   • Dynamic Dataset Outlier Injector                   │
│   • Scientific Beaker Fluid Concentration Painter      │
│   • Tolerance-Based Numeric Prediction Checker         │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│           3 Lives + Hint + Recovery Loop               │
│   • 3 Lives per experimental session                   │
│   • Zero-life lock with Concept Recovery (+1 Life)     │
│   • Incremental multi-tier hints                       │
└───────────────────────────┬────────────────────────────┘
                            ▼
┌────────────────────────────────────────────────────────┐
│     Verification Quizzes & Session Progress Tracking   │
│   • Timed multi-subject diagnostic quizzes             │
│   • Mastery breakdown, resolved misconceptions         │
└────────────────────────────────────────────────────────┘
```

---

## 2. Supported Multi-Subject Practical Simulations

### A. Physics & Electronics: Ohm's Law & DC Circuits
- **Concept:** Voltage-Current-Resistance Relationship ($I = V / R$).
- **Interactive Controls:** Dynamic Battery Voltage slider (1V – 24V) and Resistor slider (1Ω – 20Ω, bounded to $R \ge 1\ \Omega$ to prevent division-by-zero).
- **Custom Canvas:** Live circuit schematic painter featuring DC battery terminals, zig-zag resistor with resistance readout, and digital ammeter.
- **Evaluation:** Scientific tolerance checking ($\pm 5\%$) with automated misconception diagnostics (e.g. detecting if a student multiplied $V \times R$ instead of dividing).

### B. Mathematics & Statistics: Descriptive Statistics & Outliers
- **Concept:** Mean vs. Median Sensitivity & Outlier Distortion.
- **Interactive Controls:** Dynamic numerical dataset, interactive data element chips, real-time mean and median calculations.
- **Outlier Injection:** Instantaneous `+ Outlier (150)` button demonstrating how extreme values pull the arithmetic mean while positional median remains resilient.
- **Challenge:** Dynamic prediction challenge asking students to predict the updated central measure.

### C. Chemistry: Solution Dilution & Concentration
- **Concept:** Solute Conservation ($C_1V_1 = C_2V_2$).
- **Interactive Controls:** Stock molarity slider ($C_1$), initial volume slider ($V_1$), and added solvent slider ($\Delta V$).
- **Custom Canvas:** Graduated glass cylinder painter with liquid fill level and concentration-dependent optical opacity.
- **Evaluation:** Automated molarity calculation checking with tolerance bounds ($\pm 5\%$).

### D. Computer Science & Logic
- Preserved interactive coding challenge simulations: **Sum Two Numbers**, **Even or Odd**, and **Reverse a String**.
- Formatted test-case outcomes, input/output validation, and execution feedback.

### E. External Virtual Laboratory Directory
- Curated integration with national and university virtual labs:
  - **Amrita Virtual Labs / Ministry of Education, GoI** (Ohm's Law, Acid-Base Titration, Cell Osmosis).
  - **PhET Interactive Simulations, University of Colorado Boulder** (Plinko Probability & Statistics).
  - Complete with direct launch links, copyable URLs, and pedagogical descriptions.

---

## 3. Pedagogical Guardrails: Lives, Hints & Recovery

1. **3 Lives System:** Students start with 3 lives. Failed simulation calculations consume exactly 1 life. Repeated attempts without changing parameters do not double-deduct.
2. **Progressive Hints:** Multi-tier hints can be revealed incrementally without spending lives.
3. **Concept Recovery Modal:** When lives reach zero, a conceptual multiple-choice question unlocks targeting the specific misconception. Answering correctly restores **+1 life**, unlocking the workspace so the student can resume without restarting.

---

## 4. Integration Contract

The module preserves 100% backwards compatibility with CampusOS. The entry point contract remains:

```dart
PractiverseModule.getEntryPoint(context)
```

Exported from `lib/features/practiverse/practiverse_module.dart`, seamlessly invoked by `DashboardScreen` without modifying any other feature modules.

---

## 5. Verification & Testing

Run the full verification suite:

```bash
# Code formatting
dart format lib/ test/

# Static analysis (0 warnings / 0 errors)
flutter analyze

# PractiVerse Module comprehensive tests (16 tests)
flutter test test/practiverse_module_test.dart

# PractiVerse Multi-Subject Simulation tests (13 tests)
flutter test test/practiverse_simulations_test.dart

# Full project test suite (30 tests)
flutter test
```

### Running on Device / Emulator

```bash
# macOS Desktop
flutter run -d macos

# Google Chrome (Web)
flutter run -d chrome

# Android Emulator (e.g. Pixel 7)
flutter emulators --launch Pixel_7
flutter run -d Pixel_7
```
