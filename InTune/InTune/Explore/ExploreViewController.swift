//
//  ExploreViewController.swift
//  InTune
//
//  Created by Tiffany Obi on 5/26/20.
//  Copyright © 2020 Tiffany Obi. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ExploreViewController: UIViewController {
    @IBOutlet weak var resetButton: UIBarButtonItem!
    @IBOutlet weak var updatePreferenceButton: UIBarButtonItem!
    
    @IBOutlet private var tagsCollectionView: UICollectionView!
    @IBOutlet private var artistTableView: UITableView!
    @IBOutlet weak var featuredArtistCollectionView: UICollectionView!
    
    
    private var collectionView: UICollectionView?
    
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 150, height: 120)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        //        collectionView?.register(FeaturedArtistsCell.self, forCellWithReuseIdentifier: FeaturedArtistsCell.identifier)
        collectionView?.showsHorizontalScrollIndicator = false
        collectionView?.delegate = self
        collectionView?.dataSource = self
        
        guard let myCollectionView = collectionView else {
            return
        }
        
        view.addSubview(myCollectionView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView?.frame = CGRect(x: 0, y: 685, width: view.frame.size.width, height: 150).integral
    }
    
    let db = DatabaseService()
    var listener: ListenerRegistration?
    
    var artists = [Artist](){
        didSet{
            DispatchQueue.main.async {
                self.artistTableView.reloadData()
            }
        }
    }
    var allUsers = [Artist](){
        didSet {
            DispatchQueue.main.async {
                self.artistTableView.reloadData()
            }
        }
    }
    
    var currentUser: Artist?
    
    var featuredArtists = [Artist](){
        didSet{
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
                self.featuredArtistCollectionView.reloadData()
            }
        }
    }
    
    var tags = [String]() {
        didSet {
            DispatchQueue.main.async {
                self.tagsCollectionView.reloadData()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let expEdit = segue.destination as? ExploreOptionsController else {
            fatalError("could not segue to ExploreOptionsController ")
        }
        expEdit.prefDelegate = self
    }
    
    let height: CGFloat = 140
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resetButton.tintColor = .label
        updatePreferenceButton.tintColor = .label
        setUpFeaturedArtists()
        self.artistTableView.separatorColor = .clear
        fetchArtists()
        getCurrentUserPref()
        tagsCollectionView.register(UINib(nibName: "TagCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "tagCell")
        artistTableView.register(ExploreArtistCell.self, forCellReuseIdentifier: "exploreCell")
        setUpCVs()
        setUpArtistCollectionView()
        setUpTV()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        guard let currentUser1 = currentUser else { return }
        
        listener = Firestore.firestore().collection(DatabaseService.artistsCollection).document(currentUser1.artistId).addSnapshotListener({ [weak self](snapshot, error) in
            if let error = error {
                
                DispatchQueue.main.async {
                    self?.showAlert(title: "Firestore Error (Cannot Retrieve Data)", message: "\(error.localizedDescription)")
                }
            } else if let snapshot = snapshot {
                guard let data = snapshot.data() else {return}
                let artist = Artist(data)
                self?.tags = artist.preferences ?? ["no tags"]
            }
        })
        
    }
    
    private func setUpArtistCollectionView() {
        featuredArtistCollectionView.dataSource = self
        featuredArtistCollectionView.delegate = self
    }
    
    
    private func setUpCVs() {
        tagsCollectionView.delegate = self
        tagsCollectionView.dataSource = self
    }
    
    private func setUpTV() {
        artistTableView.delegate = self
        artistTableView.dataSource = self
    }
    
    func fetchArtists(){
        db.getArtists { [weak self] (result) in
            switch result {
            case .failure(let error):
                self?.showAlert(title: "Error", message: "\(error.localizedDescription)")
                
            case.success(let artists1):
                guard let user = Auth.auth().currentUser else { return }
                self?.allUsers = artists1
                self?.artists = artists1.filter { $0.isAnArtist == true && $0.artistId != user.uid}
            }
        }
    }
    
    func setUpFeaturedArtists(){
        db.getArtists { [weak self] (result) in
            switch result {
            case .failure(let error):
                self?.showAlert(title: "Error", message: "\(error.localizedDescription)")

            case.success(let artists1):
                self?.featuredArtists = self!.helperFuncForFeaturedArtist(artists1: artists1)

            }
        }
    }
    
    func filterArtist(name: String) {
        artists = allUsers.filter {$0.name.lowercased().contains(name.lowercased()) }
        if artists.count == 0 {
            DispatchQueue.main.async {
                self.showAlert(title: "Loading error", message: "Could not find artist named: \(name) ")
            }
        }
    }
    
    func getCurrentUserPref(){
        guard let user = Auth.auth().currentUser else {return}
        
        db.fetchArtist(userID: user.uid) { [weak self](result) in
            switch result {
            case.failure(let error):
                self?.showAlert(title: "Error", message: "\(error.localizedDescription)")
                
            case.success(let currentUser1):
                self?.currentUser = currentUser1
                self?.tags = currentUser1.preferences ?? ["no tags","no tags"]
                
            }
        }
    }
    
    @IBAction func resetSearch(_ sender: UIBarButtonItem) {
        fetchArtists()
        
        guard let currentUser1 = currentUser else { return }
        
        db.updateUserPreferences(currentUser1.tags) {[weak self] (result) in
            switch result {
            case .failure(let error):
                self?.showAlert(title: "Error Updating", message: error.localizedDescription)
            case .success:
                self?.getCurrentUserPref()
                
            }
        }
        
        
    }
    
    func helperFuncForFeaturedArtist(artists1:[Artist]) -> [Artist]{
        var featureSet = Set<Artist>()
        
        while featureSet.count < 5 {
            guard let randomArtist = artists1.randomElement() else {return [Artist]()}
            if randomArtist.isAnArtist == true {
            featureSet.insert(randomArtist)
            }
        }
           return Array(featureSet)
    }
}

extension ExploreViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return height
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return artists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "exploreCell", for: indexPath) as? ExploreArtistCell else {
            fatalError("could not conform to ExploreArtistCell")
        }
        let artist = artists[indexPath.row]
        cell.configureCell(artist: artist)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyBoard = UIStoryboard(name: "MainView", bundle:  nil)
        guard let profVC = storyBoard.instantiateViewController(identifier: "ProfileViewController") as? ProfileViewController else {
            fatalError("could not load ProfileViewController")
        }
        let artist = artists[indexPath.row]
        
        if artist.isAnArtist == true {
        profVC.expArtist = artist
        profVC.state = .explore
        profVC.navigationItem.title = nil
        profVC.navigationItem.backBarButtonItem?.tintColor = .label
        navigationController?.pushViewController(profVC, animated: true)
        } else {
          showAlert(title: "Hey!", message: "This user is just here to support the amazing talent that is on the app! Try searching for a fellow artist! Or checkout Gigs to see if they've posted an opportunity for you!")
        }
    }
}

