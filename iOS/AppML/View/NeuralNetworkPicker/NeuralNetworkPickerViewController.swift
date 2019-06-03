//
//  NeuralNetworkPickerViewController.swift
//  AppML
//
//  Created by Giulio Zaccaroni on 30/05/2019.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

class NeuralNetworkPickerViewController: UITableViewController {
    var selected: NeuralNetwork = NeuralNetworks.shared.default
    override func viewDidLoad() {
        super.viewDidLoad()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return NeuralNetworks.shared.list.count
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else{
            return
        }
        if cell.accessoryType != .checkmark {
            if let oldSelectedCellIndex = NeuralNetworks.shared.list.firstIndex(where: { $0.name == selected.name }) {
                tableView.cellForRow(at: IndexPath(row: oldSelectedCellIndex, section: 0))?.accessoryType = .none
            }
            cell.accessoryType = .checkmark
        }
        cell.isSelected = false
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let neuralNetwork = NeuralNetworks.shared.list[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath)
        cell.textLabel?.text = neuralNetwork.name
        cell.detailTextLabel?.text = neuralNetwork.inputType.description
        cell.accessoryType = (neuralNetwork.name == selected.name) ? .checkmark : .none
        return cell
    }
    @IBAction private func undo(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "unwindToMainVC", sender: self)
    }
    

}
