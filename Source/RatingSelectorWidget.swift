//
//  RatingSelectorWidget.swift
//  MovieSearch
//
//  Created by Guy Daher on 17/03/2017.
//  Copyright © 2017 Thibault Deutsch. All rights reserved.
//

import Foundation
import InstantSearchCore

class RatingSelectorWidget: RatingSelectorView, RefinementControlWidget {

    var searcher: Searcher!
    func initWith(searcher: Searcher) {
        self.searcher = searcher
        addObserver(self, forKeyPath: "rating", options: .new, context: nil)
    }
    
    func on(results: SearchResults?, error: Error?, userInfo: [String : Any]) {

    }
    
    func registerValueChangedAction() {}
    
    func getAttributeName() -> String {
        return "year"
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let object = object as? NSObject else { return }
        if object === self {
            if keyPath == "rating" {
                searcher.params.updateNumericRefinement("rating", .greaterThanOrEqual, NSNumber(value: rating))
                self.searcher.search()
            }
        }
    }
    
    func onReset() {
        rating = 1
    }
}
