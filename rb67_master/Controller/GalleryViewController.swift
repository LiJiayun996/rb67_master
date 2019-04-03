//
//  GalleryViewController.swift
//  rb67_master
//
//  Created by Jiayun Li on 3/3/19.
//  Copyright © 2019 Jiayun Li. All rights reserved.
//

import UIKit

class GalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var userImageCollectionView: UICollectionView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("GallVC loaded")
        setCollectionViewLayout()
        //load user image url from database
    }
    
    //MARK: - app storged user image data
    
    //MARK: - perpare data to slider view
    
    var userFullSizeImages = [Image]()
    
    func loadFullSizeImages () {
        for i in 0...GlobalVariable.userImageStorageURLGlobal.count - 1 {
            let imageURL = GlobalVariable.userImageStorageURLGlobal[i]
            userFullSizeImages.append(Image(url: imageURL))
        }
    }
    
    //MARK: - set up collection view layout
    func setCollectionViewLayout(){
        let itemSize = UIScreen.main.bounds.width/3 - 1
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 20,left: 0,bottom: 10,right: 0)
        layout.itemSize = CGSize(width: itemSize, height: itemSize)
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 1
        userImageCollectionView.collectionViewLayout = layout
        print("Layout set")
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return GlobalVariable.userImageThumbnailStorageURLsGlobal.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! imageCellViewController
        cell.userImageViewCell.image = UIImage(contentsOfFile: GlobalVariable.userImageThumbnailStorageURLsGlobal[indexPath.row].path)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        print("selection view called")
        //load user full size image here
        loadFullSizeImages()
        
        ImageSlideShowViewController.presentFrom(self){ [weak self] controller in
            controller.initialIndex = indexPath.item
            controller.dismissOnPanGesture = false
            controller.slides = self?.userFullSizeImages
            controller.enableZoom = true
            controller.controllerDidDismiss = {
                debugPrint("Controller Dismissed")
                debugPrint("last index viewed: \(controller.currentIndex)")
            }
            controller.slideShowViewDidLoad = {debugPrint("Did Load")}
            controller.slideShowViewWillAppear = { animated in debugPrint("Will Appear Animated: \(animated)")}
            controller.slideShowViewDidAppear = { animated in debugPrint("Did Appear Animated: \(animated)")}
        }
    }

    @IBAction func backButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        userFullSizeImages.removeAll()
        print(userFullSizeImages.count)
    }
}


class Image:NSObject, ImageSlideShowProtocol {
    
    fileprivate let url:URL
    init(url:URL) {
        self.url = url
    }
    func slideIdentifier() -> String {
        return String(describing: url)
    }
    
    func image(completion: @escaping (_ image: UIImage?, _ error: Error?) -> Void) {
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        session.dataTask(with: self.url) { data, response, error in
            
            if let data = data, error == nil
            {
                let image = UIImage(data: data)
                completion(image, nil)
            }
            else
            {
                completion(nil, error)
            }
            }.resume()
    }
}
