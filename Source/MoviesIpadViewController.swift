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
import InstantSearchCore
import TTRangeSlider
import UIKit

class MoviesIpadViewController: UIViewController, UICollectionViewDataSource, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var genreTableView: RefinementListView!
    @IBOutlet weak var yearRangeSlider: TTRangeSlider!
    @IBOutlet weak var ratingSelectorView: RatingSelectorView!
    @IBOutlet weak var moviesCollectionView: HitsCollectionView!
    @IBOutlet weak var actorsTableView: UITableView!
    @IBOutlet weak var genreTableViewFooter: UILabel!
    @IBOutlet weak var genreFilteringModeSwitch: UISwitch!

    var instantSearch: InstantSearchPresenter!
    var actorSearcher: Searcher!
    var movieSearcher: Searcher!
    var actorHits: [JSONObject] = []

    var yearFilterDebouncer = Debouncer(delay: 0.3)
    var searchProgressController: SearchProgressController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Customize search bar.
        searchBar.placeholder = NSLocalizedString("search_bar_placeholder", comment: "")
        
        // All the delegate setup for tableView and searchBar 

        // Customize year range slider.
        yearRangeSlider.numberFormatterOverride = NumberFormatter()
        let tintColor = self.view.tintColor
        yearRangeSlider.tintColorBetweenHandles = tintColor
        yearRangeSlider.handleColor = tintColor
        yearRangeSlider.lineHeight = 3
        yearRangeSlider.minLabelFont = UIFont.systemFont(ofSize: 12)
        yearRangeSlider.maxLabelFont = yearRangeSlider.minLabelFont

        // Customize genre table view.
//        genreTableView.tableFooterView = genreTableViewFooter
//        genreTableViewFooter.isHidden = true

        // Configure actor search.
        actorSearcher = Searcher(index: AlgoliaManager.sharedInstance.actorsIndex, resultHandler: self.handleActorSearchResults)
        actorSearcher.params.hitsPerPage = 10
        actorSearcher.params.attributesToHighlight = ["name"]

        // Configure movie search.
        movieSearcher = Searcher(index: AlgoliaManager.sharedInstance.moviesIndex, resultHandler: self.handleMovieSearchResults)
        movieSearcher.params.facets = ["genre"]
        movieSearcher.params.setFacet(withName: "genre", disjunctive: true)
        movieSearcher.params.attributesToHighlight = ["title"]
        movieSearcher.params.hitsPerPage = 30

        instantSearch = InstantSearchPresenter(searcher: movieSearcher)
        
        instantSearch.addAllWidgets(in: self.view)
        
        search()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Actions

    private func search() {
        actorSearcher.search()
        movieSearcher.params.setFacet(withName: "genre", disjunctive: genreFilteringModeSwitch.isOn)
        movieSearcher.params.clearNumericRefinements()
        movieSearcher.search()
    }

    @IBAction func genreFilteringModeDidChange(_ sender: AnyObject) {
        movieSearcher.params.setFacet(withName: "genre", disjunctive: genreFilteringModeSwitch.isOn)
        search()
    }

    @IBAction func configTapped(_ sender: AnyObject) {
        let vc = ConfigViewController(nibName: "ConfigViewController", bundle: nil)
        self.present(vc, animated: true, completion: nil)
    }

    // MARK: - Search completion handlers

    private func handleActorSearchResults(results: SearchResults?, error: Error?, userInfo: [String: Any]) {
        guard let results = results else { return }
        if results.page == 0 {
            actorHits = results.hits
        } else {
            actorHits.append(contentsOf: results.hits)
        }
        self.actorsTableView.reloadData()
    }

    private func handleMovieSearchResults(results: SearchResults?, error: Error?, userInfo: [String: Any]) {
        guard let results = results else {
            return
        }

        let exhaustiveFacetsCount = results.exhaustiveFacetsCount == true
        genreTableViewFooter.isHidden = exhaustiveFacetsCount
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return moviesCollectionView.numberOfRows(in: section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "movieCell", for: indexPath) as! MovieCell
        let hit = moviesCollectionView.hitForRow(at: indexPath)
        cell.movie = MovieRecord(json: hit)
        
        return cell
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
            case actorsTableView: return actorHits.count
            case genreTableView: return genreTableView.numberOfRows(in: section)
            default: assert(false); return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView {
            case actorsTableView:
                let cell = tableView.dequeueReusableCell(withIdentifier: "actorCell", for: indexPath) as! ActorCell
                cell.actor = Actor(json: actorHits[indexPath.item])
                if indexPath.item + 5 >= actorHits.count {
                    actorSearcher.loadMore()
                }
                return cell
            case genreTableView:
                let cell = tableView.dequeueReusableCell(withIdentifier: "genreCell", for: indexPath) as! GenreCell
                cell.value = genreTableView.facetForRow(at: indexPath)
                cell.checked = genreTableView.isRefined(at: indexPath)
                return cell
            default: assert(false); return UITableViewCell()
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView {
            case genreTableView:
                genreTableView.didSelectRow(at: indexPath)
                break
            default: return
        }
    }
}
