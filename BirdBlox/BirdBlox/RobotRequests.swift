//
//  RobotRequests.swift
//  BirdBlox
//
//  Created by Jeremy Huang on 2017-07-21.
//  Copyright © 2017年 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import CoreBluetooth
//import Swifter


class RobotRequests {
	private let bleCenter = BLECentralManager.shared
	
	static private let robotTypeKey = "type"
	
	static private func handler(fromIDAndTypeHandler:
								@escaping ((String, BBTRobotType, HttpRequest) -> HttpResponse))
	-> ((HttpRequest) -> HttpResponse) {
		
		func handler(request: HttpRequest) -> HttpResponse {
			let queries = BBTSequentialQueryArrayToDict(request.queryParams)
			
			guard let idStr = queries["id"],
				let typeStr = queries[RobotRequests.robotTypeKey] else {
					return .badRequest(.text("Missing parameter"))
			}
			guard let type = BBTRobotType.fromString(typeStr) else {
				return .badRequest(.text("Invalid robot type: \(typeStr)"))
			}
			
			return fromIDAndTypeHandler(idStr, type, request)
		}
		
		return handler
	}
	
	public func loadRequests(server: BBTBackendServer) {
		server["/robot/startDiscover"] = self.discoverRequest
		server["/robot/stopDiscover"] = self.stopDiscoverRequest
		
		server["/robot/connect"] = RobotRequests.handler(fromIDAndTypeHandler: self.connectRequest)
		server["/robot/disconnect"] = self.disconnectRequest
		
		server["/robot/stopAll"] = self.stopAllRequest
        
		server["/robot/out/triled"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setTriLEDRequest)
        server["/robot/out/beak"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setTriLEDRequest)
        server["/robot/out/tail"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setTriLEDRequest)
        
		server["/robot/out/servo"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setServoRequest)
		
		server["/robot/out/stopEverything"] = self.stopAllRequest
		server["/robot/out/led"] = RobotRequests.handler(fromIDAndTypeHandler: self.setLEDRequest)
		server["/robot/out/vibration"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setVibrationRequest)
		server["/robot/out/motor"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setMotorRequest)
        server["/robot/out/motors"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setMotorsRequest)
		
		server["/robot/out/buzzer"] =
			RobotRequests.handler(fromIDAndTypeHandler: self.setBuzzerRequest)
        
        server["/robot/out/ledArray"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setLedArrayRequest)
        server["/robot/out/printBlock"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.setLedArrayRequest)
        server["robot/out/compassCalibrate"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.compassCalibrateRequest)
        server["robot/out/write"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.writeToMBPinRequest)
        server["robot/out/resetEncoders"] =
            RobotRequests.handler(fromIDAndTypeHandler: self.resetEncodersRequest)
		
		server["/robot/in"] = RobotRequests.handler(fromIDAndTypeHandler: self.inputRequest)
        //server["/robot/out/compass"] = RobotRequests.handler(fromIDAndTypeHandler: self.compassRequest)
		
		server["/robot/showInfo"] = RobotRequests.handler(fromIDAndTypeHandler: self.infoRequest)
		
	}
	
	private func discoverRequest(request: HttpRequest) -> HttpResponse {
		//let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		print("Discover request received.")
        /*
		guard let typeStr = queries[RobotRequests.robotTypeKey] else {
			return .badRequest(.text("Missing Query Parameter"))
		}
		guard let type = BBTRobotType.fromString(typeStr) else {
			return .badRequest(.text("Invalid robot type: \(typeStr)"))
		}*/
		
        //TODO: iterate over all available robot types when this becomes possible in new versions of swift
		bleCenter.startScan(serviceUUIDs: [BBTRobotType.Hummingbird.scanningUUID], updateDiscovered: { (peripherals) in
			let altName = "Fetching name..."
            //let filteredList = peripherals.filter { $0.2 == type }
            let filteredList = peripherals.filter { $0.3 > Date().addingTimeInterval(-3.0) } //remove any robot we have not found in the last 3 seconds
            //print("Filtered list: \(filteredList.map { (p, r, t, f) in r })")
            let darray = filteredList.map { (arg) -> [String: String] in
                let (peripheral, rssi, type, _) = arg
                return ["id": peripheral.identifier.uuidString,
				 "name": BBTgetDeviceNameForGAPName(peripheral.name ?? altName),
                 //"device": BBTRobotType.fromString(peripheral.name ?? altName)?.description ?? altName,
                 "device": type.description,
                 //"RSSI": rssi.stringValue]
                "RSSI": mode(Array(rssi.suffix(50))).stringValue] //peripherals are discovered more than 30 times per second
			}
            //print("list: \(peripherals) filteredList: \(filteredList) darray: \(darray.map{ $0["RSSI"] })")
            print("Updating: \(darray.map{ "\($0["name"] ?? "?"): \($0["RSSI"] ?? "?"): \($0["id"] ?? "?"): \($0["device"] ?? "?")" })")
			let _ = FrontendCallbackCenter.shared.updateDiscoveredRobotList(robotList: darray)
		}, scanEnded: {
			let _ = FrontendCallbackCenter.shared.scanHasStopped()
		})
		
		return .ok(.text("Scanning started"))
	}
	
