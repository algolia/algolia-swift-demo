//
//  Copyright (c) 2015 Algolia
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

import Reachability
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let colorForLocalOrigin = UIColor(red: 0.9, green: 0.97, blue: 1.0, alpha: 1.0)

    var window: UIWindow?

    var reachability: Reachability!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Listen for network reachability changes.
        self.reachability = Reachability.forInternetConnection()
        self.reachability.reachableBlock = {
            (reachability: Reachability?) -> Void in
            AlgoliaManager.sharedInstance.syncIfNeededAndPossible()
        }
        self.reachability.unreachableBlock = {
            (reachability: Reachability?) -> Void in
            // Nothing to do
        }
        self.reachability.startNotifier()

        // Set up an on-disk URL cache.
        let urlCache = URLCache(memoryCapacity: 0, diskCapacity:50 * 1024 * 1024, diskPath:nil)
        URLCache.shared = urlCache

        return true
    }
}
