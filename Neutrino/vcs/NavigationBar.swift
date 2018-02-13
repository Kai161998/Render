import UIKit

// MARK: - UINavigationBarProps

open class UINavigationBarProps: UIProps {
  /// A button specialized for placement on a toolbar or tab bar.
  public struct BarButtonItem {
    /// The icon that is going to be used for this button.
    public var icon: UIImage
    /// The optional bar button title.
    public var title: String?
    /// Fallbacks on the 'title' if nothing is defined.
    public var accessibilityLabel: String?
    /// Closure executed whenever the button is tapped.
    public var onSelected: () -> (Void)
    /// A custom node that is going to be used to render the element.
    /// - note: All of the previous properties are going to be ignored when this is not 'nil'.
    public var customNode: ((UINavigationBarProps, UINavigationBarState) -> UINodeProtocol)?
    /// Whether this item should be skipped at the next render invokation.
    public var disabled: Bool = false
    /// Creates a new bar button with the given arguments.
    public init(icon: UIImage,
                title: String? = nil,
                accessibilityLabel: String? = nil,
                onSelected: @escaping () -> Void) {
      self.icon = icon
      self.title = title
      self.accessibilityLabel = accessibilityLabel
      self.onSelected = onSelected
      self.customNode = nil
    }

    /// Creates a new bar button item with the component passed as argument.
    public init(_ node: @escaping (UINavigationBarProps, UINavigationBarState) -> UINodeProtocol) {
      self.icon = UIImage()
      self.title = nil
      self.accessibilityLabel = nil
      self.onSelected = { }
      self.customNode = node
    }
  }
  /// The navigation bar title.
  public var title: String = ""
  /// *Optional* provide a custom *BarButtonItem* to override the default back button.
  public lazy var leftButtonItem: BarButtonItem = {
    return BarButtonItem(icon: makeDefaultBackButtonImage()) {
      guard let vc = UIGetTopmostViewController() else { return }
      if vc.isModal() {
        vc.dismiss(animated: true, completion: nil)
      } else {
        vc.navigationController?.popViewController(animated: true)
      }
    }
  }()
  /// *Optional* The right buttons in the navigation bar.
  public var rightButtonItems: [BarButtonItem] = []
  /// *Optional* Overrides the title component view.
  public var titleNode: ((UINavigationBarProps, UINavigationBarState) -> UINodeProtocol)?
  /// The expanded navigation bar height.
  public var heightWhenExpanded: CGFloat = 94
  /// The default navigation bar height.
  public var heightWhenNormal: CGFloat = 44
  /// A Boolean value indicating whether the title should be displayed in a large format.
  /// - note: This is currently not supported if your *TableViewController* has section headers.
  public var expandable: Bool = true
  /// The style applied to this navigation bar.
  public var style = UINavigationBarDefaultStyle()

  /// Extracts the system back button image from a navigation bar.
  private func makeDefaultBackButtonImage() -> UIImage {
    let image = UIImage.yg_image(from: "←",
                                 color: style.tintColor,
                                 font: UIFont.systemFont(ofSize: 22, weight: UIFont.Weight.bold),
                                 size: CGSize(width: 22, height: 26))
    return image
  }
}

// MARK: - UINavigationBarState

open class UINavigationBarState: UIStateProtocol {
  /// *Internal only* The state has not yet been initialized.
  var initialized: Bool = false
  /// The current navigation bar height
  public var height: CGFloat = 0
  /// Whether the navigation bar is currently expanded or not.
  public var isExpanded: Bool = false

  public required init() { }

  /// Initialise this state accordingly to the navigation bar preferences.
  func initializeIfNecessary(props: UINavigationBarProps) {
    guard !initialized else { return }
    initialized = true
    height = props.expandable ? props.heightWhenExpanded : props.heightWhenNormal
    isExpanded = props.expandable
  }
}

// MARK: - UINavigationBarComponent

