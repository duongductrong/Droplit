//
//  DroplitApp.swift
//  Droplit
//
//  Created by duongductrong on 17/5/26.
//

import SwiftUI

@main
struct DroplitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Droplit", id: "main") {
            DroplitLaunchView()
                .toolbar(removing: .title)
        }
        .defaultSize(width: 920, height: 680)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .windowToolbarStyle(.unifiedCompact)
    }
}
