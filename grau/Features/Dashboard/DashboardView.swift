//
//  DashboardView.swift
//  grau
//
//  Stub for the Dashboard feature. Real implementation in
//  docs/TASKS.md. For now, just a placeholder so the
//  navigation graph compiles.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        Text("Dashboard lands in Task 0.6")
    }
}

#Preview {
    DashboardView()
        .environment(AppViewModel())
        .frame(width: 800, height: 500)
}