open class UINavigationBarComponent: UIComponent<UINavigationBarState, UINavigationBarProps> {
  // Internal reuse identifiers.
  public enum Id: String {
    case navigationBar, notch, buttonBar, leftBarButton, rightBarButton, title, titleLabel
  }
  // Constants.
  private struct LayoutConstants {
    static let barButtonHeight: CGFloat = 44
    static let defaultMargin: CGFloat = 4
    static var topLayoutGuideMargin: CGFloat {
      if #available(iOS 11.0, *) { return 4 }
      return 12
    }
  }
  /// Builds the node hierarchy for this component.
  open override func render(context: UIContextProtocol) -> UINodeProtocol {
    let props = self.props
    let state = self.state
    state.initializeIfNecessary(props: props)
    // The main navigation bar node.
    let node = UINode<UIView>(reuseIdentifier: Id.navigationBar.rawValue) { configuration in
      configuration.set(\UIView.yoga.width, configuration.canvasSize.width)
      configuration.set(\UIView.yoga.height, state.height)
      configuration.set(\UIView.backgroundColor, props.style.backgroundColor)
    }
    // The status bar protection background.
    let statusBar = UINode<UIView>(reuseIdentifier: Id.notch.rawValue, create: {
      let view = UIView()
      view.backgroundColor = props.style.backgroundColor
      view.yoga.percent.width = 100%
      view.yoga.height = LayoutConstants.barButtonHeight
      view.yoga.marginTop = -view.yoga.height
      return view
    })
    // The overall navigation bar hierarchy.
    return node.children([
      statusBar,
      renderTitle(),
      renderBarButton(),
    ])
  }

  /// Renders the bar button view.
  /// - note: Override this method if you wish to render your navigation bar buttons differently.
  open func renderBarButton() -> UINodeProtocol {
    let props = self.props
    let state = self.state
    // Build the button bar.
    func makeBar() -> UIView {
      let view = UIView()
      view.backgroundColor = .clear
      view.yoga.position = .absolute
      view.yoga.height = LayoutConstants.barButtonHeight
      view.yoga.marginTop = LayoutConstants.topLayoutGuideMargin
      view.yoga.percent.width = 100%
      view.yoga.flexDirection = .row
      view.yoga.justifyContent = .spaceBetween
      view.yoga.alignItems = .center
      return view
    }
    // Build the left bar button item.
    func makeLeftButton() -> UIButton {
      let button = UIButton(type: .custom)
      button.setImage(props.leftButtonItem.icon, for: .normal)
      button.accessibilityLabel = props.leftButtonItem.accessibilityLabel
      button.yoga.width = LayoutConstants.barButtonHeight
      button.yoga.percent.height = 100%
      button.onTap { _ in
        props.leftButtonItem.onSelected()
      }
      return button
    }
    /// Build a right bar button item.
    func makeRightButton() -> UIButton {
      let button = UIButton(type: .custom)
      button.yoga.minWidth = LayoutConstants.barButtonHeight
      button.yoga.percent.height = 100%
      button.yoga.marginRight = LayoutConstants.defaultMargin * 4
      button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.regular)
      button.setTitleColor(props.style.tintColor, for: .normal)
      return button
    }
    // Left node.
    var left = props.leftButtonItem.customNode != nil ?
      props.leftButtonItem.customNode!(props, state) :
      UINode<UIView>(reuseIdentifier: Id.leftBarButton.rawValue, create: makeLeftButton)
    // The bar button item is skipped if 'disabled' is true.
    left = props.leftButtonItem.disabled ? UINilNode.nil : left
    // Right nodes.
    let items: [UINodeProtocol] = props.rightButtonItems.flatMap { item in
      // The bar button item is skipped if 'disabled' is true.
      if item.disabled { return nil }
      if let node = item.customNode { return node(props, state) }
      return UINode<UIButton>(reuseIdentifier: Id.rightBarButton.rawValue, create: makeRightButton){
        $0.view.onTap { _ in item.onSelected() }
        $0.view.setImage(item.icon, for: .normal)
        $0.view.accessibilityLabel = item.accessibilityLabel
        $0.view.setTitle(item.title, for: .normal)
      }
    }
    let right = UINode<UIView>().children(items)
    // Button bar node.
    let bar = UINode<UIView>(reuseIdentifier: Id.buttonBar.rawValue, create: makeBar)
    return bar.children([left, right])
  }

  /// Renders the title bar.
  /// - note: Provide the 'titleComponent' prop if you want a custom title view, or override this
  /// method.
  open func renderTitle() -> UINodeProtocol {
    let props = self.props
    let state = self.state
    // Custom title component.
    if let titleNode = props.titleNode {
      return titleNode(props, state)
    }
    // Builds the title container view.
    func makeTitleContainer() -> UIView {
      let view = UIView()
      view.yoga.percent.width = 100%
      view.yoga.percent.height = 100%
      view.yoga.marginTop = LayoutConstants.topLayoutGuideMargin
      view.yoga.paddingLeft = LayoutConstants.defaultMargin * 3
      view.yoga.paddingRight = view.yoga.paddingLeft
      view.yoga.justifyContent = .flexEnd
      view.yoga.alignItems = .center
      return view
    }
    // The title label changes its position and appearance according to the navigation bar
    // state.
    let title = UINode<UILabel>(reuseIdentifier: Id.titleLabel.rawValue) { configuration in
      configuration.set(\UILabel.yoga.percent.width, 100%)
      configuration.set(\UILabel.text, props.title)
      configuration.set(\UILabel.textColor, props.style.titleColor)
      if state.isExpanded {
        configuration.set(\UILabel.font, props.style.expandedTitleFont)
        configuration.set(\UILabel.yoga.marginTop, LayoutConstants.barButtonHeight)
        configuration.set(\UILabel.yoga.marginBottom, LayoutConstants.defaultMargin * 3)
        configuration.set(\UILabel.yoga.height, CGFloat.undefined)
        configuration.set(\UILabel.yoga.maxWidth, configuration.canvasSize.width)
        configuration.set(\UILabel.textAlignment, .left)
        let height = state.height - LayoutConstants.barButtonHeight
        let alpha = pow(height/props.heightWhenNormal, 3)
        configuration.set(\UILabel.alpha, min(1, alpha))
      } else {
        configuration.set(\UILabel.font, props.style.titleFont)
        configuration.set(\UILabel.yoga.marginTop, 0)
        configuration.set(\UILabel.yoga.marginBottom, 0)
        configuration.set(\UILabel.yoga.height, LayoutConstants.barButtonHeight)
        configuration.set(\UILabel.yoga.maxWidth, 0.5 * configuration.canvasSize.width)
        configuration.set(\UILabel.textAlignment, .center)
        configuration.set(\UILabel.alpha, 1)
      }
    }
    let container = UINode<UIView>(reuseIdentifier: Id.title.rawValue, create: makeTitleContainer)
    return container.children([title])
  }

  /// Used to propagate the navigation bar style to its container.
  public func updateNavigationBarContainer(_ view: UIView) {
    view.depthPreset = state.isExpanded ? props.style.depthWhenExpanded:props.style.depthWhenNormal
    view.backgroundColor = props.style.backgroundColor
  }
}

