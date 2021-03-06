//
//  Control.swift
//  Cameo
//
//  Created by Tamás Lustyik on 2019. 01. 06..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation
import CoreMediaIO
import CameoSDK

struct BooleanControlModel {
    var controlID: CMIOObjectID = CMIOObjectID(kCMIOObjectUnknown)
    var name: String = ""
    var value: Bool = false
}

struct SelectorControlModel {
    var controlID: CMIOObjectID = CMIOObjectID(kCMIOObjectUnknown)
    var name: String = ""
    var items: [(UInt32, String)] = []
    var currentItemID: UInt32 = 0
    var currentItemIndex: Int? {
        return items.firstIndex(where: { $0.0 == currentItemID })
    }
}

struct FeatureControlModel {
    var controlID: CMIOObjectID = CMIOObjectID(kCMIOObjectUnknown)
    var name: String = ""
    var isEnabled: Bool = false
    var isAutomatic: Bool = false
    var isTuning: Bool = false
    var isInAbsoluteUnits: Bool = false
    var minValue: Float = 0
    var maxValue: Float = 0
    var currentValue: Float = 0
    var unitName: String?
}

enum ControlModel {
    case boolean(BooleanControlModel)
    case selector(SelectorControlModel)
    case feature(FeatureControlModel)
}

enum CMIOError: Error {
    case unknown
}

enum Control {
    static func model(for controlID: CMIOObjectID) -> ControlModel? {
        guard
            let classID: CMIOClassID = ObjectProperty.class.value(in: controlID),
            let cfName: CFString = ObjectProperty.name.value(in: controlID)
        else {
            return nil
        }
        
        let name = cfName as String
        
        if classID.isSubclass(of: .booleanControl) {
            guard
                let value: UInt32 = BooleanControlProperty.value.value(in: controlID)
            else {
                return nil
            }
            
            return .boolean(BooleanControlModel(controlID: controlID, name: name, value: value != 0))
        }
        else if classID.isSubclass(of: .selectorControl) {
            guard
                let itemIDs: [UInt32] = SelectorControlProperty.availableItems.arrayValue(in: controlID),
                let items: [(UInt32, String)] = try? itemIDs.map({
                    guard let cfItemName: CFString = SelectorControlProperty.itemName.value(qualifiedBy: Qualifier(from: $0),
                                                                                            in: controlID)
                    else {
                        throw CMIOError.unknown
                    }
                    return ($0, cfItemName as String)
                }),
                let currentItemID: UInt32 = SelectorControlProperty.currentItem.value(in: controlID)
            else {
                return nil
            }

            return .selector(SelectorControlModel(controlID: controlID,
                                                  name: name,
                                                  items: items,
                                                  currentItemID: currentItemID))
        }
        else if classID.isSubclass(of: .featureControl) {
            guard
                let isEnabled: UInt32 = FeatureControlProperty.onOff.value(in: controlID),
                let isAutomatic: UInt32 = FeatureControlProperty.automaticManual.value(in: controlID),
                let isInAbsoluteUnits: UInt32 = FeatureControlProperty.absoluteNative.value(in: controlID),
                let isTuning: UInt32 = FeatureControlProperty.tune.value(in: controlID)
            else {
                return nil
            }
            
            var model = FeatureControlModel()
            model.controlID = controlID
            model.name = name
            model.isEnabled = isEnabled != 0
            model.isAutomatic = isAutomatic != 0
            model.isInAbsoluteUnits = isInAbsoluteUnits != 0
            model.isTuning = isTuning != 0
            
            if isInAbsoluteUnits != 0 {
                guard
                    let cfUnitName: CFString = FeatureControlProperty.absoluteUnitName.value(in: controlID),
                    let range: AudioValueRange = FeatureControlProperty.absoluteRange.value(in: controlID),
                    let currentValue: Float = FeatureControlProperty.absoluteValue.value(in: controlID)
                else {
                    return nil
                }
                model.unitName = cfUnitName as String
                model.minValue = Float(range.mMinimum)
                model.maxValue = Float(range.mMaximum)
                model.currentValue = currentValue
            }
            else {
                guard
                    let range: AudioValueRange = FeatureControlProperty.nativeRange.value(in: controlID),
                    let currentValue: Float = FeatureControlProperty.nativeValue.value(in: controlID)
                else {
                    return nil
                }
                model.minValue = Float(range.mMinimum)
                model.maxValue = Float(range.mMaximum)
                model.currentValue = currentValue
            }

            return .feature(model)
        }
        else {
            return nil
        }
    }
}

