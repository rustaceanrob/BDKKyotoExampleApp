//
//  ContentView.swift
//  BDKKyotoExample
//
//  Created by Robert Netzke on 7/12/24.
//

import SwiftUI
import BitcoinDevKit

class MessageHandler: ObservableObject, NodeMessageHandler {
    @Published var progress: Double = 20
    
    func handleStateChanged(state: BitcoinDevKit.NodeState) {
        DispatchQueue.main.async { [self] in
            switch state {
            case .behind:
                progress = 20
            case .headersSynced:
                progress = 40
            case .filterHeadersSynced:
                progress = 60
            case .filtersSynced:
                progress = 80
            case .transactionsSynced:
                progress = 100
            }
        }
    }
    
    func handleDialog(dialog: String) {
        print(dialog)
    }
    
    func handleWarning(warning: BitcoinDevKit.Warning) {
        switch warning {
        case .notEnoughConnections:
            print("Searching for connections")
        case .peerTimedOut:
            print("A peer timed out")
        case .unsolicitedMessage:
            print("A peer sent an unsolicited message")
        case .unlinkableAnchor:
            print("The configured recovery does not link to block headers stored in the database")
        case .corruptedHeaders:
            print("The loaded headers do not link together")
        case .transactionRejected:
            print("A transaction was rejected")
        case .failedPersistance(warning: let warning):
            print(warning)
        case .evaluatingFork:
            print("Evaluating a potential fork")
        case .emptyPeerDatabase:
            print("The peer database is empty")
        case .unexpectedSyncError(warning: let warning):
            print(warning)
        }
    }
    
    func handleSynced(tip: UInt32) {
        print("Chain synced to height \(tip)")
    }
    
    func handleTxSent() {
        print("Transaction broadcast")
    }
    
    func handleBlocksDisconnected(blocks: [UInt32]) {}
}

struct ContentView: View {
    @StateObject private var messageHandler = MessageHandler()
    @State private var balance: UInt64 = 0;
    
    var body: some View {
        VStack{
            ProgressView(value: messageHandler.progress, total: 100)
            Spacer()
            Text("\(balance)")
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .padding()
        .onAppear {
            let recv = try! Descriptor.init(descriptor: "tr([7d94197e/86'/1'/0']tpubDCyQVJj8KzjiQsFjmb3KwECVXPvMwvAxxZGCP9XmWSopmjW3bCV3wD7TgxrUhiGSueDS1MU5X1Vb1YjYcp8jitXc5fXfdC1z68hDDEyKRNr/0/*)", network: .signet);
            let change = try! Descriptor.init(descriptor: "tr([7d94197e/86'/1'/0']tpubDCyQVJj8KzjiQsFjmb3KwECVXPvMwvAxxZGCP9XmWSopmjW3bCV3wD7TgxrUhiGSueDS1MU5X1Vb1YjYcp8jitXc5fXfdC1z68hDDEyKRNr/1/*)", network: .signet);
            let wallet = try! Wallet.newOrLoad(descriptor: recv, changeDescriptor: change, changeSet: nil, network: .signet);
            balance = wallet.balance().total.toSat();
            let peers = [Peer.v4(q1: 23, q2: 137, q3: 57, q4: 100)];
            let path = URL.documentsDirectory.path();
            let spv = buildLightClient(wallet: wallet, peers: peers, connections: 1, recoveryHeight: 170_000, dataDir: path, logger: messageHandler)
            let node = spv.node;
            let client = spv.client;
            runNode(node: node)
            Task {
                while true {
                    let update = await client.update();
                    if update != nil {
                        try! wallet.applyUpdate(update: update!)
                        balance = wallet.balance().total.toSat();
                    }
                }
            }
            
        }
    }
}

#Preview {
    ContentView()
}
