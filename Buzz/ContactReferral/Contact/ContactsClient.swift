import Contacts
import Dependencies
import DependenciesMacros
import Foundation

public struct ContactClientCreateRequest: Equatable, Hashable, Sendable {
  public var givenName: String
  public var familyName: String
  public var phoneNumbers: [String]
  public var avatarData: Data?

  public init(
    givenName: String,
    familyName: String,
    phoneNumbers: [String] = [],
    avatarData: Data? = nil
  ) {
    self.givenName = givenName
    self.familyName = familyName
    self.phoneNumbers = phoneNumbers
    self.avatarData = avatarData
  }
}

/// Our ContactsClient dependency. It hides all usage of `CNContact`.
@DependencyClient
public struct ContactsClient: Sendable {
  public var requestAuthorization: @Sendable () async -> Bool = { true }
  public var fetchContacts: @Sendable () async throws -> [Contact]
  public var fetchContactById: @Sendable (_ id: Contact.ContactListIdentifier) async throws -> Contact
  public var fetchContactsByIds: @Sendable (_ ids: [Contact.ContactListIdentifier]) async throws -> [Contact]
  public var addContact: @Sendable (_ contact: ContactClientCreateRequest) async throws -> Contact
  
  public enum Failure: Error, Equatable {
    case unauthorized
    case fetchFailed
    case contactNotFound
    case saveFailed
  }
}

// MARK: - Live Implementation

private actor ContactsActor {
  let store = CNContactStore()
  
  func requestAuthorization() async -> Bool {
    let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
    guard currentStatus == .notDetermined else {
      return currentStatus == .authorized
    }
    
    return await withCheckedContinuation { continuation in
      store.requestAccess(for: .contacts) { granted, _ in
        continuation.resume(returning: granted)
      }
    }
  }
  
  func fetchContacts() async throws -> [Contact] {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      throw ContactsClient.Failure.unauthorized
    }
    
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactThumbnailImageDataKey as CNKeyDescriptor
    ]
    
    var domainContacts: [Contact] = []
    let request = CNContactFetchRequest(keysToFetch: keys)
    
    try await withCheckedThrowingContinuation { continuation in
      do {
        try self.store.enumerateContacts(with: request) { cnContact, _ in
          let c = self.domainContact(from: cnContact)
          domainContacts.append(c)
        }
        continuation.resume(returning: ())
      } catch {
        continuation.resume(throwing: ContactsClient.Failure.fetchFailed)
      }
    }
    return domainContacts
  }
  
  func fetchContactById(id: Contact.ContactListIdentifier) async throws -> Contact {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      throw ContactsClient.Failure.unauthorized
    }
    
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactThumbnailImageDataKey as CNKeyDescriptor
    ]
    
    do {
      let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
      return domainContact(from: contact)
    } catch {
      throw ContactsClient.Failure.contactNotFound
    }
  }
  
  func fetchContactsByIds(ids: [Contact.ContactListIdentifier]) async throws -> [Contact] {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      throw ContactsClient.Failure.unauthorized
    }
    
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactThumbnailImageDataKey as CNKeyDescriptor
    ]
    
    // Build Predicate
    let predicate = CNContact.predicateForContacts(withIdentifiers: ids)
    
    do {
      let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
      return contacts.map { self.domainContact(from: $0) }
    } catch {
      throw ContactsClient.Failure.fetchFailed
    }
  }
  
  func addContact(_ contactCreateRequest: ContactClientCreateRequest) async throws -> Contact {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      throw ContactsClient.Failure.unauthorized
    }
    
    let mutable = CNMutableContact()
    mutable.givenName = contactCreateRequest.givenName
    mutable.familyName = contactCreateRequest.familyName
    mutable.phoneNumbers = contactCreateRequest.phoneNumbers.map {
      CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0))
    }
    
    let saveRequest = CNSaveRequest()
    saveRequest.add(mutable, toContainerWithIdentifier: nil)
    do {
      try store.execute(saveRequest)
      
      // Create compound predicate matching both name and first phone number
      let namePredicate = CNContact.predicateForContacts(matchingName: "\(contactCreateRequest.givenName) \(contactCreateRequest.familyName)")
      let phoneNumberPredicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: contactCreateRequest.phoneNumbers[0]))
      let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [namePredicate, phoneNumberPredicate])
      
      let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor
      ]
      let contacts = try store.unifiedContacts(matching: compoundPredicate, keysToFetch: keys as [CNKeyDescriptor])
      
      guard let savedContact = contacts.last else {
        throw ContactsClient.Failure.saveFailed
      }
      
      return domainContact(from: savedContact)
    } catch {
      throw ContactsClient.Failure.saveFailed
    }
  }
  
  // MARK: - Conversion
  
  private func domainContact(from cn: CNContact) -> Contact {
    return Contact(
      id: cn.identifier,
      givenName: cn.givenName,
      familyName: cn.familyName,
      phoneNumbers: cn.phoneNumbers.map { $0.value.stringValue },
      avatarData: cn.thumbnailImageData
    )
  }
}

// MARK: - DependencyKey conformance

extension ContactsClient: DependencyKey {
  public static var liveValue: ContactsClient {
    let actor = ContactsActor()
    
    return ContactsClient(
      requestAuthorization: {
        await actor.requestAuthorization()
      },
      fetchContacts: {
        try await actor.fetchContacts()
      },
      fetchContactById: { id in
        print("Fetching: \(id)")
        return try await actor.fetchContactById(id: id)
      },
      fetchContactsByIds: { ids in
        try await actor.fetchContactsByIds(ids: ids)
      },
      addContact: { contact in
        try await actor.addContact(contact)
      }
    )
  }
}

// MARK: - Preview
extension ContactsClient {
  public static var previewValue: ContactsClient {
    let contacts = LockIsolated([Contact].mock)
    return ContactsClient(
      requestAuthorization: { true },
      fetchContacts: { contacts.value },
      fetchContactById: { id in
        guard let contact = (contacts.value.first { $0.id == id }) else {
          throw Failure.contactNotFound
        }
        return contact
      },
      fetchContactsByIds: { ids in
        contacts.value.filter { ids.contains($0.id) }
      },
      addContact: { request in
        let createdContact = Contact(id: .init(), givenName: request.givenName, familyName: request.familyName, phoneNumbers: request.phoneNumbers)
        contacts.withValue { contacts in
          contacts.append(createdContact)
        }
        return createdContact
      }
    )
  }
}
// MARK: - DependencyValues Extension

extension DependencyValues {
  public var contactsClient: ContactsClient {
    get { self[ContactsClient.self] }
    set { self[ContactsClient.self] = newValue }
  }
}
