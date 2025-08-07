;; FreelanceConnect: Decentralized Talent Marketplace Smart Contract
;; 
;; A blockchain-based platform that connects skilled freelancers with clients
;; through secure, transparent smart contracts. Features automated escrow payments, 
;; on-chain reputation tracking, milestone-based project management, and decentralized
;; dispute resolution. All core functionality operates on-chain with cryptographic
;; verification and transparent state management.

;; ERROR CONSTANTS

(define-constant ERR-ACCESS-DENIED (err u100))
(define-constant ERR-WORK-AGREEMENT-EXISTS (err u101))
(define-constant ERR-WORK-AGREEMENT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS-CHANGE (err u103))
(define-constant ERR-PAYMENT-AMOUNT-TOO-LOW (err u104))
(define-constant ERR-INVALID-WALLET-ADDRESS (err u105))
(define-constant ERR-INVALID-PARAMETERS (err u106))
(define-constant ERR-PLATFORM-UNDER-MAINTENANCE (err u107))
(define-constant ERR-INVALID-PROJECT-TIMELINE (err u108))
(define-constant ERR-RATING-VALUE-OUT-OF-BOUNDS (err u109))
(define-constant ERR-SELF-CONTRACTING-NOT-ALLOWED (err u110))
(define-constant ERR-DISPUTE-RESOLUTION-EXPIRED (err u111))
(define-constant ERR-PAYMENT-ALREADY-RELEASED (err u112))
(define-constant ERR-INSUFFICIENT-FUNDS (err u113))
(define-constant ERR-MILESTONE-ALREADY-EXISTS (err u114))
(define-constant ERR-INVALID-MILESTONE-NUMBER (err u115))

;; PLATFORM CONFIGURATION VARIABLES

(define-data-var marketplace-administrator-wallet principal tx-sender)
(define-data-var total-work-agreements-created uint u0)
(define-data-var platform-service-status bool true)
(define-data-var minimum-project-value-threshold uint u1000000) ;; 1 STX minimum
(define-data-var marketplace-commission-rate uint u250) ;; 2.5% platform fee
(define-data-var dispute-resolution-window-blocks uint u1008) ;; ~1 week in blocks

;; CORE DATA STRUCTURES

;; Work agreement registry with escrow functionality
(define-map professional-work-agreements
    { agreement-identifier: uint }
    {
        service-provider-wallet: principal,
        project-client-wallet: principal,
        project-initiation-timestamp: uint,
        project-completion-deadline: uint,
        agreed-compensation-amount: uint,
        work-agreement-status: (string-ascii 30),
        compensation-disbursed: bool,
        project-completion-timestamp: (optional uint),
        escrowed-funds: uint
    }
)

;; Service provider reputation tracking
(define-map service-provider-profiles
    { provider-wallet-address: principal }
    {
        cumulative-performance-rating: uint,
        total-projects-undertaken: uint,
        successfully-delivered-projects: uint,
        profile-creation-timestamp: uint,
        lifetime-earnings-total: uint,
        professional-verification-status: bool
    }
)

;; Client reputation and spending tracking
(define-map project-client-profiles
    { client-wallet-address: principal }
    {
        total-projects-initiated: uint,
        client-registration-timestamp: uint,
        cumulative-platform-spending: uint,
        client-trustworthiness-score: uint,
        payment-reliability-rating: uint
    }
)

;; On-chain dispute management system
(define-map work-agreement-disputes
    { disputed-agreement-id: uint }
    {
        dispute-initiator-wallet: principal,
        current-dispute-status: (string-ascii 25),
        administrator-final-decision: bool,
        dispute-submission-timestamp: uint,
        arbitration-deadline-timestamp: uint
    }
)

;; Project milestone tracking with payment release
(define-map project-milestone-registry
    { agreement-id: uint, milestone-sequence-number: uint }
    {
        milestone-compensation-value: uint,
        milestone-completion-status: bool,
        milestone-delivery-timestamp: (optional uint),
        client-approval-received: bool,
        milestone-review-deadline: uint
    }
)

