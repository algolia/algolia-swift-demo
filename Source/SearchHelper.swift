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


/// Manages search on an Algolia index.
///
/// The purpose of this class is to maintain a state between searches and handle pagination.
///
public class SearchHelper {
    public typealias ResultHandler = (results: SearchResults?, error: NSError?) -> Void

    /// Pluggable state representation for a `SearchHelper`.
    public struct State {
        /// Search query.
        /// NOTE: The page may be overridden when loading more content.
        ///
        public var query: Query = Query()
        
        /// List of facets to be treated as disjunctive facets. Defaults to the empty list.
        public var disjunctiveFacets: [String] = []
        
        /// Initial page.
        public var initialPage: Int { return query.page?.integerValue ?? 0 }
        
        /// Current page.
        public var page: Int = 0
        
        /// Whether the current page is the initial page for this search state.
        public var isInitialPage: Bool { return initialPage == page }
        
        /// Construct a default state.
        public init() {
        }

        // WARNING: Although `State` is a value type, `Query` is not (because of Objective-C bridgeability).
        // Consequently, the memberwise assignment of `State` leads to unintended state sharing.
        //
        // TODO: I found no way to customize the assignment of a struct in Swift (something like C++'s assignment
        // operator or copy constructor). So I resort to explicitly constructing copies so far.

        /// Copy a state.
        public init(copy: State) {
            // WARNING: Query is not a value type (because of Objective-C bridgeability), so let's make sure to copy it.
            self.query = Query(copy: copy.query)
            self.disjunctiveFacets = copy.disjunctiveFacets
            self.page = copy.page
        }
    }

    /// The index used by this search helper.
    public let index: Index
    
    /// User callback for handling results.
    private let resultHandler: ResultHandler

    // MARK: State management
    // ----------------------
    
    /// The state that will be used for the next search.
    /// It can be modified at will. It is not taken into account until the `search()` method is called; then it is
    /// copied and transferred to `requestedState`.
    public var nextState: State = State()

    /// The state corresponding to the last issued request.
    /// WARNING: Only valid after the first call to `search()`.
    public private(set) var requestedState: State!

    /// The state corresponding to the last received results.
    /// WARNING: Only valid after the first call to the result handler.
    public private(set) var receivedState: State!
    
    /// The last received results.
    public private(set) var results: SearchResults?
    
    // MARK: -
    
    public init(index: Index, resultHandler: ResultHandler) {
        self.index = index
        self.resultHandler = resultHandler
    }

    /// Search.
    public func search() {
        requestedState = State(copy: nextState)
        requestedState.page = requestedState.initialPage
        _doNextRequest()
    }
    
    /// Load more content, if possible.
    public func loadMore() {
        // Cannot load more when no results have been received.
        if results == nil {
            return
        }
        // Must not load more if the results are outdated with respect to the currently on-going search.
        if requestedState.query != receivedState.query {
            return
        }
        let nextPage = receivedState.page + 1
        // Cannot load more if the end has already been reached.
        if nextPage >= results!.nbPages {
            return
        }
        // Must not load more if already loading.
        if nextPage <= requestedState.page {
            return
        }
        // OK, everything's fine; let's go!
        requestedState.page = nextPage
        _doNextRequest()
    }
    
    private func _doNextRequest() {
        let state = State(copy: requestedState)
        let completionHandler: CompletionHandler = { (content: [String: AnyObject]?, error: NSError?) in
            // IMPORTANT: Mark the state as received.
            self.receivedState = state
            self.handleResults(content, error: error)
        }
        let query = Query(copy: state.query)
        query.page = state.page
        if state.disjunctiveFacets.isEmpty {
            index.search(query, completionHandler: completionHandler)
        } else {
            let queryHelper = QueryHelper(query: query)
            index.searchDisjunctiveFaceting(query, disjunctiveFacets: state.disjunctiveFacets, refinements: queryHelper.buildFacetRefinementsForDisjunctiveFaceting(), completionHandler: completionHandler)
        }
    }
    
    /// Completion handler for search requests.
    private func handleResults(content: [String: AnyObject]?, error: NSError?) {
        do {
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
        // Update hits.
        if receivedState.page == receivedState.initialPage {
            self.results = SearchResults(content: content, disjunctiveFacets: receivedState.disjunctiveFacets)
        } else {
            self.results?.add(content)
        }
    }

    /// Toggle a facet refinement on/off, in a way suitable for high latency environments.
    ///
    /// The trick here is that the toggle reads the *received* query state, but updates the *next* query. Why?
    /// Because if search results are slow to come, the user will be acting on the received state. If you just toggle
    /// the next query state, it might lead to inconsistent results.
    ///
    public func toggleFacetRefinement(facetRefinement: FacetRefinement) {
        let receivedQueryHelper = QueryHelper(query: receivedState.query)
        var enabled = receivedQueryHelper.hasFacetRefinement(facetRefinement)
        enabled = !enabled
        let newQueryHelper = QueryHelper(query: nextState.query)
        if enabled {
            if receivedState.disjunctiveFacets.contains(facetRefinement.name) {
                newQueryHelper.addDisjunctiveFacetRefinement(facetRefinement)
            } else {
                newQueryHelper.addConjunctiveFacetRefinement(facetRefinement)
            }
        } else {
            newQueryHelper.removeFacetRefinement(facetRefinement)
        }
    }
}
