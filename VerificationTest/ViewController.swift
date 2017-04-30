//
//  ViewController.swift
//  VerificationTest
//
//  Created by Michał Jaremczuk on 30.04.2017.
//  Copyright © 2017 Michał Jaremczuk. All rights reserved.
//

import UIKit
import RxSwift
import CoreLocation
import Alamofire

let ITEMS_COUNT_TO_SEND = 3

class ViewController: UIViewController {
    
    var disposeBag = DisposeBag()
    var locationThread: Observable<String>?
    var batteryThread: Observable<String>?
    var sendingThread: Observable<[String]>?
    var list: Variable<[String]> = Variable([])
    var location: CLLocation?
    var manager: CLLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIDevice.current.isBatteryMonitoringEnabled = true
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        locationThread = locationThread(interval: 1.0)
        batteryThread = batteryThread(interval: 2.0)
        sendingThread = idlingThread(serverUrl: "https://google.com")
    }
    
    @IBAction func startThreadsAction(_ sender: Any) {
        locationThread?.subscribe { value in
            self.list.value.append("location \(value)")
            }.addDisposableTo(disposeBag)
        batteryThread?.subscribe { value in
            self.list.value.append("battery \(value)")
            }.addDisposableTo(disposeBag)
        sendingThread?.subscribe { itemsCount in
            }.addDisposableTo(disposeBag)
    }
    
    @IBAction func stopThreadsAction(_ sender: Any) {
        list.value = []
        disposeBag = DisposeBag()
    }
    
    var batteryLevel: Float {
        return UIDevice.current.batteryLevel
    }
    
    func batteryThread(interval: TimeInterval) -> Observable<String> {
        return Observable.create { observer in
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.scheduleRepeating(deadline: DispatchTime.now() + interval, interval: interval)
            let cancel = Disposables.create {
                timer.cancel()
            }
            timer.setEventHandler {
                if cancel.isDisposed {
                    return
                }
                observer.on(.next("\(self.batteryLevel)"))
            }
            timer.resume()
            return cancel
            }.observeOn(MainScheduler.instance)
            .subscribeOn(ConcurrentDispatchQueueScheduler.init(qos: DispatchQoS.background))
    }
    
    func locationThread(interval: TimeInterval) -> Observable<String> {
        return Observable.create { observer in
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.scheduleRepeating(deadline: DispatchTime.now() + interval, interval: interval)
            let cancel = Disposables.create {
                timer.cancel()
            }
            timer.setEventHandler {
                if cancel.isDisposed {
                    return
                }
                if let coordinates = self.location?.coordinate {
                    observer.on(.next("Lat:\(coordinates.latitude) Long:\(coordinates.longitude)"))
                }
            }
            timer.resume()
            return cancel
            }.observeOn(MainScheduler.instance)
            .subscribeOn(ConcurrentDispatchQueueScheduler.init(qos: DispatchQoS.background))
    }
    
    func idlingThread(serverUrl: String) -> Observable<[String]> {
       return list.asObservable()
            .flatMap( { items -> Observable<[String]> in
                if(items.count == ITEMS_COUNT_TO_SEND) {
                    let parameters: Parameters = ["params":items.joined(separator: ",")]
                    Alamofire.request(serverUrl, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: nil)
                        .response(completionHandler: { (response) in
                            print("send data response: \(response)")
                        })
                }
                return Observable.just(items)
            })
            .filter({ (list) -> Bool in
                return list.count == ITEMS_COUNT_TO_SEND
            }).observeOn(MainScheduler.instance)
            .subscribeOn(ConcurrentDispatchQueueScheduler.init(qos: DispatchQoS.background))
    }
}

extension ViewController : CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // NO-OP
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if(status == CLAuthorizationStatus.authorizedAlways){
            manager.startUpdatingLocation()
        }
    }
}

