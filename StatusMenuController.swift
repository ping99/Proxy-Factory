//
//  StatusMenuController.swift
//  Proxy Factory
//
//  Created by Deping Zheng on 1/17/16.
//  Copyright © 2016 Deping Zheng. All rights reserved.
//

import Cocoa
import SystemConfiguration


class StatusMenuController: NSObject {
    
    @IBOutlet weak var statusMenu: NSMenu!
    // log window
    @IBOutlet weak var logWindow: NSWindow!
    @IBOutlet weak var logScrollView: NSScrollView!
    
    // preferences window
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var preferencesTabView: NSTabView!
    // main tab
    @IBOutlet weak var listenAddrTextField: NSTextField!
    @IBOutlet weak var proxyPortTextField: NSTextField!
    @IBOutlet weak var pacPortTextField: NSTextField!
    // app id tab
    @IBOutlet weak var appIDTextField: NSTextField!
    @IBOutlet weak var appPasswordTextField: NSTextField!
    // ip list tab
    @IBOutlet weak var iplistScrollView: NSScrollView!
    @IBOutlet weak var google_cn_CheckBox: NSButton!
    @IBOutlet weak var google_hk_CheckBox: NSButton!
    @IBOutlet weak var google_talk_CheckBox: NSButton!
    // about tab
    @IBOutlet var aboutTextView: NSTextView!
    
    // menu items for switching loop
    @IBOutlet weak var goagentMenuItem: NSMenuItem!
    @IBOutlet weak var goproxyMenuItem: NSMenuItem!
    @IBOutlet weak var enableAutoProxyMenuItem: NSMenuItem!
    @IBOutlet weak var enableGlobalProxyMenuItem: NSMenuItem!
    
    // update window
    @IBOutlet weak var updateWindow: NSWindow!
    @IBOutlet weak var downloadProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var updateProgressLabel: NSTextField!
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    
    // set as optional, init with nil
    var proxyService:ProxyService? = nil

    override func awakeFromNib() {
        let icon = NSImage(named: "statusIcon")
        icon?.template = false// best for dark mode
        statusItem.image = icon
        statusItem.menu = statusMenu
        // load about info from about.rtf
        aboutTextView.editable = false
        let aboutFilePath = NSBundle.mainBundle().pathForResource("about", ofType: ".rtf")
        let aboutData = NSData.init(contentsOfFile: aboutFilePath!)
        if let content = NSAttributedString.init(RTF: aboutData!, documentAttributes: nil){
            aboutTextView.textStorage?.setAttributedString(content)
        }
        
        // Default proxy is goproxy
        self.proxyService =  ProxyService(proxyName: "goproxy", logScrollView: self.logScrollView)
        self.proxyService?.startService()
        initProxySetting()
        icon?.template = true
    }
    
    @IBAction func logClicked(sender: AnyObject) {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        logWindow.orderFrontRegardless()
        logWindow.makeKeyWindow()
    }
    
    @IBAction func enableProxy(sender: NSMenuItem) {
        if sender.state == NSOnState {
            sender.state = NSOffState
            if sender.title == "GoAgent" {
                goproxyMenuItem.state = NSOnState
                self.proxyService = ProxyService(proxyName: "goproxy", logScrollView: self.logScrollView)
            }else{
                goagentMenuItem.state = NSOnState
                self.proxyService = ProxyService(proxyName: "goagent", logScrollView: self.logScrollView)
            }
        }else{
            sender.state = NSOnState
            if sender.title == "GoAgent" {
                goproxyMenuItem.state = NSOffState
                self.proxyService = ProxyService(proxyName: "goagent", logScrollView: self.logScrollView)
            }else{
                goagentMenuItem.state = NSOffState
                self.proxyService = ProxyService(proxyName: "goproxy", logScrollView: self.logScrollView)
            }
        }
        self.proxyService!.restartService()
    }
    