	private func stopDiscoverRequest(request: HttpRequest) -> HttpResponse {
		bleCenter.stopScan()
		return .ok(.text("Stopped scanning"))
	}
	
	
	private func connectRequest(id: String, type: BBTRobotType,
	                            request: HttpRequest) -> HttpResponse {
		let idExists = bleCenter.connectToRobot(byID: id, ofType: type)
		
		if idExists == false {
			return .notFound
		}
		
		return .ok(.text("Connected!"))
	}
	
	private func disconnectRequest(request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let id = queries["id"] else {
			return .badRequest(.text("Missing Parameter"))
		}
		//Disconnect even if the robot is still initializing
//		guard bleCenter.isRobotWithIDConnected(id) else {
//			return .notFound
//		}
		
		bleCenter.disconnect(byID: id)
		return .ok(.text("Disconnected"))
	}
	
	
	private func infoRequest(id: String, type: BBTRobotType,
	                         request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let id = queries["id"] else {
			return .badRequest(.text("Missing Parameter"))
		}
		guard let robot = bleCenter.robotForID(id) else {
			return .notFound
		}
		
		let text = FrontendCallbackCenter.safeString(from: robot.description)
		
		let _ = FrontendCallbackCenter.shared.echo(getRequestString:
			"/tablet/choice?question=\(text)&button1=Dismiss")
		
		
		return .ok(.text("Info shown"))
	}
	
	
	//MARK: Requests for all types
	
	private func stopAllRequest(request: HttpRequest) -> HttpResponse {
		bleCenter.forEachConnectedRobots(do: { robot in
			let _ = robot.setAllOutputsToOff()
		})
		
		return .ok(.text("Issued stop commands to every connected device."))
	}
	
	private func getRobotOrResponse(id: String, type: BBTRobotType, acceptTypes: [BBTRobotType])
	 -> (BBTRobotBLEPeripheral?, HttpResponse?) {
		guard let robot = bleCenter.robotForID(id) else {
			return (nil, .notFound)
		}
		
		guard robot.type == type else {
			return (nil,.badRequest(.text("Type of robot does not match type passed in parameter")))
		}
		
		guard acceptTypes.contains(robot.type) else {
			return (nil, .badRequest(.text("Operation not supported by type")))
		}
		
		return (robot, nil)
	}
	
    //MARK: Inputs
    
