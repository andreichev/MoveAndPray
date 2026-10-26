# iOS-архитектура: Controller — View — Interactor

## Назначение документа

Это нормативный контекст для ИИ, который создаёт и изменяет UIKit-приложение. Документ описывает только устройство экранов: Controller, корневую View, Interactor и необязательные вспомогательные роли. Он не задаёт разбиение приложения на модули, пакеты или targets.

Основная единица архитектуры — экран. У экрана есть один владелец поведения (`Controller`), одно корневое представление (`View`) и, когда есть нетривиальная работа, один `Interactor`.

```text
Пользователь
    ↓ событие
View → Controller → Interactor → Controller → View
         │                         │
         └─ lifecycle/решения      └─ новое состояние UI
```

Зависимости направлены так:

- Controller владеет View и Interactor.
- View сообщает Controller о намерениях пользователя.
- Controller просит Interactor выполнить сценарий.
- Interactor возвращает результат Controller через слабый output/delegate или completion.
- Только Controller решает, что показать на экране в результате.

## Неподвижные границы

### View

`FeatureView` — корневая `UIView` экрана и владелец всего визуального дерева этого экрана.

View отвечает за:

- создание subviews;
- визуальные свойства, constraints и локальный layout;
- отображение переданного состояния;
- локальное UI-поведение: подсветку, анимацию, раскрытие визуального элемента, формат ввода;
- хранение только presentation-state, необходимого для отрисовки;
- преобразование низкоуровневых событий контролов в семантические события экрана.

View не должна:

- запускать бизнес-сценарии или обращаться к прикладным сервисам;
- выполнять длительные либо фоновые операции;
- принимать решения о переходах между экранами;
- показывать другой controller;
- знать об Interactor;
- содержать правила предметной области;
- использовать Controller как хранилище данных.

View создаётся программно. Обычный порядок настройки:

1. `setupStyle()`;
2. `addSubviews()`;
3. `makeConstraints()`;
4. настройка локальных UI-событий, если она относится только к самой View.

Публичная поверхность View должна быть семантической:

- `applyState(_ state:)`;
- `showLoading()`;
- `showContent(_ model:)`;
- `showError(_ message:)`;
- `setDelegate(_:)` или обработчики намерений пользователя.

Допустимо дать Controller доступ к отдельному control для `addTarget`, если это остаётся локальной связкой одного экрана. Но Controller не должен через этот доступ строить и раскладывать UI. Для сложной View предпочтительнее delegate или callback с именем пользовательского намерения: `didTapRetry`, `didSelectItem`, `didChangeQuery`.

### Controller

`FeatureController` — `UIViewController`, владелец сценария и посредник между UI и прикладной работой. Обычно это `final class` и `@MainActor`.

Controller отвечает за:

- владение `customView` и установку её как `view` в `loadView()`;
- lifecycle экрана;
- подключение action handlers, delegates и bindings;
- перевод событий View в команды Interactor;
- перевод результатов Interactor в состояние View;
- presentation-решения: alert, sheet, системный picker и подобный UI;
- реакцию на системные события, если они влияют на текущий экран;
- запуск навигационного намерения через принятый в приложении механизм, не раскрывая его View и Interactor.

Controller не должен:

- создавать constraints и вручную собирать дерево subviews;
- содержать низкоуровневую реализацию таблицы или коллекции;
- выполнять тяжёлую работу, которую можно вынести в Interactor;
- обращаться из View к данным через обратную ссылку;
- становиться глобальным хранилищем состояния.

Установка корневой View выполняется явно:

```swift
override func loadView() {
    view = customView
}
```

`viewDidLoad()` подходит для одноразового связывания и первоначальной загрузки. `viewWillAppear`/`viewDidAppear` используются только для работы, которая действительно должна повторяться при каждом появлении. Подписки, tasks, timers и delegates необходимо симметрично отменять либо снимать.

Методы, которые принимает Controller от Interactor, называют по завершённому результату, а не по UI-детали: `didLoad`, `didUpdate`, `didFail`. Внутри них Controller выбирает `ViewState` и вызывает View.

### Interactor

`FeatureInteractor` инкапсулирует сценарии экрана, которые не являются представлением. Он не заменяет Controller и не является ViewModel.

Interactor отвечает за:

