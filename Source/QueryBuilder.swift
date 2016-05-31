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


/// Utilities to build `Query` instances.
///
public class QueryBuilder {
    let query: Query

    /// Create an initially empty query builder.
    init() {
        self.query = Query()
    }
    
    /// Create a query builder wrapping the specified query.
    init(query: Query) {
        self.query = query
    }
    
    public func hasConjunctiveFacetRefinement(name: String, value: String) -> Bool {
        return findConjunctiveFacetRefinement(name, value: value) != nil
    }

    public func addConjunctiveFacetRefinement(name: String, value: String) {
        if findConjunctiveFacetRefinement(name, value: value) == nil {
            query.facetFilters = query.facetFilters ?? []
            query.facetFilters?.append("\(name):\(value)")
        }
    }

    public func removeConjunctiveFacetRefinement(name: String, value: String) {
        if let index = findConjunctiveFacetRefinement(name, value: value) {
            query.facetFilters!.removeAtIndex(index)
        }
    }

    private func findConjunctiveFacetRefinement(name: String, value: String) -> Int? {
        if query.facetFilters == nil {
            return nil
        }
        let searchedValue = "\(name):\(value)"
        for (index, facetFilter) in query.facetFilters!.enumerate() {
            if facetFilter is String {
                if facetFilter as! String == searchedValue {
                    return index
                }
            }
        }
        return nil
    }
    
    public func listConjunctiveFacetRefinements(name: String) -> [String] {
        var refinements = [String]()
        if query.facetFilters != nil {
            for facetFilter in query.facetFilters! {
                if let filter = facetFilter as? String {
                    let components = filter.componentsSeparatedByString(":")
                    if components[0] == name {
                        refinements.append(components[1])
                        // TODO: Handle the case when the value has a colon
                    }
                }
            }
        }
        return refinements
    }
}
