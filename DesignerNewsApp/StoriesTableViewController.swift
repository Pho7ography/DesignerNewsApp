//
//  StoriesTableViewController.swift
//  DesignerNewsApp
//
//  Created by Meng To on 2015-01-08.
//  Copyright (c) 2015 Meng To. All rights reserved.
//

import UIKit
import Spring

class StoriesTableViewController: UITableViewController, StoriesTableViewCellDelegate, LoginViewControllerDelegate, MenuViewControllerDelegate {
    
    private let transitionManager = TransitionManager()
    var stories = [Story]()
    var firstTime = true
    var token = getToken()
    var upvotes = getUpvotes()
    var storySection = ""
    @IBOutlet weak var loginButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadStories(self)
        
        refreshControl?.addTarget(self, action: "loadStories:", forControlEvents: UIControlEvents.ValueChanged)
        
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableViewAutomaticDimension
        
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([NSFontAttributeName: UIFont(name: "Avenir Next", size: 18)!], forState: UIControlState.Normal)
        
        loginButton.setTitleTextAttributes([NSFontAttributeName: UIFont(name: "Avenir Next", size: 18)!], forState: UIControlState.Normal)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        if firstTime {
            view.showLoading()
            firstTime = false
        }
        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: UIStatusBarAnimation.Fade)
    }
    
    func loadStories(sender: AnyObject) {

        DesignerNewsService.getStories(storySection, page: 1) { stories in
            self.stories = stories
            self.upvotes = getUpvotes()
            self.tableView.reloadData()
            self.view.hideLoading()
            self.refreshControl?.endRefreshing()
        }
        
        if token.isEmpty {
            loginButton.title = "Login"
            loginButton.enabled = true
        }
        else {
            loginButton.title = ""
            loginButton.enabled = false
        }
    }
    
    // MARK: MenuViewControllerDelegate
    func menuViewControllerDidSelectTopStories(controller: MenuViewController) {
        view.showLoading()
        storySection = ""
        loadStories(self)
    }
    
    func menuViewControllerDidSelectRecent(controller: MenuViewController) {
        view.showLoading()
        storySection = "recent"
        loadStories(self)
    }

    func menuViewControllerDidSelectLogout(controller: MenuViewController) {
        logout()
    }

    func menuViewControllerDidLogin(controller: MenuViewController) {
        loginCompleted()
    }

    // MARK: LoginViewControllerDelegate
    func loginViewControllerDidLogin(controller: LoginViewController) {
        loginCompleted()
    }

    // MARK: Login
    @IBAction func loginButtonPressed(sender: AnyObject) {
        if token.isEmpty {
            performSegueWithIdentifier("LoginSegue", sender: self)
        }
        else {
            logout()
        }
    }

    // MARK: Misc
    func loginCompleted() {
        token = getToken()
        loadStories(self)
    }

    func logout() {
        deleteToken()
        token = ""
        loadStories(self)
    }

    // MARK: TableViewDelegate

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as StoriesTableViewCell
        configureCell(cell, story: stories[indexPath.row])
        cell.delegate = self
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let story = stories[indexPath.row]
        self.performSegueWithIdentifier("WebSegue", sender: nil)
    }
    
    // MARK: StoriesTableViewCellDelegate
    func storiesTableViewCell(cell: StoriesTableViewCell, upvoteButtonPressed sender: AnyObject) {
        var indexPath = tableView.indexPathForCell(cell)!
        let id = toString(stories[indexPath.row].id)
        
        if token.isEmpty {
            performSegueWithIdentifier("LoginSegue", sender: self)
        }
        else {
            postUpvote(id)
            saveUpvote(id)
            let upvoteInt = stories[indexPath.row].voteCount + 1
            let upvoteString = toString(upvoteInt)
            cell.upvoteButton.setTitle(upvoteString, forState: UIControlState.Normal)
            cell.upvoteButton.setImage(UIImage(named: "icon-upvote-active"), forState: UIControlState.Normal)
        }
    }

    func storiesTableViewCell(cell: StoriesTableViewCell, commentButtonPressed sender: AnyObject) {
        var indexPath = tableView.indexPathForCell(cell)!
        let story = stories[indexPath.row]
        performSegueWithIdentifier("ArticleSegue", sender: cell)
    }

    func storiesTableViewCell(cell: StoriesTableViewCell, replyButtonPressed sender: AnyObject) {
        // TODO
    }
    
    // MARK: Misc
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ArticleSegue" {
            let indexPath = tableView.indexPathForCell(sender as UITableViewCell)
            let story = stories[indexPath!.row]
            let articleViewController = segue.destinationViewController as ArticleTableViewController
            articleViewController.story = story
        }
        else if segue.identifier == "WebSegue" {
            let webViewController = segue.destinationViewController as WebViewController
            webViewController.story = JSON(sender!)
            
            webViewController.transitioningDelegate = self.transitionManager
            
            UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: UIStatusBarAnimation.Slide)
        }
        else if segue.identifier == "LoginSegue" {
            let loginViewController = segue.destinationViewController as LoginViewController
            loginViewController.delegate = self
        }
        else if segue.identifier == "MenuSegue" {
            let menuViewController = segue.destinationViewController as MenuViewController
            menuViewController.delegate = self
        }
    }
    
    func configureCell(cell: StoriesTableViewCell, story: Story) {
        cell.titleLabel.layoutSubviews()
        cell.titleLabel.text = story.title
        cell.authorLabel.text = story.userDisplayName + ", " + story.userJob
        cell.upvoteButton.setTitle(toString(story.voteCount), forState: UIControlState.Normal)
        cell.commentButton.setTitle(toString(story.commentCount), forState: UIControlState.Normal)
        cell.storyImageView.image = story.badge.isEmpty ? nil : UIImage(named: "badge-\(story.badge)")

        let date = dateFromString(story.createdAt, "yyyy-MM-dd'T'HH:mm:ssZ")
        cell.timeLabel.text = timeAgoSinceDate(date, true)

        let imageName = upvotes.containsObject(toString(story.id)) ? "icon-upvote-active" : "icon-upvote"
        cell.upvoteButton.setImage(UIImage(named: imageName), forState: UIControlState.Normal)

        cell.avatarImageView.image = UIImage(named: "content-avatar-default")
        ImageLoader.sharedLoader.imageForUrl(story.userPortraitUrl, completionHandler:{(image: UIImage?, url: String) in
            cell.avatarImageView.image = image
        })
    }
}
