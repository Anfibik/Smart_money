# Smart Money

## English

### Overview

`Smart Money` is a personal budgeting iOS app built with `SwiftUI`.
The app organizes money into 3 top-level categories:

- `Essentials`
- `Wants`
- `Savings`

Each category contains card-like subcategories. A card can have:

- a title
- a system icon
- a planned percentage inside its category
- a minimum amount
- a maximum amount
- a priority
- current allocated money
- current monthly income and expense tracking

The app is not a static tracker. It calculates money distribution with an allocation engine and keeps unassigned money inside a separate pool called `Free Capital`.

### Core Idea

Income is first split between the 3 main categories according to the selected strategy.
Inside each category, money is allocated to cards according to:

- base percentages
- minimum limits
- priority rules

If some money is not needed inside a category, it can move to `Free Capital`.
If a card has a shortage, the app can cover it from:

- free money inside the same category
- `Free Capital`

### Main Features

- 5-step onboarding flow for first launch
- automatic creation of system cards from the user profile
- monthly income distribution across categories and cards
- expense registration for every card
- automatic and manual shortage coverage
- transfers between cards and `Free Capital`
- custom user cards
- card editing: title, icon, percentage, minimum, maximum
- operation history
- month / year / all-time statistics
- full reset and onboarding restart

### Onboarding

The current onboarding flow has 5 steps:

1. Finance and housing
2. Family and obligations
3. Strategy selection
4. Need cards review
5. Final summary

During onboarding the app builds a full preview using the same allocation engine used in the main app.

### Current Strategy Presets

- `Stability`: Essentials `60%`, Wants `15%`, Savings `25%`
- `Balance`: Essentials `55%`, Wants `20%`, Savings `25%`
- `Capital Growth`: Essentials `50%`, Wants `15%`, Savings `35%`

### Current System Cards

#### Essentials

- `Housing`
  - rented housing: `25%`
  - owned housing: `10%`
- `Food`
  - `20% + 4% * adult dependents + 2% * children`
- `Health`
  - `3% + 0.5% * adult dependents + 1% * children + 5% * elderly dependents`
- `Hygiene`
  - `5%`
- `Children`
  - appears if there are children
  - `10%`
- `Animals`
  - appears if pets count is greater than 0
  - `5%`
- `Transport`
  - always exists
  - with car: `15%`, minimum `2000`
  - without car: `5%`, minimum `1000`

Notes:

- `adult dependents` include both regular adult dependents and elderly dependents
- children in onboarding are currently defined as children up to `12` years old

#### Wants

Default cards:

- `Shopping` `30%`
- `Hobby` `20%`
- `Leisure` `20%`
- `Travel` `10%`
- `Gifts` `5%`
- `Sport` `5%`

#### Savings

Default cards:

- `Emergency Fund` `50%`
- `Debt` if capital is negative
- `Credit` if the user has a monthly credit payment

### Priority Rules

The current priority model is:

- `High`: only one system card per category
- `Medium`: all other system cards
- `Low`: all user-created cards

Default `High` cards:

- `Essentials`
  - rented housing: `Housing`
  - owned housing: `Food`
- `Wants`: `Shopping`
- `Savings`: `Emergency Fund`

### Main Screens

- `ContentView`: main container and navigation entry
- `StartOnboardingFlowView`: first-launch onboarding
- `CategoryAccordionView`: category list with expandable cards
- `ExpenseSheetView`: expense entry and shortage coverage
- `HistoryAndStatisticsView`: history + analytics

### Architecture

The project follows a pragmatic `MVVM` style:

- `Models`: domain structures
- `ViewModels`: state and orchestration
- `Services`: allocation, persistence, history, statistics
- `Views`: UI

Important architectural points:

- `BudgetViewModel` is the central state holder
- `BudgetAllocationEngine` is the single source of allocation logic
- UI does not mutate finances directly; all money actions go through the view model

### Important Files

