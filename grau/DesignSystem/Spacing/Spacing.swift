//
//  Spacing.swift
//  grau
//
//  4-pt grid spacing scale. See docs/DESIGN.md § 1.5.
//

import Foundation

public enum Spacing {
    /// 4 pt — tight inline.
    public static let xs: CGFloat = 4
    /// 8 pt — within a button.
    public static let sm: CGFloat = 8
    /// 12 pt — within a card row.
    public static let md: CGFloat = 12
    /// 16 pt — card padding.
    public static let lg: CGFloat = 16
    /// 20 pt — large button horizontal padding.
    public static let xl: CGFloat = 20
    /// 24 pt — section spacing.
    public static let xxl: CGFloat = 24
    /// 32 pt — between cards.
    public static let section: CGFloat = 32
    /// 48 pt — top of page.
    public static let pageTop: CGFloat = 48
    /// 64 pt — hero / large hero.
    public static let hero: CGFloat = 64
}

public enum Radius {
    /// 4 pt — small chips, inline tags.
    public static let chip: CGFloat = 4
    /// 8 pt — buttons, inputs.
    public static let button: CGFloat = 8
    /// 12 pt — cards.
    public static let card: CGFloat = 12
    /// 16 pt — hero cards, modals.
    public static let modal: CGFloat = 16
}
