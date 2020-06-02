//
//  UITextView+textColor.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 05/09/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
extension Reactive where Base: UITextField {
    public var textColor: Binder<UIColor> {
        return Binder(self.base) { view, color in
            view.textColor = color
        }
    }
    public var placeholder: Binder<String?> {
        return Binder(self.base) { view, placeholder in
            view.placeholder = placeholder
        }
    }
}
