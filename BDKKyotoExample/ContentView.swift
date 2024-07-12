//
//  ContentView.swift
//  BDKKyotoExample
//
//  Created by Robert Netzke on 7/12/24.
//

import SwiftUI
import BitcoinDevKit

struct ContentView: View {
    @State private var balance: UInt64 = 0;
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "bitcoinsign.circle")
                .imageScale(.large)
                .foregroundColor(.orange)
            Text("\(balance)")
                .font(.largeTitle)
                .bold()
        }
        .padding()
        .onAppear {
            let recv = try! Descriptor.init(descriptor: "tr([7d94197e/86'/1'/0']tpubDCyQVJj8KzjiQsFjmb3KwECVXPvMwvAxxZGCP9XmWSopmjW3bCV3wD7TgxrUhiGSueDS1MU5X1Vb1YjYcp8jitXc5fXfdC1z68hDDEyKRNr/0/*)", network: .signet);
            let change = try! Descriptor.init(descriptor: "tr([7d94197e/86'/1'/0']tpubDCyQVJj8KzjiQsFjmb3KwECVXPvMwvAxxZGCP9XmWSopmjW3bCV3wD7TgxrUhiGSueDS1MU5X1Vb1YjYcp8jitXc5fXfdC1z68hDDEyKRNr/1/*)", network: .signet);
            let wallet = try! Wallet.newOrLoad(descriptor: recv, changeDescriptor: change, changeSet: nil, network: .signet);
            balance = wallet.balance().total.toSat();
            let peers = [Peer.v4(q1: 170, q2: 75, q3: 163, q4: 219), Peer.v4(q1: 23, q2: 137, q3: 57, q4: 100)];
            let path = URL.documentsDirectory.path();
            let spv = buildLightClient(wallet: wallet, peers: peers, connections: 2, recoveryHeight: 170_000, dataDir: path)
            let node = spv.node;
            let client = spv.client;
            Task {
                await runNode(node: node)
            }
            Task {
                let update = await client.update();
                if update != nil {
                    try! wallet.applyUpdate(update: update!)
                    balance = wallet.balance().total.toSat();
                }
            }
            
        }
    }
}

#Preview {
    ContentView()
}
