//
//  SMJobBlessHelper.swift
//  SMJobBlessApp
//
//  Created by Deping Zheng on 5/24/16.
//  Copyright © 2016 Deping Zheng. All rights reserved.
//
import SystemConfiguration
import Cocoa
class SMJobBlessHelper: NSObject, SMJobBlessHelperProtocol, NSXPCListenerDelegate{
    private static let _sharedInstance = SMJobBlessHelper()
    private var listener:NSXPCListener
    
    private let kHelperToolMachServiceName = "com.ping99.proxyfactory.SMJobBlessHelper"
    
    var proxyTypes = ["PROXY"]
    var proxyPort:Int32 = 99
    var previousDeviceProxies:NSMutableDictionary = NSMutableDictionary()
    
    class func GetSMJobBlessHelperTool() -> SMJobBlessHelper{
        return _sharedInstance
    }
    
    override init(){
        // Set up our XPC listener to handle requests on our Mach service.
        self.listener = NSXPCListener(machServiceName:kHelperToolMachServiceName)
        super.init()
        self.listener.delegate = self

    }

    func run(){
        // Tell the XPC listener to start processing requests.
        // Resume the listener. At this point, NSXPCListener will take over the execution of this service, managing its lifetime as needed.
        self.listener.resume()
        // Run the run loop forever.
        NSRunLoop.currentRunLoop().run()
        
    }
    
    // Called by our XPC listener when a new connection comes in.  We configure the connection
    // with our protocol and ourselves as the main object.
    func listener(listener:NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        print("new incoming connection")
        //#pragma unused(listener)
        // Configure the new connection and resume it. Because this is a singleton object, we set 'self' as the exported object and configure the connection to export the 'SMJobBlessHelperProtocol' protocol that we implement on this object.
        newConnection.exportedInterface = NSXPCInterface(withProtocol:SMJobBlessHelperProtocol.self)
        newConnection.exportedObject = self;
        newConnection.resume()
        return true
    }
    
    func proxiesPathOfDevice(devId:NSString) -> NSString {
        let path = "/\(kSCPrefNetworkServices)/\(devId)/\(kSCEntNetProxies)"
        return path as NSString
    }
    

