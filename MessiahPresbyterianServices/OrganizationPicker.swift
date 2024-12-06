//
//  OrganizationPicker.swift
//

import SwiftUI

struct OrganizationPicker: View {
    @Binding var selectedOrganizationId: String
    var organizationIds: [String]

    var body: some View {
        Picker("Select Organization", selection: $selectedOrganizationId) {
            ForEach(organizationIds, id: \.self) { orgId in
                Text(orgId).tag(orgId)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
}
