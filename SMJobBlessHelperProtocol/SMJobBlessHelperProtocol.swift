//
//  SMJobBlessHelperInterface.swift
//  SMJobBlessApp
//
//  Created by Deping Zheng on 5/24/16.
//  Copyright © 2016 Deping Zheng. All rights reserved.
//

import Foundation
@objc(SMJobBlessHelperProtocol)
protocol SMJobBlessHelperProtocol{
    func toggleSystemProxy(useProxy:Bool, usePAC:Bool, proxyPort:String, pacPath:String)
    func killProcess(onListenPort port:Int)
    func installRootCertificate(certificatePath:String, withReply reply:(response:String)->Void) -> Void

}
    