- выполнение одного или нескольких use cases экрана;
- координацию зависимостей, нужных этим use cases;
- асинхронную и фоновую работу;
- валидацию и преобразования, относящиеся к сценарию, а не к отображению;
- отмену, дедупликацию и порядок своих операций;
- возврат успеха или ошибки Controller.

Interactor не должен:

- импортировать UIKit без объективной платформенной необходимости;
- обращаться к `controller.view` или `customView`;
- создавать alert, sheet или другой UI;
- выполнять переходы между экранами;
- выбирать цвета, тексты контролов, анимации и layout;
- удерживать Controller сильной ссылкой.

Предпочтительная связь — отдельный output-протокол:

```swift
protocol FeatureInteractorOutput: AnyObject {
    @MainActor func interactorDidLoad(_ items: [FeatureItem])
    @MainActor func interactorDidFail(_ error: Error)
}

final class FeatureInteractor {
    private weak var output: FeatureInteractorOutput?
    private var loadTask: Task<Void, Never>?

    init(output: FeatureInteractorOutput) {
        self.output = output
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            do {
                let items = try await performLoad()
                guard !Task.isCancelled else { return }
                await output?.interactorDidLoad(items)
            } catch is CancellationError {
                return
            } catch {
                await output?.interactorDidFail(error)
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
    }
}
```

Слабая ссылка непосредственно на конкретный Controller допустима как упрощённый вариант той же схемы, но Interactor всё равно общается только через методы результата и никогда не трогает View.

Для маленького синхронного экрана Interactor не создаётся «для симметрии». Его добавляют, когда у экрана появляется самостоятельный сценарий, асинхронность, несколько зависимостей или логика, которую вредно держать в Controller.

## Поток данных и событий

Правильный поток однонаправленный:

```text
1. View фиксирует действие пользователя.
2. View сообщает намерение Controller.
3. Controller валидирует только presentation-контекст и вызывает Interactor.
4. Interactor выполняет сценарий.
5. Interactor возвращает типизированный результат Controller.
6. Controller строит presentation state/model.
7. View целиком отображает переданное состояние.
```

Обратные обходы запрещены: Interactor не обновляет controls, View не вызывает Interactor, DataSource не запускает use case напрямую.

## Состояние экрана

Состояние должно быть явным, особенно у асинхронного экрана:

```swift
enum FeatureViewState: Equatable {
    case idle
    case loading
    case content([FeatureRowModel])
    case empty(message: String)
    case error(message: String)
}
```

Controller владеет выбором состояния, View — его визуализацией. `applyState(_:)` должен приводить экран к полному и непротиворечивому виду: скрывать элементы предыдущего состояния, обновлять данные и показывать элементы нового.

Не следует распределять одно состояние между десятком несвязанных флагов `isLoading`, `hasError`, `isEmpty`. Если состояния взаимоисключающие, они выражаются одним enum.

`FeatureRowModel`, `FeatureDisplayModel` и похожие типы содержат уже подготовленные для UI значения. Они не выполняют операции и не владеют lifecycle.

## Списки и коллекции

Для сложного `UITableView`/`UICollectionView` вводится `FeatureDataSource`.

DataSource отвечает за:

- presentation-массив элементов;
- состояние списка: loading/content/empty/error;
- регистрацию, dequeue и полную конфигурацию ячеек;
- batch updates, pagination trigger, selection и переиспользование;
- перевод событий ячейки или списка в семантический delegate-вызов.

DataSource не обращается к Interactor и не выполняет прикладную работу. Его delegate слабый и обычно указывает на Controller.

Предпочтительная цепочка сложного события:

```text
Cell → DataSource → Controller → Interactor
```

Корневая View обычно владеет table/collection и DataSource, а наружу предоставляет методы `setData`, `appendData`, `showLoading`, `showError` и `setDelegate`. Для простого списка отдельный DataSource не обязателен.

Ячейка является маленькой View: она полностью конфигурируется входной presentation-моделью, сбрасывает переиспользуемое состояние и сообщает действия наверх через callback/delegate. Ячейка не загружает бизнес-данные самостоятельно.

## Дополнительные роли

Добавлять роль следует только при реальной ответственности:

- `ViewState` — взаимоисключающие состояния всего экрана или его крупной части.
- `DisplayModel` / `RowModel` — данные, уже подготовленные для отображения.
- `DataSource` — механика и состояние сложного списка/коллекции.
- `Cell` / component View — переиспользуемый визуальный элемент.
- `ViewDelegate` — семантические события от View к Controller.
- `InteractorOutput` — результаты Interactor к Controller.
- `Mapper` / `Formatter` — заметное преобразование domain-данных в presentation-данные.
- `ChildController` — самостоятельная вложенная сцена со своим lifecycle и поведением; не нужен для обычной составной View.
- `ScreenFactory` / `Builder` — создание Controller и передача зависимостей, если инициализация стала нетривиальной.

Отдельный Presenter обычно не нужен: presentation-решения уже принадлежат Controller. Термин `ViewModel` не используется как универсальная корзина. Если объект только хранит отображаемые данные, он называется `DisplayModel`; если выполняет сценарий — это Interactor.

## Владение и память

Каноническое владение:

```text
Controller ─strong→ View
Controller ─strong→ Interactor
View/DataSource ─weak→ Controller (delegate)
Interactor ─weak→ Controller/InteractorOutput
Closure ─weak→ Controller
```

Правила:

- UI изменяется на `MainActor`.
- Любой escaping closure, принадлежащий View, Interactor, timer или subscription, захватывает Controller слабо.
- Interactor отменяет принадлежащие ему tasks при остановке сценария или уничтожении.
- Controller снимает observers и delegates, если источник живёт дольше экрана.
- Результат устаревшей или отменённой операции не должен перезаписывать новое состояние.

## Канонический каркас экрана

```swift
protocol FeatureViewDelegate: AnyObject {
    func featureViewDidTapRetry(_ view: FeatureView)
    func featureView(_ view: FeatureView, didSelect id: FeatureItem.ID)
}

@MainActor
final class FeatureView: UIView {
    weak var delegate: FeatureViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
        addSubviews()
        makeConstraints()
        bindLocalActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func applyState(_ state: FeatureViewState) {
        // Только приведение visual tree к переданному состоянию.
    }
}

@MainActor
final class FeatureController: UIViewController {
    private let customView = FeatureView()
    private lazy var interactor = FeatureInteractor(output: self)

    override func loadView() {
        view = customView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        customView.delegate = self
        customView.applyState(.loading)
        interactor.load()
    }

    deinit {
        interactor.cancel()
    }
}

extension FeatureController: FeatureViewDelegate {
    func featureViewDidTapRetry(_ view: FeatureView) {
        customView.applyState(.loading)
        interactor.load()
    }

    func featureView(_ view: FeatureView, didSelect id: FeatureItem.ID) {
        // Решение уровня экрана.
    }
}

extension FeatureController: FeatureInteractorOutput {
    func interactorDidLoad(_ items: [FeatureItem]) {
        let rows = items.map(FeatureRowModel.init)
        customView.applyState(rows.isEmpty ? .empty(message: "Нет данных") : .content(rows))
    }

    func interactorDidFail(_ error: Error) {
        customView.applyState(.error(message: error.localizedDescription))
    }
}
```

Имена и число методов меняются под экран; направления зависимостей и границы ответственности — нет.

## Как ИИ должен создавать новый экран

1. Сначала перечислить пользовательские намерения, состояния и результаты сценария.
2. Создать корневую View, полностью содержащую visual tree и layout.
3. Определить семантический интерфейс событий View.
4. Создать Controller, установить View через `loadView()` и связать события.
5. Добавить Interactor только при наличии самостоятельной прикладной или асинхронной работы.
6. Определить output Interactor и возвращать результат только Controller.
7. Для сложного списка добавить DataSource и слабый delegate.
8. Проверить отмену tasks, слабые ссылки и выполнение UI-обновлений на главном actor.
9. Разнести большой Controller по extensions по протоколам или зонам ответственности, не меняя владельца поведения.

## Проверка границ перед завершением задачи

- Controller устанавливает отдельную корневую View.
- В Controller нет constraints и сборки дерева UI.
- Во View нет use cases, навигации и прикладных зависимостей.
- В Interactor нет доступа к View и presentation API.
- События идут View → Controller → Interactor.
- Результаты идут Interactor → Controller → View.
- Delegate/output ссылки слабые, escaping closures не удерживают Controller.
- Состояния loading/content/empty/error не противоречат друг другу.
- DataSource, если он есть, занимается только представлением списка.
- Новая вспомогательная роль имеет одну ясную причину существовать.
