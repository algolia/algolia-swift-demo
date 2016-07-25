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
import AFNetworking
import InstantSearch
import UIKit


class MoviesTableViewController: UITableViewController, UISearchBarDelegate, UISearchResultsUpdating {

    var searchController: UISearchController!
    
    var movieSearcher: Searcher!
    
    let placeholder = UIImage(named: "white")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Algolia Search
        movieSearcher = Searcher(index: AlgoliaManager.sharedInstance.moviesIndex, resultHandler: { (results, error) in
            self.tableView.reloadData()
        })
        movieSearcher.nextState.query.hitsPerPage = 15
        movieSearcher.nextState.query.attributesToRetrieve = ["title", "image", "rating", "year"]
        movieSearcher.nextState.query.attributesToHighlight = ["title"]
        
        // Search controller
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        
        // Add the search bar
        tableView.tableHeaderView = self.searchController!.searchBar
        definesPresentationContext = true
        searchController!.searchBar.sizeToFit()
        
        // First load
        updateSearchResultsForSearchController(searchController)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movieSearcher.results?.hits.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("movieCell", forIndexPath: indexPath) 

        // Load more?
        if indexPath.row + 5 >= movieSearcher.results!.hits.count {
            movieSearcher.loadMore()
        }
        
        // Configure the cell...
        let movie = MovieRecord(json: movieSearcher.results!.hits[indexPath.row])
        cell.textLabel?.highlightedText = movie.title_highlighted
        
        cell.detailTextLabel?.text = movie.year != nil ? "\(movie.year!)" : nil
        cell.imageView?.cancelImageDownloadTask()
        if let url = movie.imageUrl {
            cell.imageView?.setImageWithURL(url, placeholderImage: placeholder)
        }
        else {
            cell.imageView?.image = nil
        }

        return cell
    }
    
    // MARK: - Search bar
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        movieSearcher.nextState.query.query = searchController.searchBar.text
        movieSearcher.search()
    }
    
}
