//
//  AppDelegate.swift
//  LoginItemHelper
//
//  Created by Deping Zheng on 6/26/16.
//  Copyright © 2016 Deping Zheng. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        var pathComponents:NSArray = (NSBundle.mainBundle().bundlePath as NSString).pathComponents
        pathComponents = pathComponents.subarrayWithRange(NSMakeRange(0, pathComponents.count - 4))
        let path = NSString.pathWithComponents(pathComponents as! [String])
        NSWorkspace.sharedWorkspace().launchApplication(path)
        NSApp.terminate(nil)        
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

