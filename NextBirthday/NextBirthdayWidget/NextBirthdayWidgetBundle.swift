import WidgetKit
import SwiftUI

@main
struct NextBirthdayWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        CountdownWidget()
        LockScreenWidget()
    }
}
