//
//  RomDatabase.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/9/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging
#if canImport(UIKit)
import UIKit
#endif
import SQLite

let schemaVersion: UInt64 = 11

public extension Notification.Name {
    static let DatabaseMigrationStarted = Notification.Name("DatabaseMigrarionStarted")
    static let DatabaseMigrationFinished = Notification.Name("DatabaseMigrarionFinished")
}

public final class RealmConfiguration {
    public class var supportsAppGroups: Bool {
		#if targetEnvironment(macCatalyst)
		return false
		#else
        return !PVAppGroupId.isEmpty && RealmConfiguration.appGroupContainer != nil
		#endif
    }

    public class var appGroupContainer: URL? {
		#if targetEnvironment(macCatalyst)
		return nil
		#else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)
		#endif
    }

    public class var appGroupPath: URL? {
        guard let appGroupContainer = RealmConfiguration.appGroupContainer else {
            ILOG("appGroupContainer is Nil")
            return nil
        }

        ILOG("appGroupContainer => (\(appGroupContainer.absoluteString))")

        #if os(tvOS)
            let appGroupPath = appGroupContainer.appendingPathComponent("Library/Caches/")
        #else
            let appGroupPath = appGroupContainer
        #endif
        return appGroupPath
    }

    public class func setDefaultRealmConfig() {
        let config = RealmConfiguration.realmConfig
        Realm.Configuration.defaultConfiguration = config
    }

    private static var realmConfig: Realm.Configuration = {
        let realmFilename = "default.realm"
        let nonGroupPath = PVEmulatorConfiguration.documentsPath.appendingPathComponent(realmFilename, isDirectory: false)

        var realmURL: URL = nonGroupPath
        if RealmConfiguration.supportsAppGroups, let appGroupPath = RealmConfiguration.appGroupPath {
            ILOG("AppGroups: Supported")
            realmURL = appGroupPath.appendingPathComponent(realmFilename, isDirectory: false)

            let fm = FileManager.default
            if fm.fileExists(atPath: nonGroupPath.path) {
                do {
                    ILOG("Found realm database at non-group path location. Will attempt to move to group path location")
                    if fm.fileExists(atPath: realmURL.path) {
                        try fm.removeItem(at: realmURL)
                    }
                    try fm.moveItem(at: nonGroupPath, to: realmURL)
                    ILOG("Moved old database to group path location.")
                } catch {
                    ELOG("Failed to move old database to new group path: \(error.localizedDescription)")
                }
            }
        } else {
            ILOG("AppGroups: Not Supported")
        }

        let migrationBlock: MigrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                ILOG("Migrating to version 2. Adding MD5s")
                NotificationCenter.default.post(name: NSNotification.Name.DatabaseMigrationStarted, object: nil)

                var counter = 0
                var deletions = 0
                migration.enumerateObjects(ofType: PVGame.className()) { oldObject, newObject in
                    let romPath = oldObject!["romPath"] as! String
                    let systemID = oldObject!["systemIdentifier"] as! String
                    let system = SystemIdentifier(rawValue: systemID)!

                    var offset: UInt = 0
                    if system == .SNES {
                        offset = 16
                    }

                    let fullPath = PVEmulatorConfiguration.documentsPath.appendingPathComponent(romPath, isDirectory: false)
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: fullPath.path) {
                        ELOG("Cannot find file at path: \(fullPath). Deleting entry")
                        if let oldObject = oldObject {
                            migration.delete(oldObject)
                            deletions += 1
                        }
                        return
                    }

                    if let md5 = FileManager.default.md5ForFile(atPath: fullPath.path, fromOffset: offset), !md5.isEmpty {
                        newObject!["md5Hash"] = md5
                        counter += 1
                    } else {
                        ELOG("Couldn't get md5 for \(fullPath.path). Removing entry")
                        if let oldObject = oldObject {
                            migration.delete(oldObject)
                            deletions += 1
                        }
                    }

                    newObject!["importDate"] = Date()
                }