;; Performance ratings for completed work
(define-map performance-ratings
    { rated-provider-wallet: principal, rating-block-height: uint }
    {
        rating-score: uint,
        rating-timestamp: uint
    }
)

;; PLATFORM ADMINISTRATION FUNCTIONS

;; Transfer platform ownership
(define-public (transfer-marketplace-ownership (new-administrator-wallet principal))
    (begin
        (asserts! (is-eq tx-sender (var-get marketplace-administrator-wallet)) ERR-ACCESS-DENIED)
        (asserts! (validate-wallet-address-format new-administrator-wallet) ERR-INVALID-WALLET-ADDRESS)
        (var-set marketplace-administrator-wallet new-administrator-wallet)
        (ok true)
    )
)

;; Toggle platform operational status
(define-public (modify-platform-operational-status (updated-service-status bool))
    (begin
        (asserts! (is-eq tx-sender (var-get marketplace-administrator-wallet)) ERR-ACCESS-DENIED)
        (var-set platform-service-status updated-service-status)
        (ok true)
    )
)

;; Update marketplace commission rate
(define-public (adjust-marketplace-commission-rate (new-commission-percentage uint))
    (begin
        (asserts! (is-eq tx-sender (var-get marketplace-administrator-wallet)) ERR-ACCESS-DENIED)
        (asserts! (<= new-commission-percentage u1000) ERR-INVALID-PARAMETERS) ;; Maximum 10%
        (var-set marketplace-commission-rate new-commission-percentage)
        (ok true)
    )
)

;; Configure minimum project value
(define-public (set-minimum-project-threshold (new-minimum-value uint))
    (begin
        (asserts! (is-eq tx-sender (var-get marketplace-administrator-wallet)) ERR-ACCESS-DENIED)
        (asserts! (>= new-minimum-value u100000) ERR-INVALID-PARAMETERS) ;; Minimum 0.1 STX
        (var-set minimum-project-value-threshold new-minimum-value)
        (ok true)
    )
)

;; WORK AGREEMENT LIFECYCLE WITH ESCROW

