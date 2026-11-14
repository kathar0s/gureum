//
//  main.swift
//  Gureum
//
//  Created by Jeong YunWon on 2018. 9. 26..
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import Cocoa

// _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

let mainNibName = Bundle.main.infoDictionary!["NSMainNibFile"] as! String
let nib = NSNib(nibNamed: NSNib.Name(mainNibName), bundle: Bundle.main)!
var mainNibTopLevelObjects: NSArray?
if nib.instantiate(
  withOwner: NSApplication.shared, topLevelObjects: &mainNibTopLevelObjects) == false
{
  dlog(true, "!! Gureum fails to load Main Nib File !!")
}
dlog(true, "****   Main bundle \(mainNibName) loaded   ****")
withExtendedLifetime(mainNibTopLevelObjects) {
  NSApplication.shared.run()
}
dlog(true, "******* Gureum finalized! *******")