                NotificationCenter.default.post(name: NSNotification.Name.DatabaseMigrationFinished, object: nil)
                ILOG("Migration complete of \(counter) roms. Removed \(deletions) bad entries.")
            }
            if oldSchemaVersion < 10 {
                migration.enumerateObjects(ofType: PVCore.className()) { oldObject, newObject in
                    newObject!["disabled"] = false
                }
            }
            if oldSchemaVersion < 11 {
                migration.enumerateObjects(ofType: PVSystem.className()) { oldObject, newObject in
                    newObject!["supported"] = true
                }
            }
        }

        #if DEBUG
            let deleteIfMigrationNeeded = true
        #else
            let deleteIfMigrationNeeded = false
        #endif
        let config = Realm.Configuration(
            fileURL: realmURL,
            inMemoryIdentifier: nil,
            syncConfiguration: nil,
            encryptionKey: nil,
            readOnly: false,
            schemaVersion: schemaVersion,
            migrationBlock: migrationBlock,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: { totalBytes, usedBytes in
                // totalBytes refers to the size of the file on disk in bytes (data + free space)
                // usedBytes refers to the number of bytes used by data in the file

                // Compact if the file is over 20MB in size and less than 60% 'used'
                let twentyMB = 20 * 1024 * 1024
                return (totalBytes > twentyMB) && (Double(usedBytes) / Double(totalBytes)) < 0.6
            },
            objectTypes: nil
        )

        return config
    }()
}

internal final class WeakWrapper: NSObject {
    static var associatedKey = "WeakWrapper"
    weak var weakObject: RomDatabase?

    init(_ weakObject: RomDatabase?) {
        self.weakObject = weakObject
    }
}

import ObjectiveC
public extension Thread {
    var realm: RomDatabase? {
        get {
            let weakWrapper: WeakWrapper? = objc_getAssociatedObject(self, &WeakWrapper.associatedKey) as? WeakWrapper
            return weakWrapper?.weakObject
        }
        set {
            var weakWrapper: WeakWrapper? = objc_getAssociatedObject(self, &WeakWrapper.associatedKey) as? WeakWrapper
            if weakWrapper == nil {
                weakWrapper = WeakWrapper(newValue)
                objc_setAssociatedObject(self, &WeakWrapper.associatedKey, weakWrapper, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                weakWrapper!.weakObject = newValue
            }
        }
    }
}

public typealias RomDB = RomDatabase
public final class RomDatabase {
    public private(set) static var databaseInitialized = false
    static var gamesCache: [String: PVGame]?
    static var systemCache: [String: PVSystem]?
    static var coreCache: [String: PVCore]?
    static var biosCache: [String: [String]]?
    static var fileSystemROMCache:[URL:PVSystem]?
    static var artMD5DBCache:[String:[String: NSObject]]?
    static var artFileNameToMD5Cache:[String:String]?
    
    public class func initDefaultDatabase() throws {
        if !databaseInitialized {
            RealmConfiguration.setDefaultRealmConfig()
            try _sharedInstance = RomDatabase()

            let existingLocalLibraries = _sharedInstance.realm.objects(PVLibrary.self).filter("isLocal == YES")

            if !existingLocalLibraries.isEmpty, let first = existingLocalLibraries.first {
                VLOG("Existing PVLibrary(s) found.")
                _sharedInstance.libraryRef = ThreadSafeReference(to: first)
            } else {
                VLOG("No local library, need to create")
                createInitialLocalLibrary()
            }

            databaseInitialized = true
        }
    }

    private static func createInitialLocalLibrary() {
        // This is all pretty much place holder as I scope out the idea of
        // local and remote libraries
        let newLibrary = PVLibrary()
        newLibrary.bonjourName = ""
        newLibrary.domainname = "localhost"
        newLibrary.name = "Default Library"
        newLibrary.ipaddress = "127.0.0.1"
        if let existingGames = _sharedInstance?.realm.objects(PVGame.self).filter("libraries.@count == 0") {
            newLibrary.games.append(objectsIn: existingGames)
        }
        try! _sharedInstance?.add(newLibrary)
        _sharedInstance.libraryRef = ThreadSafeReference(to: newLibrary)
    }

    // Primary local library

    private var libraryRef: ThreadSafeReference<PVLibrary>!
    public var library: PVLibrary {
        let realm = try! Realm()
        return realm.resolve(libraryRef)!
    }

    //	public static var localLibraries : Results<PVLibrary> {
    //		return sharedInstance.realm.objects(PVLibrary.self).filter { $0.isLocal }
    //	}
//
    //	public static var remoteLibraries : Results<PVLibrary> {
    //		return sharedInstance.realm.objects(PVLibrary.self).filter { !$0.isLocal }
    //	}

    // Private shared instance that propery initializes
    private static var _sharedInstance: RomDatabase!

