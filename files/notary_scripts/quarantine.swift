#!/usr/bin/swift

import Foundation

struct swifterr: TextOutputStream {
    public static var stream = swifterr()
    mutating func write(_ string: String) { fputs(string, stderr) }
}

if #available(macOS 10.10, *) {
    if (CommandLine.arguments.count < 2) {
        print("usage: swift quarantine.swift <file>", to: &swifterr.stream)
        exit(1)
    }

    let dataLocationUrl: NSURL = NSURL.init(fileURLWithPath: CommandLine.arguments[1])

    var errorBag: NSError?

    let quarantineProperties: [String: Any] = [
        kLSQuarantineAgentNameKey as String: "Quarantine Tester",
        kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
        kLSQuarantineDataURLKey as String: "http://www.example.com/data_url",
        kLSQuarantineOriginURLKey as String: "http://www.example.com/"
    ]

    if (dataLocationUrl.checkResourceIsReachableAndReturnError(&errorBag)) {
        do {
            try dataLocationUrl.setResourceValue(
                quarantineProperties as NSDictionary,
                forKey: URLResourceKey.quarantinePropertiesKey
            )
        }
        catch {
            print(error.localizedDescription, to: &swifterr.stream)
            exit(1)
        }
    }
    else {
        print(errorBag!.localizedDescription, to: &swifterr.stream)
        exit(1)
    }

    exit(0)
}
else {
    print("Quarantine API not available on 10.9 and earlier", to: &swifterr.stream)
    exit(1)
}