;; Create work agreement with automatic escrow
(define-public (establish-professional-work-agreement
    (unique-agreement-identifier uint)
    (selected-service-provider-wallet principal)
    (project-start-timestamp uint)
    (project-delivery-deadline uint)
    (total-compensation-amount uint))
    
    (let ((platform-currently-active (var-get platform-service-status))
          (existing-agreement-check (retrieve-work-agreement-details unique-agreement-identifier))
          (platform-fee (/ (* total-compensation-amount (var-get marketplace-commission-rate)) u10000)))
        
        (asserts! platform-currently-active ERR-PLATFORM-UNDER-MAINTENANCE)
        (asserts! (is-none existing-agreement-check) ERR-WORK-AGREEMENT-EXISTS)
        (asserts! (>= project-delivery-deadline project-start-timestamp) ERR-INVALID-PROJECT-TIMELINE)
        (asserts! (>= total-compensation-amount (var-get minimum-project-value-threshold)) ERR-PAYMENT-AMOUNT-TOO-LOW)
        (asserts! (validate-wallet-address-format selected-service-provider-wallet) ERR-INVALID-WALLET-ADDRESS)
        (asserts! (not (is-eq selected-service-provider-wallet tx-sender)) ERR-SELF-CONTRACTING-NOT-ALLOWED)
        (asserts! (>= (stx-get-balance tx-sender) (+ total-compensation-amount platform-fee)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer funds to contract escrow
        (try! (stx-transfer? (+ total-compensation-amount platform-fee) tx-sender (as-contract tx-sender)))
        
        ;; Create work agreement record
        (map-set professional-work-agreements
            { agreement-identifier: unique-agreement-identifier }
            {
                service-provider-wallet: selected-service-provider-wallet,
                project-client-wallet: tx-sender,
                project-initiation-timestamp: project-start-timestamp,
                project-completion-deadline: project-delivery-deadline,
                agreed-compensation-amount: total-compensation-amount,
                work-agreement-status: "awaiting-provider-acceptance",
                compensation-disbursed: false,
                project-completion-timestamp: none,
                escrowed-funds: (+ total-compensation-amount platform-fee)
            }
        )
        
        ;; Update participant profiles
        (initialize-or-update-provider-metrics selected-service-provider-wallet)
        (initialize-or-update-client-metrics tx-sender)
        (var-set total-work-agreements-created (+ (var-get total-work-agreements-created) u1))
        (ok unique-agreement-identifier)
    )
)

;; Provider accepts work agreement
(define-public (provider-accepts-work-agreement (agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (is-eq (get work-agreement-status agreement-details) "awaiting-provider-acceptance") ERR-INVALID-STATUS-CHANGE)
        (asserts! (is-eq tx-sender (get service-provider-wallet agreement-details)) ERR-ACCESS-DENIED)
        
        (map-set professional-work-agreements
            { agreement-identifier: agreement-identifier }
            (merge agreement-details { work-agreement-status: "project-development-phase" })
        )
        (ok true)
    )
)

;; Provider submits completed work
(define-public (submit-completed-work-for-evaluation (agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (is-eq (get work-agreement-status agreement-details) "project-development-phase") ERR-INVALID-STATUS-CHANGE)
        (asserts! (is-eq tx-sender (get service-provider-wallet agreement-details)) ERR-ACCESS-DENIED)
        
        (map-set professional-work-agreements
            { agreement-identifier: agreement-identifier }
            (merge agreement-details { work-agreement-status: "client-review-and-evaluation" })
        )
        (ok true)
    )
)

;; Client approves work and releases payment from escrow
(define-public (approve-deliverables-and-release-payment (agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND))
          (compensation-amount (get agreed-compensation-amount agreement-details))
          (platform-fee (/ (* compensation-amount (var-get marketplace-commission-rate)) u10000)))
        
        (asserts! (is-eq (get work-agreement-status agreement-details) "client-review-and-evaluation") ERR-INVALID-STATUS-CHANGE)
        (asserts! (is-eq tx-sender (get project-client-wallet agreement-details)) ERR-ACCESS-DENIED)
        (asserts! (not (get compensation-disbursed agreement-details)) ERR-PAYMENT-ALREADY-RELEASED)
        
        ;; Release payment to provider
        (try! (as-contract (stx-transfer? compensation-amount tx-sender (get service-provider-wallet agreement-details))))
        ;; Transfer platform fee to admin
        (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get marketplace-administrator-wallet))))
        
        ;; Update agreement status
        (map-set professional-work-agreements
            { agreement-identifier: agreement-identifier }
            (merge agreement-details { 
                work-agreement-status: "successfully-completed",
                compensation-disbursed: true,
                project-completion-timestamp: (some block-height)
            })
        )
        
        ;; Update provider success metrics
        (increment-provider-successful-completions (get service-provider-wallet agreement-details))
        (ok true)
    )
)

;; Client requests work revisions
(define-public (request-work-revisions (agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (is-eq (get work-agreement-status agreement-details) "client-review-and-evaluation") ERR-INVALID-STATUS-CHANGE)
        (asserts! (is-eq tx-sender (get project-client-wallet agreement-details)) ERR-ACCESS-DENIED)
        
        (map-set professional-work-agreements
            { agreement-identifier: agreement-identifier }
            (merge agreement-details { work-agreement-status: "revision-requested" })
        )
        (ok true)
    )
)

;; Provider resubmits revised work
(define-public (resubmit-revised-deliverables (agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (is-eq (get work-agreement-status agreement-details) "revision-requested") ERR-INVALID-STATUS-CHANGE)
        (asserts! (is-eq tx-sender (get service-provider-wallet agreement-details)) ERR-ACCESS-DENIED)
        
        (map-set professional-work-agreements
            { agreement-identifier: agreement-identifier }
            (merge agreement-details { work-agreement-status: "client-review-and-evaluation" })
        )
        (ok true)
    )
)

