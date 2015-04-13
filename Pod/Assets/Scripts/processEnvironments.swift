#!/usr/bin/xcrun swift
// Playground - noun: a place where people can play

import Foundation

let envKey = "KZBEnvironments"
let overrideKey = "KZBEnvOverride"

func validateEnvSettings(envSettings: NSDictionary?, prependMessage: NSString? = nil) -> Bool {
    if envSettings == nil {
        return false
    }
    
    var settings = envSettings!.mutableCopy() as NSMutableDictionary
    let allowedEnvs = settings[envKey] as [String]
    
    settings.removeObjectForKey(envKey)
    
    var missingOptions = [String : [String]]()
    
    for (name, values) in settings {
        let variable = name as String
        let envValues = values as [String: AnyObject]
        
        let notConfiguredOptions = allowedEnvs.filter {
            return envValues.indexForKey($0) == nil
        }
        
        if notConfiguredOptions.count > 0 {
            missingOptions[variable] = notConfiguredOptions
        }
    }
    
    for (variable, options) in missingOptions {
        if let prepend = prependMessage {
            println("\(prepend) error:\(variable) is missing values for '\(options)'")
        } else {
            println("error:\(variable) is missing values for '\(options)'")
        }
    }
    
    return missingOptions.count == 0
}

func filterEnvSettings(plist: NSDictionary, env: String, prependMessage: String? = nil) -> NSDictionary {
    var settings = plist.mutableCopy() as [String:AnyObject]
    settings[envKey] = [env]
    for (name, values) in plist {
        let variable = name as String
        if let envValues = values as? [String: AnyObject] {
            if let allowedValue: AnyObject = envValues[env] {
                settings[variable] = [env: allowedValue]
            } else {
                if let prepend = prependMessage {
                    println("\(prepend) missing value of variable \(name) for env \(env) available values \(values)")
                } else {
                    println("missing value of variable \(name) for env \(env) available values \(values)")
                }
            }
        }
    }
    
    return settings
}


func processSettings(var settingsPath: String, availableEnvs:[String], defaultEnv: String, plist: NSDictionary) -> Bool {
    let preferenceKey = "PreferenceSpecifiers"
    settingsPath = (settingsPath as NSString).stringByAppendingPathComponent("Root.plist") as String
    
    if var settings = NSMutableDictionary(contentsOfFile: settingsPath) {
        if var existing = settings[preferenceKey] as? [AnyObject] {
            existing = existing.filter {
                if let dictionary = $0 as? [String:AnyObject] {
                    let value = dictionary["Key"] as? String
                    if value == overrideKey {
                        return false
                    }
                }
                return true
            }
            
            var availableEnvsWithCUSTOM = (availableEnvs as NSArray).mutableCopy() as NSMutableArray
            availableEnvsWithCUSTOM.addObject("CUSTOM")
            var updatedPreferences = (existing as NSArray).mutableCopy() as NSMutableArray
            
            updatedPreferences.addObject(
                [   "Type" : "PSMultiValueSpecifier",
                    "Title" : "Environment",
                    "Key" : overrideKey,
                    "Titles" : availableEnvsWithCUSTOM,
                    "Values" : availableEnvsWithCUSTOM,
                    "DefaultValue" : defaultEnv
                ])
            
            var plistCopy = plist.mutableCopy() as NSMutableDictionary
            let envsFromPlist = plistCopy[envKey] as [String]
            plistCopy.removeObjectForKey(envKey)
            
            updatedPreferences.addObject(
                [   "Type" : "PSGroupSpecifier",
                    "Title" : "Values used for CUSTOM environment:",
                ])
            for (name, values) in plistCopy{
                let variable = name as String
                updatedPreferences.addObject(
                    [   "Type" : "PSTextFieldSpecifier",
                        "Title" : variable,
                        "Key" : "KZBCustom.Current." + variable
                    ])
            }
            settings[preferenceKey] = updatedPreferences
            println("Updating settings at \(settingsPath)")
            return settings.writeToFile(settingsPath, atomically: true)
        }
    }
    return false
}

func processEnvs(bundledPlistPath: String, srcPlistPath: String, bundledSettingsPath: String, defaultEnv: String, configuration: String) -> Bool {
    let plist = NSDictionary(contentsOfFile: bundledPlistPath)
    let availableEnvs = (plist as [String:AnyObject])[envKey] as [String]
    
    if validateEnvSettings(plist, prependMessage: "\(srcPlistPath):1:") {
        //for release - clean KZBEnvironments.plist. Remove all values not related to Release default environment (PRODUCTION in most cases)
        if(configuration == "Release"){
            let productionSettings = filterEnvSettings(plist!, defaultEnv, prependMessage: "\(srcPlistPath):1:")
            productionSettings.writeToFile(bundledPlistPath, atomically: true)
            return true
        }
        //for other than Release, adjust settings.
        else {
            let settingsAdjusted = processSettings(bundledSettingsPath, availableEnvs, defaultEnv, plist!)
            if settingsAdjusted == false {
                println("\(__FILE__):\(__LINE__): Unable to adjust settings bundle")
            }
            return settingsAdjusted
        }
        
    }
    
    return false
}

let count = Process.arguments.count
if count != 6 {
    println("\(__FILE__):\(__LINE__): Received \(count) arguments. Proper usage: processEnvironments.swift -- [bundledPlistPath] [srcPlistPath] [settingsPath] [defaultEnv] [configuration]")
    exit(1)
}

let bundledPlistPath = Process.arguments[1]
let srcPlistPath = Process.arguments[2]
let bundledSettingsPath = Process.arguments[3]
let defaultEnv = Process.arguments[4]
let configuration = Process.arguments[5]

exit(processEnvs(bundledPlistPath, srcPlistPath, bundledSettingsPath, defaultEnv, configuration) == true ? 0 : 1)
