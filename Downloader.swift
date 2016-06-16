//
//  Downloader.swift
//  Proxy Factory
//
//  Thanks someone who shared the code on Internet.
//

import Foundation
class Downloader : NSObject, NSURLSessionDownloadDelegate
{
    var url : NSURL?
    var progress : Double
    // will be used to do whatever is needed once download is complete
    var yourOwnObject : NSObject?
    
    init(yourOwnObject : NSObject)
    {
        self.progress = 0
        self.yourOwnObject = yourOwnObject
    }
    
    //is called once the download is complete
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL)
    {
        //copy downloaded data to your documents directory with same names as source file
        //let documentsUrl =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
        let destinationUrl = NSBundle.mainBundle().URLForResource("goproxy", withExtension: "")!.URLByAppendingPathComponent(url!.lastPathComponent!)
        let dataFromURL = NSData(contentsOfURL: location)
        dataFromURL!.writeToURL(destinationUrl, atomically: true)
        print("Download completed.")
        
        //now it is time to do what is needed to be done after the download
        //yourOwnObject!.callWhatIsNeeded()
    }
    
    //this is to track progress
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print(self.progress)
    }
    
    // if there is an error during download this will be called
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?)
    {
        if(error != nil)
        {
            //handle the error
            print("Download completed with error: \(error!.localizedDescription)");
        }
    }
    
    //method to be called to download
    func download(url: NSURL)
    {
        self.url = url
        print("Downloading \(url) ...")
        //download identifier can be customized. I used the "ulr.absoluteString"
        let sessionConfig = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(url.absoluteString)
        let session = NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let task = session.downloadTaskWithURL(url)
        task.resume()
    }
}