    @IBAction func setProxyClicked(sender: NSMenuItem) {
        var usePAC:Bool = true
        if sender == enableAutoProxyMenuItem {
            usePAC = true
        }else if sender == enableGlobalProxyMenuItem{
            usePAC = false
        }else{
            print("something triggled method setProxyClicked(sender: NSMenuItem)")
        }
        
        let setProxyOnOff:Bool = (!(sender.state == NSOnState)) ? true : false
        print("set proxy \(setProxyOnOff)")
        let xpcClient =  SMJobBlessXPCClient()
        xpcClient.toggleSystemProxy(setProxyOnOff, usePAC: usePAC, proxyPort:(self.proxyService?.proxyPort)!, pacPath: (self.proxyService?.pacPath)!)
        
        // Update menu status. Turn one and Turn off another
        if sender.state == NSOffState {
            sender.state = NSOnState
            if sender == enableAutoProxyMenuItem {
                enableGlobalProxyMenuItem.state = NSOffState
            }else{
                enableAutoProxyMenuItem.state = NSOffState
            }
        } else{
            sender.state = NSOffState
        }
    }
 
    @IBAction func releasePortClicked(sender: NSMenuItem) {
        self.proxyService!.releasePort()
        self.proxyService!.restartService()
        logClicked(self)
    }
    
    @IBAction func installCertificate(sender: NSMenuItem) {
        self.proxyService!.installCertificate()
    }
    
    @IBAction func preferencesClicked(sender: NSMenuItem) {
        // Setup Main tabview
        if self.proxyService?.proxyName == "goproxy" {
            pacPortTextField.enabled = false
        }
        
        listenAddrTextField.stringValue = self.proxyService!.listenAddr
        proxyPortTextField.stringValue = self.proxyService!.proxyPort
        pacPortTextField.stringValue = self.proxyService!.pacPort
        
        // Setup App ID tabview
        appIDTextField.stringValue = ""
        for appID in self.proxyService!.appIDs{
            appIDTextField.stringValue += (appID as! String) + "\t"
        }
        appPasswordTextField.stringValue = self.proxyService!.password
        
        // Setup IP list tab
        iplistScrollView.documentView!.textStorage!!.mutableString.setString("")
        for ip in self.proxyService!.ipList{
            iplistScrollView.documentView!.textStorage!!.mutableString.appendString( ip as! String + "\n")
        }
        
        // Display preferences window
        if self.proxyService!.proxyName == "goagent" {
            preferencesWindow.title = "GoAgent Preferences"
        }else if self.proxyService!.proxyName == "goproxy" {
            preferencesWindow.title = "GoProxy Preferences"
        }
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        preferencesWindow.orderFrontRegardless()
        preferencesWindow.makeKeyWindow()
    }
    
    @IBAction func updateMainClicked(sender: NSButton) {
        // Check port confict for goagent
        if proxyPortTextField.stringValue == pacPortTextField.stringValue{
            let alert = NSAlert()
            alert.messageText = "Warning"
            alert.addButtonWithTitle("OK")
            alert.informativeText = "The pac port must be different from proxy port for goagent"
            alert.beginSheetModalForWindow(self.preferencesWindow, completionHandler: nil)
            return
        }
        
        self.proxyService!.listenAddr = listenAddrTextField.stringValue
        self.proxyService!.proxyPort = proxyPortTextField.stringValue
        self.proxyService!.pacPort = pacPortTextField.stringValue
        self.proxyService!.updateSettingToFile()
        self.proxyService!.restartService()
        
        // Inform user
        let alert = NSAlert()
        alert.messageText = "Information"
        alert.addButtonWithTitle("OK")
        alert.informativeText = "Updated successfully! \nProxy service has been restarted!"
        alert.beginSheetModalForWindow(self.preferencesWindow, completionHandler: nil)
    }