    func modifyPrefProxiesDictionary(inout proxies: Dictionary<NSObject,AnyObject>, withProxyEnabled enabled:Bool, usePAC:Bool, proxyPort:String, pacPath:String){
        // Disable all proxies
        proxies.updateValue(NSNumber(int:0), forKey:kCFNetworkProxiesHTTPEnable as NSString)
        proxies.updateValue(NSNumber(int:0), forKey:kCFNetworkProxiesHTTPSEnable as NSString)
        proxies.updateValue(NSNumber(int:0), forKey:kCFNetworkProxiesProxyAutoConfigEnable as NSString)
        proxies.updateValue(NSNumber(int:0), forKey:kCFNetworkProxiesSOCKSEnable as NSString)
        
        if (enabled) {
            if (usePAC) {
                proxies.updateValue(pacPath, forKey:kCFNetworkProxiesProxyAutoConfigURLString as NSString)
                proxies.updateValue(NSNumber(int:1), forKey:kCFNetworkProxiesProxyAutoConfigEnable as NSString)
                
            } else if (proxyTypes.indexOf("PROXY") != NSNotFound) {
                proxies.updateValue(NSNumber(int:Int32(proxyPort)!), forKey:kCFNetworkProxiesHTTPPort as NSString)
                proxies.updateValue("127.0.0.1", forKey:kCFNetworkProxiesHTTPProxy as NSString)
                proxies.updateValue(NSNumber(int:1), forKey:kCFNetworkProxiesHTTPEnable as NSString)
                proxies.updateValue(NSNumber(int:Int32(proxyPort)!), forKey:kCFNetworkProxiesHTTPSPort as NSString)
                proxies.updateValue("127.0.0.1", forKey:kCFNetworkProxiesHTTPSProxy as NSString)
                proxies.updateValue(NSNumber(int:1), forKey:kCFNetworkProxiesHTTPSEnable as NSString)
                
            } else if (proxyTypes.indexOf("SOCKS") != NSNotFound ||
                proxyTypes.indexOf("SOCKS5") != NSNotFound) {
                proxies.updateValue(NSNumber(int:Int32(proxyPort)!), forKey:kCFNetworkProxiesSOCKSPort as NSString)
                proxies.updateValue("127.0.0.1", forKey:kCFNetworkProxiesSOCKSProxy as NSString)
                proxies.updateValue(NSNumber(int:1), forKey:kCFNetworkProxiesSOCKSEnable as NSString)
            }
        }
        
    }
    
    
    func toggleSystemProxy(useProxy:Bool, usePAC:Bool, proxyPort:String, pacPath:String, withReply reply:(response:String)->Void) {
        var authRef:AuthorizationRef = nil
        let authFlags: AuthorizationFlags = [
            .Defaults,
            .ExtendRights,
            .InteractionAllowed,
            .PreAuthorize
        ]
        _ = AuthorizationCreate(nil, nil, authFlags, &authRef)
        
        if (authRef == nil) {
            print("No authorization has been granted to modify network configuration")
            reply(response: "No authorization has been granted to modify network configuration")
            return
        }
       
        let prefRef: SCPreferencesRef  = SCPreferencesCreateWithAuthorization(nil, "Proxy-Factory" as CFString, nil, authRef)!
        
        let sets:NSDictionary = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices) as! NSDictionary
        // Set proxies for AirPort and Ethernet
        if (previousDeviceProxies.count == 0) {
            for key in sets.allKeys {
                let dict = sets.objectForKey(key)
                for item in (dict?.allKeys)!{
                    if item as! String == "Interface"{
                        let interface = dict!.valueForKeyPath("Interface")! as! NSDictionary
                        for interfaceKey in interface.allKeys{
                            if interfaceKey as! String == "Hardware"{
                                if let hardware = interface.valueForKey("Hardware"){
                                    if (hardware.isEqualToString("AirPort") || hardware.isEqualToString("Ethernet")) {
                                        let proxies = dict!.objectForKey(kSCEntNetProxies)
                                        if (proxies != nil) {
                                            previousDeviceProxies.setObject(proxies!.mutableCopy(), forKey:key as! NSString)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if (useProxy) {
            // Enable proxy
            for deviceId in previousDeviceProxies.allKeys {
                var proxies  = SCPreferencesPathGetValue(prefRef, self.proxiesPathOfDevice(deviceId as! NSString ))! as Dictionary?
                modifyPrefProxiesDictionary(&proxies!, withProxyEnabled: true, usePAC:usePAC, proxyPort: proxyPort, pacPath: pacPath)
                SCPreferencesPathSetValue(prefRef, self.proxiesPathOfDevice(deviceId as! CFStringRef as String), proxies!)
            }
            
        } else {
            for deviceId in previousDeviceProxies.allKeys {
                // Disable previous proxy setting with SOCKS or PAC
                var dict = (previousDeviceProxies.objectForKey(deviceId))! as! Dictionary<NSObject, AnyObject>
                self.modifyPrefProxiesDictionary(&dict, withProxyEnabled:false, usePAC:usePAC, proxyPort: proxyPort, pacPath: pacPath)
                SCPreferencesPathSetValue(prefRef, self.proxiesPathOfDevice(deviceId as! CFStringRef as String),dict)
            }
            previousDeviceProxies.removeAllObjects()
        }
        
        SCPreferencesCommitChanges(prefRef)
        SCPreferencesApplyChanges(prefRef)
        SCPreferencesSynchronize(prefRef)
    }

    func killProcess(onListenPort port:Int){
        var script = "set grepResults to do shell script \"sudo lsof -i:" + String(port) + " | grep -v grep | awk '{ print $2 }'\" with administrator privileges\n"
        script += "set grepResultsList to paragraphs of grepResults\n"
        script += "if (count of items of grepResultsList) ≥ 2 then\n"
        script += "set pidList to {}\n"
        script += "repeat with i from 1 to count of items of grepResultsList\n"
        script += "if item i of grepResultsList is not in pidList then\n"
        script += "copy item i of grepResultsList to end of pidList\n"
        script += "if item i of grepResultsList is not \"PID\" then\n"
        script += "do shell script \"sudo kill \" & item i of grepResultsList with administrator privileges\n"
        script += "end if\n"
        script += "end if\n"
        script += "end repeat\n"
        script += "end if\n"
        let appScript: NSAppleScript = NSAppleScript(source:script)!
        var error: NSDictionary?
        appScript.executeAndReturnError(&error)
    }
    
    func installRootCertificate(certificatePath:String, withReply reply:(response:String)->Void) -> Void{
        // Search and delete certificate in keychain if there is a certificate with same name
        // Default is GoProxy
        var certificateName = "GoProxy"
        if certificatePath.containsString("goagent"){
            certificateName = "GoAgent"
        }
        let query = [
            kSecClass as String: kSecClassCertificate as String,
            kSecAttrLabel as String: certificateName,
            kSecMatchLimit as String: kSecMatchLimitOne as String,
            kSecReturnRef as String: true
        ]
        var result: SecKeychainItemRef?
        let status = withUnsafeMutablePointer (&result) { SecItemCopyMatching (query, UnsafeMutablePointer ($0)) }
        if status == errSecSuccess{
            SecKeychainItemDelete(result!)
        } else {
            NSLog("No certificate with same label in keychain")
        }
        
        // Import new certificate
        var script:String = ""
        script += "do shell script \"sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain " + "'" + certificatePath + "'\"" + " with administrator privileges"
        var error: NSDictionary?
        if let appleScript: NSAppleScript = NSAppleScript(source:script){
            if let output: NSAppleEventDescriptor = appleScript.executeAndReturnError(&error){
                print(output.stringValue)
                reply(response: "Succeed!")
            }else if (error != nil){
                reply(response: "error: \(error)!")
            }
        }
    }
}
