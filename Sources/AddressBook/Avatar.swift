//
//  Avatar.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ContactsCore

/// A contact's initials in a circle of their own color, or a person's
/// outline when there are none.
struct Avatar: View {

    let contact: Contact

    var size: CGFloat = 40

    static let colors: [Color] = [
        Color(red: 0.89, green: 0.36, blue: 0.33),
        Color(red: 0.93, green: 0.55, blue: 0.22),
        Color(red: 0.85, green: 0.68, blue: 0.13),
        Color(red: 0.35, green: 0.68, blue: 0.35),
        Color(red: 0.2, green: 0.65, blue: 0.67),
        Color(red: 0.27, green: 0.5, blue: 0.85),
        Color(red: 0.53, green: 0.4, blue: 0.82),
        Color(red: 0.8, green: 0.38, blue: 0.62),
    ]

    var body: some View {
        let initials = contact.initials
        ZStack {
            Circle()
                .fill(initials.isEmpty ? Color.gray : Self.colors[contact.colorIndex(of: Self.colors.count)])
            if initials.isEmpty {
                Image(systemName: "person")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Color.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
    }
}

#endif
