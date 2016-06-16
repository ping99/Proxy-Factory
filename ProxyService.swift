//
//  ProxyService.swift
//  Proxy Factory
//
//  Created by Deping Zheng on 5/21/16.
//  Copyright © 2016 Deping Zheng. All rights reserved.
//

import Foundation
import Cocoa

class ProxyService{
    var proxyName: String = ""
    var listenAddr: String = ""
    var previousProxyPort: String = ""
    var proxyPort: String = "" {
        willSet{
            self.previousProxyPort = self.proxyPort
        }
    }
    
    var previousPacPort = ""
    var pacPort: String = "" {
        willSet{
            self.previousPacPort = self.pacPort
        }
    }
    
    var pacPath: String{
        return "http://127.0.0.1:\(self.pacPort.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " ")))/proxy.pac"
    }
    var certificatePath: String = ""
    var appIDs:[AnyObject] = []
    var password: String = ""
    var ipList:[AnyObject] = []
    
    var task: NSTask
    var currentDirectoryPath: String = ""
    var launchPath: String = ""
    var arguments:[String] = []
    
    var logScrollView: NSScrollView

    init(proxyName:String, logScrollView:NSScrollView){
        self.task = NSTask()
        self.proxyName = proxyName
        self.logScrollView = logScrollView
        
        if proxyName == "goproxy"{
            goproxyInitialize()
        }else if proxyName == "goagent"{
            goagentInitialize()
        }else{
            assertionFailure("Required service not available.")
        }
    }
    
    func goproxyInitialize(){
        self.currentDirectoryPath = NSBundle.mainBundle().pathForResource("goproxy", ofType: "")!
        self.launchPath = self.currentDirectoryPath + "/goproxy"
        self.arguments = []
        
        if let certificatePath = NSBundle.mainBundle().pathForResource("GoProxy", ofType: ".crt", inDirectory: "goproxy"){
            print("certificatePath")
            self.certificatePath = certificatePath
            
        }
        
        let httpproxyJsonPath = NSBundle.mainBundle().pathForResource("httpproxy", ofType: ".json", inDirectory: "goproxy")!
        var strData = ""
        do {
            let str = try String(contentsOfFile: httpproxyJsonPath, encoding: NSUTF8StringEncoding)
            str.enumerateLines({
                (line: String, inout stop: Bool) -> () in
                if line.containsString("//"){
                }else{
                    strData += line
                }
            })
        }catch{
            assertionFailure("Failed to load httpproxy.json")
        }
        
        let httpproxyData: NSData? =  strData.dataUsingEncoding(NSUTF8StringEncoding)
        var httpproxyJson = JSON(data: httpproxyData!)
        
        self.listenAddr = httpproxyJson["Default"]["Address"].stringValue.componentsSeparatedByString(":").first!
        self.proxyPort = httpproxyJson["Default"]["Address"].stringValue.componentsSeparatedByString(":").last!
        self.pacPort = self.proxyPort
        
        // Parse gae.user.json
        let gaeuserJsonPath = NSBundle.mainBundle().pathForResource("gae.user", ofType: ".json", inDirectory: "goproxy")!
        let gaeuserJsonData: NSData? =  NSData(contentsOfFile: gaeuserJsonPath)
        let gaeuserJson = JSON(data: gaeuserJsonData!)
        self.appIDs = gaeuserJson["AppIDs"].arrayObject!
        self.password = gaeuserJson["Password"].stringValue
        self.ipList = gaeuserJson["HostMap"]["google_hk"].arrayObject!
    }
    
