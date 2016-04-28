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

import AlgoliaSearch
import Foundation


class AlgoliaManager {
    static let sharedInstance = AlgoliaManager()
    
    let moviesIndex: MirroredIndex
    let client: OfflineClient
    
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
            DataSelectionQuery(query: Query(parameters: ["filters": "year >= 2000"]), maxObjects: 2500),
            DataSelectionQuery(query: Query(parameters: ["filters": "year < 2000"]), maxObjects: 1500)
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
    }
}