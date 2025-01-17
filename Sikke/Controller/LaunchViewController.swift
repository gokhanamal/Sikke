//
//  LaunchViewController.swift
//  Sikke
//
//  Created by Gokhan Namal on 19.04.2020.
//  Copyright © 2020 Gokhan Namal. All rights reserved.
//

import UIKit
import CoreData

class LaunchViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        if let baseCurrency = UserDefaults.standard.string(forKey: "baseCurrency")  {
            getRates(baseCurrency)
        } else {
            //Use USD as a base currency if there is no selected base currency
            let currencyCode = Locale.current.currencyCode!
            UserDefaults.standard.setValue(currencyCode, forKey: "baseCurrency")
            getRates(currencyCode)
        }
        
    }
    
    fileprivate func getRates(_ baseCurrency: String) {
        SikkeClient.getRates(baseCurrency: baseCurrency) {rates, error in
            if let error = error {
                self.showAlert(title: "Currency Error!", message: error.localizedDescription, actions: nil)
            } else {
                // Show main view after get currencies rate
                self.performSegue(withIdentifier: "showMain", sender: nil)
            }
        }
    }
    
    fileprivate func getCoreData(_ vc: PortfolioViewController) {
        let fetchRequest: NSFetchRequest<Portfolio> = Portfolio.fetchRequest()
        if let result = try? DataModel.dataController.viewContext.fetch(fetchRequest) {
            var total = 0.0
            for item in result {
                let currency = DataModel.getCurrency(currencyCode: item.currency ?? "USD")
                if let currency = currency {
                    let currentRate = DataModel.rates[currency.currencyCode] ?? 1.0
                    let currentVal = (1/currentRate) * item.amount
                    total += currentVal
                }
            }
            vc.sumOfCurrentValues = total
            vc.investments = result
        } else {
            showAlert(title: "Failed!", message: "Could not fetch your local data.", actions: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMain" {
            let tabBar = segue.destination as! UITabBarController
            let navController = tabBar.viewControllers?.first as! UINavigationController
            let vc = navController.topViewController as! PortfolioViewController
            
            getCoreData(vc)
        }
    }
}
