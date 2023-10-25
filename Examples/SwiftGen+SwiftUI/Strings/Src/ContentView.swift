//
//  ContentView.swift
//  Strings
//
//  Created by Sergey Balalaev on 04.09.2022.
//

import SwiftUI

struct ContentView: View {
    
    let count = 5
    
    var body: some View {
        Text(Strings.Localizable.Hello.world)
        Text(Strings.Localizable.Hello.worlds(count))
        Text("Help.me")
        Text("Strings.Catalog")
        Text("Strings.Catalog in %lld to %lld")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

