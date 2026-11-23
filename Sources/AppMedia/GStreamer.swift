//
//  GStreamer.swift
//  CoreApps
//

#if Native

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// GStreamer, opened when the first player needs it, as Perry's
/// AVFoundation and LinuxAppRuntime's media host open it: the programs
/// build without its headers, and where it isn't installed a video fails
/// to load with `.unavailable` rather than the program failing to start.
///
/// Only what a `playbin` with an `appsink` for its pictures needs.
final class GStreamer: @unchecked Sendable {

    typealias Pointer = UnsafeMutableRawPointer

    // MARK: GStreamer

    let elementFactoryMake: @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>?) -> Pointer?
    let elementSetState: @convention(c) (Pointer, Int32) -> Int32
    let elementGetBus: @convention(c) (Pointer) -> Pointer?
    let elementQueryPosition: @convention(c) (Pointer, Int32, UnsafeMutablePointer<Int64>) -> Int32
    let elementQueryDuration: @convention(c) (Pointer, Int32, UnsafeMutablePointer<Int64>) -> Int32
    let elementSeekSimple: @convention(c) (Pointer, Int32, Int32, Int64) -> Int32
    let busPopFiltered: @convention(c) (Pointer, UInt32) -> Pointer?
    let messageParseError: @convention(c) (Pointer, UnsafeMutablePointer<Pointer?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Void
    let messageParseBuffering: @convention(c) (Pointer, UnsafeMutablePointer<Int32>) -> Void
    let miniObjectUnref: @convention(c) (Pointer) -> Void
    let objectUnref: @convention(c) (Pointer) -> Void
    let capsFromString: @convention(c) (UnsafePointer<CChar>) -> Pointer?
    let capsGetStructure: @convention(c) (Pointer, UInt32) -> Pointer?
    let structureGetInt: @convention(c) (Pointer, UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> Int32
    let sampleGetBuffer: @convention(c) (Pointer) -> Pointer?
    let sampleGetCaps: @convention(c) (Pointer) -> Pointer?
    let bufferMap: @convention(c) (Pointer, Pointer, Int32) -> Int32
    let bufferUnmap: @convention(c) (Pointer, Pointer) -> Void
    let filenameToURI: @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<Pointer?>?) -> UnsafeMutablePointer<CChar>?

    // MARK: The app sink

    let appSinkSetCaps: @convention(c) (Pointer, Pointer) -> Void
    let appSinkSetCallbacks: @convention(c) (Pointer, Pointer, Pointer?, (@convention(c) (Pointer?) -> Void)?) -> Void
    let appSinkPullSample: @convention(c) (Pointer) -> Pointer?
    let appSinkPullPreroll: @convention(c) (Pointer) -> Pointer?

    // MARK: GObject and GLib

    let valueInit: @convention(c) (Pointer, UInt) -> Pointer?
    let valueUnset: @convention(c) (Pointer) -> Void
    let valueSetString: @convention(c) (Pointer, UnsafePointer<CChar>?) -> Void
    let valueSetObject: @convention(c) (Pointer, Pointer?) -> Void
    let valueSetDouble: @convention(c) (Pointer, Double) -> Void
    let valueSetBoolean: @convention(c) (Pointer, Int32) -> Void
    let valueSetUInt: @convention(c) (Pointer, UInt32) -> Void
    let valueGetInt: @convention(c) (Pointer) -> Int32
    let objectSetProperty: @convention(c) (Pointer, UnsafePointer<CChar>, Pointer) -> Void
    let objectGetProperty: @convention(c) (Pointer, UnsafePointer<CChar>, Pointer) -> Void
    let free: @convention(c) (Pointer?) -> Void
    let errorFree: @convention(c) (Pointer) -> Void

    // MARK: Constants

    /// GstState.
    static let null: Int32 = 1, paused: Int32 = 3, playing: Int32 = 4
    /// GstStateChangeReturn.
    static let stateChangeFailure: Int32 = 0
    /// GST_FORMAT_TIME.
    static let formatTime: Int32 = 3
    /// GstSeekFlags.
    static let seekFlush: Int32 = 1 << 0, seekAccurate: Int32 = 1 << 1, seekKeyUnit: Int32 = 1 << 2
    /// GstMessageType.
    static let messageEOS: UInt32 = 1 << 0, messageError: UInt32 = 1 << 1, messageBuffering: UInt32 = 1 << 5
    static let messageDurationChanged: UInt32 = 1 << 18, messageAsyncDone: UInt32 = 1 << 21
    /// GST_MAP_READ.
    static let mapRead: Int32 = 1
    /// GstFlowReturn.
    static let flowOK: Int32 = 0
    /// GLib's fundamental types, shifted as `G_TYPE_MAKE_FUNDAMENTAL` does.
    static let typeBoolean: UInt = 5 << 2, typeInt: UInt = 6 << 2, typeUInt: UInt = 7 << 2
    static let typeDouble: UInt = 15 << 2, typeString: UInt = 16 << 2, typeObject: UInt = 20 << 2

    // MARK: Opening

    /// GStreamer, opened and started once; `nil` where it isn't installed
    /// or lacks the app sink.
    static let shared: GStreamer? = GStreamer()

    private init?() {
        #if canImport(Darwin)
        let names = (core: "libgstreamer-1.0.0.dylib", app: "libgstapp-1.0.0.dylib",
                     object: "libgobject-2.0.0.dylib", glib: "libglib-2.0.0.dylib")
        #else
        let names = (core: "libgstreamer-1.0.so.0", app: "libgstapp-1.0.so.0",
                     object: "libgobject-2.0.so.0", glib: "libglib-2.0.so.0")
        #endif
        guard let core = dlopen(names.core, RTLD_NOW | RTLD_GLOBAL),
              let app = dlopen(names.app, RTLD_NOW | RTLD_GLOBAL),
              let object = dlopen(names.object, RTLD_NOW | RTLD_GLOBAL),
              let glib = dlopen(names.glib, RTLD_NOW | RTLD_GLOBAL) else {
            return nil
        }
        func load<T>(_ library: UnsafeMutableRawPointer, _ name: String, as type: T.Type = T.self) -> T? {
            guard let symbol = dlsym(library, name) else { return nil }
            return unsafeBitCast(symbol, to: type)
        }
        typealias Init = @convention(c) (UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>?) -> Void
        guard let initialize: Init = load(core, "gst_init"),
              let elementFactoryMake: @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>?) -> Pointer? = load(core, "gst_element_factory_make"),
              let elementSetState: @convention(c) (Pointer, Int32) -> Int32 = load(core, "gst_element_set_state"),
              let elementGetBus: @convention(c) (Pointer) -> Pointer? = load(core, "gst_element_get_bus"),
              let elementQueryPosition: @convention(c) (Pointer, Int32, UnsafeMutablePointer<Int64>) -> Int32 = load(core, "gst_element_query_position"),
              let elementQueryDuration: @convention(c) (Pointer, Int32, UnsafeMutablePointer<Int64>) -> Int32 = load(core, "gst_element_query_duration"),
              let elementSeekSimple: @convention(c) (Pointer, Int32, Int32, Int64) -> Int32 = load(core, "gst_element_seek_simple"),
              let busPopFiltered: @convention(c) (Pointer, UInt32) -> Pointer? = load(core, "gst_bus_pop_filtered"),
              let messageParseError: @convention(c) (Pointer, UnsafeMutablePointer<Pointer?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Void = load(core, "gst_message_parse_error"),
              let messageParseBuffering: @convention(c) (Pointer, UnsafeMutablePointer<Int32>) -> Void = load(core, "gst_message_parse_buffering"),
              let miniObjectUnref: @convention(c) (Pointer) -> Void = load(core, "gst_mini_object_unref"),
              let objectUnref: @convention(c) (Pointer) -> Void = load(core, "gst_object_unref"),
              let capsFromString: @convention(c) (UnsafePointer<CChar>) -> Pointer? = load(core, "gst_caps_from_string"),
              let capsGetStructure: @convention(c) (Pointer, UInt32) -> Pointer? = load(core, "gst_caps_get_structure"),
              let structureGetInt: @convention(c) (Pointer, UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> Int32 = load(core, "gst_structure_get_int"),
              let sampleGetBuffer: @convention(c) (Pointer) -> Pointer? = load(core, "gst_sample_get_buffer"),
              let sampleGetCaps: @convention(c) (Pointer) -> Pointer? = load(core, "gst_sample_get_caps"),
              let bufferMap: @convention(c) (Pointer, Pointer, Int32) -> Int32 = load(core, "gst_buffer_map"),
              let bufferUnmap: @convention(c) (Pointer, Pointer) -> Void = load(core, "gst_buffer_unmap"),
              let filenameToURI: @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<Pointer?>?) -> UnsafeMutablePointer<CChar>? = load(core, "gst_filename_to_uri"),
              let appSinkSetCaps: @convention(c) (Pointer, Pointer) -> Void = load(app, "gst_app_sink_set_caps"),
              let appSinkSetCallbacks: @convention(c) (Pointer, Pointer, Pointer?, (@convention(c) (Pointer?) -> Void)?) -> Void = load(app, "gst_app_sink_set_callbacks"),
              let appSinkPullSample: @convention(c) (Pointer) -> Pointer? = load(app, "gst_app_sink_pull_sample"),
              let appSinkPullPreroll: @convention(c) (Pointer) -> Pointer? = load(app, "gst_app_sink_pull_preroll"),
              let valueInit: @convention(c) (Pointer, UInt) -> Pointer? = load(object, "g_value_init"),
              let valueUnset: @convention(c) (Pointer) -> Void = load(object, "g_value_unset"),
              let valueSetString: @convention(c) (Pointer, UnsafePointer<CChar>?) -> Void = load(object, "g_value_set_string"),
              let valueSetObject: @convention(c) (Pointer, Pointer?) -> Void = load(object, "g_value_set_object"),
              let valueSetDouble: @convention(c) (Pointer, Double) -> Void = load(object, "g_value_set_double"),
              let valueSetBoolean: @convention(c) (Pointer, Int32) -> Void = load(object, "g_value_set_boolean"),
              let valueSetUInt: @convention(c) (Pointer, UInt32) -> Void = load(object, "g_value_set_uint"),
              let valueGetInt: @convention(c) (Pointer) -> Int32 = load(object, "g_value_get_int"),
              let objectSetProperty: @convention(c) (Pointer, UnsafePointer<CChar>, Pointer) -> Void = load(object, "g_object_set_property"),
              let objectGetProperty: @convention(c) (Pointer, UnsafePointer<CChar>, Pointer) -> Void = load(object, "g_object_get_property"),
              let free: @convention(c) (Pointer?) -> Void = load(glib, "g_free"),
              let errorFree: @convention(c) (Pointer) -> Void = load(glib, "g_error_free") else {
            return nil
        }
        self.elementFactoryMake = elementFactoryMake
        self.elementSetState = elementSetState
        self.elementGetBus = elementGetBus
        self.elementQueryPosition = elementQueryPosition
        self.elementQueryDuration = elementQueryDuration
        self.elementSeekSimple = elementSeekSimple
        self.busPopFiltered = busPopFiltered
        self.messageParseError = messageParseError
        self.messageParseBuffering = messageParseBuffering
        self.miniObjectUnref = miniObjectUnref
        self.objectUnref = objectUnref
        self.capsFromString = capsFromString
        self.capsGetStructure = capsGetStructure
        self.structureGetInt = structureGetInt
        self.sampleGetBuffer = sampleGetBuffer
        self.sampleGetCaps = sampleGetCaps
        self.bufferMap = bufferMap
        self.bufferUnmap = bufferUnmap
        self.filenameToURI = filenameToURI
        self.appSinkSetCaps = appSinkSetCaps
        self.appSinkSetCallbacks = appSinkSetCallbacks
        self.appSinkPullSample = appSinkPullSample
        self.appSinkPullPreroll = appSinkPullPreroll
        self.valueInit = valueInit
        self.valueUnset = valueUnset
        self.valueSetString = valueSetString
        self.valueSetObject = valueSetObject
        self.valueSetDouble = valueSetDouble
        self.valueSetBoolean = valueSetBoolean
        self.valueSetUInt = valueSetUInt
        self.valueGetInt = valueGetInt
        self.objectSetProperty = objectSetProperty
        self.objectGetProperty = objectGetProperty
        self.free = free
        self.errorFree = errorFree
        initialize(nil, nil)
    }

    // MARK: Properties

    /// A `GValue`: its type, then two words of data.
    private func withValue(_ type: UInt, _ body: (Pointer) -> Void) {
        let value = Pointer.allocate(byteCount: 24, alignment: 8)
        value.initializeMemory(as: UInt8.self, repeating: 0, count: 24)
        defer { value.deallocate() }
        _ = valueInit(value, type)
        body(value)
        valueUnset(value)
    }

    func set(_ object: Pointer, _ name: String, string: String) {
        withValue(Self.typeString) { value in
            valueSetString(value, string)
            objectSetProperty(object, name, value)
        }
    }

    func set(_ object: Pointer, _ name: String, object property: Pointer) {
        withValue(Self.typeObject) { value in
            valueSetObject(value, property)
            objectSetProperty(object, name, value)
        }
    }

    func set(_ object: Pointer, _ name: String, double: Double) {
        withValue(Self.typeDouble) { value in
            valueSetDouble(value, double)
            objectSetProperty(object, name, value)
        }
    }

    func set(_ object: Pointer, _ name: String, bool: Bool) {
        withValue(Self.typeBoolean) { value in
            valueSetBoolean(value, bool ? 1 : 0)
            objectSetProperty(object, name, value)
        }
    }

    func set(_ object: Pointer, _ name: String, uint: UInt32) {
        withValue(Self.typeUInt) { value in
            valueSetUInt(value, uint)
            objectSetProperty(object, name, value)
        }
    }

    func int(_ object: Pointer, _ name: String) -> Int32 {
        var result: Int32 = 0
        withValue(Self.typeInt) { value in
            objectGetProperty(object, name, value)
            result = valueGetInt(value)
        }
        return result
    }

    /// A message's `GstMessageType`, which follows its mini object's
    /// fields: the only field of a message read directly, as no function
    /// returns it.
    func type(of message: Pointer) -> UInt32 {
        message.load(fromByteOffset: MemoryLayout<Int>.size == 8 ? 64 : 36, as: UInt32.self)
    }

    /// The text of an error message, which is freed.
    func errorText(_ message: Pointer) -> String {
        var error: Pointer?
        var debug: UnsafeMutablePointer<CChar>?
        messageParseError(message, &error, &debug)
        defer {
            if let error { errorFree(error) }
            free(debug)
        }
        // A GError is its domain, its code, then its message.
        guard let error,
              let text = error.load(fromByteOffset: 8, as: UnsafePointer<CChar>?.self) else {
            return "GStreamer couldn't play this"
        }
        return String(cString: text)
    }
}

#endif
