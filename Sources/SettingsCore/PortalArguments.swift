//
//  PortalArguments.swift
//  CoreApps
//

// Settings as D-Bus message arguments. Off the platforms with a D-Bus
// package, which are Linux and macOS, there's no desktop to ask.
#if canImport(DBus)

import DBus

public extension SettingValue {

    /// The value an argument holds, inside any variants: `ReadOne` and
    /// `SettingChanged` send it in one, and the older `Read` in two.
    /// Types the settings don't use are `nil`.
    init?(_ argument: DBusMessageArgument) {
        var argument = argument
        while case let .variant(variant) = argument {
            argument = variant.element
        }
        switch argument {
        case let .uint32(value):
            self = .uint32(value)
        case let .int32(value):
            self = .int32(value)
        case let .string(value):
            self = .string(value)
        case let .boolean(value):
            self = .bool(value)
        case let .struct(structure):
            let components = structure.compactMap { element -> Double? in
                if case let .double(component) = element { return component }
                return nil
            }
            guard components.count == 3, structure.count == 3 else {
                return nil
            }
            self = .color(red: components[0], green: components[1], blue: components[2])
        default:
            return nil
        }
    }

    /// The value as a message argument, not in a variant.
    var argument: DBusMessageArgument {
        switch self {
        case let .uint32(value):
            .uint32(value)
        case let .int32(value):
            .int32(value)
        case let .string(value):
            .string(value)
        case let .bool(value):
            .boolean(value)
        case let .color(red, green, blue):
            // Three doubles always make a structure.
            .struct(DBusMessageArgument.Structure([.double(red), .double(green), .double(blue)])!)
        }
    }

    /// The value in a variant, as `Set` takes it.
    var variant: DBusMessageArgument {
        .variant(DBusMessageArgument.Variant(argument))
    }
}

public enum PortalArguments {

    /// The values of a `ReadAll` reply, an `a{sa{sv}}`, by namespace and
    /// then key. Values of types the settings don't use are left out.
    public static func readAll(_ reply: DBusMessageArgument) -> [String: [String: SettingValue]] {
        guard case let .dictionary(namespaces) = reply else {
            return [:]
        }
        var values: [String: [String: SettingValue]] = [:]
        for entry in namespaces {
            guard case let .string(namespace) = entry.key, case let .dictionary(keys) = entry.value else {
                continue
            }
            for item in keys {
                guard case let .string(key) = item.key, let value = SettingValue(item.value) else {
                    continue
                }
                values[namespace, default: [:]][key] = value
            }
        }
        return values
    }

    /// A `SettingChanged(s namespace, s key, v value)` signal's arguments.
    public static func settingChanged(_ arguments: [DBusMessageArgument]) -> (namespace: String, key: String, value: SettingValue)? {
        guard arguments.count == 3,
              case let .string(namespace) = arguments[0],
              case let .string(key) = arguments[1],
              let value = SettingValue(arguments[2])
        else {
            return nil
        }
        return (namespace, key, value)
    }
}

#endif
