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


/// Match level of a highlight or snippet result.
public enum MatchLevel: String {
    case Full = "full"
    case Partial = "partial"
    case None = "none"
}

/// Highlight result for an attribute of a hit.
/// NOTE: Wraps the raw JSON returned by the API.
///
public struct HighlightResult {
    public let json: [String: AnyObject]
    public var value: String? { return json["value"] as? String }
    public var matchLevel: MatchLevel? {
        if let matchLevelString = json["matchLevel"] as? String {
            return MatchLevel(rawValue: matchLevelString)
        } else {
            return nil
        }
    }
    public var matchedWords: [String]? { return json["matchedWords"] as? [String] }
}

/// Snippet result for an attribute of a hit.
/// NOTE: Wraps the raw JSON returned by the API.
///
public struct SnippetResult {
    public let json: [String: AnyObject]
    public var value: String? { return json["value"] as? String }
    public var matchLevel: MatchLevel? {
        if let matchLevelString = json["matchLevel"] as? String {
            return MatchLevel(rawValue: matchLevelString)
        } else {
            return nil
        }
    }
}

/// Ranking info for a hit.
/// NOTE: Wraps the raw JSON returned by the API.
///
public struct RankingInfo {
    public let json: [String: AnyObject]
    public var nbTypos: Int? { return json["nbTypos"] as? Int }
    public var firstMatchedWord: Int? { return json["firstMatchedWord"] as? Int }
    public var proximityDistance: Int? { return json["proximityDistance"] as? Int }
    public var userScore: Int? { return json["userScore"] as? Int }
    public var geoDistance: Int? { return json["geoDistance"] as? Int }
    public var geoPrecision: Int? { return json["geoPrecision"] as? Int }
    public var nbExactWords: Int? { return json["nbExactWords"] as? Int }
    public var words: Int? { return json["words"] as? Int }
    public var filters: Int? { return json["filters"] as? Int }
}

/// Search results.
/// NOTE: Wraps the raw JSON returned by the API.
///
public class SearchResults {
    /// The last received JSON content.
    /// Either that passed to the initializer, or that last passed to `add()`.
    public private(set) var lastContent: [String: AnyObject]
    
    /// Facets that will be treated as disjunctive (`OR`). By default, facets are conjunctive (`AND`).
    public let disjunctiveFacets: [String]

    /// Hits for all the received pages.
    public private(set) var hits: [[String: AnyObject]] = []
    
    /// Facets for the last results. Lazily computed; accessed through `facets()`.
    private var facets: [String: [FacetValue]] = [:]

    /// Total number of hits.
    public var nbHits: Int? { return lastContent["nbHits"] as? Int }

    /// Last returned page.
    public var page: Int? { return lastContent["page"] as? Int }

    /// Total number of pages.
    public var nbPages: Int? { return lastContent["nbPages"] as? Int }
    
    /// Number of hits per page.
    public var hitsPerPage: Int? { return lastContent["hitsPerPage"] as? Int }
    
    /// Processing time of the last query (in ms).
    public var processingTimeMS: Int? { return lastContent["processingTimeMS"] as? Int }
    
    /// Whether facet counts are exhaustive.
    public var exhaustiveFacetsCount: Bool? { return lastContent["exhaustiveFacetsCount"] as? Bool }
    
    /// Query corresponding to the last results.
    /// WARNING: Do not modify it!
    ///
    public private(set) var lastQuery: Query

    // MARK: - Initialization, termination
    
    /// Create search results from an initial response from the API.
    public init(content: [String: AnyObject], disjunctiveFacets: [String]) {
        self.lastContent = content
        self.disjunctiveFacets = disjunctiveFacets
        self.hits = content["hits"] as? [[String: AnyObject]] ?? [[String: AnyObject]]()
        if let queryString = content["params"] as? String {
            self.lastQuery = Query.parse(queryString)
        } else {
            self.lastQuery = Query() // TODO: Suboptimal
        }
    }
    
    /// Add a new page to the results.
    public func add(results: [String: AnyObject]) {
        if let hits = results["hits"] as? [[String: AnyObject]] {
            self.hits.appendContentsOf(hits)
        }
        self.facets.removeAll() // TODO: Should we really parse facets from start again?
    }
    
    // MARK: - Accessors
    
    /// Retrieve the facet values for a given facet.
    ///
    /// - parameter name: Facet name.
    /// - parameter disjunctive: true if this is a disjunctive facet, false if it's a conjunctive facet (default).
    /// - return: The corresponding facet values.
    ///
    public func facets(name: String) -> [FacetValue]? {
        // Use stored values if available.
        if let values = facets[name] {
            return values
        }
        // Otherwise lazily compute the values.
        else {
            let disjunctive = disjunctiveFacets.contains(name)
            guard let returnedFacets = lastContent[disjunctive ? "disjunctiveFacets" : "facets"] as? [String: AnyObject] else { return nil }
            var values = [FacetValue]()
            let returnedValues = returnedFacets[name] as? [String: Int]
            if let returnedValues = returnedValues {
                for (value, count) in returnedValues {
                    values.append(FacetValue(value: value, count: count))
                }
            }
            // Make sure there is a value at least for the refined values.
            let queryHelper = QueryHelper(query: lastQuery)
            if let facetRefinements = queryHelper.parseFacetRefinements()[name] {
                for value in facetRefinements {
                    if returnedValues?[value] == nil {
                        values.append(FacetValue(value: value, count: 0))
                    }
                }
            }
            // Remember values for later use.
            self.facets[name] = values
            return values
        }
    }
    
    /// Get the highlight result for an attribute of a hit.
    public func highlightResult(index: Int, path: String) -> HighlightResult? {
        return SearchResults.getHighlightResult(hits[index], path: path)
    }

    /// Get the snippet result for an attribute of a hit.
    public func snippetResult(index: Int, path: String) -> SnippetResult? {
        return SearchResults.getSnippetResult(hits[index], path: path)
    }

    /// Get the ranking information for a hit.
    /// NOTE: Only available when `Query.getRankingInfo` is set to true.
    public func rankingInfo(index: Int) -> RankingInfo? {
        if let rankingInfo = hits[index]["_rankingInfo"] as? [String: AnyObject] {
            return RankingInfo(json: rankingInfo)
        } else {
            return nil
        }
    }
    
    // MARK: - Utils
    
    /// Retrieve the highlight result corresponding to an attribute inside the JSON representation of a hit.
    ///
    /// - param hit: The JSON object for a hit.
    /// - param path: Path of the attribute to retrieve, in dot notation.
    /// - return The highlight result, or nil if not available.
    ///
    static func getHighlightResult(hit: [String: AnyObject], path: String) -> HighlightResult? {
        guard let highlights = hit["_highlightResult"] as? [String: AnyObject] else { return nil }
        guard let attribute = JSONHelper.valueForKeyPath(highlights, path: path) as? [String: AnyObject] else { return nil }
        return HighlightResult(json: attribute)
    }
    
    /// Retrieve the snippet result corresponding to an attribute inside the JSON representation of a hit.
    ///
    /// - param hit: The JSON object for a hit.
    /// - param path: Path of the attribute to retrieve, in dot notation.
    /// - return The snippet result, or nil if not available.
    ///
    static func getSnippetResult(hit: [String: AnyObject], path: String) -> SnippetResult? {
        guard let snippets = hit["_snippetResult"] as? [String: AnyObject] else { return nil }
        guard let attribute = JSONHelper.valueForKeyPath(snippets, path: path) as? [String: AnyObject] else { return nil }
        return SnippetResult(json: attribute)
    }
}