	private func inputRequest(id: String, type: BBTRobotType,
	                          request: HttpRequest) -> HttpResponse {
        
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		guard let sensor = queries["sensor"] else {
            return .badRequest(.text("Malformed Request - sensor type missing"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Flutter, .Hummingbird, .HummingbirdBit, .Finch, .MicroBit])
		guard let robot = roboto else {
			return requesto!
		}
		
		let values = robot.sensorValues
		var sensorValue: String
        
        let rawAcc = Array(values[robot.type.accXindex...(robot.type.accXindex + 2)])
        var accValues = [0.0, 0.0, 0.0]
        if (type == .Finch) {
            let rawFinchAcc = rawToRawFinchAccelerometer(rawAcc)
            accValues = [rawToAccelerometer(rawFinchAcc[0]), rawToAccelerometer(rawFinchAcc[1]), rawToAccelerometer(rawFinchAcc[2])]
        } else {
            accValues = [rawToAccelerometer(rawAcc[0]), rawToAccelerometer(rawAcc[1]), rawToAccelerometer(rawAcc[2])]
        }
        
		//print("about to return sensor values \(values)")
		switch sensor {
            
        case "isMoving":
            if values[4] > 127 {sensorValue = String(1)} else {sensorValue = String(0)}
            
        //Screen up and Screen down are z: Acc Z > 0.8*g screen down, Acc Z < -0.8*g screen up
        //Tilt left and tilt right are x: Acc X > 0.8g tilt left, Acc X < -0.8g tilt right
        //Logo up and logo down are y: Acc Y > 0.8g logo down, Acc Y < -0.8g logo up
        // 0.8g = 7.848m/s2
        case "screenUp":
            //let val = rawToAccelerometer(rawAcc[2])
            //if val < -0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            //if val < -7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
            if accValues[2] < -7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "screenDown":
            //let val = rawToAccelerometer(rawAcc[2])
            //if val > 0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            //if val > 7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
            if accValues[2] > 7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "tiltLeft":
            //let val = rawToAccelerometer(rawAcc[0])
            //if val > 0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            //if val > 7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
            if accValues[0] > 7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "tiltRight":
            //let val = rawToAccelerometer(rawAcc[0])
            //if val < -0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            //if val < -7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
            if accValues[0] < -7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "logoUp":
            //let val = rawToAccelerometer(rawAcc[1])
            //if val < -0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            //if val < -7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
            if accValues[1] < -7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "logoDown":
            //let val = rawToAccelerometer(rawAcc[1])
            //if val > 0.8 {sensorValue = String(1)} else {sensorValue = String(0)}
            //if val > 7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
            if accValues[1] > 7.848 {sensorValue = String(1)} else {sensorValue = String(0)}
        case "buttonA", "buttonB", "shake": //microbit buttons and shake
            let buttonShake = values[robot.type.buttonShakeIndex]
            let bsBitValues = byteToBits(buttonShake)
            //TODO: should the buttons return true when pressed?
            switch sensor {
            case "buttonA":
                let val = bsBitValues[4]
                if val == 0 {
                    sensorValue = String(1)
                } else {
                    sensorValue = String(0)
                }
            case "buttonB":
                let val = bsBitValues[5]
                if val == 0 {
                    sensorValue = String(1)
                } else {
                    sensorValue = String(0)
                }
            case "shake": sensorValue = String(bsBitValues[0])
            default: return .badRequest(.text("sensor not specified correctly"))
            }
            
        //TODO: add a check to make sure there is an accelerometer or magnetometer when requested
        case "accelerometer": 
            guard let axis = queries["axis"] else {
                return .badRequest(.text("Accelerometer axis not specified."))
            }
            
            /*let xIndex = robot.type.accXindex
            
            switch axis {
            case "x": sensorValue = String(rawToAccelerometer(values[xIndex]))
            case "y": sensorValue = String(rawToAccelerometer(values[xIndex + 1]))
            case "z": sensorValue = String(rawToAccelerometer(values[xIndex + 2]))
            default:
                return .badRequest(.text("Accelerometer axis incorrectly specified as \(axis)"))
            }*/
            switch axis {
            case "x": sensorValue = String(accValues[0])
            case "y": sensorValue = String(accValues[1])
            case "z": sensorValue = String(accValues[2])
            default:
                return .badRequest(.text("Accelerometer axis incorrectly specified as \(axis)"))
            }
        case "magnetometer":
            guard let axis = queries["axis"] else {
                return .badRequest(.text("Accelerometer axis not specified."))
            }/*
            let adjust: ((UInt8, UInt8) -> String) = { msb, lsb in
                let uIntVal = (UInt16(msb) << 8) | UInt16(lsb)
                let intVal = Int16(bitPattern: uIntVal)
                print( "MAGNETOMETER VALUES! \(msb) \(lsb) \(uIntVal) \(intVal)" )
                return String( intVal / 10 ) //TODO: check
            }
            let x = adjust(values[8], values[9])
            let y = adjust(values[10], values[11])
            let z = adjust(values[12], values[13])
            */
            //let (x, y, z) = magnetometerValues(values)
            switch robot.type {
            case .Finch:
                let finchMag = rawToFinchMagnetometer(Array(values[17...19]))
                switch axis {
                case "x": sensorValue = String(Int(finchMag[0].rounded()))
                case "y": sensorValue = String(Int(finchMag[1].rounded()))
                case "z": sensorValue = String(Int(finchMag[2].rounded()))
                default:
                    return .badRequest(.text("Magnetometer axis not specified."))
                }
                /*
                //Values for the finch are already in uT, and don't need conversion
                switch axis {
                case "x": sensorValue = String(Int8(bitPattern: values[17]))
                case "y": sensorValue = String(Int8(bitPattern: values[18]))
                case "z": sensorValue = String(Int8(bitPattern: values[19]))
                default:
                    return .badRequest(.text("Magnetometer axis not specified."))
                }*/
            case .HummingbirdBit, .MicroBit:
                switch axis {
                case "x": sensorValue = String(rawToMagnetometer(values[8], values[9]))
                case "y": sensorValue = String(rawToMagnetometer(values[10], values[11]))
                case "z": sensorValue = String(rawToMagnetometer(values[12], values[13]))
                default:
                    return .badRequest(.text("Magnetometer axis not specified."))
                }
            default:
                return .badRequest(.text("robot type not supported for magnetometer block."))
            }
        case "compass":
            switch robot.type {
            case .Finch:
                let finchMaguT = rawToFinchMagnetometer(Array(values[17...19]))
                let finchMag = finchMaguT
                //let finchMag = finchMaguT.map { $0 * 10 } //convert to units used in microbit
                let rawFinchAcc = rawToRawFinchAccelerometer(rawAcc)
                if let finchRawCompass = DoubleToCompass(acc: rawFinchAcc, mag: finchMag) {
                    //turn it around so that the finch beak points north at 0
                    let finchCompass = (finchRawCompass + 180) % 360
                    sensorValue = String(finchCompass)
                } else {
                    sensorValue = "nil"
                }
            case .HummingbirdBit, .MicroBit:
                let magArray = Array(values[8...13])
                if let compass = rawToCompass(rawAcc: rawAcc, rawMag: magArray) {
                    sensorValue = String(compass)
                } else {
                    sensorValue = "nil"
                }
            default:
                return .badRequest(.text("robot type not supported for compass block."))
            }
            /*var magArray:[UInt8]
            switch robot.type {
            case .Finch:
                magArray = Array(values[17...19])
            default: //.HummingbirdBit and .MicroBit
                magArray = Array(values[8...13])
            }
            //print("Compass!! \(values) \(accArray) \(magArray)")
            if let compass = rawToCompass(rawAcc: rawAcc, rawMag: magArray) {
                sensorValue = String(compass)
            } else {
                sensorValue = "nil"
            }*/
        case "battery":
            if let i = robot.type.batteryVoltageIndex {
                //sensorValue = String(rawToVoltage(values[i]))
                sensorValue = String(Double(values[i]) * robot.type.rawToBatteryVoltage)
                print("\(sensorValue)")
            } else {
                return .badRequest(.text("robot type not supported battery values."))
            }
		default:
            
            var value:UInt8 = 0
            var port:Int = 0
            if robot.type != .Finch { //Finch has no ports
                //For hummingbird type sensors, a port will be specified.
                //These sensor values will be in the first 4 value array spots.
                //Also used for micro:bit pins
                guard let portStr = queries["port"], let portInt = Int(portStr) else {
                    return .badRequest(.text("Malformed Request - port not specified."))
                }
                
                port = portInt - 1
                guard port < robot.type.sensorPortCount && port >= 0 else {
                    return .badRequest(.text("Port is out of bounds"))
                }
                
                value = values[port]
            }
            let percent = UInt8(rawToPercent(value))
            let realPercent = Double(value) / 2.55
            
            switch sensor {
            case "pin":
                //If the pin is not already in read mode, we must change modes
                // and then wait for a new sensor value.
                let scaledPin: (UInt8) -> String = { String(round(Double($0) * (114/255))) }
                if !robot.checkReadMode(forPin: port) {
                    if robot.setMicroBitRead(port) {
                        Thread.sleep(forTimeInterval: 0.2)
                        let newVals = robot.sensorValues
                        print("Read mode updated for pin \(port), thread slept. returning \(newVals[port]) from \(newVals)")
                        sensorValue = scaledPin(newVals[port])
                    } else {
                        return .internalServerError
                    }
                } else {
                    print("Value for pin \(port) is \(value). \(values)")
                    sensorValue = scaledPin(value)
                }
            case "dial":
                var scaledVal = Int( round(Double(value) * (100 / 230)) )
                if scaledVal > 100 { scaledVal = 100 }
                sensorValue = String(scaledVal)
            case "distance":
                if robot.type == .Finch {
                    let msb = Int(values[0])
                    let lsb = Int(values[1])
                    let num = (msb << 8) + lsb
                    //sensorValue = String(Int(round(Double(num) * (117/100))))
                    sensorValue = String(num)
                } else if robot.type == .HummingbirdBit {
                    sensorValue = String(Int(round(Double(value) * (117/100))))
                } else {
                    sensorValue = String(rawToDistance(value))
                }
            case "temperature":
                sensorValue = String(rawToTemp(value))
            case "soil":
                sensorValue = String(bound(Int(percent), min: 0, max: 90))
            case "sound":
                if robot.type == .HummingbirdBit {
                    sensorValue = String(round(Double(value) * (200/255))) //scaling from bambi
                } else {
                    //Raw values are already in the approximate range of 0 to 100
                    sensorValue = String(value)
                }
            case "light":
                if robot.type == .Finch {
                    guard let position = queries["position"] else {
                        return .badRequest(.text("Specific light sensor not specified."))
                    }
                    if position == "right" {
                        sensorValue = String(values[3])
                    } else {
                        sensorValue = String(values[2])
                    }
                } else {
                    return .ok(.text(String(realPercent)))
                }
            case "line":
                guard let position = queries["position"] else {
                    return .badRequest(.text("Specific line sensor not specified."))
                }
                if position == "right" {
                    sensorValue = String(values[5])
                } else {
                    //the value for the left line sensor also contains the move flag
                    var val = values[4]
                    if val > 127 { val -= 128 }
                    sensorValue = String(val)
                }
            case "encoder":
                guard let position = queries["position"] else {
                    return .badRequest(.text("Specific line sensor not specified."))
                }
                var i = 7
                if position == "right" {
                    i = 10
                }
                //3 bytes is a 24bit int which is not a type in swift. Therefore, we shove the bytes over such that the sign will be carried over correctly when converted and then divide to go back to 24bit.
                let uNum = (UInt32(values[i]) << 24) + (UInt32(values[i+1]) << 16) + (UInt32(values[i+2]) << 8)
                let num = Int32(bitPattern: uNum) / 256
                print("encoder \(values[i]) \(values[i+1]) \(values[i+2]) \(uNum) \(num)")
                sensorValue = String( num )
                
            case "other":
                sensorValue = String(Double(value) * (3.3/255))
            default:
                return .ok(.text(String(realPercent)))
            }
		}
		
		return .ok(.text(sensorValue))
	}
	/*
    private func compassRequest(id: String, type: BBTRobotType,
                                request: HttpRequest) -> HttpResponse {
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.HummingbirdBit, .Finch, .MicroBit])
        
        guard let robot = roboto else {
            return requesto!
        }
        
        //let (imx, imy, imz) = magnetometerValues(robot.sensorValues)
        //let (mx, my, mz) = (Double(imx), Double(imy), Double(imz))
        //let (ax, ay, az) = accelerometerValues(robot.sensorValues)
        let values = robot.sensorValues
        //let mx = Double(magVal(values[8], values[9]))
        //let my = Double(magVal(values[10], values[11]))
        //let mz = Double(magVal(values[12], values[13]))
        
        let mx = rawToRawMag(values[8], values[9])
        let my = rawToRawMag(values[10], values[11])
        let mz = rawToRawMag(values[12], values[13])
        
        let ax = Double(Int8(bitPattern: values[4]))
        let ay = Double(Int8(bitPattern: values[5]))
        let az = Double(Int8(bitPattern: values[6]))
        
        //let mx = Double((UInt16(values[9]) & 0xFF) | (UInt16(values[8]) << 8))
        //let my = Double((UInt16(values[11]) & 0xFF) | (UInt16(values[10]) << 8))
        //let mz = Double((UInt16(values[13]) & 0xFF) | (UInt16(values[12]) << 8))
        
        let phi = atan(-ay/az)
        let theta = atan( ax / (ay*sin(phi) + az*cos(phi)) )
        
        let xP = mx
        let yP = my * cos(phi) - mz * sin(phi)
        let zP = my * sin(phi) + mz * cos(phi)
        
        let xPP = xP * cos(theta) + zP * sin(theta)
        let yPP = yP
        
        //let angle = 180 + atan2(xPP, yPP)
        let angle = 180 + GLKMathRadiansToDegrees(Float(atan2(xPP, yPP)))
        let roundedAngle = Int(angle.rounded())
        
        return .ok(.text(String(roundedAngle)))
    }*/
    /*
    private func magnetometerValues(_ values: [UInt8]) -> (Int, Int, Int) {
        /*let adjust: ((UInt8, UInt8) -> Int) = { msb, lsb in
            let uIntVal = (UInt16(msb) << 8) | UInt16(lsb)
            let intVal = Int16(bitPattern: uIntVal)
            print( "MAGNETOMETER VALUES! \(msb) \(lsb) \(uIntVal) \(intVal)" )
            return Int( intVal / 10 ) //TODO: check
        }
        let x = adjust(values[8], values[9])
        let y = adjust(values[10], values[11])
        let z = adjust(values[12], values[13])
        */
        let x = magVal(values[8], values[9]) // / 10
        let y = magVal(values[10], values[11]) // / 10
        let z = magVal(values[12], values[13]) // / 10
        
        return (x, y, z)
    }
    
