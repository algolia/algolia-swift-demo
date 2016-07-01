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


/// A value of a given facet, together with its number of occurrences.
///
public struct FacetValue {
    let value: String
    let count: Int
    
}

/// Manages search on an Algolia index.
///
/// The purpose of this class is to maintain a state between searches and handle pagination.
///
public class SearchHelper {
    public typealias ResultHandler = (results: SearchResults?, error: NSError?) -> Void
    
    public let index: Index
    private let resultHandler: ResultHandler
    
    /// The query that will be used for the next search.
    /// It can be modified at will. It is not taken into account until the `search()` method is called.
    public var query: Query = Query()
    
    /// Facets that will be treated as disjunctive (`OR`). By default, facets are conjunctive (`AND`).
    public var disjunctiveFacets: [String] = []
    
    // MARK: On-going request
    // ----------------------
    
    /// The query corresponding to the currently on-going search, if any.
    private var requestedQuery: Query?

    /// The last requested page.
    private var requestedPage: Int = 0
    
    /// The initial page, i.e. that of the first request. Defaults to 0, unless the user provided one.
    private var initialPage: Int {
        return requestedQuery?.page?.integerValue ?? 0
    }

    private var requestedDisjunctiveFacets: [String]!

    // MARK: Last received results
    // ---------------------------
    
    /// Total number of pages in results.
    private var nbPages: Int = 0

    /// The initial page for the last received results.
    public var receivedInitialPage: Int {
        return receivedQuery?.page?.integerValue ?? 0
    }

    /// The last received page.
    public private(set) var receivedPage: Int = 0
    
    /// The query corresponding to the last received results.
    public private(set) var receivedQuery: Query?
    
    /// The last received results.
    public private(set) var results: SearchResults?
    
    // MARK: -
    
    public init(index: Index, resultHandler: ResultHandler) {
        self.index = index
        self.resultHandler = resultHandler
    }

    /// Search.
    public func search() {
        requestedQuery = Query(copy: query)
        requestedDisjunctiveFacets = disjunctiveFacets
        requestedPage = initialPage
        _doNextRequest(requestedQuery!)
    }
    
    /// Load more content, if possible.
    public func loadMore() {
        // Cannot load more when no results have been received.
        if receivedQuery == nil {
            return
        }
        // Must not load more if the results are outdated with respect to the currently on-going search.
        if requestedQuery != receivedQuery {
            return
        }
        let nextPage = receivedPage + 1
        // Cannot load more if the end has already been reached.
        if nextPage >= nbPages {
            return
        }
        // Must not load more if already loading.
        if nextPage <= requestedPage {
            return
        }
        // OK, everything's fine; let's go!
        let newQuery = Query(copy: requestedQuery!)
        requestedPage = nextPage
        newQuery.page = nextPage
        _doNextRequest(newQuery)
    }
    
    private func _doNextRequest(query: Query) {
        if disjunctiveFacets.isEmpty {
            index.search(query, completionHandler: self.handleResults)
        } else {
            let queryHelper = QueryHelper(query: query)
            index.searchDisjunctiveFaceting(query, disjunctiveFacets: disjunctiveFacets, refinements: queryHelper.parseFacetRefinements(), completionHandler: self.handleResults)
        }
    }

    /// Completion handler for search requests.
    private func handleResults(content: [String: AnyObject]?, error: NSError?) {
        do {
            receivedQuery = self.requestedQuery
            if content != nil {
                try _handleResults(content!)
            }
            resultHandler(results: self.results, error: error)
        } catch let e as NSError {
            resultHandler(results: self.results, error: e)
        }
    }
    
    /// Exception-throwing flavor of `handleResults`.
    private func _handleResults(content: [String: AnyObject]) throws {
        guard let
            receivedPage = content["page"] as? Int,
            nbPages = content["nbPages"] as? Int
        else {
            throw NSError(domain: Client.ErrorDomain, code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        // Update page.
        self.receivedPage = receivedPage
        self.nbPages = nbPages
        
        // Update hits.
        if receivedPage == initialPage {
            self.results = SearchResults(content: content, disjunctiveFacets: requestedDisjunctiveFacets)
        } else {
            self.results?.add(content)
        }
    }
}
