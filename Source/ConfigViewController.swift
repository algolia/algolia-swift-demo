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
import UIKit


class ConfigViewController: UIViewController {
    @IBOutlet weak var syncStatusLabel: UILabel!
    @IBOutlet weak var syncActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var syncNowButton: UIButton!
    @IBOutlet weak var strategySegmentedControl: UISegmentedControl!
    @IBOutlet weak var timeoutValueSlider: UISlider!
    @IBOutlet weak var timeoutValueLabel: UILabel!
    @IBOutlet weak var mirroredSwitch: UISwitch!

    var manager: AlgoliaManager!
    var index: MirroredIndex!
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = AlgoliaManager.sharedInstance
        index = manager.moviesIndex
        manager.addObserver(self, forKeyPath: "syncing", options: .New, context: nil)
        
        update()
    }
    
    deinit {
        manager.removeObserver(self, forKeyPath: "syncing")
    }
    
    // MARK: - State
    
    private func update() {
        mirroredSwitch.on = index.mirrored
        if let syncDate = index.lastSuccessfulSyncDate {
            syncStatusLabel.text = "Last successful sync: \(syncDate)"
        } else {
            syncStatusLabel.text = "Not yet synced"
        }
        if manager.syncing {
            syncActivityIndicator.hidden = false
            syncActivityIndicator.startAnimating()
        } else {
            syncActivityIndicator.hidden = true
            syncActivityIndicator.stopAnimating()
        }
        syncNowButton.enabled = index.mirrored && !manager.syncing
        strategySegmentedControl.enabled = index.mirrored
        switch (manager.requestStrategy) {
        case .OfflineOnly: strategySegmentedControl.selectedSegmentIndex = 0
        case .OnlineOnly: strategySegmentedControl.selectedSegmentIndex = 1
        default: strategySegmentedControl.selectedSegmentIndex = 2
        }
        timeoutValueSlider.enabled = index.mirrored
        timeoutValueSlider.value = Float(index.offlineFallbackTimeout)
        timeoutValueLabel.text = "\(Int(index.offlineFallbackTimeout * 1000))ms"
    }

    // MARK: - Actions
    
    @IBAction func syncNow(sender: AnyObject) {
        index.sync()
    }

    @IBAction func requestStrategyDidChange(sender: AnyObject) {
        switch (strategySegmentedControl.selectedSegmentIndex) {
        case 0: manager.requestStrategy = .OnlineOnly
        case 1: manager.requestStrategy = .OfflineOnly
        default: manager.requestStrategy = .FallbackOnTimeout
        }
    }
    
    @IBAction func timeoutDidChange(sender: AnyObject) {
        index.offlineFallbackTimeout = Double(timeoutValueSlider.value)
        update()
    }
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func mirroredDidChange(sender: AnyObject) {
        index.mirrored = mirroredSwitch.on
        update()
    }
    
    // MARK: - KVO
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if object === AlgoliaManager.sharedInstance {
            if keyPath == "syncing" {
                dispatch_async(dispatch_get_main_queue()) {
                    self.update()
                }
            }
        }
    }
}
