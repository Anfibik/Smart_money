# Smart Money: Current Project Context

## 1. What this project is

`Smart_money` is an iOS application built with `SwiftUI` for personal budget management around 3 main categories:
- `Essentials`
- `Wants`
- `Savings`

Each category contains card-like subcategories. Every card has:
- a name
- an icon
- a base percentage inside its parent category
- a minimum amount `minLimit`
- a maximum amount `maxLimit`
- a priority
- an already spent amount

The app does not only store a list of cards. It calculates income distribution across categories and cards through a single allocation engine. It also has a separate pool of unassigned money called `Free Capital`.

## 2. Current feature set

At the moment the project can:
- run a full first-time onboarding flow
- build an initial budget configuration from the user's financial profile
- add monthly income
- distribute income across categories and cards
- register expenses on cards
- automatically use free money inside a category and `Free Capital` during expense coverage
- cover remaining shortages inside a category in either automatic or manual reallocation mode
- add custom user cards
- edit card percentage, minimum, maximum, and icon
- transfer money from a card to `Free Capital`
- transfer money from `Free Capital` to a card
- keep internal card-to-card reallocation history inside one category
- keep an operation history
- show statistics by month, by year, and for all time since the last full reset
- fully reset the state and start from scratch

## 3. Technologies

Main stack:
- `Swift`
- `SwiftUI`
- `Combine`
- `Foundation`
- `Charts` for the history and statistics screen
- `XCTest` for unit tests

There are no external dependencies through `Swift Package Manager`.

Data storage:
- the current budget state is stored in `UserDefaults`
- operation history is stored as a separate `JSON` file in `Application Support`

## 4. Entry point

File:
- `App/Smart_moneyApp.swift`

The app entry is simple:
- the application starts with `ContentView()`

File:
- `App/Views/Main/ContentView.swift`

`ContentView` is the main container of the app. It is responsible for:
- creating `BudgetViewModel`
- showing the main category screen
- presenting the onboarding flow through `fullScreenCover`
- opening the side menu
- navigating to `History and Statistics`
- performing a full reset and restarting onboarding

Onboarding completion flag:
- `@AppStorage("has_completed_start_onboarding_v2")`

If the flag is `false`, the app shows `StartOnboardingFlowView` on first launch.

## 5. Architecture

The architecture is close to `MVVM`, but pragmatic:
- `Models` for domain structures
- `ViewModels` for state and orchestration
- `Services` for business rules, persistence, history, and statistics
- `Views` for UI

The main architectural rule in the project is:
- all money logic is centralized in `BudgetViewModel`
- the allocation algorithm itself is extracted into `BudgetAllocationEngine`

This matters: the UI should not mutate finances directly. All financial actions should go through `BudgetViewModel`.

## 6. Project structure

### 6.1 Models

`App/Models/ExpenseCategory.swift`
- `ExpenseCategoryType`: the 3 main categories (`essentials`, `wants`, `savings`)
- `ExpenseCategory`: category with a percentage from total income and a set of cards

`App/Models/Subcategory.swift`
- `Subcategory`: a card inside a category
- contains business fields such as `percentage`, `minLimit`, `maxLimit`, `priority`, and `spentAmount`
- also contains `SubcategoryIconCatalog`

`App/Models/BudgetSettings.swift`
- the current configuration of the system
- stores categories and currency
- contains fallback defaults

`App/Models/BudgetDistribution.swift`
- runtime representation of the calculated allocation
- this is the calculated money state for categories and cards
- also contains the current `Free Capital` amount

`App/Models/StartOnboardingModels.swift`
- all models related to the new startup onboarding flow
- housing type
- strategy
- draft/input/configuration/preview
- custom cards for startup configuration

`App/Models/BudgetHistoryEvent.swift`
- domain model for operation history
- event types:
  - `income`
  - `expense`
  - `transferToFreeCapital`
  - `transferFromFreeCapital`
  - `categoryReallocation`
- also contains history period modes and history filters

`App/Models/BudgetStatisticsSummary.swift`
- aggregated data for the statistics screen
- summary cards
- timeline
- category expense breakdown
- top cards

