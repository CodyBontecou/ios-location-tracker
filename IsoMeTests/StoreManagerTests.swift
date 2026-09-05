import XCTest
@testable import IsoMe

final class StoreManagerTests: XCTestCase {
    func testProductCatalogContainsIndividualFamilyAndUpgrade() {
        XCTAssertEqual(
            Set(IsoMePurchaseOption.allCases),
            Set([.individual, .family, .familyUpgrade])
        )
        XCTAssertEqual(
            Set(StoreManager.productIDs),
            Set([
                "com.bontecou.isome.lifetime.individual",
                "com.bontecou.isome.lifetime",
                "com.bontecou.isome.lifetime.family.upgrade",
            ])
        )
    }

    func testOriginalLifetimeProductIsTheGrandfatheredFamilyPlan() {
        XCTAssertEqual(StoreManager.familyProductID, "com.bontecou.isome.lifetime")
        XCTAssertTrue(StoreManager.isFamilyEntitlement(productID: StoreManager.familyProductID))
    }

    func testFamilyUpgradeEligibilityRequiresOnlyIndividualLifetime() {
        XCTAssertTrue(
            StoreManager.canBuyFamilyUpgrade(unlockedProductID: StoreManager.individualProductID)
        )
        XCTAssertFalse(
            StoreManager.canBuyFamilyUpgrade(unlockedProductID: StoreManager.familyProductID)
        )
        XCTAssertFalse(
            StoreManager.canBuyFamilyUpgrade(unlockedProductID: StoreManager.familyUpgradeProductID)
        )
        XCTAssertFalse(StoreManager.canBuyFamilyUpgrade(unlockedProductID: nil))
    }

    func testPreferredEntitlementPrioritizesFamilyOverUpgradeOverIndividual() {
        XCTAssertEqual(
            StoreManager.preferredEntitlementProductID(from: [
                StoreManager.individualProductID,
                StoreManager.familyUpgradeProductID,
                StoreManager.familyProductID,
            ]),
            StoreManager.familyProductID
        )
        XCTAssertEqual(
            StoreManager.preferredEntitlementProductID(from: [
                StoreManager.individualProductID,
                StoreManager.familyUpgradeProductID,
            ]),
            StoreManager.familyUpgradeProductID
        )
        XCTAssertEqual(
            StoreManager.preferredEntitlementProductID(from: [StoreManager.individualProductID]),
            StoreManager.individualProductID
        )
        XCTAssertNil(
            StoreManager.preferredEntitlementProductID(from: ["com.example.unknown"])
        )
    }

    func testAnalyticsProductIDsMatchStoreKitProductIDs() {
        for option in IsoMePurchaseOption.allCases {
            XCTAssertEqual(option.analyticsProductID.rawValue, option.productID)
        }
    }
}
