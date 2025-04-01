//
//  ContentView.swift
//  BDKKyotoExample
//
//  Created by Robert Netzke on 7/12/24.
//

import SwiftUI
import BitcoinDevKit

let recv = try! Descriptor.init(descriptor: "tr([12071a7c/86'/1'/0']tpubDCaLkqfh67Qr7ZuRrUNrCYQ54sMjHfsJ4yQSGb3aBr1yqt3yXpamRBUwnGSnyNnxQYu7rqeBiPfw3mjBcFNX4ky2vhjj9bDrGstkfUbLB9T/0/*)", network: .signet);
let change = try! Descriptor.init(descriptor: "tr([12071a7c/86'/1'/0']tpubDCaLkqfh67Qr7ZuRrUNrCYQ54sMjHfsJ4yQSGb3aBr1yqt3yXpamRBUwnGSnyNnxQYu7rqeBiPfw3mjBcFNX4ky2vhjj9bDrGstkfUbLB9T/1/*)", network: .signet);
let path = URL.temporaryDirectory.path()

class MessageHandler: ObservableObject {
    @Published var progress: Float = 0
    @Published var height: UInt32? = nil
    @Published var connected: Bool = false
    
    func handleLog(log: BitcoinDevKit.Log) {
        DispatchQueue.main.async { [self] in
            switch log {
            case .debug(log: let log): print(log)
            case .connectionsMet: self.connected = true
            case .stateUpdate(nodeState: let state): print(state)
            case .txSent(txid: let txid): print("Sent transaction: \(txid)")
            case .progress(progress: let progress): self.progress = progress
            }
        }
    }
    
    func handleWarning(warn: BitcoinDevKit.Warning) {
        DispatchQueue.main.async { [self] in
            switch warn {
            case .needConnections: self.connected = false
            default: print(warn)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var messageHandler = MessageHandler()
    @State private var balance: UInt64 = 0;
    
    var body: some View {
        VStack{
            HStack {
                if messageHandler.connected {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(.red)
                }
                ProgressView(value: messageHandler.progress, total: 1.0)
                    .foregroundStyle(.green)
            }
            Spacer()
            Text("\(balance) Satoshis")
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .padding()
        .onAppear {
            let wallet = try! Wallet(descriptor: recv, changeDescriptor: change, network: .signet, connection: .newInMemory())
            balance = wallet.balance().total.toSat();
            let ip_addr = IpAddress.fromIpv4(q1: 174, q2: 50, q3: 212, q4: 60)
            let peer = Peer(address: ip_addr, port: nil, v2Transport: false)
            let spv = try! CbfBuilder()
                .connections(connections: 1)
                .dataDir(dataDir: path)
                .scanType(scanType: .recovery(fromHeight: 200_000))
                .build(wallet: wallet)
            let node = spv.node
            let client = spv.client
            node.run()
            Task {
                while true {
                    let update = await client.update();
                    if update != nil {
                        try! wallet.applyUpdate(update: update!)
                        balance = wallet.balance().total.toSat();
                    }
                }
            }
            Task {
                while true {
                    let log = try? await client.nextLog()
                    if let log = log {
                        messageHandler.handleLog(log: log)
                    }
                }
            }
            Task {
                while true {
                    let warn = try? await client.nextWarning()
                    if let warn = warn {
                        messageHandler.handleWarning(warn: warn)
                    }
                }
            }
            
        }
    }
}

#Preview {
    ContentView()
}
