//
//  Copyright (c) 2015 Algolia
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
import AFNetworking
import UIKit


class MoviesTableViewController: UITableViewController, UISearchBarDelegate, UISearchResultsUpdating, SearchProgressDelegate {

    var searchController: UISearchController!
    var searchProgressController: SearchProgressController!

    var actorSearcher: Searcher!
    var movieSearcher: Searcher!
    var actorHits: [JSONObject] = []
    var movieHits: [JSONObject] = []
    var originIsLocal: Bool = false

    let placeholder = UIImage(named: "white")

    override func viewDidLoad() {
        super.viewDidLoad()

        // Algolia Search
        movieSearcher = Searcher(index: AlgoliaManager.sharedInstance.moviesIndex, resultHandler: self.handleSearchResults)
        movieSearcher.params.hitsPerPage = 20
        movieSearcher.params.attributesToRetrieve = ["title", "image", "rating", "year"]
        movieSearcher.params.attributesToHighlight = ["title"]

        // Configure actor search.
        actorSearcher = Searcher(index: AlgoliaManager.sharedInstance.actorsIndex, resultHandler: self.handleActorSearchResults)
        actorSearcher.params.hitsPerPage = 3
        actorSearcher.params.attributesToHighlight = ["name"]

        // Search controller
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = NSLocalizedString("search_bar_placeholder", comment: "")
        searchController.searchBar.enablesReturnKeyAutomatically = false

        // Add the search bar
        tableView.tableHeaderView = self.searchController!.searchBar
        definesPresentationContext = true
        searchController!.searchBar.sizeToFit()

        // Configure search progress monitoring.
        searchProgressController = SearchProgressController(searcher: movieSearcher)
        searchProgressController.delegate = self

        // First load
        updateSearchResults(for: searchController)

        // Start a sync if needed.
        AlgoliaManager.sharedInstance.syncIfNeededAndPossible()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Actions

    @IBAction func configTapped(_ sender: AnyObject) {
        let vc = ConfigViewController(nibName: "ConfigViewController", bundle: nil)
        self.present(vc, animated: true, completion: nil)
    }

    // MARK: - Search completion handlers

    private func handleSearchResults(results: SearchResults?, error: Error?) {
        guard let results = results else { return }
        if results.page == 0 {
            movieHits = results.hits
        } else {
            movieHits.append(contentsOf: results.hits)
        }
        originIsLocal = results.content["origin"] as? String == "local"
        self.tableView.reloadData()
    }

    private func handleActorSearchResults(results: SearchResults?, error: Error?) {
        guard let results = results else { return }
        actorHits = results.hits
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? actorHits.count : movieHits.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Actors
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "movieCell", for: indexPath)
            cell.textLabel?.highlightedText = SearchResults.highlightResult(hit: actorHits[indexPath.row], path: "name")?.value
            if let imagePath = actorHits[indexPath.row]["image_path"] as? String, let url = URL(string: "https://image.tmdb.org/t/p/w154" + imagePath) {
                cell.imageView?.setImageWith(url, placeholderImage: placeholder)
            } else {
                cell.imageView?.image = nil
            }
            cell.detailTextLabel?.text = nil
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "movieCell", for: indexPath)

        // Load more?
        if indexPath.row + 5 >= movieHits.count {
            movieSearcher.loadMore()
        }

        // Configure the cell...
        let movie = MovieRecord(json: movieHits[indexPath.row])
        cell.textLabel?.highlightedText = movie.title_highlighted

        cell.detailTextLabel?.text = movie.year != nil ? "\(movie.year!)" : nil
        cell.imageView?.cancelImageDownloadTask()
        if let url = movie.imageUrl {
            cell.imageView?.setImageWith(url, placeholderImage: placeholder)
        }
        else {
            cell.imageView?.image = nil
        }
        cell.backgroundColor = originIsLocal ? AppDelegate.colorForLocalOrigin : UIColor.white

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return actorHits.count != 0 ? "Actors" : nil
        } else {
            return movieHits.count != 0 ? "Movies" : nil
        }
    }

    // MARK: - Search

    func updateSearchResults(for searchController: UISearchController) {
        movieSearcher.params.query = searchController.searchBar.text
        movieSearcher.search()
        actorSearcher.params.query = searchController.searchBar.text
        actorSearcher.search()
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    }

    // MARK: - SearchProgressDelegate

    func searchDidStart(_ searchProgressController: SearchProgressController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }

    func searchDidStop(_ searchProgressController: SearchProgressController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}