`App/Models/SystemSubcategorySetup.swift`
- helper model for system card setup
- currently infrastructure-only; the main startup flow now uses the new onboarding process instead

### 6.2 Services

`App/Services/BudgetAllocationEngine.swift`
- the main money allocation engine
- this is critical business logic

What the engine does:
- distributes newly added income across categories
- inside each category, covers needs by allocation stages
- if nothing else needs to be covered in a category, leftover money goes to `Free Capital`
- resolves minimum deficits from `Free Capital`
- can rebalance existing cards when a new card with a minimum is created
- can move excess above `maxLimit` back to `Free Capital`

Important:
- `BudgetAllocationEngine` should remain the single source of allocation logic
- any new allocation rules should be integrated here or through `BudgetViewModel`, not duplicated elsewhere

`App/Services/StartOnboardingBuilder.swift`
- builds the startup configuration after onboarding
- creates system cards
- calculates minimums
- builds the launch preview
- runs the startup configuration through the current `BudgetAllocationEngine`

`App/Services/PersistenceService.swift`
- saves the current budget snapshot in `UserDefaults`
- storage key: `budget_state_v2`

`App/Services/BudgetHistoryStorage.swift`
- stores operation history as a separate JSON file
- file name: `budget_history_v1.json`
- directory: `Application Support/<bundle id>/`

`App/Services/BudgetStatisticsService.swift`
- filters history by period
- builds summary values
- builds timeline data
- calculates expense breakdown by category
- calculates top-5 expense cards

`App/Services/BudgetService.swift`
- currently an empty placeholder service
- it is not used as a business logic layer

### 6.3 ViewModels

`App/ViewModels/BudgetViewModel.swift`
- the central state holder of the application
- the main object through which all financial actions pass

What it stores:
- total income
- last added income
- current `BudgetSettings`
- calculated `BudgetDistribution`
- `historyEvents`
- allocated amounts by card
- baseline targets by category
- `Free Capital`

What it can do:
- `addIncome`
- `addExpense`
- `transferFromSubcategoryToBank`
- `transferFromBankToSubcategory`
- `addCustomSubcategory`
- `updateSubcategory`
- `deleteSubcategory`
- `applyStartOnboardingConfiguration`
- `resetMoneyData`
- `resetToInitialSystemState`

Important:
- history events are created here
- full reset of both history and budget happens here
- `BudgetDistribution` is built here

`App/ViewModels/HistoryAndStatisticsViewModel.swift`
- manages the unified history/statistics screen
- modes:
  - month
  - year
  - all time
- builds day sections for the operation list
- observes `budgetViewModel.$historyEvents`

`App/ViewModels/CategoriesViewModel.swift`
- lightweight adapter over `distribution.categoryAllocations`
- not the main logic center of the project

`App/ViewModels/SettingsViewModel.swift`
- older/supporting settings editing view model
- not the main product flow anymore

### 6.4 Views

#### Main

`App/Views/Main/ContentView.swift`
- root screen

`App/Views/Main/StartOnboardingFlowView.swift`
- the new 5-step onboarding flow

`App/Views/Main/HistoryAndStatisticsView.swift`
- the unified history and statistics screen

`App/Views/Main/DashboardView.swift`
- simplified summary screen
- currently not the main product screen

`App/Views/Main/Components/SideMenuDrawerView.swift`
- side menu
- currently contains navigation to `History and Statistics` and the reset action

#### Categories

`App/Views/Categories/CategoryAccordionView.swift`
- main category screen
- expands and collapses categories
- opens expense/add/edit sheets
- shows `BankSummaryView`

`App/Views/Categories/Components/*`
- visual components for categories and cards

`App/Views/Categories/Sheets/*`
- modal forms for:
  - adding a card
  - editing a card
  - entering an expense

## 7. Core business logic

### 7.1 Main categories

The system is built around 3 main categories:
- `Essentials`
- `Wants`
- `Savings`

Each category has a percentage of total income.

Example:
- `Essentials 60%`
- `Wants 15%`
- `Savings 25%`