extension ExploreViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if collectionView == featuredArtistCollectionView {
            cell.colorShadow(for: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if collectionView == tagsCollectionView {
            return currentUser?.preferences?.count ?? 0
        }
        if collectionView == featuredArtistCollectionView {
            return featuredArtists.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView == tagsCollectionView {
            
            guard let tagCell = collectionView.dequeueReusableCell(withReuseIdentifier: "tagCell", for: indexPath) as? TagCollectionViewCell else {
                fatalError("could not downcast to TagCollectionViewCell")
            }
            
            let tag = currentUser?.preferences?[indexPath.row] ?? "no tag"
            tagCell.configureCell(tag)
            
            
            return tagCell
        } else {
            guard let artistCell = collectionView.dequeueReusableCell(withReuseIdentifier: "artistCell", for: indexPath) as? FeaturedArtistCell else {
                fatalError("could not downcast to TagCollectionViewCell")
            }
            
            let featuredArtist = featuredArtists[indexPath.row]
            artistCell.layer.cornerRadius = 14
            artistCell.configureCell(artistPhotoURL: featuredArtist.photoURL, artistName: featuredArtist.name)
            
            return artistCell
        }
        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if collectionView == tagsCollectionView {
            let maxSize: CGSize = UIScreen.main.bounds.size
            let itemWidth: CGFloat = maxSize.width * 0.20
            let itemHeight: CGFloat = maxSize.height * 0.18
            return CGSize(width: itemWidth, height: itemHeight)
            
        } else {
            let maxSize: CGSize = UIScreen.main.bounds.size
            let itemWidth: CGFloat = maxSize.width * 0.24
            let itemHeight: CGFloat = maxSize.height * 0.11
            return CGSize(width: itemWidth, height: itemHeight)
            
        }
    }
    
    
    
}

extension ExploreViewController: UpdateUsertPref {
    func didSearchArtist(_ searchText: String, _ exploreVC: ExploreOptionsController) {
        filterArtist(name: searchText)
    }
    
    func didUpdatePreferences(_ tags: [String], _ exploreVC: ExploreOptionsController) {
        getCurrentUserPref()
        tagsCollectionView.reloadData()
        artistTableView.reloadData()
        
        db.getArtists { (result) in
            switch result {
            case .failure(let error):
                print(error)
                
            case .success(let filteredArtist):
                guard let user = Auth.auth().currentUser else { return }
                for pref in self.currentUser?.preferences ?? ["none"] {
                    
                    self.artists = filteredArtist.filter{ $0.artistId != user.uid && $0.tags.contains(pref) }
                }
            }
        }
        
    }
}