    func goagentInitialize(){
        self.currentDirectoryPath = NSBundle.mainBundle().pathForResource("local", ofType: "",inDirectory:"goagent")!
        let python27_8_path = "/usr/local/opt/pyenv/versions/2.7.8/bin/python"
        if NSFileManager.defaultManager().fileExistsAtPath(python27_8_path){
            self.launchPath = "/usr/local/opt/pyenv/versions/2.7.8/bin/python"
        } else{
            self.launchPath = "/usr/bin/python"
        }
        self.arguments = [self.currentDirectoryPath + "/proxy.py"]
        self.certificatePath = NSBundle.mainBundle().pathForResource("CA", ofType: ".crt", inDirectory: "goagent/local")!
        
        let goagentFilePath = NSBundle.mainBundle().pathForResource("proxy.user", ofType: ".ini", inDirectory: "goagent/local")!
        var goagentString = ""
        do
        {
            goagentString = try String(contentsOfFile: goagentFilePath, encoding: NSUTF8StringEncoding)
        }
        catch
        {
            goagentString = ""
        }
        var currentParagraphForSetting = ""
        for line in goagentString.componentsSeparatedByString("\n"){
            if line.hasPrefix("[listen]"){
                currentParagraphForSetting = "[listen]"
            }
            if line.hasPrefix("[gae]"){
                currentParagraphForSetting = "[gae]"
            }
            if line.hasPrefix("[iplist]"){
                currentParagraphForSetting = "[iplist]"
            }
            if line.hasPrefix("[pac]"){
                currentParagraphForSetting = "[pac]"
            }
            if line.hasPrefix("[proxy]"){
                currentParagraphForSetting = "[proxy]"
            }
            

            if currentParagraphForSetting == "[listen]" && line.hasPrefix("ip ="){
                self.listenAddr = line.stringByReplacingOccurrencesOfString("ip = ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\n\r\t"))
            }
            
            if currentParagraphForSetting == "[listen]" && line.hasPrefix("port = "){
                self.proxyPort = line.stringByReplacingOccurrencesOfString("port = ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\n\r\t"))
            }
            