    // Public shared instance that makes sure threads are handeled right
    // TODO: Since if a function calls a bunch of RomDatabase.sharedInstance calls,
    // this helper might do more damage than just putting a fatalError() around isMainThread
    // and simply fixing any threaded callst to call temporaryDatabaseContext
    // Or maybe there should be no public sharedInstance and instead only a
    // databaseContext object that must be used for all calls. It would be another class
    // and RomDatabase would just exist to provide context instances and init the initial database - jm
    public static var sharedInstance: RomDatabase {
        // Make sure real shared is inited first
        let shared = RomDatabase._sharedInstance!

        if Thread.isMainThread {
            return shared
        } else {
            if let realm = Thread.current.realm {
                return realm
            } else {
                let realm = try! RomDatabase.temporaryDatabaseContext()
                Thread.current.realm = realm
                return realm
            }
        }
    }

    // For multi-threading
    fileprivate static func temporaryDatabaseContext() throws -> RomDatabase {
        return try RomDatabase()
    }

    public private(set) var realm: Realm

    private init() throws {
        realm = try Realm()
    }
}

// MARK: - Queries

public extension RomDatabase {
    // Generics
    func all<T: Object>(_ type: T.Type) -> Results<T> {
        return realm.objects(type)
    }

    // Testing a Swift hack to make Swift 4 keypaths work with KVC keypaths
    /*
     public func all<T:Object>(sortedByKeyPath keyPath : KeyPath<T, AnyKeyPath>, ascending: Bool = true) -> Results<T> {
     return realm.objects(T.self).sorted(byKeyPath: keyPath._kvcKeyPathString!, ascending: ascending)
     }

     public func all<T:Object>(where keyPath: KeyPath<T, AnyKeyPath>, value : String) -> Results<T> {
     return T.objects(in: self.realm, with: NSPredicate(format: "\(keyPath._kvcKeyPathString) == %@", value))
     }

     public func allGames(sortedByKeyPath keyPath: KeyPath<PVGame, AnyKeyPath>, ascending: Bool = true) -> Results<PVGame> {
     return all(sortedByKeyPath: keyPath, ascending: ascending)
     }

     */

    func all<T: Object>(_: T.Type, sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<T> {
        return realm.objects(T.self).sorted(byKeyPath: keyPath, ascending: ascending)
    }

    func all<T: Object>(_: T.Type, where keyPath: String, value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", value))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, contains value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) CONTAINS[cd] %@", value))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, beginsWith value: String) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) BEGINSWITH[cd] %@", value))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, value: Bool) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", NSNumber(value: value)))
    }

    func all<T: Object, KeyType>(_: T.Type, where keyPath: String, value: KeyType) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %@", [value]))
    }

    func all<T: Object>(_: T.Type, where keyPath: String, value: Int) -> Results<T> {
        return realm.objects(T.self).filter(NSPredicate(format: "\(keyPath) == %i", value))
    }

    func all<T: Object>(_: T.Type, filter: NSPredicate) -> Results<T> {
        return realm.objects(T.self).filter(filter)
    }

    func object<T: Object, KeyType>(ofType _: T.Type, wherePrimaryKeyEquals value: KeyType) -> T? {
        return realm.object(ofType: T.self, forPrimaryKey: value)
    }

    // HELPERS -- TODO: Get rid once we're all swift
    var allGames: Results<PVGame> {
        return all(PVGame.self)
    }

    func allGames(sortedByKeyPath keyPath: String, ascending: Bool = true) -> Results<PVGame> {
        return all(PVGame.self, sortedByKeyPath: keyPath, ascending: ascending)
    }

    func allGamesSortedBySystemThenTitle() -> Results<PVGame> {
        return realm.objects(PVGame.self).sorted(byKeyPath: "systemIdentifier").sorted(byKeyPath: "title")
    }
}

public enum RomDeletionError: Error {
    case relatedFiledDeletionError
}

// MARK: - Update

public extension RomDatabase {
    @objc
    func writeTransaction(_ block: () -> Void) throws {
        if realm.isInWriteTransaction {
            block()
        } else {
            try realm.write {
                block()
            }
        }
    }

    @objc
    func asyncWriteTransaction(_ block: @escaping () -> Void) {
        if realm.isPerformingAsynchronousWriteOperations {
            block()
        } else {
            realm.writeAsync(block)
        }
    }