    private func magVal(_ msb: UInt8, _ lsb: UInt8) -> Int {
        let uIntVal = (UInt16(msb) << 8) | UInt16(lsb)
        let intVal = Int16(bitPattern: uIntVal)
        print( "MAGNETOMETER VALUES! \(msb) \(lsb) \(uIntVal) \(intVal)" )
        return Int( intVal )
    }
    
    private func accelerometerValues(_ values: [UInt8]) -> (Double, Double, Double) {
        let x = accelerometerAdjust(values[4])
        let y = accelerometerAdjust(values[5])
        let z = accelerometerAdjust(values[6])
        
        return (x, y, z)
    }
    
    //The accelerometer values are used for multiple blocks
    private func accelerometerAdjust (_ x: UInt8) -> Double {
        let intVal = Int8(bitPattern: x) //convert to 2's complement signed int
        let scaledVal = Double(intVal) * 196/1280 //scaling from bambi
        print("ACCELEROMETER VALUES! \(x) \(intVal) \(scaledVal)")
        return scaledVal
    }*/
    
    
	
	//MARK: Outputs
    
    private func setTriLEDRequest(id: String, type: BBTRobotType,
                                  request: HttpRequest) -> HttpResponse {
        let queries = BBTSequentialQueryArrayToDict(request.queryParams)
        
        guard let redStr = queries["red"],
            let greenStr = queries["green"],
            let blueStr = queries["blue"],
            let red = UInt8(redStr),
            let green = UInt8(greenStr),
            let blue = UInt8(blueStr),
            red <= 100, green <= 100, blue <= 100 else {
                return .badRequest(.text("Missing or invalid parameters"))
        }
        
        var port:UInt = 0
        if request.path.contains("beak") { //Finch Beak
            port = 1
        } else if request.path.contains("tail") { //Finch Tail
            guard let portStr = queries["port"] else {
                return .badRequest(.text("Missing or invalid tail parameters"))
            }
            if portStr == "all" {
                port = 6
            } else {
                guard let portNum = UInt(portStr) else {
                    return .badRequest(.text("Invalid tail port"))
                }
                port = portNum + 1
            }
        } else { //Hummingbird Duo and Bit tri-leds
            guard let portStr = queries["port"], let portNum = UInt(portStr) else {
                return .badRequest(.text("Missing or invalid tri-led parameters"))
            }
            port = portNum
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.Hummingbird, .HummingbirdBit, .Finch, .Flutter])
        guard let robot = roboto else {
            return requesto!
        }
        