- [App/Smart_moneyApp.swift](/Users/fibik/Programming/Swift/Smart_money/App/Smart_moneyApp.swift)
- [App/Views/Main/ContentView.swift](/Users/fibik/Programming/Swift/Smart_money/App/Views/Main/ContentView.swift)
- [App/Views/Main/StartOnboardingFlowView.swift](/Users/fibik/Programming/Swift/Smart_money/App/Views/Main/StartOnboardingFlowView.swift)
- [App/ViewModels/BudgetViewModel.swift](/Users/fibik/Programming/Swift/Smart_money/App/ViewModels/BudgetViewModel.swift)
- [App/Services/BudgetAllocationEngine.swift](/Users/fibik/Programming/Swift/Smart_money/App/Services/BudgetAllocationEngine.swift)
- [App/Services/StartOnboardingBuilder.swift](/Users/fibik/Programming/Swift/Smart_money/App/Services/StartOnboardingBuilder.swift)
- [App/Services/PersistenceService.swift](/Users/fibik/Programming/Swift/Smart_money/App/Services/PersistenceService.swift)

### Persistence

- current budget state: `UserDefaults`
- operation history: JSON file in `Application Support`

### Tech Stack

- `Swift`
- `SwiftUI`
- `Combine`
- `Foundation`
- `Charts`
- `XCTest`

The project currently does not use third-party package dependencies.

### Run and Test

Open the project in Xcode:

```bash
open Smart_money.xcodeproj
```

Run tests:

```bash
xcodebuild test -project Smart_money.xcodeproj -scheme Smart_moneyTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```

---

## Русский

### О проекте

`Smart Money` — это iOS-приложение для личного бюджета на `SwiftUI`.
Приложение строится вокруг 3 основных категорий:

- `Основные`
- `Желаемые`
- `Накопления`

Внутри каждой категории находятся карточки-подкатегории. У карточки могут быть:

- название
- иконка
- плановый процент внутри категории
- минимальная сумма
- максимальная сумма
- приоритет
- текущая выделенная сумма
- учёт доходов и расходов за текущий месяц

Приложение не просто хранит список расходов. Оно распределяет деньги через отдельный движок аллокации и использует отдельный пул нераспределённых средств — `Свободный капитал`.

### Основная логика

Доход сначала делится между 3 главными категориями по выбранной стратегии.
Дальше внутри каждой категории деньги распределяются по карточкам с учётом:

- базовых процентов
- минимальных лимитов
- правил приоритета

Если деньги внутри категории не нужны, остаток может уйти в `Свободный капитал`.
Если карточке не хватает денег, дефицит может покрываться:

- за счёт свободных денег внутри той же категории
- из `Свободного капитала`

### Основные возможности

- стартовый онбординг из 5 шагов
- автоматическое создание системных карточек по профилю пользователя
- распределение ежемесячного дохода по категориям и карточкам
- учёт расходов по каждой карточке
- автоматическое и ручное покрытие дефицитов
- переводы между карточками и `Свободным капиталом`
- пользовательские карточки
- редактирование карточек: название, иконка, процент, минимум, максимум
- история операций
- статистика по месяцу, году и за всё время
- полный сброс состояния и повторный онбординг

### Онбординг

Текущий онбординг состоит из 5 шагов:

1. Финансы и жильё
2. Семья и обязательства
3. Выбор стратегии
4. Проверка карт потребностей
5. Итоговая конфигурация

Во время онбординга приложение строит полноценный preview через тот же `BudgetAllocationEngine`, который используется и в основном приложении.

### Текущие стратегии

- `Стабильность`: Основные `60%`, Желаемые `15%`, Накопления `25%`
- `Баланс`: Основные `55%`, Желаемые `20%`, Накопления `25%`
- `Рост Капитала`: Основные `50%`, Желаемые `15%`, Накопления `35%`

### Текущие системные карточки

#### Основные

- `Жилье`
  - аренда: `25%`
  - своё жильё: `10%`
- `Питание`
  - `20% + 4% * взрослые иждивенцы + 2% * дети`