;; Cancel agreement and return escrowed funds
(define-public (cancel-work-agreement (agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND))
          (escrowed-amount (get escrowed-funds agreement-details)))
        
        (asserts! (or (is-eq tx-sender (get service-provider-wallet agreement-details))
                      (is-eq tx-sender (get project-client-wallet agreement-details))) ERR-ACCESS-DENIED)
        (asserts! (is-eq (get work-agreement-status agreement-details) "awaiting-provider-acceptance") ERR-INVALID-STATUS-CHANGE)
        (asserts! (not (get compensation-disbursed agreement-details)) ERR-PAYMENT-ALREADY-RELEASED)
        
        ;; Return escrowed funds to client
        (try! (as-contract (stx-transfer? escrowed-amount tx-sender (get project-client-wallet agreement-details))))
        
        ;; Update agreement status
        (map-set professional-work-agreements
            { agreement-identifier: agreement-identifier }
            (merge agreement-details { 
                work-agreement-status: "cancelled-by-mutual-agreement",
                escrowed-funds: u0
            })
        )
        (ok true)
    )
)

;; DISPUTE RESOLUTION SYSTEM

;; Initiate dispute for work agreement
(define-public (initiate-work-agreement-dispute (disputed-agreement-identifier uint))
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details disputed-agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (or (is-eq tx-sender (get service-provider-wallet agreement-details))
                      (is-eq tx-sender (get project-client-wallet agreement-details))) ERR-ACCESS-DENIED)
        (asserts! (not (is-eq (get work-agreement-status agreement-details) "successfully-completed")) ERR-INVALID-STATUS-CHANGE)
        
        ;; Create dispute record
        (map-set work-agreement-disputes
            { disputed-agreement-id: disputed-agreement-identifier }
            {
                dispute-initiator-wallet: tx-sender,
                current-dispute-status: "pending-arbitration",
                administrator-final-decision: false,
                dispute-submission-timestamp: block-height,
                arbitration-deadline-timestamp: (+ block-height (var-get dispute-resolution-window-blocks))
            }
        )
        
        ;; Update agreement status
        (map-set professional-work-agreements
            { agreement-identifier: disputed-agreement-identifier }
            (merge agreement-details { work-agreement-status: "under-dispute-arbitration" })
        )
        (ok true)
    )
)

;; Admin resolves dispute with payment decision
(define-public (resolve-disputed-work-agreement
    (disputed-agreement-identifier uint)
    (award-to-provider bool))
    
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details disputed-agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND))
          (dispute-details (unwrap! (retrieve-dispute-information disputed-agreement-identifier) ERR-WORK-AGREEMENT-NOT-FOUND))
          (compensation-amount (get agreed-compensation-amount agreement-details))
          (platform-fee (/ (* compensation-amount (var-get marketplace-commission-rate)) u10000)))
        
        (asserts! (is-eq tx-sender (var-get marketplace-administrator-wallet)) ERR-ACCESS-DENIED)
        (asserts! (is-eq (get work-agreement-status agreement-details) "under-dispute-arbitration") ERR-INVALID-STATUS-CHANGE)
        (asserts! (<= block-height (get arbitration-deadline-timestamp dispute-details)) ERR-DISPUTE-RESOLUTION-EXPIRED)
        (asserts! (not (get compensation-disbursed agreement-details)) ERR-PAYMENT-ALREADY-RELEASED)
        
        ;; Award payment based on decision
        (if award-to-provider
            (begin
                ;; Award to provider
                (try! (as-contract (stx-transfer? compensation-amount tx-sender (get service-provider-wallet agreement-details))))
                (increment-provider-successful-completions (get service-provider-wallet agreement-details))
            )
            ;; Return to client (minus platform fee for dispute resolution)
            (try! (as-contract (stx-transfer? compensation-amount tx-sender (get project-client-wallet agreement-details))))
        )
        
        ;; Platform fee always goes to admin
        (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get marketplace-administrator-wallet))))
        
        ;; Update dispute resolution
        (map-set work-agreement-disputes
            { disputed-agreement-id: disputed-agreement-identifier }
            (merge dispute-details {
                current-dispute-status: "administratively-resolved",
                administrator-final-decision: award-to-provider
            })
        )
        
        ;; Update agreement status
        (map-set professional-work-agreements
            { agreement-identifier: disputed-agreement-identifier }
            (merge agreement-details { 
                work-agreement-status: (if award-to-provider "successfully-completed" "dispute-resolved-for-client"),
                compensation-disbursed: true
            })
        )
        (ok true)
    )
)