// MARK: - UINavigationBarManager

/// The container object for this navigation bar.
public final class UINavigationBarManager {
  /// The context for the component hierarchy that is going to be instantiated from the controller.
  /// - note: This can be passed as argument of the view controller constructor.
  private weak var context: UIContext?
  /// The custom navigation bar component.
  public lazy var component: UINavigationBarComponent? = nil
  /// The view that is going to be used to mount the *navigationBarComponent*.
  public lazy var view: UIView = makeNavigationBarView()
  /// The current navigation bar height.
  public var heightConstraint: NSLayoutConstraint?
  /// 'true' only if the navigation bar component is defined.
  public var hasCustomNavigationBar: Bool {
    return component != nil
  }
  /// Whether the navigation bar was hidden before pushing this viewController.
  public var wasNavigationBarHidden: Bool = false

  /// Builds the canvas view the navigation bar.
  private func makeNavigationBarView() -> UIView {
    let navBar = UIView()
    navBar.translatesAutoresizingMaskIntoConstraints = false
    return navBar
  }

  /// Constructs the default navigation bar.
  public func makeDefaultNavigationBarComponent() {
    component = context?.component(UINavigationBarComponent.self, key: "navigationBar")
  }

  /// Creates a new custom navigation bar container with the given context.
  public init(context: UIContext) {
    self.context = context
  }
}

// MARK: - UICustomNavigationBarProtocol

public protocol UICustomNavigationBarProtocol: UIScrollViewDelegate {
  /// The navigation bar manager associated with this *UIViewController*.
  var navigationBarManager: UINavigationBarManager { get }
}

