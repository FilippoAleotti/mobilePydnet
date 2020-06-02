//
//  AppDelegate.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 21/04/2019.
//  Copyright © 2019 Apple. All rights reserved.
//
import UIKit
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.window = UIWindow(frame: UIScreen.main.bounds)

         let storyboard = UIStoryboard(name: "Main", bundle: nil)

         let initialViewController = storyboard.instantiateInitialViewController()!

         self.window?.rootViewController = initialViewController
         self.window?.makeKeyAndVisible()

        return true
    }
}
