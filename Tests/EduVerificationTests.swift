import Foundation

@main
struct EduVerificationTests {
    static func main() {
        var count = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, name)
            count += 1
        }

        let domains = ["yalova.edu.tr"]
        check(EduEmailCheck.looksLikeEmail("student@yalova.edu.tr"), "valid email shape")
        check(EduEmailCheck.isAllowed("student@yalova.edu.tr", domains: domains), "root domain")
        check(EduEmailCheck.isAllowed("student@ogrenci.yalova.edu.tr", domains: domains), "student subdomain")
        check(EduEmailCheck.isAllowed("STUDENT@OGR.YALOVA.EDU.TR", domains: domains), "case insensitive")
        check(!EduEmailCheck.isAllowed("student@gmail.com", domains: domains), "personal email rejected")
        check(!EduEmailCheck.isAllowed("student@fakeyalova.edu.tr", domains: domains), "suffix confusion rejected")
        check(!EduEmailCheck.isAllowed("@yalova.edu.tr", domains: domains), "missing local part rejected")
        check(!EduEmailCheck.isAllowed("student@yalova.edu.tr.evil.test", domains: domains), "lookalike rejected")
        check(!EduEmailCheck.isAllowed("student@yalova.edu.tr", domains: []), "empty allowlist fails closed")

        let verified = EduVerificationStatus(email: "student@yalova.edu.tr", verifiedAt: .now, exempt: false, pendingEmail: nil)
        check(verified.isVerified && !verified.needsAttention, "verified account complete")
        let pending = EduVerificationStatus(email: nil, verifiedAt: nil, exempt: false, pendingEmail: "student@yalova.edu.tr")
        check(pending.isPending && pending.needsAttention, "pending account remains actionable")
        let exempt = EduVerificationStatus(email: nil, verifiedAt: nil, exempt: true, pendingEmail: nil)
        check(!exempt.needsAttention, "review and staff exemption")

        print("Edu verification: \(count) checks passed.")
    }
}