These percentages are percentages of total income.

### 7.2 Cards inside a category

Each card has its own percentage inside its parent category.

This is important:
- a card percentage is not calculated from total income
- a card percentage is calculated from its category budget

Example:
- income = `100,000`
- `Essentials = 60%`, so category budget = `60,000`
- `Food = 10%` inside `Essentials`
- base card amount = `6,000`

But this is only a soft target. The minimum has higher priority.

### 7.3 Minimums and priorities

The key rule in the project is:
- first satisfy `minLimit`
- then apply percentage logic

There are 2 related but different behaviors in the current code:
1. during allocation/recalculation, unresolved minimums can remain as visible deficits
2. during an expense or new-card operation, the app tries free money inside the category, then `Free Capital`, then internal category reallocation; if the full amount still cannot be covered, the operation is rejected

Current priority levels:
- `High`
- `Medium`
- `Low`

Current rule set:
- `High`: exactly one system card per main category
- `Essentials`: `Housing`
- `Wants`: `Shopping`
- `Savings`: `Emergency Fund`
- all other system cards are `Medium`
- all user-created cards are always `Low`

How allocation works:
- first the engine satisfies `High`
- then it distributes the remaining money across `Medium`
- then anything left can reach `Low`
- if money is not enough for a whole priority group, that group is filled proportionally to each card's unmet minimum, not one-by-one

### 7.4 Free Capital

`Free Capital` is the pool of money outside cards.

It is used in several ways:
- leftover money can flow into it
- deficits on cards can be covered from it automatically
- onboarding minimum deficits can be covered from it automatically

There is also a special rule:
- the emergency reserve card is topped up from `Free Capital` first whenever possible

### 7.5 Expenses

When the user records an expense:
- the system finds the target card
- it first uses the target card's own remaining amount
- then it automatically reuses free money from other cards in the same category
- then it automatically uses `Free Capital`
- if there is still a shortage but the category can cover it, the user chooses automatic or manual internal reallocation
- if even that is not enough, the expense is blocked

History behavior:
- one `expense` history record is always created for the final expense
- if the app had to move money between category cards, additional `categoryReallocation` history events are also created

### 7.6 Transfers

There are three types of internal transfers:
- from a card to `Free Capital`
- from `Free Capital` to a card
- from one card to another card inside the same category (`categoryReallocation`)

They:
- appear in history
- do not participate in financial statistics

## 8. Startup onboarding logic

### 8.1 Screen flow

The onboarding is implemented in `App/Views/Main/StartOnboardingFlowView.swift`.

The current flow has 5 steps:
1. finances and housing
2. family and obligations
3. system cards and custom cards
4. strategy selection
5. final summary

### 8.2 Onboarding input data

The startup flow currently collects:
- average monthly income for the last year
- current capital, which can be positive or negative
- housing type
- housing cost
- number of cars
- number of adult dependents
- number of children under 16
- whether there is a credit payment and its monthly amount
- custom cards
- strategy

### 8.3 Strategies

Current strategies:
- `Stability = 60 / 15 / 25`
- `Balance = 55 / 20 / 25`
- `Capital Growth = 50 / 15 / 35`

The order is always:
- `Essentials / Wants / Savings`

### 8.4 System cards created by onboarding

Always created:
- `Essentials`: `Housing`, `Food`, `Health`, `Hygiene`
- `Wants`: `Shopping`, `Hobby`, `Entertainment`
- `Savings`: `Emergency Fund`

Conditionally created:
- `Essentials`: `Children`, if children > 0
- `Essentials`: `Transport`, if cars > 0
- `Savings`: `Debt`, if capital is negative
- `Savings`: `Credit`, if credit is enabled

### 8.5 Minimums currently calculated by onboarding

Key formulas in `StartOnboardingBuilder`:

`Housing`
- the user enters the base housing amount
- minimum = entered amount * `1.10`
- base percentage inside `Essentials` = `30%` for rented housing, `10%` for owned housing

`Food`
- percentage inside `Essentials`: `20 + 5 * adult dependents + 4 * children`
- money minimum:
  - `8000 * (1 + 0.8 * adult dependents)`
  - plus `5000 * children`