- `Здоровье`
  - `3% + 0.5% * взрослые иждивенцы + 1% * дети + 5% * иждивенцы-старики`
- `Гигиена`
  - `5%`
- `Дети`
  - появляется, если есть дети
  - `10%`
- `Животные`
  - появляется, если количество домашних животных больше `0`
  - `5%`
- `Транспорт`
  - создаётся всегда
  - с авто: `15%`, минимум `2000`
  - без авто: `5%`, минимум `1000`

Примечания:

- `взрослые иждивенцы` включают и обычных взрослых иждивенцев, и стариков
- дети в онбординге сейчас определяются как дети до `12` лет

#### Желаемые

Карточки по умолчанию:

- `Шопинг` `30%`
- `Хобби` `20%`
- `Досуг` `20%`
- `Путешествия` `10%`
- `Подарки` `5%`
- `Спорт` `5%`

#### Накопления

Карточки по умолчанию:

- `Подушка` `50%`
- `Долг`, если капитал отрицательный
- `Кредит`, если есть ежемесячный платёж по кредиту

### Правила приоритетов

Текущая модель приоритетов:

- `High`: только одна системная карточка на категорию
- `Medium`: все остальные системные карточки
- `Low`: все пользовательские карточки

Карточки с высоким приоритетом по умолчанию:

- `Основные`
  - аренда: `Жилье`
  - своё жильё: `Питание`
- `Желаемые`: `Шопинг`
- `Накопления`: `Подушка`

### Основные экраны

- `ContentView` — главный контейнер приложения
- `StartOnboardingFlowView` — стартовый онбординг
- `CategoryAccordionView` — список категорий с раскрывающимися карточками
- `ExpenseSheetView` — экран внесения расхода и покрытия дефицита
- `HistoryAndStatisticsView` — история и аналитика

### Архитектура

Проект построен в прагматичном стиле `MVVM`:

- `Models` — доменные структуры
- `ViewModels` — состояние и orchestration
- `Services` — аллокация, сохранение, история, статистика
- `Views` — интерфейс

Ключевые архитектурные принципы:

- `BudgetViewModel` — главный держатель состояния
- `BudgetAllocationEngine` — единый источник логики распределения денег
- UI не меняет финансы напрямую; все денежные действия идут через view model

### Важные файлы

- [App/Smart_moneyApp.swift](/Users/fibik/Programming/Swift/Smart_money/App/Smart_moneyApp.swift)
- [App/Views/Main/ContentView.swift](/Users/fibik/Programming/Swift/Smart_money/App/Views/Main/ContentView.swift)
- [App/Views/Main/StartOnboardingFlowView.swift](/Users/fibik/Programming/Swift/Smart_money/App/Views/Main/StartOnboardingFlowView.swift)
- [App/ViewModels/BudgetViewModel.swift](/Users/fibik/Programming/Swift/Smart_money/App/ViewModels/BudgetViewModel.swift)
- [App/Services/BudgetAllocationEngine.swift](/Users/fibik/Programming/Swift/Smart_money/App/Services/BudgetAllocationEngine.swift)
- [App/Services/StartOnboardingBuilder.swift](/Users/fibik/Programming/Swift/Smart_money/App/Services/StartOnboardingBuilder.swift)
- [App/Services/PersistenceService.swift](/Users/fibik/Programming/Swift/Smart_money/App/Services/PersistenceService.swift)

### Хранение данных

- текущее состояние бюджета: `UserDefaults`
- история операций: JSON-файл в `Application Support`

### Технологии

- `Swift`
- `SwiftUI`
- `Combine`
- `Foundation`
- `Charts`
- `XCTest`

Сторонние пакетные зависимости сейчас не используются.

### Запуск и тесты

Открыть проект в Xcode:

```bash
open Smart_money.xcodeproj
```

Запустить тесты:

```bash
xcodebuild test -project Smart_money.xcodeproj -scheme Smart_moneyTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'
```
