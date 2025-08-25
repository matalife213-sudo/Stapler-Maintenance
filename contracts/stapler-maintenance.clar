;; stapler-maintenance.clar
;; Basic office equipment care system for stapler maintenance, troubleshooting, and supply tracking

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u401))
(define-constant err-not-found (err u404))
(define-constant err-invalid-status (err u400))

;; Data structures
(define-map staplers
    { stapler-id: uint }
    {
        location: (string-ascii 50),
        status: (string-ascii 20),
        last-maintenance: uint,
        staple-count: uint,
        jam-count: uint
    }
)

(define-map maintenance-requests
    { request-id: uint }
    {
        stapler-id: uint,
        request-type: (string-ascii 30),
        status: (string-ascii 20),
        created-at: uint,
        resolved-at: (optional uint),
        notes: (string-ascii 200)
    }
)

(define-map troubleshooting-guides
    { issue-type: (string-ascii 30) }
    {
        steps: (string-ascii 500),
        difficulty: (string-ascii 10),
        est-time: uint
    }
)

(define-data-var next-stapler-id uint u1)
(define-data-var next-request-id uint u1)

;; Register new stapler
(define-public (register-stapler (location (string-ascii 50)))
    (let
        ((stapler-id (var-get next-stapler-id)))
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (map-set staplers
            { stapler-id: stapler-id }
            {
                location: location,
                status: "operational",
                last-maintenance: stacks-block-height,
                staple-count: u0,
                jam-count: u0
            }
        )
        (var-set next-stapler-id (+ stapler-id u1))
        (ok stapler-id)
    )
)

;; Submit maintenance request
(define-public (submit-maintenance-request
    (stapler-id uint)
    (request-type (string-ascii 30))
    (notes (string-ascii 200)))
    (let
        ((request-id (var-get next-request-id)))
        (asserts! (is-some (map-get? staplers { stapler-id: stapler-id })) err-not-found)
        (map-set maintenance-requests
            { request-id: request-id }
            {
                stapler-id: stapler-id,
                request-type: request-type,
                status: "pending",
                created-at: stacks-block-height,
                resolved-at: none,
                notes: notes
            }
        )
        (var-set next-request-id (+ request-id u1))
        (ok request-id)
    )
)

;; Clear jam and update counters
(define-public (clear-jam (stapler-id uint))
    (match (map-get? staplers { stapler-id: stapler-id })
        stapler-data
        (begin
            (map-set staplers
                { stapler-id: stapler-id }
                (merge stapler-data {
                    status: "operational",
                    jam-count: (+ (get jam-count stapler-data) u1),
                    last-maintenance: stacks-block-height
                })
            )
            (ok true)
        )
        err-not-found
    )
)

;; Refill staples
(define-public (refill-staples (stapler-id uint) (staple-count uint))
    (match (map-get? staplers { stapler-id: stapler-id })
        stapler-data
        (begin
            (map-set staplers
                { stapler-id: stapler-id }
                (merge stapler-data {
                    staple-count: staple-count,
                    last-maintenance: stacks-block-height
                })
            )
            (ok true)
        )
        err-not-found
    )
)

;; Resolve maintenance request
(define-public (resolve-request (request-id uint))
    (match (map-get? maintenance-requests { request-id: request-id })
        request-data
        (begin
            (asserts! (is-eq (get status request-data) "pending") err-invalid-status)
            (map-set maintenance-requests
                { request-id: request-id }
                (merge request-data {
                    status: "resolved",
                    resolved-at: (some stacks-block-height)
                })
            )
            (ok true)
        )
        err-not-found
    )
)

;; Add troubleshooting guide
(define-public (add-troubleshooting-guide
    (issue-type (string-ascii 30))
    (steps (string-ascii 500))
    (difficulty (string-ascii 10))
    (est-time uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (map-set troubleshooting-guides
            { issue-type: issue-type }
            {
                steps: steps,
                difficulty: difficulty,
                est-time: est-time
            }
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-stapler (stapler-id uint))
    (map-get? staplers { stapler-id: stapler-id })
)

(define-read-only (get-maintenance-request (request-id uint))
    (map-get? maintenance-requests { request-id: request-id })
)

(define-read-only (get-troubleshooting-guide (issue-type (string-ascii 30)))
    (map-get? troubleshooting-guides { issue-type: issue-type })
)

(define-read-only (get-stapler-status (stapler-id uint))
    (match (map-get? staplers { stapler-id: stapler-id })
        stapler-data (ok (get status stapler-data))
        err-not-found
    )
)
