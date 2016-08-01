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


private let DEFAULTS_KEY_MIRRORED       = "algolia.mirrored"
private let DEFAULTS_KEY_STRATEGY       = "algolia.requestStrategy"
private let DEFAULTS_KEY_TIMEOUT        = "algolia.offlineFallbackTimeout"


class AlgoliaManager: NSObject {
    /// The singleton instance.
    static let sharedInstance = AlgoliaManager()

    let client: OfflineClient
    var actorsIndex: MirroredIndex
    var moviesIndex: MirroredIndex
    
    var shouldLoadImages = true
    var imagesToLoad: [NSURL] = []
    var imagesLoading = 0
    
    let imageQueue = dispatch_queue_create("Image download queue", DISPATCH_QUEUE_SERIAL)

    // TODO: Should be moved to a default value in `Client` class.
    var requestStrategy: MirroredIndex.Strategy {
        get {
            return moviesIndex.requestStrategy
        }
        set {
            for index in [ actorsIndex, moviesIndex ] {
                index.requestStrategy = newValue
            }
            NSUserDefaults.standardUserDefaults().setInteger(newValue.rawValue, forKey: DEFAULTS_KEY_STRATEGY)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    var offlineFallbackTimeout: NSTimeInterval {
        get {
            return moviesIndex.offlineFallbackTimeout
        }
        set {
            for index in [ actorsIndex, moviesIndex ] {
                index.offlineFallbackTimeout = newValue
            }
            NSUserDefaults.standardUserDefaults().setDouble(newValue, forKey: DEFAULTS_KEY_TIMEOUT)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    var mirrored: Bool {
        get {
            return moviesIndex.mirrored
        }
        set {
            for index in [ actorsIndex, moviesIndex ] {
                index.mirrored = newValue
            }
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: DEFAULTS_KEY_MIRRORED)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    dynamic var syncing: Bool = false
    
    private override init() {
        let apiKey = NSBundle.mainBundle().infoDictionary!["AlgoliaApiKey"] as! String
        client = OfflineClient(appID: "latency", apiKey: apiKey)
        // NOTE: Edit your license key in the build settings.
        let licenseKey = NSBundle.mainBundle().infoDictionary!["AlgoliaOfflineSdkLicenseKey"] as! String
        client.enableOfflineMode(licenseKey)
        actorsIndex = client.getIndex("actors")
        moviesIndex = client.getIndex("movies")
        
        // Sync the indices for offline use.
        let delayBetweenSyncs: NSTimeInterval = 30 * 60 // 30 minutes
        moviesIndex.mirrored = true
        moviesIndex.dataSelectionQueries = [
            DataSelectionQuery(query: Query(parameters: ["filters": "year >= 2000"]), maxObjects: 500),
            DataSelectionQuery(query: Query(parameters: ["filters": "year < 2000"]), maxObjects: 100)
        ]
        moviesIndex.delayBetweenSyncs = delayBetweenSyncs

        actorsIndex.mirrored = true
        actorsIndex.dataSelectionQueries = [
            DataSelectionQuery(query: Query(), maxObjects: 500) // should mirror the entire index
        ]
        actorsIndex.delayBetweenSyncs = delayBetweenSyncs
        
        super.init()

        // Read settings from defaults.
        self.mirrored = NSUserDefaults.standardUserDefaults().boolForKey(DEFAULTS_KEY_MIRRORED) // defaults to false
        if let strategyRawValue = NSUserDefaults.standardUserDefaults().valueForKey(DEFAULTS_KEY_STRATEGY) as? Int, strategy = MirroredIndex.Strategy(rawValue: strategyRawValue) {
            requestStrategy = strategy
        } else {
            requestStrategy = .FallbackOnTimeout
        }
        if let timeout = NSUserDefaults.standardUserDefaults().valueForKey(DEFAULTS_KEY_TIMEOUT) as? NSTimeInterval {
            offlineFallbackTimeout = timeout
        } else {
            offlineFallbackTimeout = 1.0
        }

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(syncDidStart), name: MirroredIndex.SyncDidStartNotification, object: moviesIndex)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(syncDidFinish), name: MirroredIndex.SyncDidFinishNotification, object: moviesIndex)
    }
    
    func syncIfNeededAndPossible() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if appDelegate.reachability.isReachableViaWiFi() {
            if actorsIndex.mirrored {
                actorsIndex.syncIfNeeded()
            }
            if moviesIndex.mirrored {
                moviesIndex.syncIfNeeded()
            }
        }
    }

    // MARK: - Listeners

    @objc func syncDidStart(notification: NSNotification) {
        syncing = true
        NSLog("Sync did start: %@", notification)
    }
    
    @objc func syncDidFinish(notification: NSNotification) {
        NSLog("Sync did finish: %@", notification)
        if shouldLoadImages {
            preloadImages()
        } else {
            syncFinished()
        }
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
            syncFinished()
            return
        }
        let cursor = content!["cursor"] as? String
        if let hits = content!["hits"] as? [[String: AnyObject]] {
            for hit in hits {
                let movie = MovieRecord(json: hit)
                if movie.imageUrl != nil {
                    imagesToLoad.append(movie.imageUrl!)
                }
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
            let url = imagesToLoad.removeFirst()
            // Check if the image is already in the URL cache.
            let request = NSURLRequest(URL: url)
            let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request)
            if cachedResponse != nil {
                NSLog("Image %@ already in cache", url)
                dispatch_async(self.imageQueue) {
                    self.dequeueNext()
                }
            } else {
                NSLog("Loading image %@", url)
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
        } else if imagesLoading == 0 {
            syncFinished()
        }
    }
    
    private func handleImageDownloaded(data: NSData?, response: NSURLResponse?, error: NSError?) {
        imagesLoading -= 1
        dequeueNext()
    }
    
    private func syncFinished() {
        syncing = false
        NSLog("Sync finished")
    }
}