;; REPUTATION AND RATING SYSTEM

;; Submit performance rating for completed work
(define-public (submit-provider-performance-rating
    (rated-provider-wallet principal)
    (performance-rating-score uint))
    
    (let ((provider-profile-data (retrieve-provider-professional-profile rated-provider-wallet)))
        
        (asserts! (validate-wallet-address-format rated-provider-wallet) ERR-INVALID-WALLET-ADDRESS)
        (asserts! (validate-rating-value-range performance-rating-score) ERR-RATING-VALUE-OUT-OF-BOUNDS)
        (asserts! (not (is-eq tx-sender rated-provider-wallet)) ERR-SELF-CONTRACTING-NOT-ALLOWED)
        
        ;; Store individual rating
        (map-set performance-ratings
            { rated-provider-wallet: rated-provider-wallet, rating-block-height: block-height }
            {
                rating-score: performance-rating-score,
                rating-timestamp: block-height
            }
        )
        
        ;; Update provider profile if exists
        (match provider-profile-data
            existing-provider-data
            (begin
                (map-set service-provider-profiles
                    { provider-wallet-address: rated-provider-wallet }
                    (merge existing-provider-data {
                        cumulative-performance-rating: (calculate-weighted-performance-average 
                            (get cumulative-performance-rating existing-provider-data)
                            (get total-projects-undertaken existing-provider-data)
                            performance-rating-score)
                    })
                )
                (ok true)
            )
            (ok false)
        )
    )
)

;; Admin verification of provider credentials
(define-public (verify-provider-professional-credentials (provider-wallet-for-verification principal))
    (let ((provider-profile-data (retrieve-provider-professional-profile provider-wallet-for-verification)))
        
        (asserts! (is-eq tx-sender (var-get marketplace-administrator-wallet)) ERR-ACCESS-DENIED)
        (asserts! (validate-wallet-address-format provider-wallet-for-verification) ERR-INVALID-WALLET-ADDRESS)
        
        (match provider-profile-data
            existing-provider-data
            (begin
                (map-set service-provider-profiles
                    { provider-wallet-address: provider-wallet-for-verification }
                    (merge existing-provider-data { professional-verification-status: true })
                )
                (ok true)
            )
            (ok false)
        )
    )
)

;; MILESTONE MANAGEMENT SYSTEM

;; Create project milestone with proper validation
(define-public (establish-project-milestone
    (parent-agreement-id uint)
    (milestone-sequence-number uint)
    (milestone-compensation-amount uint)
    (milestone-delivery-deadline uint))
    
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details parent-agreement-id) ERR-WORK-AGREEMENT-NOT-FOUND))
          (validated-milestone-number (validate-milestone-sequence-number milestone-sequence-number))
          (existing-milestone (retrieve-milestone-information parent-agreement-id validated-milestone-number)))
        
        (asserts! (or (is-eq tx-sender (get service-provider-wallet agreement-details))
                      (is-eq tx-sender (get project-client-wallet agreement-details))) ERR-ACCESS-DENIED)
        (asserts! (> milestone-compensation-amount u0) ERR-INVALID-PARAMETERS)
        (asserts! (> milestone-delivery-deadline block-height) ERR-INVALID-PROJECT-TIMELINE)
        (asserts! (> validated-milestone-number u0) ERR-INVALID-MILESTONE-NUMBER) ;; Check validation result
        (asserts! (is-none existing-milestone) ERR-MILESTONE-ALREADY-EXISTS)
        
        (map-set project-milestone-registry
            { agreement-id: parent-agreement-id, milestone-sequence-number: validated-milestone-number }
            {
                milestone-compensation-value: milestone-compensation-amount,
                milestone-completion-status: false,
                milestone-delivery-timestamp: none,
                client-approval-received: false,
                milestone-review-deadline: milestone-delivery-deadline
            }
        )
        (ok true)
    )
)