            if currentParagraphForSetting == "[pac]" && line.hasPrefix("port = "){
                self.pacPort = line.stringByReplacingOccurrencesOfString("port = ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\n\r\t"))
            }
            
            if currentParagraphForSetting == "[gae]" && line.hasPrefix("appid = "){
                self.appIDs = line.stringByReplacingOccurrencesOfString("appid = ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\n\r\t")).componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "|"))
            }
            
            if currentParagraphForSetting == "[gae]" && line.hasPrefix("password = "){
                self.password = line.stringByReplacingOccurrencesOfString("password = ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\n\r\t"))
            }
            
            if currentParagraphForSetting == "[iplist]" && line.hasPrefix("google_hk = "){
                self.ipList = line.stringByReplacingOccurrencesOfString("google_hk = ", withString: "").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\n\r\t")).componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "|"))
            }
        }
    }
    
    func startService() {
        // Set up task
        self.task = NSTask()
        self.task.currentDirectoryPath = self.currentDirectoryPath
        self.task.launchPath = self.launchPath
        self.task.arguments = self.arguments
        
        // Pipe the standard out to an NSPipe, and set it to notify us when it gets data
        let outPipe = NSPipe()
        self.task.standardError = outPipe
        let fileHandle = outPipe.fileHandleForReading
        fileHandle.waitForDataInBackgroundAndNotify()
        
        // Set up the observer function
        let notificationCenter = NSNotificationCenter.defaultCenter()
        var obs1 : NSObjectProtocol!
        obs1 = notificationCenter.addObserverForName(NSFileHandleDataAvailableNotification,object: fileHandle, queue: nil) {
                    notification -> Void in
                    let data = fileHandle.availableData
                    if data.length > 1 {
                        // Append output to scrollview
                        if let stdOutString = String(data: data, encoding: NSUTF8StringEncoding) {
                            self.logScrollView.documentView!.textStorage!!.mutableString.appendString(stdOutString)
                            // Check port conflict
                            if stdOutString.containsString("address already in use"){
                                print("The proxy port is already in use by other processes. Try to kill them.")
                                self.stopService()
                                self.releasePort()
                                sleep(2)
                                self.startService()
                            }

                            if self.logScrollView.documentView!.textStorage!!.size().height > 999{
                                self.logScrollView.documentView!.textStorage!!.mutableString.deleteCharactersInRange(NSRange(location: 0, length: self.logScrollView.documentView!.textStorage!!.mutableString.length - stdOutString.characters.count))
                            }
                           
                            fileHandle.waitForDataInBackgroundAndNotify()
                            // Scroll to bottom of NSScrollview
                            let scrollLocation = NSPoint(x: 0, y: self.logScrollView.documentView!.frame.size.height - self.logScrollView.contentView.frame.size.height)
                            self.logScrollView.contentView.scrollToPoint(scrollLocation)
                            self.logScrollView.reflectScrolledClipView(self.logScrollView.contentView)
                        } else {
                                    print("EOF on stdout from process")
                                    NSNotificationCenter.defaultCenter().removeObserver(obs1)
                                }
                    }
                }
        
        var obs2 : NSObjectProtocol!
        obs2 = notificationCenter.addObserverForName(NSTaskDidTerminateNotification, object: self.task, queue: nil) {
                    notification -> Void in
                    print("Proxy terminated")
                    NSNotificationCenter.defaultCenter().removeObserver(obs2)
                }

        self.task.launch()
        /* another way to handle output
        let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(fileHandle.fileDescriptor), 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
        
        dispatch_source_set_event_handler(source, {
            let dataBuffer = malloc(4096)
            var readResult:ssize_t = 0
            repeat{
                errno = 0
                readResult = read(fileHandle.fileDescriptor, dataBuffer, 4096)
            } while (readResult == -1 && errno == EINTR)            
            assert(readResult >= 0)
            if (readResult > 0)
            {
                //AppKit UI should only be updated from the main thread
                dispatch_async(dispatch_get_main_queue(),{
                    let stdOutString = NSString.init(bytesNoCopy: dataBuffer, length: readResult, encoding: NSUTF8StringEncoding, freeWhenDone: true)
                    print(stdOutString)
                    let stdOutAttributedString = NSAttributedString.init(string:stdOutString as! String)
                    self.logScrollView.documentView?.textStorage!!.appendAttributedString(stdOutAttributedString)
                    })
            }
            else{free(dataBuffer)}
            })
        dispatch_resume(source)
         */
    }
    
    func stopService() {
        if self.task.running {
            self.task.terminate()
        }
    }
    
    func restartService(){
        if self.task.running {
            self.task.terminate()
        }
        startService()
    }
    
    func releasePort() {
        let client = SMJobBlessXPCClient()
        client.killProcess(onListenPort: Int(self.proxyPort)!)
    }
    
    func installCertificate() {
        let client = SMJobBlessXPCClient()
        client.installRootCertificate(self.certificatePath)
    }
    
    func updateSettingToFile(){
        // Inner function for updating proxy.pac
        func updatePACFile(inDirectory directory:String){
            let pacFilePath = NSBundle.mainBundle().pathForResource("proxy", ofType: ".pac", inDirectory: directory)!
            var pacString = ""
            do
            {
                pacString = try String(contentsOfFile: pacFilePath, encoding: NSUTF8StringEncoding)
            }
            catch
            {
                pacString = ""
            }
            
            var newPacString = ""
            
            for line in pacString.componentsSeparatedByString("\n"){
                var newLine = ""
                if line.containsString(previousProxyPort){
                    newLine = line.stringByReplacingOccurrencesOfString(previousProxyPort, withString: self.proxyPort) + "\n"
                    newPacString += newLine
                }else if line.containsString(previousPacPort){
                    newLine = line.stringByReplacingOccurrencesOfString(previousPacPort, withString: self.proxyPort) + "\n"
                    newPacString += newLine
                }else{
                    
                    newPacString += line
                    newPacString +=  "\n"
                }
            }
            do{
                try newPacString.writeToFile(pacFilePath, atomically: true, encoding:   NSUTF8StringEncoding)
            }
            catch{
                print("Unable to save settings to proxy.pac!")
            }
        }
        
        if self.proxyName == "goproxy" {
            // Write settings to goproxy config file
            // Update gae.user.json
            let gaeUserJsonPath = NSBundle.mainBundle().pathForResource("gae.user", ofType: ".json", inDirectory: "goproxy")!
            let gaeUserJsonData: NSData? =  NSData(contentsOfFile: gaeUserJsonPath)
            var gaeUserJson = JSON(data: gaeUserJsonData!)
            gaeUserJson ["HostMap"]["google_cn"].arrayObject = self.ipList
            gaeUserJson ["HostMap"]["google_hk"].arrayObject = self.ipList
            gaeUserJson ["HostMap"]["google_talk"].arrayObject = self.ipList
            gaeUserJson["AppIDs"].arrayObject = self.appIDs
            gaeUserJson["Password"].stringValue = self.password
            // Write to file
            let data = gaeUserJson.rawString()!.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            data.writeToFile(gaeUserJsonPath, atomically: true)
            
            // Update httpproxy.json
            let httpproxyJsonPath = NSBundle.mainBundle().pathForResource("httpproxy", ofType: ".json", inDirectory: "goproxy")!
            var strData = ""
            do {
                let str = try String(contentsOfFile: httpproxyJsonPath, encoding: NSUTF8StringEncoding)
                str.enumerateLines({
                    (line: String, inout stop: Bool) -> () in
                    if line.containsString("//"){
                    }else{
                        strData += line
                    }
                })
                
            }catch{
                print("failed to load httpproxy.json")
                return
            }
            let httpproxyJsonData: NSData? =  strData.dataUsingEncoding(NSUTF8StringEncoding)//NSData(contentsOfFile: mainFilePath)
            var httpproxyJson = JSON(data: httpproxyJsonData!)
            httpproxyJson["Default"]["Address"].stringValue = self.listenAddr + ":" + self.proxyPort
            // Write to file
            let httpproxyData = httpproxyJson.rawString()!.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            httpproxyData.writeToFile(httpproxyJsonPath, atomically: true)
            
            // Update PAC file
            updatePACFile(inDirectory: "goproxy")
            
        }else if self.proxyName == "goagent"{
            // Write settings to goagent config file
            // update proxy.user.ini
            let goagentFilePath = NSBundle.mainBundle().pathForResource("proxy.user", ofType: ".ini", inDirectory: "goagent/local")!
            var goagentString = ""
            do
            {
                goagentString = try String(contentsOfFile: goagentFilePath, encoding: NSUTF8StringEncoding)
            }
            catch
            {
                goagentString = ""
            }
    
            var newGoagentString = ""
            var currentParagraphForSetting = ""
            for line in goagentString.componentsSeparatedByString("\n"){
                if line.hasPrefix("[listen]"){
                    currentParagraphForSetting = "[listen]"
                }
                if line.hasPrefix("[gae]"){
                    currentParagraphForSetting = "[gae]"
                }
                if line.hasPrefix("[iplist]"){
                    currentParagraphForSetting = "[iplist]"
                }
                if line.hasPrefix("[pac]"){
                    currentParagraphForSetting = "[pac]"
                }
                if line.hasPrefix("[proxy]"){
                    currentParagraphForSetting = "[proxy]"
                }
    
                var newLine = line
                if currentParagraphForSetting == "[listen]" && line.hasPrefix("ip = "){
                    newLine = "ip = " + self.listenAddr
                }
                
                if (currentParagraphForSetting == "[listen]") && line.hasPrefix("port = "){
                    newLine = "port = " + self.proxyPort
                }
                
                if (currentParagraphForSetting == "[pac]" && line.hasPrefix("port = ")){
                    newLine = "port = " + self.pacPort
                }

                if currentParagraphForSetting == "[gae]" && line.hasPrefix("appid = "){
                    newLine = "appid = "
                    for appID in self.appIDs{
                        newLine += appID as! String
                        if appID as! String != (self.appIDs.last as! String){
                            newLine += "|"
                        }
                    }
                }
                
                if currentParagraphForSetting == "[iplist]" && line.hasPrefix("google_hk = "){
                    newLine = "google_hk = "
                    for ip in self.ipList{
                        newLine += ip as! String
                        if ip as! String != self.ipList.last as! String{
                            newLine += "|"
                        }
                    }
                }
                
                if currentParagraphForSetting == "[iplist]" && line.hasPrefix("google_cn = "){
                    newLine = "google_hk = "
                    for ip in self.ipList{
                        newLine += ip as! String
                        if ip as! String != self.ipList.last as! String{
                            newLine += "|"
                        }
                    }
                }
                
                newGoagentString += newLine + "\n"
                newLine = ""
            }
            
            do{
                try newGoagentString.writeToFile(goagentFilePath, atomically: true, encoding: NSUTF8StringEncoding)
            }
            catch{
                print("Unable to save settings to proxy.user.ini!")
            }
            
            // update proxy.pac
            updatePACFile(inDirectory: "goagent/local")
        }

    }
}