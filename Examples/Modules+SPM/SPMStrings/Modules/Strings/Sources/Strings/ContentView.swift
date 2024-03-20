//
//  ContentView.swift
//  SPMStrings
//
//  Created by Sergey Balalaev on 19.03.2024.
//

import SwiftUI

public struct ContentView: View {

    private let count: Int

    public init(count: Int = 5) {
        self.count = count
    }

    public var body: some View {
        Text("Hello.world", bundle: Bundle.module)
        //Text(Strings.Localizable.Hello.worlds(count))
        Text("Help.me", bundle: Bundle.module)
        Text("Strings.Catalog", tableName: "LocalizableCatalog", bundle: Bundle.module)
        Text("Strings.Catalog in %lld to %lld", tableName: "LocalizableCatalog", bundle: Bundle.module)


        Text("Special.Untranslated")
    }
}

#Preview {
    ContentView()
}
