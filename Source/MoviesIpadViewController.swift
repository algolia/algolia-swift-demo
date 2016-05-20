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
import UIKit

class MoviesIpadViewController: UIViewController, UICollectionViewDataSource, UISearchBarDelegate, UITableViewDataSource {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var moviesCollectionView: UICollectionView!
    @IBOutlet weak var actorsTableView: UITableView!

    var actorSearcher: SearchHelper!
    var movieSearcher: SearchHelper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        actorSearcher = SearchHelper(index: AlgoliaManager.sharedInstance.actorsIndex, completionHandler: { (content, error) in
            self.actorsTableView.reloadData()
        })
        actorSearcher.query.hitsPerPage = 10

        movieSearcher = SearchHelper(index: AlgoliaManager.sharedInstance.moviesIndex, completionHandler: { (content, error) in
            self.moviesCollectionView.reloadData()
        })
        movieSearcher.query.hitsPerPage = 30

        search()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Actions
    
    private func search() {
        actorSearcher.search()
        movieSearcher.search()
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        actorSearcher.query.query = searchText
        movieSearcher.query.query = searchText
        search()
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
        return actorSearcher.hits.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("actorCell", forIndexPath: indexPath) as! ActorCell
        cell.actor = Actor(json: actorSearcher.hits[indexPath.item])
        if indexPath.item + 5 >= actorSearcher.hits.count {
            actorSearcher.loadMore()
        }
        return cell
    }
}