    @IBAction func updateAppIDClicked(sender: NSButton) {
        // Get iplist from scroll view
        let appIDString = appIDTextField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "|\n\t "))
        let appIDList = appIDString.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "|\n\t "))
        self.proxyService!.appIDs = appIDList
        self.proxyService!.updateSettingToFile()
        self.proxyService!.restartService()
        
        // Inform user
        let alert = NSAlert()
        alert.messageText = "Information"
        alert.addButtonWithTitle("OK")
        alert.informativeText = "Updated successfully! \nProxy service has been restarted!"
        alert.beginSheetModalForWindow(self.preferencesWindow, completionHandler: nil)
    }
    
    @IBAction func updateIPListClicked(sender: NSButton) {
        // Get iplist from scroll view
        let iplistString = iplistScrollView.documentView!.textStorage!!.string.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "|\n "))
        let iplist = iplistString.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "|\n "))
        self.proxyService?.ipList = iplist
        self.proxyService?.updateSettingToFile()
        self.proxyService!.restartService()
        
        // Inform user
        let alert = NSAlert()
        alert.messageText = "Information"
        alert.addButtonWithTitle("OK")
        alert.informativeText = "Updated successfully! \nProxy service has been restarted!"
        alert.beginSheetModalForWindow(self.preferencesWindow, completionHandler: nil)
    }

    @IBAction func aboutClicked(sender: NSMenuItem) {
        // Display preferences window
        if goagentMenuItem.state == NSOnState {
            preferencesWindow.title = "GoAgent Preferences"
        }else{
            preferencesWindow.title = "GoProxy Preferences"
        }
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        preferencesWindow.orderFrontRegardless()
        preferencesWindow.makeKeyWindow()
        preferencesTabView.selectTabViewItemWithIdentifier("About")
    }
    
    @IBAction func quitClicked(sender: NSMenuItem) {
        self.proxyService!.stopService()
        let xpcClient =  SMJobBlessXPCClient()
        xpcClient.toggleSystemProxy(false, usePAC: true, proxyPort:(self.proxyService?.proxyPort)!, pacPath: (self.proxyService?.pacPath)!)
        NSApplication.sharedApplication().terminate(self)
    }
    
    @IBAction func checkUpdate(sender: AnyObject) {
        if self.proxyService?.proxyName == "goagent"{
            // no update for goagent
            let alert = NSAlert()
            alert.messageText = "Information"
            alert.addButtonWithTitle("OK")
            alert.informativeText = "No update available for goagent. The project is no longer supported!"
            alert.beginSheetModalForWindow(self.preferencesWindow, completionHandler: nil)
            return
        }

        self.proxyService!.stopService()
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        updateWindow.orderFrontRegardless()
        updateWindow.center()
        updateWindow.makeKeyWindow()
        updateProgressLabel.stringValue = "Checking update on github ..."
        if !Reachability.isConnectedToNetwork(){
            updateProgressLabel.stringValue = "The Internet connection appears to be offline."
            return
        }
        
        //let goproxyDownload = Downloader(yourOwnObject: "goporxyUpdate")
        let session = NSURLSession.sharedSession()
        var downloadURL:NSURL = NSURL(string: "")!
        print("Checking update on github ...\n")
        self.downloadProgressIndicator.startAnimation(self)
        
        let url = NSURL(string: "https://api.github.com/repos/phuslu/goproxy-ci/releases/latest")
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "GET" //Or POST if that's what you need
        session.dataTaskWithRequest(request, completionHandler: { (returnData, response, error) -> Void in
            let strData = NSString(data: returnData!, encoding: NSUTF8StringEncoding)
            let lastestdict = strData!.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: ","))
            for item in lastestdict{
                if item.containsString("browser_download_url") && item.containsString("macosx_amd64"){
                    let downloadLinkString = item.stringByReplacingOccurrencesOfString("\"browser_download_url\":\"", withString: "").stringByReplacingOccurrencesOfString("\"}", withString: "")
                    downloadURL = NSURL(string: downloadLinkString)!
                }
            }
            
            self.updateProgressLabel.stringValue = "Downloading \(downloadURL.lastPathComponent! as String)"
            
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let goproxyDownload = Downloader(yourOwnObject: "goporxyUpdate")
                goproxyDownload.download(downloadURL)
                while goproxyDownload.progress <= 1 {
                    dispatch_sync(dispatch_get_main_queue()) {
                        // now update UI on main thread
                        self.downloadProgressIndicator.doubleValue = goproxyDownload.progress * 100
                        self.downloadProgressIndicator.animator()
                        
                        if goproxyDownload.progress == 1.0 {
                            // add 1 to escape from loop
                            goproxyDownload.progress += 1.0
                            self.updateProgressLabel.stringValue = "Download completed. Unpacking ... "
                            sleep(3)
                            let downloadedFilePath = (NSBundle.mainBundle().pathForResource("goproxy", ofType: "")?.stringByAppendingString("/" + downloadURL.lastPathComponent! as String))!
                            // shell to unzip to tar
                            let task = NSTask()
                            task.launchPath = "/usr/bin/bzip2"
                            task.arguments = ["-d", "-f", downloadedFilePath]
                            task.launch()
                            task.waitUntilExit()
                           
                            do {
                                // untar
                                let tarData = NSData(contentsOfFile: downloadedFilePath.stringByReplacingOccurrencesOfString(".bz2", withString: ""))
                                try NSFileManager.defaultManager().createFilesAndDirectoriesAtPath(NSBundle.mainBundle().pathForResource("goproxy", ofType: "")! + "/", withTarData: tarData, progress: nil)
                                
                                // delete origin
                                do {
                                    try NSFileManager.defaultManager().removeItemAtPath(downloadedFilePath.stringByReplacingOccurrencesOfString(".bz2", withString: ""))
                                } catch {
                                    print("unable to delete downloaded file")
                                }
                                print("delete downloaded file")
                                self.updateProgressLabel.stringValue = "Deleting cached file"
                                
                            }
                            catch {
                                self.updateProgressLabel.stringValue = "The downloaded file is damaged."
                                print("The download file is damaged.")
                            }
                            self.updateProgressLabel.stringValue = "Goproxy updated successfully."
                            self.proxyService!.restartService()
                            print("Goproxy updated successfully.\n")
                            
                        }
                    }
                    
                }

            }
        }).resume()
        return
    }
    
    func initProxySetting(){
        let proxies = SCDynamicStoreCopyProxies(nil)
        let proxyConfiguration: NSDictionary = proxies!
        var proxyEnable: Bool = false
        if let httpEnable = proxyConfiguration.valueForKey("HTTPEnable"){
            if httpEnable as! NSNumber == 1 {
                proxyEnable = true
                enableGlobalProxyMenuItem.state = NSOnState
                if self.proxyService!.proxyPort != String.init(proxyConfiguration.valueForKey("HTTPPort")!) || (self.proxyService!.listenAddr != "0.0.0.0" && self.proxyService!.listenAddr != String.init(proxyConfiguration.valueForKey("HTTPProxy")!)){
                    updateProxySetting()
                }
            }
        }
        if let httpsEnable = proxyConfiguration.valueForKey("HTTPSEnable"){
            if httpsEnable as! NSNumber == 1 {
                proxyEnable = true
                enableGlobalProxyMenuItem.state = NSOnState
                if self.proxyService!.proxyPort != String.init(proxyConfiguration.valueForKey("HTTPSPort")!) || (self.proxyService!.listenAddr != "0.0.0.0" && self.proxyService!.listenAddr != String.init(proxyConfiguration.valueForKey("HTTPSProxy")!)){
                    updateProxySetting()
                }
            }
        }
        if let proxyAutoConfigEnable = proxyConfiguration.valueForKey("ProxyAutoConfigEnable"){
            if proxyAutoConfigEnable as! NSNumber == 1 {
                proxyEnable = true
                enableAutoProxyMenuItem.state = NSOnState
                let configString = proxyConfiguration.valueForKey("ProxyAutoConfigURLString")! as! String
                if configString.containsString("://") && configString.containsString("/proxy.pac"){
                    let configString = configString[configString.rangeOfString("://")!.startIndex.advancedBy(3) ... configString.rangeOfString("/proxy.pac")!.startIndex.advancedBy(-1)]
                    _ = configString[configString.startIndex ... configString.rangeOfString(":")!.startIndex.advancedBy(-1)]
                    let pacPort = configString[configString.rangeOfString(":")!.startIndex.advancedBy(1) ... configString.endIndex.advancedBy(-1)]
                    if self.proxyService!.proxyPort != pacPort {
                        updateProxySetting()
                    }
                }
            }
        }
        if proxyEnable == false{
            // Make automatic proxy configuration default
            enableAutoProxyMenuItem.state = NSOnState
            updateProxySetting()
        }
    }
    
    func updateProxySetting(){
        var usePAC = false, setProxyOnOff:Bool
        if  enableAutoProxyMenuItem.state == NSOnState {
            setProxyOnOff = true
            usePAC = true
        }else if enableGlobalProxyMenuItem.state == NSOnState {
            setProxyOnOff = true
        }else{
            setProxyOnOff = false
        }
        let xpcClient =  SMJobBlessXPCClient()
        xpcClient.toggleSystemProxy(setProxyOnOff, usePAC:usePAC, proxyPort:(self.proxyService?.proxyPort)!, pacPath: (self.proxyService?.pacPath)!)
    }
}


