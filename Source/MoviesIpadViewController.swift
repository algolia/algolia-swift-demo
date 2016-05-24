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
import TTRangeSlider
import UIKit

class MoviesIpadViewController: UIViewController, UICollectionViewDataSource, TTRangeSliderDelegate, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var genreTableView: UITableView!
    @IBOutlet weak var yearRangeSlider: TTRangeSlider!
    @IBOutlet weak var moviesCollectionView: UICollectionView!
    @IBOutlet weak var actorsTableView: UITableView!

    var actorSearcher: SearchHelper!
    var movieSearcher: SearchHelper!
    
    var genreFacets: [FacetValue] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yearRangeSlider.numberFormatterOverride = NSNumberFormatter()
        let tintColor = self.view.tintColor
        yearRangeSlider.tintColorBetweenHandles = tintColor
        yearRangeSlider.handleColor = tintColor
        yearRangeSlider.lineHeight = 3
        
        // Configure actor search.
        actorSearcher = SearchHelper(index: AlgoliaManager.sharedInstance.actorsIndex, completionHandler: self.handleActorSearchResults)
        actorSearcher.query.hitsPerPage = 10

        // Configure movie search.
        movieSearcher = SearchHelper(index: AlgoliaManager.sharedInstance.moviesIndex, completionHandler: self.handleMovieSearchResults)
        movieSearcher.query.facets = ["genre"]
        movieSearcher.query.hitsPerPage = 30

        search()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Actions
    
    private func search() {
        actorSearcher.search()
        movieSearcher.query.numericFilters = [ "year >= \(Int(yearRangeSlider.selectedMinimum))", "year <= \(Int(yearRangeSlider.selectedMaximum))" ]
        movieSearcher.search()
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        actorSearcher.query.query = searchText
        movieSearcher.query.query = searchText
        search()
    }
    
    // MARK: - Search completion handlers

    private func handleActorSearchResults(content: [String: AnyObject]?, error: NSError?) {
        self.actorsTableView.reloadData()
    }

    private func handleMovieSearchResults(content: [String: AnyObject]?, error: NSError?) {
        // Sort facets: first selected facets, then by decreasing count, then by name.
        let receivedQueryBuilder = QueryBuilder(query: movieSearcher.receivedQuery!)
        genreFacets = self.movieSearcher.facets["genre"]?.sort({ (lhs, rhs) in
            let lhsChecked = receivedQueryBuilder.hasConjunctiveFacetRefinement("genre", value: lhs.value)
            let rhsChecked = receivedQueryBuilder.hasConjunctiveFacetRefinement("genre", value: rhs.value)
            if lhsChecked != rhsChecked {
                return lhsChecked
            } else if lhs.count != rhs.count {
                return lhs.count > rhs.count
            } else {
                return lhs.value < rhs.value
            }
        }) ?? []
        self.genreTableView.reloadData()
        self.moviesCollectionView.reloadData()
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return movieSearcher.hits.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("movieCell", forIndexPath: indexPath) as! MovieCell
        cell.movie = MovieRecord(json: movieSearcher.hits[indexPath.item])
        if indexPath.item + 6 >= movieSearcher.hits.count {
            movieSearcher.loadMore()
        }
        return cell
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
            case actorsTableView: return actorSearcher.hits.count
            case genreTableView: return genreFacets.count
            default: assert(false)
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch tableView {
            case actorsTableView:
                let cell = tableView.dequeueReusableCellWithIdentifier("actorCell", forIndexPath: indexPath) as! ActorCell
                cell.actor = Actor(json: actorSearcher.hits[indexPath.item])
                if indexPath.item + 5 >= actorSearcher.hits.count {
                    actorSearcher.loadMore()
                }
                return cell
            case genreTableView:
                let cell = tableView.dequeueReusableCellWithIdentifier("genreCell", forIndexPath: indexPath) as! GenreCell
                cell.value = genreFacets[indexPath.item]
                cell.checked = QueryBuilder(query: movieSearcher.receivedQuery!).hasConjunctiveFacetRefinement("genre", value: genreFacets[indexPath.item].value)
                return cell
            default: assert(false)
        }
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch tableView {
            case genreTableView:
                let facetValue = genreFacets[indexPath.item].value
                let receivedQueryBuilder = QueryBuilder(query: movieSearcher.receivedQuery!)
                var checked = receivedQueryBuilder.hasConjunctiveFacetRefinement("genre", value: facetValue)
                checked = !checked
                let newQueryBuilder = QueryBuilder(query: movieSearcher.query)
                if checked {
                    newQueryBuilder.addConjunctiveFacetRefinement("genre", value: facetValue)
                } else {
                    newQueryBuilder.removeConjunctiveFacetRefinement("genre", value: facetValue)
                }
                movieSearcher.search()
                break
            default: return
        }
    }
    
    // MARK: - TTRangeSliderDelegate
    
    func rangeSlider(sender: TTRangeSlider!, didChangeSelectedMinimumValue selectedMinimum: Float, andMaximumValue selectedMaximum: Float) {
        search()
    }
}