/// Helper methods that coordinates the change of appearance in the custom navigation bar
/// component.
public extension UICustomNavigationBarProtocol where Self: UIViewController {
  /// Create and initalize the navigation bar (if necessary).
  /// - note: If 'navigationBarManager.component' is not defined, this method is no-op.
  public func initializeNavigationBarIfNecessary() {
    let nv = navigationController
    navigationBarManager.wasNavigationBarHidden = nv?.isNavigationBarHidden ?? false
    // No custom navigation bar - nothing to do.
    guard let navigationBarComponent = navigationBarManager.component else { return }
    // Hides the system navigation bar.
    nv?.isNavigationBarHidden = true
    // Render the component-based one.
    navigationBarComponent.setCanvas(view: navigationBarManager.view,
                                     options: UIComponentCanvasOption.defaults())
    // No back button for the root view controller.
    if nv?.viewControllers.first === self {
      navigationBarComponent.props.leftButtonItem.disabled = true
    }
    renderNavigationBar()
  }

  /// Renders the navigation bar in its current state.
  /// - note: If 'navigationBarManager.component' is not defined, this method is no-op.
  public func renderNavigationBar(updateHeightConstraint: Bool = true) {
    guard let navigationBarComponent = navigationBarManager.component else {
      navigationBarManager.heightConstraint?.constant = 0
      return
    }
    navigationBarComponent.setNeedsRender()
    navigationBarComponent.updateNavigationBarContainer(navigationBarManager.view)
    if updateHeightConstraint {
      navigationBarManager.heightConstraint?.constant = navigationBarComponent.state.height
    }
  }

  /// Tells the delegate when the user scrolls the content view within the receiver.
  /// - note: If 'navigationBarManager.component' is not defined, this method is no-op.
  public func navigationBarDidScroll(_ scrollView: UIScrollView) {
    // There's no custom navigation bar component.
    guard let navigationBarComponent = navigationBarManager.component else { return }
    let y = scrollView.contentOffset.y
    let state = navigationBarComponent.state
    let props = navigationBarComponent.props
    // The navigation bar is not expandable, nothing to do.
    guard props.expandable else {
      renderNavigationBar(updateHeightConstraint: true)
      return
    }
    // Bounces the navigation bar.
    if y < 0 {
      state.height = props.heightWhenExpanded + (-y)
      scrollView.contentInset.top = 0
      renderNavigationBar(updateHeightConstraint: false)
      return
    }
    // Breaks when the scroll reaches the default navigation bar height.
    if y > props.heightWhenNormal {
      let wasExpanded = state.isExpanded
      state.isExpanded = false
      // Make sure that the height constraint is updated.
      if wasExpanded {
        let offset = props.heightWhenExpanded - props.heightWhenNormal
        state.height = offset
        scrollView.contentInset.top = offset
        renderNavigationBar(updateHeightConstraint: true)
      }
      state.height = props.heightWhenNormal
      renderNavigationBar(updateHeightConstraint: false)
    // Adjusts the height otherwise.
    } else {
      state.isExpanded = true
      state.height = props.heightWhenExpanded - y
      scrollView.contentInset.top = y
      renderNavigationBar(updateHeightConstraint: true)
    }
  }
}

// MARK: - UINavigationBarDefaultStyle

// Default (system-like) appearance proxy for the component-based navigation bar.
public struct UINavigationBarDefaultStyle {
  /// The default background color.
  public var backgroundColor: UIColor = UIColor(displayP3Red:0.98, green: 0.98, blue: 0.98, alpha:1)
  /// The default title color.
  public var titleColor: UIColor = .black
  /// The font used when 'prefersLargeTitles' is enabled.
  public var expandedTitleFont: UIFont = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.black)
  /// The font used when the navigation bar is in its default mode.
  public var titleFont: UIFont = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.semibold)
  /// The tint color applied to the icons and the the buttons.
  public var tintColor: UIColor = UIColor(displayP3Red:0, green:0.47, blue:1, alpha:1)
  /// The font applied to the button items.
  public var buttonFont: UIFont = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.regular)
  /// The shadow applied when the navigation bar is expanded.
  public var depthWhenExpanded: DepthPreset = .none
  /// The shadow applied when the navigation bar is in its default mode.
  public var depthWhenNormal: DepthPreset = .depth2
}
