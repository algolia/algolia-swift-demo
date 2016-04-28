//
//  Copyright (c) 2016 Algolia
//  http://www.algolia.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import AFNetworking
import AlgoliaSearch
import Foundation
import SwiftyJSON


class AlgoliaManager {
    static let sharedInstance = AlgoliaManager()
    
    let moviesIndex: MirroredIndex
    let client: OfflineClient
    
    var imagesToLoad: [String] = []
    var imagesLoading = 0
    
    let imageQueue = dispatch_queue_create("Image download queue", DISPATCH_QUEUE_SERIAL)
    
    private init() {
        let apiKey = NSBundle.mainBundle().infoDictionary!["AlgoliaApiKey"] as! String
        client = OfflineClient(appID: "latency", apiKey: apiKey)
        // NOTE: Edit your license key in the build settings.
        let licenseKey = NSBundle.mainBundle().infoDictionary!["AlgoliaOfflineSdkLicenseKey"] as! String
        client.enableOfflineMode(licenseKey)
        moviesIndex = client.getIndex("movies")
        
        // Sync the index for offline use.
        moviesIndex.mirrored = true
        moviesIndex.dataSelectionQueries = [
            DataSelectionQuery(query: Query(parameters: ["filters": "year >= 2000"]), maxObjects: 500),
            DataSelectionQuery(query: Query(parameters: ["filters": "year < 2000"]), maxObjects: 100)
        ]
        moviesIndex.delayBetweenSyncs = 10 // FIXME: Raise the value for Release configuration
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(syncDidStart), name: MirroredIndex.SyncDidStartNotification, object: moviesIndex)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(syncDidFinish), name: MirroredIndex.SyncDidFinishNotification, object: moviesIndex)
    }
    
    func syncIfNeededAndPossible() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if appDelegate.reachability.isReachableViaWiFi() {
            moviesIndex.syncIfNeeded()
        }
    }

    // MARK: - Listeners

    @objc func syncDidStart(notification: NSNotification) {
        NSLog("Sync did start: %@", notification)
    }
    
    @objc func syncDidFinish(notification: NSNotification) {
        NSLog("Sync did finish: %@", notification)
        preloadImages()
    }
    
    private func preloadImages() {
        moviesIndex.browseMirror(Query()) {
            (content, error) in
            dispatch_async(self.imageQueue) {
                self.handleBrowse(content, error: error)
            }
        }
    }
    
    private func handleBrowse(content: [String: AnyObject]?, error: NSError?) {
        if error != nil {
            preloadImagesFinished()
            return
        }
        let cursor = content!["cursor"] as? String
        if let hits = content!["hits"] as? [[String: AnyObject]] {
            for hit in hits {
                let json = JSON(hit)
                let movie = MovieRecord(json: json)
                imagesToLoad.append(movie.image)
            }
            self.dequeueNext()
        }
        if cursor != nil {
            moviesIndex.browseMirrorFrom(cursor!) {
                (content, error) in
                dispatch_async(self.imageQueue) {
                    self.handleBrowse(content, error: error)
                }
            }
        }
    }
    
    private func dequeueNext() {
        // WARNING: Calls to this method must be serialized: use the `imageQueue` dispatch queue.
        if !imagesToLoad.isEmpty {
            let urlString = imagesToLoad.removeFirst()
            if let url = NSURL(string: urlString) {
                // Check if the image is already in the URL cache.
                let request = NSURLRequest(URL: url)
                let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request)
                if cachedResponse != nil {
                    NSLog("Image %@ already in cache", urlString)
                    dispatch_async(self.imageQueue) {
                        self.dequeueNext()
                    }
                } else {
                    NSLog("Loading image %@", urlString)
                    imagesLoading += 1
                    // Load the image. We don't care about the content now. We just want the URL cache to intercept it
                    // and store it on disk.
                    let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
                        (data, response, error) in
                        dispatch_async(self.imageQueue) {
                            self.handleImageDownloaded(data, response: response, error: error)
                        }
                    }
                    task.resume()
                }
            }
        } else if imagesLoading == 0 {
            preloadImagesFinished()
        }
    }
    
    private func handleImageDownloaded(data: NSData?, response: NSURLResponse?, error: NSError?) {
        imagesLoading -= 1
        dequeueNext()
    }
    
    private func preloadImagesFinished() {
        NSLog("Sync finished")
    }
}