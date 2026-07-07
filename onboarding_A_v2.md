# Onboarding A — Financial Assistant (Production Spec v2)

## 1. Purpose
Guided onboarding flow that collects user financial profile and builds initial configuration without exposing internal allocation complexity.

---

## 2. Container

StartOnboardingFlowView

- Single SwiftUI view
- Uses local @State
- No separate ViewModel
- Presented via fullScreenCover

---

## 3. State

```swift
enum Step {
    case finances
    case family
    case strategy
    case cards
    case summary
}

@State private var step: Step
```

---

## 4. Data State

```swift
@State var income: Double
@State var capital: Double

@State var housingType: HousingType
@State var housingCost: Double

@State var hasCar: Bool

@State var adultDependents: Int
@State var elderlyDependents: Int
@State var children: Int
@State var pets: Int

@State var hasCredit: Bool
@State var creditAmount: Double

@State var selectedRecommendedCards: Set<SystemCardKey>

@State var strategy: StrategyType
```

---

## 5. Navigation

- Forward: Continue button
- Back: Navigation back
- Disable continue if required fields invalid

---

## 6. Screens

### 6.1 Finances & Housing

Layout:

VStack
- Title
- IncomeInput
- CapitalInput
- HousingChoice
- HousingCostInput
- CarToggle
- ContinueButton

Rules:
- income > 0 required
- housing cost required if rent

---

### 6.2 Family & Obligations

Layout:

VStack
- Stepper adultDependents
- Stepper elderlyDependents
- Stepper children
- Stepper pets
- CreditToggle
- CreditInput (if enabled)
- ContinueButton

Rules:
- credit amount required if credit enabled

---

### 6.3 Strategy

Layout:

VStack
- Title
- StrategyCard x3
- ContinueButton

StrategyCard:
- title
- ratio (e.g. 60/15/25)
- selected state

---

### 6.4 Cards

Layout:

ScrollView
- Section Current
- Section Recommended
- ContinueButton

Behavior:
- current cards always active
- recommended cards toggle on tap

Component:

RecommendedCardRow:
- title
- icon
- active state

---

### 6.5 Summary

Layout:

VStack
- Title
- DonutChart
- Insights
- CardsPreview
- StartButton

DonutChart:
- Essentials
- Wants
- Savings

Insights:
- short textual summary

CardsPreview:
- grouped by category

---

## 7. Components

### PrimaryButton
- title
- isEnabled
- action

### InputCard
- title
- value
- numeric input

### StepperCard
- title
- value
- +/- buttons

### ToggleCard
- title
- boolean binding

### ChoiceCard
- title
- icon
- selected state

---

## 8. Validation

- income must be > 0
- no negative values
- credit requires amount
- housing requires cost if rent

---

## 9. Completion

```swift
let config = StartOnboardingBuilder.build(...)
budgetViewModel.applyStartOnboardingConfiguration(config)
```

- set onboarding flag true
- do not write income to history

---

## 10. Definition of Done

- all steps implemented
- navigation works
- state persists across steps
- configuration builds successfully
- no crashes on edge cases