    @objc
    func add(_ object: Object, update: Bool = false) throws {
        try writeTransaction {
            realm.add(object, update: update ? .all : .error)
        }
    }

    func add<T: Object>(objects: [T], update: Bool = false) throws {
        try writeTransaction {
            realm.add(objects, update: update ? .all : .error)
        }
    }
    func deleteAll() throws {
        Realm.Configuration.defaultConfiguration.deleteRealmIfMigrationNeeded = true
        let realm = try! Realm()
        try! realm.write {
            realm.deleteAll()
        }
    }
    func deleteAllData() throws {
        print("!!!Delete Called!!!")
        let realm = try! Realm()
        let games = realm.objects(PVGame.self)
        let system = realm.objects(PVSystem.self)
        let core = realm.objects(PVCore.self)
        let saves = realm.objects(PVSaveState.self)
        let recent = realm.objects(PVRecentGame.self)
        let user = realm.objects(PVUser.self)
        try! realm.write {
            realm.delete(games)
            realm.delete(system)
            realm.delete(core)
            realm.delete(saves)
            realm.delete(recent)
            realm.delete(user)
            realm.deleteAll()
        }
    }

    func deleteAllGames() throws {
        let realm = try! Realm()
        let allUploadingObjects = realm.objects(PVGame.self)

        try! realm.write {
            realm.delete(allUploadingObjects)
        }
    }

    @objc
    func delete(_ object: Object) throws {
        try writeTransaction {
            realm.delete(object)
        }
    }

    func renameGame(_ game: PVGame, toTitle title: String) {
        if !title.isEmpty {
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    game.realm?.refresh()
                    game.title = title
                    if game.releaseID == nil || game.releaseID!.isEmpty {
                        ILOG("Game isn't already matched, going to try to re-match after a rename")
                        GameImporter.shared.lookupInfo(for: game, overwrite: false)
                    }
                }
            } catch {
                ELOG("Failed to rename game \(game.title)\n\(error.localizedDescription)")
            }
        }
    }
    func hideGame(_ game: PVGame) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                game.realm?.refresh()
                game.genres = "hidden"
            }
        } catch {
            NSLog("Failed to hide game \(game.title)\n\(error.localizedDescription)")
        }
    }
    func delete(game: PVGame, deleteArtwork: Bool = false, deleteSaves: Bool = false) throws {
        let romURL = PVEmulatorConfiguration.path(forGame: game)
        if deleteArtwork, !game.customArtworkURL.isEmpty {
            do {
                try PVMediaCache.deleteImage(forKey: game.customArtworkURL)
            } catch {
                NSLog("Failed to delete image " + game.customArtworkURL)
                // Don't throw, not a big deal
            }
        }
        if deleteSaves {
            let savesPath = PVEmulatorConfiguration.saveStatePath(forGame: game)
            if FileManager.default.fileExists(atPath: savesPath.path) {
                do {
                    try FileManager.default.removeItem(at: savesPath)
                } catch {
                    ELOG("Unable to delete save states at path: " + savesPath.path + "because: " + error.localizedDescription)
                }
            }

            let batteryPath = PVEmulatorConfiguration.batterySavesPath(forGame: game)
            if FileManager.default.fileExists(atPath: batteryPath.path) {
                do {
                    try FileManager.default.removeItem(at: batteryPath)
                } catch {
                    ELOG("Unable to delete battery states at path: \(batteryPath.path) because: \(error.localizedDescription)")
                }
            }
        }
        if FileManager.default.fileExists(atPath: romURL.path) {
            do {
                try FileManager.default.removeItem(at: romURL)
            } catch {
                ELOG("Unable to delete rom at path: \(romURL.path) because: \(error.localizedDescription)")
            }
        }
        // Delete from Spotlight search
        #if os(iOS)
            deleteFromSpotlight(game: game)
        #endif
        do {
            deleteRelatedFilesGame(game)
            game.saveStates.forEach { try? $0.delete() }
            game.cheats.forEach { try? $0.delete() }
            game.recentPlays.forEach { try? $0.delete() }
            game.screenShots.forEach { try? $0.delete() }
            try game.delete()
        } catch {
            // Delete the DB entry anyway if any of the above files couldn't be removed
            do { try game.delete() } catch {
                NSLog("\(error.localizedDescription)")
            }
            NSLog("\(error.localizedDescription)")
        }
    }

    func deleteRelatedFilesGame(_ game: PVGame) {
        guard let system = game.system else {
            ELOG("Game \(game.title) belongs to an unknown system \(game.systemIdentifier)")
            return
        }
        game.relatedFiles.forEach {
            do {
                let file = PVEmulatorConfiguration.path(forGame: game, url: $0.url)
                if FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
            } catch {
                NSLog(error.localizedDescription)
            }
        }
    }
}

