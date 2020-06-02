//
//  UIAlertController+LoadingAlert.swift
//  DataGrabber
//
//  Created by Giulio Zaccaroni on 24/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
extension UIAlertController {
    convenience init(loadingMessage: String) {
        self.init(title: nil, message: loadingMessage, preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();
        
        self.view.addSubview(loadingIndicator)
    }
    convenience init(title: String, info: String) {
        self.init(title: title, message: info, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "Ok", style: .default) { (action:UIAlertAction!) in
            self.dismiss(animated: true)
        }
        self.addAction(OKAction)
    }
}
