//
//  RangerSliderWidget.swift
//  MovieSearch
//
//  Created by Guy Daher on 17/03/2017.
//  Copyright © 2017 Thibault Deutsch. All rights reserved.
//

import UIKit
import InstantSearchCore
import TTRangeSlider

class RangerSliderWidget: TTRangeSlider, RefinementControlWidget, TTRangeSliderDelegate {

    var searcher: Searcher!
    internal var numericFiltersDebouncer = Debouncer(delay: 0.2)
    
    func initWith(searcher: Searcher) {
        self.searcher = searcher
        delegate = self
    }
    
    func on(results: SearchResults?, error: Error?, userInfo: [String : Any]) {
        
    }
    
    func registerValueChangedAction() {}
    
    func getAttributeName() -> String {
        return "year"
    }
    
    func rangeSlider(_ sender: TTRangeSlider!, didChangeSelectedMinimumValue selectedMinimum: Float, andMaximumValue selectedMaximum: Float) {
        numericFiltersDebouncer.call {
            self.searcher.params.updateNumericRefinement("year", .greaterThanOrEqual, NSNumber(value: Int(selectedMinimum)))
            self.searcher.params.updateNumericRefinement("year", .lessThanOrEqual, NSNumber(value: Int(selectedMaximum)))
            self.searcher.search()
        }
    }
    
    @objc func onRefinementChange(numerics: [NumericRefinement]) {
        for numeric in numerics {
            if numeric.op == .greaterThanOrEqual {
                selectedMinimum = numeric.value.floatValue
            }
            if numeric.op == .lessThanOrEqual {
                selectedMaximum = numeric.value.floatValue
            }
        }
    }
    
    func onReset() {
        selectedMinimum = 1950
        selectedMaximum = 2020
    }
}
