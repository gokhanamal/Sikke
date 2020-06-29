//
//  PortfolioViewController.swift
//  Sikke
//
//  Created by Gokhan Namal on 17.04.2020.
//  Copyright © 2020 Gokhan Namal. All rights reserved.
//

import UIKit
import CoreData
import JGProgressHUD

final class PortfolioViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    var investments = [Portfolio]()
    var sumOfCurrentValues = 0.0
    var baseCurrency: String!
    let currencyViewIdentifier = "showCurrency"
    
    @IBOutlet weak var totalValueLabel: UILabel!
    @IBOutlet weak var baseCurrencyLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = true
        
        baseCurrency = UserDefaults.standard.string(forKey: "baseCurrency")
        setupLabels()
        setupNavigationButtons()
    }
    
    func setupLabels() {
       baseCurrencyLabel.text = baseCurrency
       totalValueLabel.text = sumOfCurrentValues.formatCurrency(currency: baseCurrency)
    }
       
    fileprivate func setupNavigationButtons() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(onPressCreateInvestment))
        addButton.tintColor = .white

        navigationItem.rightBarButtonItem = addButton
        navigationItem.leftBarButtonItem = self.editButtonItem
        navigationItem.leftBarButtonItem?.tintColor = .white
    }
       
    
    @objc func onPressCreateInvestment() {
        performSegue(withIdentifier: currencyViewIdentifier, sender: ActionType.createInvestment)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.setEditing(editing, animated: true)
    }
    
    @IBAction func changeBaseCurrency(_ sender: Any) {
        performSegue(withIdentifier: currencyViewIdentifier, sender: ActionType.changeBaseCurrency)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == currencyViewIdentifier {
            let vc = segue.destination as! CurrencyViewController
            let actionType = sender as! ActionType
            vc.delegate = self
            vc.actionType = actionType
        }
    }
    
    fileprivate func calculateTotalCurrentValue() {
        var sum = 0.0
        for investment in investments {
            let currentRate = DataModel.rates[investment.currency!] ?? 1.0
            let currentVal = (1/currentRate) * investment.amount
            sum += currentVal
        }
        sumOfCurrentValues = sum
        setupLabels()
    }
    
    func selectBaseCurrency(currencyCode: String) {
        baseCurrency = currencyCode
        calculateTotalCurrentValue()
        UserDefaults.standard.setValue(currencyCode, forKey: "baseCurrency")
        tableView.reloadData()
    }
    
    fileprivate func updateInvestment(amount: Double, investment: Portfolio, index: Int) {
        investment.amount = amount
        self.investments[index] = investment
        self.calculateTotalCurrentValue()
        self.tableView.reloadData()
        try? DataModel.dataController.viewContext.save()
    }
    
    func updateInvestmentAlert(index: Int) {
        let investment = investments[index]
        
        let ac = UIAlertController(title: "Update Investment", message: nil, preferredStyle: .alert)
        
        ac.message = "Please type the new amount for your investment."
        ac.addTextField(configurationHandler: { textField in
            textField.placeholder = "Amount in \(investment.currency!)"
            textField.keyboardType = .decimalPad
            textField.text = investment.amount.toString()
        })
    
        let submitAction = UIAlertAction(title: "Update", style: .default) { [unowned ac] _ in
            if let textfield = ac.textFields?.first, let amount = textfield.text, let amountInDouble = Double(amount) {
                self.updateInvestment(amount: amountInDouble, investment: investment, index: index)
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        ac.addAction(submitAction)
        ac.addAction(cancel)

        present(ac, animated: true)
    }
    
}

extension PortfolioViewController: CurrencyViewControllerDelegate {
    func createInvestment(portfolio: Portfolio) {
        investments.append(portfolio)
        let indexPath = IndexPath(row: investments.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .fade)
        calculateTotalCurrentValue()
    }
    
    fileprivate func deleteAllInvestments(_ currencyCode: String) {
        for investment in investments {
            DataModel.dataController.viewContext.delete(investment)
        }
        
        investments = []
        try? DataModel.dataController.viewContext.save()
    }
    
    fileprivate func getCurrentRates(_ currencyCode: String) {
        let hud = JGProgressHUD(style: .dark)
        hud.textLabel.text = "Updating"
        hud.show(in: self.view)
        SikkeClient.getRates(baseCurrency: currencyCode) { success, error in
            if let error = error {
                self.showAlert(title: "Failed!", message: error.localizedDescription, actions: nil)
            }
            hud.dismiss(animated: true)
        }
    }
    
    fileprivate func changeCurrency(_ currencyCode: String) {
        if investments.count > 0 {
            deleteAllInvestments(currencyCode)
        }
        self.selectBaseCurrency(currencyCode: currencyCode)
        getCurrentRates(currencyCode)
    }
    
    func didSelect(currencyCode: String) {
        if investments.count > 0 {
            let change = UIAlertAction(title: "Change", style: .default, handler: {_ in self.changeCurrency(currencyCode)})
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            showAlert(title: "Are you sure?", message: "You will lose your current investments to change your base currency.", actions: [change, cancel])
        } else {
            changeCurrency(currencyCode)
        }
    }
}

extension PortfolioViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return investments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PortfolioCell") as! PortfolioCell
        let portfolioItem = investments[indexPath.row]
        guard let currency = DataModel.getCurrency(currencyCode: portfolioItem.currency!) else { return UITableViewCell() }
        cell.setCell(currency: currency, portfolio: portfolioItem, baseCurrency: baseCurrency)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let portfolioItem = investments[indexPath.row]
            DataModel.dataController.viewContext.delete(portfolioItem)
            try? DataModel.dataController.viewContext.save()
            investments.remove(at: indexPath.row)
            calculateTotalCurrentValue()
            tableView.deleteRows(at:[indexPath], with: .fade)
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        updateInvestmentAlert(index: indexPath.row)
    }
}