;; Complete milestone
(define-public (complete-project-milestone
    (parent-agreement-id uint)
    (completed-milestone-number uint))
    
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details parent-agreement-id) ERR-WORK-AGREEMENT-NOT-FOUND))
          (validated-milestone-number (validate-milestone-sequence-number completed-milestone-number))
          (milestone-details (unwrap! (retrieve-milestone-information parent-agreement-id validated-milestone-number) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender (get service-provider-wallet agreement-details)) ERR-ACCESS-DENIED)
        (asserts! (> validated-milestone-number u0) ERR-INVALID-MILESTONE-NUMBER) ;; Check validation result
        (asserts! (not (get milestone-completion-status milestone-details)) ERR-INVALID-STATUS-CHANGE)
        
        (map-set project-milestone-registry
            { agreement-id: parent-agreement-id, milestone-sequence-number: validated-milestone-number }
            (merge milestone-details {
                milestone-completion-status: true,
                milestone-delivery-timestamp: (some block-height)
            })
        )
        (ok true)
    )
)

;; Approve milestone
(define-public (approve-completed-milestone
    (parent-agreement-id uint)
    (approved-milestone-number uint))
    
    (let ((agreement-details (unwrap! (retrieve-work-agreement-details parent-agreement-id) ERR-WORK-AGREEMENT-NOT-FOUND))
          (validated-milestone-number (validate-milestone-sequence-number approved-milestone-number))
          (milestone-details (unwrap! (retrieve-milestone-information parent-agreement-id validated-milestone-number) ERR-WORK-AGREEMENT-NOT-FOUND)))
        
        (asserts! (is-eq tx-sender (get project-client-wallet agreement-details)) ERR-ACCESS-DENIED)
        (asserts! (> validated-milestone-number u0) ERR-INVALID-MILESTONE-NUMBER) ;; Check validation result
        (asserts! (get milestone-completion-status milestone-details) ERR-INVALID-STATUS-CHANGE)
        (asserts! (not (get client-approval-received milestone-details)) ERR-INVALID-STATUS-CHANGE)
        
        (map-set project-milestone-registry
            { agreement-id: parent-agreement-id, milestone-sequence-number: validated-milestone-number }
            (merge milestone-details { client-approval-received: true })
        )
        (ok true)
    )
)

;; PUBLIC READ-ONLY QUERY FUNCTIONS

(define-read-only (retrieve-work-agreement-details (agreement-identifier uint))
    (map-get? professional-work-agreements { agreement-identifier: agreement-identifier })
)

(define-read-only (retrieve-provider-professional-profile (provider-wallet-address principal))
    (map-get? service-provider-profiles { provider-wallet-address: provider-wallet-address })
)

(define-read-only (retrieve-client-organizational-profile (client-wallet-address principal))
    (map-get? project-client-profiles { client-wallet-address: client-wallet-address })
)

(define-read-only (retrieve-dispute-information (disputed-agreement-identifier uint))
    (map-get? work-agreement-disputes { disputed-agreement-id: disputed-agreement-identifier })
)

(define-read-only (get-marketplace-administrator-wallet)
    (var-get marketplace-administrator-wallet)
)

