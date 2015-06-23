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

import UIKit
import AlgoliaSearch
import AFNetworking
import SwiftyJSON

class MoviesTableViewController: UITableViewController, UISearchBarDelegate, UISearchResultsUpdating {

    var searchController: UISearchController!
    
    var movieIndex: Index!
    let query = Query()
    
    var movies = [MovieRecord]()
    
    var searchId = 0
    var displayedSearchId = -1
    var loadedPage: UInt = 0
    
    let placeholder = UIImage(named: "white")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Search controller
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        
        // Add the search bar
        tableView.tableHeaderView = self.searchController!.searchBar
        definesPresentationContext = true
        searchController!.searchBar.sizeToFit()
        
        // Algolia Search
        let apiClient = Client(appID: "latency", apiKey: "dce4286c2833e8cf4b7b1f2d3fa1dbcb")
        movieIndex = apiClient.getIndex("movies")
        
        query.hitsPerPage = 15
        query.attributesToRetrieve = ["title", "image", "rating", "year"]
        query.attributesToHighlight = ["title"]
        
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
        return movies.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("movieCell", forIndexPath: indexPath) as! UITableViewCell

        // Load more?
        if (indexPath.row + 3) >= (movies.count - 1) {
            loadMore()
        }
        
        // Configure the cell...
        let movie = movies[indexPath.row]
        cell.textLabel?.text = movie.title
        cell.detailTextLabel?.text = "\(movie.year)"
        cell.imageView?.cancelImageRequestOperation()
        cell.imageView?.setImageWithURL(NSURL(string: movie.image), placeholderImage: placeholder)

        return cell
    }
    
    // MARK: - Search bar
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        query.query = searchController.searchBar.text
        let curSearchId = searchId
        
        movieIndex.search(query, block: { (data, error) -> Void in
            if (curSearchId <= self.displayedSearchId) || (error != nil) {
                return
            }
            
            self.displayedSearchId = curSearchId
            self.loadedPage = 0 // reset loaded page
            
            let json = JSON(data!)
            let hits: [JSON] = json["hits"].arrayValue
            
            var tmp = [MovieRecord]()
            for record in hits {
                tmp.append(MovieRecord(json: record))
            }
            
            self.movies = tmp
            self.tableView.reloadData()
        })
        
        ++self.searchId
    }
    
    // MARK: - Load more
    
    func loadMore() {
        let nextQuery = Query(copy: query)
        nextQuery.page = loadedPage + 1
        movieIndex.search(nextQuery, block: { (data , error) -> Void in
            // Reject if query has changed
            if (nextQuery.query != self.query.query) || (error != nil) {
                return
            }
            
            self.loadedPage = nextQuery.page
            
            let json = JSON(data!)
            let hits: [JSON] = json["hits"].arrayValue
            
            var tmp = [MovieRecord]()
            for record in hits {
                tmp.append(MovieRecord(json: record))
            }
            
            self.movies.extend(tmp)
            self.tableView.reloadData()
        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

}
