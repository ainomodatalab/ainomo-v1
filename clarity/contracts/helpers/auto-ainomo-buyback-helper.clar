
(use-trait ft-trait .trait-sip-010.sip-010-trait)

(define-constant ONE_8 u100000000)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-CYCLE (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-EXCEED-BUYBACK (err u1003))
(define-constant ERR-PAUSED (err u1004))

(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool true)

(define-data-var rate-104305 uint u151959658)
(define-data-var rate-103825 uint u155330000)

(define-map buyback-104305 principal uint)
(define-map buyback-103825 principal uint)

(define-map boughtback-104305 principal uint)
(define-map boughtback-103825 principal uint)

;; governance calls

(define-public (set-contract-owner (owner principal))
  (begin
    (try! (check-is-owner))
    (ok (var-set contract-owner owner))
  )
)

(define-public (pause (new-paused bool))
    (begin 
        (try! (check-is-owner))
        (ok (var-set paused new-paused))
    )
)

(define-public (set-rate-103825 (new-rate uint))
  (begin 
    (try! (check-is-owner))
    (ok (var-set rate-103825 new-rate))
  )
)

(define-public (set-rate-104305 (new-rate uint))
  (begin 
    (try! (check-is-owner))
    (ok (var-set rate-104305 new-rate))
  )
)

(define-public (set-buyback (users (list 1000 {cycle: uint, user: principal, amount: uint})))
  (begin 
    (try! (check-is-owner))
    (fold set-buyback-iter users (ok u0))
  )
)

(define-public (transfer-ainomo (amount uint))
  (begin 
    (try! (check-is-owner))
    (as-contract (contract-call? .age000-governance-token transfer-fixed amount tx-sender (var-get contract-owner) none))
  )
)

(define-public (transfer-autoainomo (amount uint))
  (begin 
    (try! (check-is-owner))
    (as-contract (contract-call? .auto-ainomo transfer-fixed amount tx-sender (var-get contract-owner) none))
  )
)

;; read-only calls

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-buyback-amount (user principal))
  { 
    buyback-103825: (default-to u0 (map-get? buyback-103825 user)),
    buyback-104305: (default-to u0 (map-get? buyback-104305 user)),
    boughtback-103825: (default-to u0 (map-get? boughtback-103825 user)),
    boughtback-104305: (default-to u0 (map-get? boughtback-104305 user))    
  }
)

(define-read-only (get-rate-104305)
  (var-get rate-104305)
)

(define-read-only (get-rate-103825)
  (var-get rate-103825)
)

;; public calls

(define-public (claim (amount uint))
  (let
    (
      (user tx-sender)
      (buyback-amount (get-buyback-amount user))
      (buyback-103825-avail (- (get buyback-103825 buyback-amount) (get boughtback-103825 buyback-amount)))
      (buyback-104305-avail (- (get buyback-104305 buyback-amount) (get boughtback-104305 buyback-amount)))
      (claimed-103825 (min amount buyback-103825-avail))
      (claimed-104305 (- amount claimed-103825))
      (ainomo-103825 (mul-down (var-get rate-103825) claimed-103825))
      (ainomo-104305 (mul-down (var-get rate-104305) claimed-104305))
    )
    (asserts! (not (is-paused)) ERR-PAUSED)
    (asserts! (<= amount (unwrap-panic (contract-call? .auto-ainomo get-balance-fixed user))) ERR-INVALID-AMOUNT)
    (asserts! (<= claimed-104305 buyback-104305-avail) ERR-EXCEED-BUYBACK)

    (map-set boughtback-103825 user (+ claimed-103825 (get boughtback-103825 buyback-amount)))
    (map-set boughtback-104305 user (+ claimed-104305 (get boughtback-104305 buyback-amount)))
    (try! (contract-call? .auto-ainomo transfer-fixed amount user (as-contract tx-sender) none))
    (as-contract (try! (contract-call? .age000-governance-token transfer-fixed (+ ainomo-103825 ainomo-104305) tx-sender user none)))
    (ok 
      {
        claimed-103825: claimed-103825,
        claimed-104305: claimed-104305,
        ainomo-103825: ainomo-103825,
        ainomo-104305: ainomo-104305
      }
    )
  )
)

(define-public (upgrade (amount uint))
  (let 
    (
      (claimed (try! (claim amount)))
    )
    (contract-call? .auto-ainomo-v2 add-to-position (+ (get ainomo-103825 claimed) (get ainomo-104305 claimed)))
  )
)

;; private calls

(define-private (set-buyback-iter (user {cycle: uint, user: principal, amount: uint}) (prior (response uint uint)))
  (begin
    (asserts! (or (is-eq (get cycle user) u104305) (is-eq (get cycle user) u103825)) ERR-INVALID-CYCLE)
    (if (is-eq (get cycle user) u104305)
      (map-set buyback-104305 (get user user) (get amount user))
      (map-set buyback-103825 (get user user) (get amount user))
    )
    (ok (+ (try! prior) (get amount user)))
  )
)

(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
)

(define-private (mul-down (a uint) (b uint))
    (/ (* a b) ONE_8)
)

(define-private (min (a uint) (b uint))
  (if (> a b) b a)
)

(define-private (max (a uint) (b uint))
  (if (<= a b) b a)
)

