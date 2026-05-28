import WidgetKit
import SwiftUI

@main
struct SmartCartWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ShoppingLiveActivity()
        if #available(iOS 18.0, *) {
            QuickAddControl()
        }
    }
}
