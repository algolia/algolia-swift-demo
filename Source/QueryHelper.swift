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


public struct FacetRefinement {
    /// Name of the facet.
    public var name: String
    
    /// Value for the facet.
    public var value: String

    /// Whether the refinement is inclusive (default) or exclusive (value prefixed with "-").
    public var inclusive: Bool = true
    
    /// Build a facet filter corresponding to this refinement.
    public func buildFacetFilter() -> String {
        return "\(name):\(inclusive ? "" : "-")\(value)"
    }
}

/// Utilities to build and interpret `Query` instances.
///
public class QueryHelper {
    public let query: Query
    
    /// Create an initially empty query builder.
    init() {
        self.query = Query()
    }
    
    /// Create a query builder wrapping the specified query.
    init(query: Query) {
        self.query = query
    }
    
    /// Parse facet filters into facet refinements.
    /// Please note that doing so discards the notion of conjunctive ("AND") vs disjunctive ("OR") filters.
    ///
    /// - return: A dictionary mapping each facet name to the corresponding list of values.
    ///
    public func parseFacetRefinements() -> [String: [String]] {
        if let facetFilters = query.facetFilters {
            return _parseFacetRefinements(facetFilters)
        } else {
            return [:]
        }
    }
    
    /// Recursively parse facet filters into facet refinements.
    private func _parseFacetRefinements(facetFilters: [AnyObject]) -> [String: [String]] {
        var refinements = [String: [String]]()
        for facetFilter in facetFilters {
            if let facetFilter = facetFilter as? String, facetRefinement = QueryHelper.parseFacetRefinement(facetFilter) {
                if let facetRefinements = refinements[facetRefinement.name] {
                    refinements[facetRefinement.name] = facetRefinements + [facetRefinement.value]
                } else {
                    refinements[facetRefinement.name] = [facetRefinement.value]
                }
            } else if let facetFilter = facetFilter as? [AnyObject] {
                let additionalRefinements = _parseFacetRefinements(facetFilter)
                for (facetName, facetValues) in additionalRefinements {
                    if let facetRefinements = refinements[facetName] {
                        refinements[facetName] = facetRefinements + facetValues
                    } else {
                        refinements[facetName] = facetValues
                    }
                }
            }
        }
        return refinements
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
    
    /// Parse a facet filter into a facet refinement.
    ///
    /// - parameter facetFilter: A string representation of a facet filter, as used by `Query`.
    /// - return: The corresponding facet refinement, or nil if the string is invalid.
    ///
    public static func parseFacetRefinement(facetFilter: String) -> FacetRefinement? {
        let components = facetFilter.characters.split(":", maxSplit: 1, allowEmptySlices: true)
        if components.count == 2 {
            let facetName = String(components[0])
            var facetValue = String(components[1])
            var inclusive = true
            if facetValue.characters.first == "-" {
                facetValue = facetValue.substringFromIndex(facetValue.startIndex.successor())
                inclusive = false
            }
            return FacetRefinement(name: facetName, value: facetValue, inclusive: inclusive)
        } else {
            return nil
        }
    }
}