(define-read-only (retrieve-comprehensive-platform-statistics)
    {
        total-agreements-created: (var-get total-work-agreements-created),
        current-commission-rate: (var-get marketplace-commission-rate),
        minimum-project-threshold: (var-get minimum-project-value-threshold),
        platform-operational-status: (var-get platform-service-status),
        dispute-resolution-window: (var-get dispute-resolution-window-blocks)
    }
)

(define-read-only (retrieve-milestone-information (parent-agreement-id uint) (milestone-sequence-number uint))
    (map-get? project-milestone-registry { agreement-id: parent-agreement-id, milestone-sequence-number: milestone-sequence-number })
)

(define-read-only (get-performance-rating (rated-provider-wallet principal) (rating-block-height uint))
    (map-get? performance-ratings { rated-provider-wallet: rated-provider-wallet, rating-block-height: rating-block-height })
)

;; PRIVATE HELPER FUNCTIONS

;; Initialize or update provider metrics
(define-private (initialize-or-update-provider-metrics (provider-wallet-address principal))
    (match (retrieve-provider-professional-profile provider-wallet-address)
        existing-provider-profile
        (map-set service-provider-profiles
            { provider-wallet-address: provider-wallet-address }
            (merge existing-provider-profile {
                total-projects-undertaken: (+ (get total-projects-undertaken existing-provider-profile) u1)
            })
        )
        (map-set service-provider-profiles
            { provider-wallet-address: provider-wallet-address }
            {
                cumulative-performance-rating: u0,
                total-projects-undertaken: u1,
                successfully-delivered-projects: u0,
                profile-creation-timestamp: block-height,
                lifetime-earnings-total: u0,
                professional-verification-status: false
            }
        )
    )
)

;; Initialize or update client metrics
(define-private (initialize-or-update-client-metrics (client-wallet-address principal))
    (match (retrieve-client-organizational-profile client-wallet-address)
        existing-client-profile
        (map-set project-client-profiles
            { client-wallet-address: client-wallet-address }
            (merge existing-client-profile {
                total-projects-initiated: (+ (get total-projects-initiated existing-client-profile) u1)
            })
        )
        (map-set project-client-profiles
            { client-wallet-address: client-wallet-address }
            {
                total-projects-initiated: u1,
                client-registration-timestamp: block-height,
                cumulative-platform-spending: u0,
                client-trustworthiness-score: u0,
                payment-reliability-rating: u5
            }
        )
    )
)

;; Increment provider successful completions
(define-private (increment-provider-successful-completions (provider-wallet-address principal))
    (match (retrieve-provider-professional-profile provider-wallet-address)
        provider-profile-data
        (begin
            (map-set service-provider-profiles
                { provider-wallet-address: provider-wallet-address }
                (merge provider-profile-data {
                    successfully-delivered-projects: (+ (get successfully-delivered-projects provider-profile-data) u1)
                })
            )
            true
        )
        false
    )
)

;; Calculate weighted performance average
(define-private (calculate-weighted-performance-average
    (current-cumulative-average uint)
    (total-existing-ratings uint)
    (new-performance-rating uint))
    (if (is-eq total-existing-ratings u0)
        new-performance-rating
        (/ (+ (* current-cumulative-average total-existing-ratings) new-performance-rating) (+ total-existing-ratings u1))
    )
)

;; VALIDATION FUNCTIONS

;; Validate wallet address format
(define-private (validate-wallet-address-format (wallet-address principal))
    (is-ok (principal-destruct? wallet-address))
)

;; Validate rating values
(define-private (validate-rating-value-range (rating-value uint))
    (and (>= rating-value u1) (<= rating-value u5))
)

;; Validate milestone sequence number to prevent malicious inputs
(define-private (validate-milestone-sequence-number (sequence-number uint))
    (if (and (> sequence-number u0) (<= sequence-number u1000))
        sequence-number
        u0 ;; Return 0 for invalid numbers, will be caught by caller
    )
)