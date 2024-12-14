//
//  DinnerWidgetBundle.swift
//  DinnerWidget
//
//  Created by Thom Rietberg on 21/12/2024.
//

import WidgetKit
import SwiftUI

@main
struct DinnerWidgetBundle: WidgetBundle {
    var body: some Widget {
        DinnerWidget()
        DinnerWidgetControl()
    }
}