// MARK: - Spotlight

#if os(iOS)
    import CoreSpotlight

    extension RomDatabase {
        private func deleteFromSpotlight(game: PVGame) {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [game.spotlightUniqueIdentifier], completionHandler: { error in
                if let error = error {
                    print("Error deleting game spotlight item: \(error)")
                } else {
                    print("Game indexing deleted.")
                }
            })
        }

        private func deleteAllGamesFromSpotlight() {
            CSSearchableIndex.default().deleteAllSearchableItems { error in
                if let error = error {
                    print("Error deleting all games spotlight index: \(error)")
                } else {
                    print("Game indexing deleted.")
                }
            }
        }
    }
#endif

public extension RomDatabase {
    @objc
    func refresh() {
        realm.refresh()
    }
}

public extension RomDatabase {
    func reloadCache() {
        NSLog("RomDatabase:reloadCache")
        self.refresh()
        reloadGamesCache()
        reloadSystemsCache()
        reloadCoresCache()
        reloadBIOSCache()
    }
    func reloadBIOSCache() {
        var files:[String:[String]]=[:]
        getSystemCache().values.forEach { system in
            files = addFileSystemBIOSCache(system, files:files)
        }
        RomDatabase.biosCache = files
    }
    func addFileSystemBIOSCache(_ system:PVSystem, files:[String:[String]]) -> [String:[String]] {
        var files = files
        let systemDir = system.biosDirectory
        if !FileManager.default.fileExists(atPath: systemDir.path) {
            do {
                try FileManager.default.createDirectory(atPath: systemDir.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog(error.localizedDescription)
            }
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
            !contents.isEmpty else {
            return files
        }
        contents
            .forEach {
            file in
                var bioses:[String]=files[system.identifier] ?? []
                bioses.append(system.identifier + "/" + file.lastPathComponent.lowercased())
                files[system.identifier] = bioses
        }
        return files
    }
    func reloadCoresCache() {
        let cores = PVCore.all.toArray()
        RomDatabase.coreCache = cores.reduce(into: [:]) {
            dbCore, core in
            dbCore[core.identifier] = core.detached()
        }
    }
    func reloadSystemsCache() {
        let systems = PVSystem.all.toArray()
        RomDatabase.systemCache = systems.reduce(into: [:]) {
            dbSystem, system in
            dbSystem[system.identifier] = system.detached()
        }
    }
    func reloadGamesCache() {
        let games = PVGame.all.toArray()
        RomDatabase.gamesCache = games.reduce(into: [:]) {
            dbGames, game in
            dbGames=addGameCache(game, cache: dbGames)
        }
    }
    func addGameCache(_ game:PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        var cache:[String:PVGame] = cache
        game.relatedFiles.forEach {
            relatedFile in
            cache = addRelativeFileCache(relatedFile.url, game:game, cache:cache)
        }
        cache[game.romPath] = game.detached()
        cache[altName(game.file.url, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    func addRelativeFileCache(_ file:URL, game: PVGame) {
        if let cache = RomDatabase.gamesCache {
            RomDatabase.gamesCache = addRelativeFileCache(file, game: game, cache: cache)
        }
    }
    func addRelativeFileCache(_ file:URL, game: PVGame, cache:[String:PVGame]) -> [String:PVGame] {
        var cache = cache
        cache[(game.systemIdentifier as NSString)
            .appendingPathComponent(file.lastPathComponent)] = game.detached()
        cache[altName(file, systemIdentifier: game.systemIdentifier)]=game.detached()
        return cache
    }
    func addGamesCache(_ game:PVGame) {
        if RomDatabase.gamesCache == nil {
            self.reloadCache()
        }
        RomDatabase.gamesCache=addGameCache(game, cache: RomDatabase.gamesCache ?? [:])
    }
    func altName(_ romPath:URL, systemIdentifier:String) -> String {
        var similarName = romPath.deletingPathExtension().lastPathComponent
        similarName = PVEmulatorConfiguration.stripDiscNames(fromFilename: similarName)
        return (systemIdentifier as NSString).appendingPathComponent(similarName)
    }
    func getGamesCache() -> [String:PVGame] {
        if RomDatabase.gamesCache == nil {
            self.reloadCache()
        }
        if let gamesCache = RomDatabase.gamesCache {
            return gamesCache
        } else {
            reloadGamesCache()
            return RomDatabase.gamesCache ?? [:]
        }
    }
    func getSystemCache() -> [String:PVSystem] {
        if RomDatabase.systemCache == nil {
            self.reloadCache()
        }
        if let systemCache = RomDatabase.systemCache {
            return systemCache
        } else {
            reloadSystemsCache()
            return RomDatabase.systemCache ?? [:]
        }
    }
    func getCoreCache() -> [String:PVCore] {
        if RomDatabase.coreCache == nil {
            self.reloadCache()
        }
        if let coreCache = RomDatabase.coreCache {
            return coreCache
        } else {
            reloadCoresCache()
            return RomDatabase.coreCache ?? [:]
        }
    }
    func getBIOSCache() -> [String:[String]] {
        if let biosCache = RomDatabase.biosCache {
            return biosCache
        } else {
            reloadBIOSCache()
            return RomDatabase.biosCache ?? [:]
        }
    }
    func reloadFileSystemROMCache() {
        NSLog("RomDatabase: reloadFileSystemROMCache")
        var files:[URL:PVSystem]=[:]
        getSystemCache().values.forEach { system in
            files = addFileSystemROMCache(system, files:files)
        }
        RomDatabase.fileSystemROMCache = files
    }
    func addFileSystemROMCache(_ system:PVSystem, files:[URL:PVSystem]) -> [URL:PVSystem] {
        var files = files
        let systemDir = system.romsDirectory
        if !FileManager.default.fileExists(atPath: systemDir.path) {
            do {
                try FileManager.default.createDirectory(atPath: systemDir.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog(error.localizedDescription)
            }
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
            !contents.isEmpty else {
            return files
        }
        contents
            .filter { system.extensions.contains($0.pathExtension) }
            .forEach {
            file in
                files[file] = system.detached()
        }
        return files
    }
    func addFileSystemROMCache(_ system:PVSystem) {
        if let files = RomDatabase.fileSystemROMCache {
            RomDatabase.fileSystemROMCache = addFileSystemROMCache(system, files:files)
        }
    }
    func getFileSystemROMCache() -> [URL:PVSystem] {
        if RomDatabase.fileSystemROMCache == nil {
            self.reloadFileSystemROMCache()
        }
        var files:[URL:PVSystem] = [:]
        if let fileCache = RomDatabase.fileSystemROMCache {
            files = fileCache
        }
        return files
    }

    func getFileSystemROMCache(for system: PVSystem) -> [URL:PVSystem] {
        if RomDatabase.fileSystemROMCache == nil {
            self.reloadFileSystemROMCache()
        }
        var files:[URL:PVSystem] = [:]
        if let fileCache = RomDatabase.fileSystemROMCache {
            fileCache.forEach({
                key, value in
                if value.identifier == system.identifier {
                    files[key]=system
                }
            })
        }
        return files
    }
    
    func reloadArtDBCache(_ db: OESQLiteDatabase? ) {
        NSLog("RomDatabase:reloadArtDBCache")
        if RomDatabase.artMD5DBCache != nil && RomDatabase.artFileNameToMD5Cache != nil {
            NSLog("RomDatabase:reloadArtDBCache:Cache Found, Skipping Data Reload")
        }
        do {
            var openVGDB: OESQLiteDatabase?
            if let db=db {
                openVGDB = db
            } else {
                openVGDB = try {
                    let ThisBundle: Bundle = Bundle(for: RomDatabase.self)
                    let bundle = ThisBundle
                    let _openVGDB = try OESQLiteDatabase(url: bundle.url(forResource: "openvgdb", withExtension: "sqlite")!)
                    return _openVGDB
                }()
            }
            let queryString = """
                SELECT
                    rom.romHashMD5 as 'romHashMD5',
                    rom.romFileName as 'romFileName',
                    rom.systemID as 'systemID',
                    release.releaseTitleName as 'gameTitle',
                    release.releaseCoverFront as 'boxImageURL',
                    rom.TEMPRomRegion as 'region',
                    release.releaseDescription as 'gameDescription',
                    release.releaseCoverBack as 'boxBackURL',
                    release.releaseDeveloper as 'developer',
                    release.releasePublisher as 'publisher',
                    rom.romSerial as 'serial',
                    release.releaseDate as 'releaseDate',
                    release.releaseGenre as 'genres',
                    release.releaseReferenceURL as 'referenceURL',
                    release.releaseID as 'releaseID',
                    rom.romLanguage as 'language',
                    release.regionLocalizedID as 'regionID',
                    system.systemShortName as 'systemShortName',
                    rom.romHashCRC as 'romHashCRC',
                    rom.romID as 'romID'
                FROM ROMs rom, RELEASES release, SYSTEMS system, REGIONS region
                WHERE rom.romID = release.romID
                AND rom.systemID = system.systemID
                AND release.regionLocalizedID = region.regionID
                """
            let results = try openVGDB!.executeQuery(queryString)
            var romMD5:[String:[String: NSObject]] = [:]
            var romFileNameToMD5:[String:String] = [:]
            for res in results {
                if let md5 = res["romHashMD5"] as? String, !md5.isEmpty {
                    let md5 : String = md5.uppercased()
                    romMD5[md5] = res
                    if let systemID = res["systemID"] as? Int {
                        if let filename = res["romFileName"] as? String, !filename.isEmpty {
                            let key : String = String(systemID) + ":" + filename
                            romFileNameToMD5[key]=md5
                            romFileNameToMD5[filename]=md5
                        }
                        let key : String = String(systemID) + ":" + md5
                        romFileNameToMD5[key]=md5
                    }
                    if let crc = res["romHashCRC"] as? String, !crc.isEmpty {
                        romFileNameToMD5[crc]=md5
                    }
                }
            }
            RomDatabase.artMD5DBCache = romMD5
            RomDatabase.artFileNameToMD5Cache = romFileNameToMD5
        } catch {
            NSLog("Failed to execute query: \(error.localizedDescription)")
        }
    }

    func getArtCache(_ md5:String) -> [String: NSObject]? {
        if RomDatabase.artMD5DBCache == nil {
            NSLog("RomDatabase:getArtCache:Artcache not found reloading")
            self.reloadArtDBCache(nil)
        }
        if let artCache = RomDatabase.artMD5DBCache,
           let art = artCache[md5] {
            return art
        }
        return nil
    }
    
    func getArtCache(_ md5:String, systemIdentifier:String) -> [String: NSObject]? {
        if RomDatabase.artMD5DBCache == nil ||
            RomDatabase.artFileNameToMD5Cache == nil {
            NSLog("RomDatabase:getArtCache:ArtCache not found, reloading")
            self.reloadArtDBCache(nil)
        }
        if let systemID = PVEmulatorConfiguration.databaseID(forSystemID: systemIdentifier),
           let artFile = RomDatabase.artFileNameToMD5Cache,
           let artCache = RomDatabase.artMD5DBCache,
           let md5 = artFile[String(systemID) + ":" + md5],
           let art = artCache[md5] {
            return art
        }
        return nil
    }

    func getArtCacheByFileName(_ filename:String, systemIdentifier:String) ->  [String: NSObject]? {
        if RomDatabase.artMD5DBCache == nil ||
            RomDatabase.artFileNameToMD5Cache == nil {
            NSLog("RomDatabase:getArtCacheByFileName:ArtCache not found, reloading")
            self.reloadArtDBCache(nil)
        }
        if  let systemID = PVEmulatorConfiguration.databaseID(forSystemID: systemIdentifier),
            let artFile = RomDatabase.artFileNameToMD5Cache,
            let artCache = RomDatabase.artMD5DBCache,
            let md5 = artFile[String(systemID) + ":" + filename],
            let art = artCache[md5] {
                return art
        }
        return nil
    }
    
    func getArtCacheByFileName(_ filename:String) -> [String: NSObject]? {
        if RomDatabase.artMD5DBCache == nil || RomDatabase.artFileNameToMD5Cache == nil {
            NSLog("RomDatabase:getArtCacheByFileName: ArtCache not found, reloading")
            self.reloadArtDBCache(nil)
        }
        if let artFile = RomDatabase.artFileNameToMD5Cache,
           let artCache = RomDatabase.artMD5DBCache,
           let md5 = artFile[filename],
           let art = artCache[md5] {
            return art
        }
        return nil
    }
}