        let scaled: ((UInt8) -> UInt8) = { intensity in
            return UInt8(round(Double(intensity) * (255/100)))
        }
        
        //In the case of all tail, we must set several leds
        if port == 6 {
            if robot.setTriLED(port: 2, intensities: BBTTriLED(scaled(red), scaled(green), scaled(blue))) {
                if robot.setTriLED(port: 3, intensities: BBTTriLED(scaled(red), scaled(green), scaled(blue))) {
                    if robot.setTriLED(port: 4, intensities: BBTTriLED(scaled(red), scaled(green), scaled(blue))) {
                        if robot.setTriLED(port: 5, intensities: BBTTriLED(scaled(red), scaled(green), scaled(blue))) {
                            return .ok(.text("set"))
                        }
                    }
                }
            } else {
                return .internalServerError
            }
        }
        
        if robot.setTriLED(port: port, intensities: BBTTriLED(scaled(red), scaled(green), scaled(blue))) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
    }
    
    private func setServoRequest(id: String, type: BBTRobotType,
                                 request: HttpRequest) -> HttpResponse {
        let queries = BBTSequentialQueryArrayToDict(request.queryParams)
        
        guard let portStr = queries["port"],
            let port = UInt(portStr)  else {
                return .badRequest(.text("Missing or invalid port"))
        }
        
        //sending 255 turns it off
        var value: UInt8 = 0
        if let angleStr = queries["angle"], let angle = UInt8(angleStr) {
            //let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
            switch type {
            case .Hummingbird:
                let adjustServo: ((UInt8) -> UInt8) = { ($0 > 180) ? 255 : $0 + ($0 >> 2) }
                value = adjustServo(angle)
            case .HummingbirdBit:
                if angle > 180 { value = UInt8(254)
                } else {
                    value = UInt8( round(Double(angle) * (254 / 180)) )
                }
            default: fatalError("position servo not set up for type \(type)")
            }
            //This is only for rotation servos. Currently only available in hummingbird bit
        } else if let percentStr = queries["percent"], let percent = Int(percentStr) {
            if percent >= -10 && percent <= 10 { value = UInt8(255) //off signal
            } else if percent > 100 { value = UInt8(254)
            } else if percent < -100 { value = UInt8(0)
            } else { value = UInt8( ( (percent * 23) / 100 ) + 122 ) } //from bambi
        } else {
            return .badRequest(.text("Missing or invalid parameter"))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.Hummingbird, .HummingbirdBit, .Flutter])
        guard let robot = roboto else {
            return requesto!
        }
        
        if robot.setServo(port: port, value: value) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
    }
	
	private func setLEDRequest(id: String, type: BBTRobotType,
	                           request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let intensityStr = queries["intensity"],
			let port = Int(portStr),
			let intensity = UInt8(intensityStr),
            intensity <= 100 else {
			
			return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird, .HummingbirdBit])
		guard let robot = roboto else {
			return requesto!
		}
		
        let scaledIntensity = UInt8(round(Double(intensity) * (255/100)))
		if robot.setLED(port: port, intensity: scaledIntensity) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	private func setVibrationRequest(id: String, type: BBTRobotType,
	                                 request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let intensityStr = queries["intensity"],
			let port = Int(portStr),
			let intensity = UInt8(intensityStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird])
		guard let robot = roboto else {
			return requesto!
		}
		
		if robot.setVibration(port: port, intensity: intensity) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
	
	private func setMotorRequest(id: String, type: BBTRobotType,
	                             request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
		
		guard let portStr = queries["port"],
			let speedStr = queries["speed"],
			let port = Int(portStr),
			let speed = Int(speedStr) else {
				
				return .badRequest(.text("Missing or invalid parameters"))
		}
		
		let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
		                                                 acceptTypes: [.Hummingbird])
		guard let robot = roboto else {
			return requesto!
		}
		
		if robot.setMotor(port: port, speed: Int8(speed)) {
			return .ok(.text("set"))
		} else {
			return .internalServerError
		}
	}
    
    //Handle a request that sets 2 motors at once
    //Just used with the finch
    private func setMotorsRequest(id: String, type: BBTRobotType,
                                 request: HttpRequest) -> HttpResponse {
        let queries = BBTSequentialQueryArrayToDict(request.queryParams)
        
        guard let speedLStr = queries["speedL"], let speedRStr = queries["speedR"],
            let speedL = Int8(speedLStr), let speedR = Int8(speedRStr),
            let ticksLStr = queries["ticksL"], let ticksRStr = queries["ticksR"],
            let ticksL = Int(ticksLStr), let ticksR = Int(ticksRStr) else {
                
                return .badRequest(.text("Missing or invalid parameters"))
        }

        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.Finch])
        guard let robot = roboto else {
            return requesto!
        }
        print("found robot, ready to set motors... \(speedL) \(ticksL) \(speedR) \(ticksR)")

        if robot.setMotors(speedL: speedL, ticksL: ticksL, speedR: speedR, ticksR: ticksR) {
            //if (ticksL != 0 || ticksR != 0) && (speedL != 0 || speedR != 0){
            /*if (ticksL != 0 && speedL != 0) && (ticksR != 0 && speedR != 0) { //assumes all turns involve both wheels.
                return .finchMoving
            } else {*/
                return .ok(.text("set"))
            //}
        } else {
            return .internalServerError
        }
    }
	
	
	private func setBuzzerRequest(id: String, type: BBTRobotType,
	                              request: HttpRequest) -> HttpResponse {
		let queries = BBTSequentialQueryArrayToDict(request.queryParams)
        
        guard let noteStr = queries["note"], let durationStr = queries["duration"],
            let note = UInt8(noteStr), let exactDur = Double(durationStr) else {
            return .badRequest(.text("Missing or invalid parameters"))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.Finch, .HummingbirdBit, .MicroBit])
        guard let robot = roboto else {
            return requesto!
        }
        
        let duration = UInt16(round(exactDur))
        
        if let period = noteToPeriod(note), robot.setBuzzer(period: period, duration: duration) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
        
	}
	
    private func setLedArrayRequest(id: String, type: BBTRobotType,
                                  request: HttpRequest) -> HttpResponse {
        let queries = BBTSequentialQueryArrayToDict(request.queryParams)
        var ledStatusString:[String] = []
        
        if request.path.contains("printBlock") {
            guard let printString = queries["printString"] else {
                return .badRequest(.text("String to print not specified."))
            }
            
            ledStatusString.append("F" + String(printString.prefix(18)))
            
            
        } else if request.path.contains("ledArray") {
            guard let ledArrayStatus = queries["ledArrayStatus"] else {
                return .badRequest(.text("Missing or invalid parameters in set led array request"))
            }
            ledStatusString.append("S" + ledArrayStatus)
        } else {
            return .badRequest(.text("Specify printBlock or ledArray when setting the array"))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.MicroBit, .HummingbirdBit, .Finch])
        
        guard let robot = roboto else {
            return requesto!
        }
        
        print("led array string: \(ledStatusString)")
        if robot.setLedArray(ledStatusString[0]) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
    }
    
    private func writeToMBPinRequest(id: String, type: BBTRobotType,
                                     request: HttpRequest) -> HttpResponse {
        let queries = BBTSequentialQueryArrayToDict(request.queryParams)

        guard let pinString = queries["port"], let pinNum = Int(pinString),
            let percentString = queries["percent"], let percent = Int(percentString) else {
            return .badRequest(.text("Poorly formed write request."))
        }
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.MicroBit])
        
        guard let robot = roboto else {
            return requesto!
        }
        
        let scaledValue = UInt8(percent * 255/100)
        print("write request for pin \(pinNum), value \(scaledValue) from \(percent)")
        
        if robot.setMicroBitPin(pinNum, scaledValue) {
            return .ok(.text("set"))
        } else {
            return .internalServerError
        }
    }
    
    private func compassCalibrateRequest(id: String, type: BBTRobotType,
                                    request: HttpRequest) -> HttpResponse {
        
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.MicroBit, .HummingbirdBit, .Finch])
        
        guard let robot = roboto else {
            return requesto!
        }
        
        if robot.calibrateCompass() {
            return .ok(.text("calibrating"))
        } else {
            return .internalServerError
        }
    }
    
    private func resetEncodersRequest(id: String, type: BBTRobotType,
                                      request: HttpRequest) -> HttpResponse {
        let (roboto, requesto) = self.getRobotOrResponse(id: id, type: type,
                                                         acceptTypes: [.MicroBit, .HummingbirdBit, .Finch])
        
        guard let robot = roboto else {
            return requesto!
        }
        
        if robot.resetEncoders() {
            return .ok(.text("encoders reset"))
        } else {
            return .internalServerError
        }
    }
}
