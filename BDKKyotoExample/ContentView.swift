//
//  ContentView.swift
//  BDKKyotoExample
//
//  Created by Robert Netzke on 7/12/24.
//

import SwiftUI
import BitcoinDevKit

let network = Network.bitcoin
let scanHeight: UInt32 = 830_000
let numConnections: UInt8 = 1
// Taken from BIP382 - SegWit output descriptors
let recv = try! Descriptor.init(descriptor: "sh(wpkh(xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi/10/20/30/40/*))", network: network);
let change = try! Descriptor.init(descriptor: "wpkh(xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH/1/2/*)", network: network);
let path = URL.documentsDirectory.path()

class MessageHandler: ObservableObject {
    @Published var progress: Float = 0
    @Published var height: UInt32? = nil
    @Published var connected: Bool = false
    
    func listen(client: CbfClient) {
        Task {
            while true {
                let log = try? await client.nextLog()
                if let log = log {
                    print(log)
                }
            }
        }
        Task {
            while true {
                let log = try? await client.nextInfo()
                if let log = log {
                    self.handleInfo(log: log)
                }
            }
        }
        Task {
            while true {
                let warn = try? await client.nextWarning()
                if let warn = warn {
                    self.handleWarning(warn: warn)
                }
            }
        }
    }
    
    func handleInfo(log: BitcoinDevKit.Info) {
        DispatchQueue.main.async { [self] in
            switch log {
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
                    .animation(.easeInOut(duration: 0.3), value: messageHandler.progress)
            }
            Spacer()
            Text("\(balance) Satoshis")
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .padding()
        .onAppear {
            let wallet = try! Wallet(descriptor: recv, changeDescriptor: change, network: network, connection: .newInMemory())
            balance = wallet.balance().total.toSat();
            let spv = try! CbfBuilder()
                .connections(connections: numConnections)
                .dataDir(dataDir: path)
                .scanType(scanType: .recovery(fromHeight: scanHeight))
                .build(wallet: wallet)
            let node = spv.node
            let client = spv.client
            node.run()
            messageHandler.listen(client: client)
            Task {
                while true {
                    let start = Date()
                    let update = await client.update()
                    try! wallet.applyUpdate(update: update)
                    let syncTime = -1 * start.timeIntervalSinceNow
                    print("Sync time \(syncTime)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
