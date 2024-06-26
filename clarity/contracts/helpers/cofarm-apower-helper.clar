(impl-trait .trait-ownable.ownable-trait)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-ALREADY-PROCESSED (err u1409))
(define-constant ERR-DISTRIBUTION (err u1410))

(define-constant ONE_8 (pow u10 u8))

(define-map distributed-per-cycle uint uint)
(define-map user-distributed-per-cycle { user: principal, cycle: uint } bool)
(define-map processed-batches { cycle: uint, batch: uint } bool)

(define-data-var contract-owner principal tx-sender)
(define-map approved-contracts principal bool)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (owner principal))
  (begin
    (try! (check-is-owner))
    (ok (var-set contract-owner owner))
  )
)

(define-public (add-approved-contract (new-approved-contract principal))
	(begin
		(try! (check-is-owner))
		(ok (map-set approved-contracts new-approved-contract true))
	)
)

(define-public (set-approved-contract (owner principal) (approved bool))
	(begin
		(try! (check-is-owner))
		(ok (map-set approved-contracts owner approved))
	)
)

(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
)

(define-private (check-is-approved)
  (ok (asserts! (default-to false (map-get? approved-contracts tx-sender)) ERR-NOT-AUTHORIZED))
)

(define-read-only (get-distributed-per-cycle-or-default (cycle uint))
  (default-to u0 (map-get? distributed-per-cycle cycle))
)

(define-read-only (get-user-distributed-per-cycle-or-default (user principal) (cycle uint))
  (default-to false (map-get? user-distributed-per-cycle { user: user, cycle: cycle }))
)

(define-private (distribute-iter (recipient principal) (prior (response { cycle: uint, atainomo: uint, balance: uint, sum: uint } uint)))
  (let 
    (
      (prior-unwrapped (try! prior))
      (cycle (get cycle prior-unwrapped))
      (sum (get sum prior-unwrapped))
      (atainomo (get atainomo prior-unwrapped))
      (balance (get balance prior-unwrapped))
      (shares (div-down (mul-down atainomo (contract-call? .fwp-wstx-ainomo-tranched-64 get-user-balance-per-cycle-or-default recipient cycle)) balance))
    )
    (if (get-user-distributed-per-cycle-or-default recipient cycle)
      ;; if the user already received distribution, then skip
      (ok { cycle: cycle, atainomo: atainomo, balance: balance, sum: sum })
      (let 
        (
            (ainomo (if (is-eq shares u0) u0 (try! (contract-call? .auto-ainomo get-token-given-position shares))))
            (apower (if (is-eq ainomo u0) u0 (mul-down ainomo (contract-call? .ainomo-reserve-pool get-apower-multiplier-in-fixed-or-default .fwp-wstx-ainomo-50-50-v1-01))))
        ) 
        (and 
            (> apower u0) 
            (as-contract (try! (contract-call? .token-apower mint-fixed apower recipient)))
            (as-contract (try! (contract-call? .token-apower burn-fixed apower .fwp-wstx-ainomo-tranched-64)))
        )
        (map-set user-distributed-per-cycle { user: recipient, cycle: cycle } true)
        (ok { cycle: cycle, atainomo: atainomo, balance: balance, sum: (+ sum shares) })
      )
    )
  )
)

(define-read-only (is-cycle-batch-processed (cycle uint) (batch uint))
  (default-to
    false
    (map-get? processed-batches { cycle: cycle, batch: batch })
  )
)

(define-public (distribute-apower-only (cycle uint) (batch uint) (recipients (list 200 principal)))
	(let
        (
            (distributable-per-cycle (contract-call? .fwp-wstx-ainomo-tranched-64 get-distributable-per-cycle-or-default cycle))
        )
        (asserts! (or (is-ok (check-is-owner)) (is-ok (check-is-approved))) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (is-cycle-batch-processed cycle batch) false) ERR-ALREADY-PROCESSED)
        (asserts! (> distributable-per-cycle u0) ERR-DISTRIBUTION)
        (let
            (
                (output (try! (fold distribute-iter recipients (ok { cycle: cycle, atainomo: distributable-per-cycle, balance:  (contract-call? .fwp-wstx-ainomo-tranched-64 get-total-balance-per-cycle-or-default cycle), sum: u0 }))))
            )
            (map-set processed-batches { cycle: cycle, batch: batch } true)            
            (map-set distributed-per-cycle cycle (+ (get-distributed-per-cycle-or-default cycle) (get sum output)))

            (ok (get sum output))
        )
	)
)

(define-public (distribute (cycle uint) (batch uint) (recipients (list 200 principal)))
    (begin 
        (try! (contract-call? .fwp-wstx-ainomo-tranched-64 distribute cycle batch recipients))
        (distribute-apower-only cycle batch recipients)
    )
)

(define-private (mul-down (a uint) (b uint))
    (/ (* a b) ONE_8)
)

(define-private (div-down (a uint) (b uint))
  (if (is-eq a u0)
    u0
    (/ (* a ONE_8) b)
  )
)

;; contract initialisation
;; (set-contract-owner .executor-dao)