`Health`
- percentage inside `Essentials`: `5 + 0.5 * adult dependents + 1.5 * children`
- minimum = the maximum of:
  - the percentage-based amount
  - `500 * total number of people`

`Hygiene`
- base percentage inside `Essentials` = `5%`
- minimum = `500 UAH`

`Children`
- a separate card for child-related costs excluding food and health
- created only if children > 0
- base percentage inside `Essentials` = `10%`
- minimum = `10%` of the `Essentials` category budget

`Transport`
- created if cars > 0
- base percentage inside `Essentials` = `10%`
- minimum = `10%` of the `Essentials` category budget

`Shopping`
- base percentage inside `Wants` = `30%`
- minimum = `max(500, wantsBudget * 0.30)`

`Hobby`
- base percentage inside `Wants` = `20%`
- minimum = `max(500, wantsBudget * 0.20)`

`Entertainment`
- base percentage inside `Wants` = `20%`
- minimum = `wantsBudget * 0.20`

`Emergency Fund`
- reserve target = `6 months` of mandatory living costs
- `minLimit` is set to the full 6-month target
- `maxLimit` is set to `12 months` of mandatory living costs
- current positive capital is then applied immediately from `Free Capital`

`Debt`
- appears when capital is negative
- base percentage inside `Savings` = `50%`
- minimum = `max(50% of savings budget, abs(negative capital) / 24)`

`Credit`
- appears when credit is enabled
- base percentage inside `Savings` = `10%`
- minimum = `max(monthly payment, 10% of savings budget)`

### 8.6 Custom cards in onboarding

At step 3:
- system cards are displayed only
- custom cards are added separately

Current behavior:
- creation happens in a dedicated popup `sheet`
- the creation form is no longer inline on the main step screen
- after saving, the card appears in its category list next to system cards
- a custom card can be edited through the same popup
- a custom card can be deleted

Custom card fields:
- name
- icon
- minimum amount
- percentage inside category (optional)

If percentage is not provided:
- the builder derives it from the minimum relative to the category budget

### 8.7 Applying onboarding

When the user completes onboarding:
- the builder creates `StartOnboardingConfiguration`
- `ContentView` calls `budgetViewModel.applyStartOnboardingConfiguration(...)`
- settings are fully replaced with the new configuration
- income is applied immediately
- positive starting capital goes into `Free Capital`
- then `BudgetAllocationEngine` tries to automatically cover minimum deficits from `Free Capital`

Starting capital and starting income from onboarding:
- are not logged as regular income history events

## 9. History and statistics

### 9.1 Screen

File:
- `App/Views/Main/HistoryAndStatisticsView.swift`

This is a single screen, not two separate sections.

It contains:
- period selection
- summary cards
- income/expense chart
- expense analytics
- operation history list

### 9.2 Periods

Current modes:
- `Month`
- `Year`
- `All Time`

Meaning:
- `Month` = a selected calendar month
- `Year` = a selected calendar year
- `All Time` = all data since the last full reset

### 9.3 What goes into history

The app records:
- income
- expenses
- transfers to `Free Capital`
- transfers from `Free Capital`
- internal card-to-card reallocations inside a category

### 9.4 What goes into statistics

Only these affect statistics:
- income
- expenses

These do not affect statistics:
- internal transfers
- onboarding starting capital
- onboarding starting income

### 9.5 What the statistics screen calculates

Summary:
- income
- expenses
- net result
- number of operations

Additional metrics:
- largest expense
- average expense
- expenses by category
- top-5 expense cards
- transfer count inside the selected period
- a timeline by day or month

### 9.6 History storage

History does not live in `UserDefaults`.

It is stored as a separate file through `BudgetHistoryStorage`.

This is an important architectural boundary:
- `PersistenceService` stores a snapshot of current state
- `BudgetHistoryStorage` stores the event log

## 10. Full reset behavior

A full reset is triggered from `ContentView` through the side menu.

