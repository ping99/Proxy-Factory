//
//  SMJobBlessClient.swift
//  SMJobBlessApp
//
//  Created by Deping Zheng on 5/25/16.
//  Copyright © 2016 Deping Zheng. All rights reserved.
//

import Foundation
import ServiceManagement
class SMJobBlessXPCClient{
    
    var kHelperToolName:String = "com.ping99.proxyfactory.SMJobBlessHelper"
    
    var xpcServiceConnection: NSXPCConnection?
    private var authRef:AuthorizationRef = nil
    
    init(){
        if self.isNeedInstallHelperTool(){
            installHelperTool()
        }
        self.connectToXPCService()
    }
    
    func installHelperTool(){
        /* Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper). */
        let authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value:UnsafeMutablePointer<Void>(bitPattern: 0), flags: 0)
        var authItems = [authItem]
        var authRights:AuthorizationRights = AuthorizationRights(count: UInt32(authItems.count), items:&authItems)
        
        let authFlags: AuthorizationFlags = [
            .Defaults,
            .ExtendRights,
            .InteractionAllowed,
            .PreAuthorize
        ]
        
        let status = AuthorizationCreate(&authRights, nil, authFlags, &self.authRef)
        var error = NSError.init(domain: NSOSStatusErrorDomain, code: 0, userInfo: nil)
        if (status != errAuthorizationSuccess){
            error = NSError(domain:NSOSStatusErrorDomain, code:Int(status), userInfo:nil)
            NSLog("Authorization error: \(error)")
        }else{
            /* This does all the work of verifying the helper tool against the application
             * and vice-versa. Once verification has passed, the embedded launchd.plist
             * is extracted and placed in /Library/LaunchDaemons and then loaded. The
             * executable is placed in /Library/PrivilegedHelperTools.
             */
            var cfError: Unmanaged<CFError>? = nil
            if !SMJobBless(kSMDomainSystemLaunchd, kHelperToolName as CFString, authRef, &cfError) {
                let blessError = cfError!.takeRetainedValue() as NSError
                NSLog("Error: \(blessError)")
            }else{
                NSLog("\(kHelperToolName) installed successfully")
            }
        }
    }
    
    func connectToXPCService(){
        // Create a connection to the service
        assert(NSThread.isMainThread())
        if (self.xpcServiceConnection == nil){
            self.xpcServiceConnection = NSXPCConnection(machServiceName:kHelperToolName, options:NSXPCConnectionOptions.Privileged)//NSXPCConnection.init(serviceName: kHelperToolName)
            self.xpcServiceConnection!.remoteObjectInterface = NSXPCInterface(withProtocol:SMJobBlessHelperProtocol.self)
            self.xpcServiceConnection!.invalidationHandler = {
                // If the connection gets invalidated then, on the main thread, nil out our
                // reference to it.  This ensures that we attempt to rebuild it the next time around.
                self.xpcServiceConnection!.invalidationHandler = nil
                NSOperationQueue.mainQueue().addOperationWithBlock(){
                    self.xpcServiceConnection = nil
                    NSLog("connection invalidated\n")
                }
            }
        }
        self.xpcServiceConnection?.resume()
    }

    func isNeedInstallHelperTool() -> Bool {
        let installedHelperJobDict = SMJobCopyDictionary(kSMDomainSystemLaunchd,kHelperToolName)
        if installedHelperJobDict == nil {
            NSLog( "Helper tool \(kHelperToolName) has not been installed")
            return true
        }

        if let installedHelperJobData = installedHelperJobDict.takeUnretainedValue() as NSDictionary?{
            var installedVersion = 0,currentVersion:Int
            // Helper tool in place, check installed version
            let installedPath = installedHelperJobData.objectForKey("ProgramArguments")!.objectAtIndex(0)
            let installedPathURL = NSURL(fileURLWithPath: installedPath as! String) as CFURL
            if let installedInfoPlist:NSDictionary = CFBundleCopyInfoDictionaryForURL(installedPathURL){
                let installedBundleVersion = installedInfoPlist.objectForKey("CFBundleVersion")
                installedVersion = (installedBundleVersion?.integerValue)!
                //NSLog( "installedVersion: \(installedVersion)")
            }
            
            let currentHelperToolURL = NSBundle.mainBundle().bundleURL.URLByAppendingPathComponent("Contents/Library/LaunchServices/" + kHelperToolName)
            let currentInfoPlist:NSDictionary = CFBundleCopyInfoDictionaryForURL(currentHelperToolURL)
            let currentBundleVersion = currentInfoPlist.objectForKey("CFBundleVersion")
            currentVersion = (currentBundleVersion?.integerValue)!
            //NSLog( "currentVersion: \(currentVersion)")
            if ( currentVersion == installedVersion )
            {
                return false
            }else{
                return true
            }
        }else{
            NSLog( "Can not get installed helper tool information.")
        }
    }
    
    
    func toggleSystemProxy(useProxy:Bool, usePAC:Bool, proxyPort:String, pacPath:String){
        self.xpcServiceConnection!.remoteObjectProxy.toggleSystemProxy(useProxy, usePAC: usePAC, proxyPort: proxyPort, pacPath: pacPath)
    }
    
    func killProcess(onListenPort port:Int){
        self.xpcServiceConnection!.remoteObjectProxy.killProcess(onListenPort: port)
    }
    
     func installRootCertificate(certificatePath:String) -> Void{
        self.xpcServiceConnection!.remoteObjectProxy.installRootCertificate(certificatePath, withReply:{ response in
            NSOperationQueue.mainQueue().addOperationWithBlock(){
                if (!response.isEmpty){
                    // Display notifications
                    let notification:NSUserNotification = NSUserNotification()
                    notification.title = "Proxy Factory"
                    notification.subtitle = "Import \(certificatePath.componentsSeparatedByString("/").last!) to system"
                    notification.informativeText = response
                    notification.soundName = NSUserNotificationDefaultSoundName
                    notification.deliveryDate = NSDate(timeIntervalSinceNow: 1)
                    let notificationCenter:NSUserNotificationCenter = NSUserNotificationCenter.defaultUserNotificationCenter()
                    notificationCenter.scheduleNotification(notification)
                }else{
                    NSLog("No reply received from helper tool.")
                }
            }
            self.xpcServiceConnection!.invalidate()
        })
    }    
}