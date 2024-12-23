import Foundation
import SwiftData
import SwiftUI
import Observation

import GRDB
import Foundation

/// A Contact Referral Record stored in the database
public struct ReferralRecord: Codable, Sendable {
  public var contactUUID: UUID
  public var referredByUUID: UUID?  // Optional UUID for the referrer
  public var createdOn: Date
  
  // Database initializer
  public init(
    contactUUID: UUID = UUID(),
    referredByUUID: UUID? = nil,
    createdOn: Date = Date()
  ) {
    self.contactUUID = contactUUID
    self.referredByUUID = referredByUUID
    self.createdOn = createdOn
  }
}

extension ReferralRecord: Identifiable {
  public var id: UUID {
    contactUUID
  }
}

extension ReferralRecord: FetchableRecord, PersistableRecord {
  /// Database Table Name
  public static let databaseTableName = "contact_referral_records"
  
  /// Association to parent referral
  static let referrer = belongsTo(ReferralRecord.self, key: "referrer", using: ForeignKey(["referredByUUID"]))
  
  /// Association to child referrals
  static let referrals = hasMany(ReferralRecord.self, key: "referrals", using: ForeignKey(["referredByUUID"]))
  
  /// Columns Enum
  public enum Columns {
    public static let contactUUID = Column("contactUUID")
    public static let referredByUUID = Column("referredByUUID")
    public static let createdOn = Column("createdOn")
  }
  
  /// Table Creation
  public static func createTable(_ db: Database) throws {
    try db.create(table: databaseTableName, ifNotExists: true) { t in
      t.column("contactUUID", .text)
        .notNull()
        .unique()
        .primaryKey()
      t.column("referredByUUID", .text)
        .references(databaseTableName, onDelete: .setNull) // Handle parent deletion
      t.column("createdOn", .datetime).notNull()
    }
  }
}