Chain:
- `ContentView.resetInitialSetup()`
- `BudgetViewModel.resetToInitialSystemState()`
- `BudgetViewModel.resetMoneyData()`

What is cleared:
- current income
- last income
- free capital
- all allocated amounts by card
- all spent amounts on cards
- operation history
- persisted budget state
- onboarding completion flag

After that:
- onboarding starts again
- statistics restart from zero

## 11. Main user flows

### 11.1 Everyday usage flow

1. The user opens the app
2. The user sees categories and cards
3. The user adds income through the top bar in `ContentView`
4. Income is distributed through the system
5. The user taps a card and records an expense
6. If needed, the app first uses free category money and `Free Capital`, then can ask for automatic or manual internal reallocation
7. The user can long-press a card to open the edit flow
8. In the edit flow the user can also withdraw to or deposit from `Free Capital`
9. The user can add a new custom card inside a category
10. Through the side menu the user can open history and statistics

### 11.2 Gestures and modal flows

- tap on a card: record expense
- long press on a card: edit the card
- plus inside category: add a new card
- top menu: history/statistics or reset

## 12. Current limitations and important notes

1. `BudgetService` is empty and does not participate in logic.
2. Historical data from before `BudgetHistoryStorage` cannot be reconstructed, because older versions stored only snapshots.
3. `DashboardView` is not currently the main product screen.
4. A lot of logic is concentrated in `BudgetViewModel`; if the app grows further, splitting use cases into more services may become necessary.
5. `SettingsViewModel` and some older infrastructure still exist, but the active product flow now goes through `BudgetViewModel + StartOnboardingBuilder + BudgetAllocationEngine`.
6. Several onboarding and engine rules still rely on exact system card names in Russian, especially the emergency reserve card `Подушка`.

## 13. Tests

Current unit tests:
- `Smart_moneyTests/BudgetAllocationEngineTests.swift`
- `Smart_moneyTests/BudgetHistoryStorageTests.swift`
- `Smart_moneyTests/BudgetStatisticsServiceTests.swift`

What is already covered:
- core allocation engine behavior
- deficits and minimum resolution
- moving excess to `Free Capital`
- low-priority-first rebalance for a newly added minimum card
- history write/load/clear behavior
- building available months and years
- filtering history by period
- excluding transfers from financial statistics

## 14. Key files for future development

If money logic changes:
- `App/ViewModels/BudgetViewModel.swift`
- `App/Services/BudgetAllocationEngine.swift`

If startup flow changes:
- `App/Views/Main/StartOnboardingFlowView.swift`
- `App/Services/StartOnboardingBuilder.swift`
- `App/Models/StartOnboardingModels.swift`

If statistics change:
- `App/Views/Main/HistoryAndStatisticsView.swift`
- `App/ViewModels/HistoryAndStatisticsViewModel.swift`
- `App/Services/BudgetStatisticsService.swift`
- `App/Services/BudgetHistoryStorage.swift`
- `App/Models/BudgetHistoryEvent.swift`
- `App/Models/BudgetStatisticsSummary.swift`

If card/category UI changes:
- `App/Views/Categories/CategoryAccordionView.swift`
- `App/Views/Categories/Components/*`
- `App/Views/Categories/Sheets/*`

If reset/startup behavior changes:
- `App/Views/Main/ContentView.swift`
- `App/ViewModels/BudgetViewModel.swift`
- `App/Services/PersistenceService.swift`

## 15. Short mental model of the app

If explained very simply:
- there is income
- there are 3 main money buckets
- inside them there are cards with rules
- the system first tries to satisfy required minimums
- the leftover goes to `Free Capital`
- the user spends from cards
- history records real events
- statistics are built from those events
- a full reset wipes everything and starts the flow again

## 16. What to remember for future tasks

1. Do not duplicate allocation logic in the UI or in ad-hoc helper code.
2. All money mutations should go through `BudgetViewModel`.
3. Statistics must be built from the event history, not from state snapshots.
4. A full reset must also clear history.
5. In onboarding, system cards are created by the builder, not manually inside the view.
6. `Free Capital` is a core product concept, not just a leftover amount.
