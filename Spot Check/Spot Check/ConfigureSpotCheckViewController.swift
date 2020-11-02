//
//  ConfigureSpotCheckViewController.swift
//  Spot Check
//
//  Created by Brian Team on 11/2/20.
//

import Foundation
import SystemConfiguration
import UIKit

class ConfigureSpotCheckViewController : UIViewController, UITextFieldDelegate {
    var spotNameTextValid: Bool = false
    var numberOfDaysTextValid: Bool = false
    var forecastTypesValid: Bool = false
    var httpRequest: URLSessionDataTask?

    // MARK: - Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.spotNameTextField.delegate = self
        self.numberOfDaysTextField.delegate = self

        configValuesChanged()
        getCurrentConfig()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // MARK: - IBOutlets

    @IBOutlet weak var spotNameTextField: UITextField!
    @IBOutlet weak var numberOfDaysTextField: UITextField!
    @IBOutlet weak var saveConfigButton: UIButton!
    @IBOutlet weak var swellForecastSwitch: UISwitch!
    @IBOutlet weak var tidesForecastSwitch: UISwitch!
    
    // MARK: - IBActions

    @IBAction func spotNameTextFieldChanged(_ sender: Any) {
        spotNameTextValid = !(spotNameTextField.text?.isEmpty ?? false)
        configValuesChanged()
    }

    @IBAction func numberOfDaysTextFieldChanged(_ sender: Any) {
        numberOfDaysTextValid = !(numberOfDaysTextField.text?.isEmpty ?? true)
        configValuesChanged()
    }
    
    @IBAction func forecastSwitchToggled(_ sender: Any) {
        // Lower keyboard in case we had either of these fields selected
        spotNameTextField.resignFirstResponder()
        numberOfDaysTextField.resignFirstResponder()
        
        forecastTypesValid = swellForecastSwitch.isOn || tidesForecastSwitch.isOn
        configValuesChanged()
    }

    @IBAction func saveConfigClicked(_ sender: Any) {
        applyConfig()
    }
    
    // MARK: - ViewController functions
    
    func textFieldShouldReturn(_ userText: UITextField) -> Bool {
        if (userText == spotNameTextField) {
            numberOfDaysTextField.becomeFirstResponder()
        } else {
            userText.resignFirstResponder()
        }

        return true;
    }

    private func configValuesChanged() {
        saveConfigButton.isEnabled = spotNameTextValid && numberOfDaysTextValid && forecastTypesValid
    }
    
    private func getCurrentConfig() {
        httpRequest?.cancel()
        saveConfigButton.isEnabled = false
        //spinner
        
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "spot-check.local.", path: "current_configuration", body: nil, method: "GET", contentType: "application/json") { data, error in
            DispatchQueue.main.async {
                // hide spinner
                self.saveConfigButton.isEnabled = true
            }

            if (error != nil) {
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Error", message: "Could not retrieve current Spot Check configuration saved on device, functionality to save new configuration might be broken.", preferredStyle: .alert)
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                guard let deserialized = json as? [String: Any] else {
                    print("Could not deserialize json response when retrieving current config from device, check 'current_configuration' endpoint")
                    return
                }
                
                DispatchQueue.main.async {
                    if let numDays = deserialized["number_of_days"] as? String {
                        self.numberOfDaysTextField.text = numDays
                    }
                    if let spotName = deserialized["spot_name"] as? String {
                        self.spotNameTextField.text = spotName
                    }
                    if let forecastTypes = deserialized["forecast_types"] as? [String] {
                        for type in forecastTypes {
                            switch (type) {
                            case "swell":
                                self.swellForecastSwitch.isOn = true
                                break
                            case "tides":
                                self.tidesForecastSwitch.isOn = true
                                break
                            default:
                                print("Got an unsupported forecast type: \(type)")
                                break
                            }
                        }
                    }
                }
            } catch {
                print("Could not deserialize json response when retrieving current config from device, check 'current_configuration' endpoint")
            }
        }
    }
    
    private func applyConfig() {
        httpRequest?.cancel()
        // spinner
        saveConfigButton.isEnabled = false

        let body: [String: Any] = [
            "number_of_days": numberOfDaysTextField.text!,
            "spot_name": spotNameTextField.text!,
            "forecast_types": buildForecastTypesArray()
        ]

        var data: Data = Data("{}".utf8)
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "spot-check.local.", path: "configure", body: data, method: "POST", contentType: "application/json") { data, error in
            //hide spinner
            DispatchQueue.main.async {
                self.saveConfigButton.isEnabled = true
            }
            
            guard error == nil else {
                print(error!.localizedDescription)

                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Error", message: "Could not find Spot Check device on network, are you sure it is turned on and connected?", preferredStyle: .alert)
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
                return
            }
            
            DispatchQueue.main.async {
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Success", message: "Successfully applied new configuration to Spot Check device", preferredStyle: .alert)
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    private func buildForecastTypesArray() -> [String] {
        var forecastTypes: [String] = []
        if (swellForecastSwitch.isOn) {
            forecastTypes.append("swell")
        }
        if (tidesForecastSwitch.isOn) {
            forecastTypes.append("tides")
        }
        
        return forecastTypes
    }
    
}