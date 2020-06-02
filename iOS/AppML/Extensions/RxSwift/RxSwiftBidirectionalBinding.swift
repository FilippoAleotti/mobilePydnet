//
//  RxSwiftBidirectionalBinding.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 04/09/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
infix operator <-> : DefaultPrecedence

func <-> <T>(property: ControlProperty<T>, relay: BehaviorRelay<T>) -> Disposable {
    
    let bindToUIDisposable = relay.bind(to: property)
    let bindToRelay = property
        .subscribe(onNext: { n in
            relay.accept(n)
        }, onCompleted:  {
            bindToUIDisposable.dispose()
        })

    return Disposables.create(bindToUIDisposable, bindToRelay)
}
