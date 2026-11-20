//
//  Metrics.swift
//  CoreApps
//

import AppUI

/// Sizes the apps share.
public enum Metrics {

    /// The smallest a control someone touches should be, in points, along
    /// either axis.
    public static let minimumTarget: CGFloat = 44

    /// The space between a screen's edge and its content.
    public static let screenPadding: CGFloat = 16

    /// The space between keys of a pad.
    public static let keySpacing: CGFloat = 10

    public static let keyCornerRadius: CGFloat = 14

    /// The size a window opens at on a desktop: a phone's, since the apps
    /// are laid out for that first.
    public static let phoneSize = (width: CGFloat(360), height: CGFloat(640))
}
