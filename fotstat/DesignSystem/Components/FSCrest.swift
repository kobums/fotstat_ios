import SwiftUI

struct FSCrest: View {
    let name: String
    let color: Color
    var size: CGFloat = 36
    var radius: CGFloat = 8

    init(name: String, size: CGFloat = 36, radius: CGFloat = 8) {
        self.name = name
        self.color = fsColorForName(name)
        self.size = size
        self.radius = radius
    }

    init(color: Color, initials: String, size: CGFloat = 36, radius: CGFloat = 8) {
        self.name = initials
        self.color = color
        self.size = size
        self.radius = radius
    }

    var initials: String { fsInitials(name) }

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.40, weight: .black))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
            )
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
