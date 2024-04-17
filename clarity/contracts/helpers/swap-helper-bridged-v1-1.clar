(use-trait ft-trait .trait-sip-010.sip-010-trait)

(define-public (swap-helper-to-amm (token-x-trait <ft-trait>) (token-y-trait <ft-trait>) (token-z-trait <ft-trait>) (factor-y uint) (dx uint) (min-dz (optional uint)))
  (contract-call? .amm-swap-pool-v1-1 swap-helper token-y-trait token-z-trait factor-y (try! (contract-call? .swap-helper-v1-03 swap-helper token-x-trait token-y-trait dx none)) min-dz)
)

(define-public (swap-helper-from-amm (token-x-trait <ft-trait>) (token-y-trait <ft-trait>) (token-z-trait <ft-trait>) (factor-x uint) (dx uint) (min-dz (optional uint)))
  (contract-call? .swap-helper-v1-03 swap-helper token-y-trait token-z-trait (try! (contract-call? .amm-swap-pool-v1-1 swap-helper token-x-trait token-y-trait factor-x dx none)) min-dz)
)

(define-read-only (get-helper-to-amm (token-x principal) (token-y principal) (token-z principal) (factor-y uint) (dx uint))
  (contract-call? .amm-swap-pool-v1-1 get-helper token-y token-z factor-y (try! (contract-call? .swap-helper-v1-03 get-helper token-x token-y dx)))
)

(define-read-only (get-helper-from-amm (token-x principal) (token-y principal) (token-z principal) (factor-x uint) (dx uint))
  (contract-call? .swap-helper-v1-03 get-helper token-y token-z (try! (contract-call? .amm-swap-pool-v1-1 get-helper token-x token-y factor-x dx)))
)

(define-read-only (oracle-instant-helper-to-amm (token-x principal) (token-y principal) (token-z principal) (factor-y uint))
  (ok 
    (mul-down 
      (try! (contract-call? .swap-helper-v1-03 oracle-instant-helper token-x token-y))
      (try! (contract-call? .amm-swap-pool-v1-1 get-oracle-instant token-y token-z factor-y))
    )
  )
)

(define-read-only (oracle-instant-helper-from-amm (token-x principal) (token-y principal) (token-z principal) (factor-x uint))
  (ok 
    (mul-down 
      (try! (contract-call? .amm-swap-pool-v1-1 get-oracle-instant token-x token-y factor-x))
      (try! (contract-call? .swap-helper-v1-03 oracle-instant-helper token-y token-z))    
    )
  )
)

(define-read-only (oracle-resilient-helper-to-amm (token-x principal) (token-y principal) (token-z principal) (factor-y uint))
  (ok 
    (mul-down 
      (try! (contract-call? .swap-helper-v1-03 oracle-resilient-helper token-x token-y))
      (try! (contract-call? .amm-swap-pool-v1-1 get-oracle-resilient token-y token-z factor-y))
    )
  )
)

(define-read-only (oracle-resilient-helper-from-amm (token-x principal) (token-y principal) (token-z principal) (factor-x uint))
  (ok 
    (mul-down 
      (try! (contract-call? .amm-swap-pool-v1-1 get-oracle-resilient token-x token-y factor-x))
      (try! (contract-call? .swap-helper-v1-03 oracle-resilient-helper token-y token-z))    
    )
  )
)

(define-read-only (fee-helper-to-amm (token-x principal) (token-y principal) (token-z principal) (factor-y uint))
  (ok 
    (+
      (try! (contract-call? .swap-helper-v1-03 fee-helper token-x token-y))
      (if (is-some (contract-call? .amm-swap-pool-v1-1 get-pool-exists token-y token-z factor-y))
        (try! (contract-call? .amm-swap-pool-v1-1 get-fee-rate-x token-y token-z factor-y))
        (try! (contract-call? .amm-swap-pool-v1-1 get-fee-rate-y token-z token-y factor-y))
      )
    )
  )
)

(define-read-only (fee-helper-from-amm (token-x principal) (token-y principal) (token-z principal) (factor-x uint))
  (ok 
    (+
      (if (is-some (contract-call? .amm-swap-pool-v1-1 get-pool-exists token-x token-y factor-x))
        (try! (contract-call? .amm-swap-pool-v1-1 get-fee-rate-x token-x token-y factor-x))
        (try! (contract-call? .amm-swap-pool-v1-1 get-fee-rate-y token-y token-x factor-x))
      )
      (try! (contract-call? .swap-helper-v1-03 fee-helper token-y token-z))      
    )
  )
)

(define-read-only (route-helper-to-amm (token-x principal) (token-y principal) (token-z principal) (factor-y uint))
  (ok (append (unwrap-panic (contract-call? .swap-helper-v1-03 route-helper token-x token-y)) token-z))
)

(define-read-only (route-helper-from-amm (token-x principal) (token-y principal) (token-z principal) (factor-x uint))
  (ok (concat (list token-x) (unwrap-panic (contract-call? .swap-helper-v1-03 route-helper token-y token-z))))
)

(define-constant ONE_8 u100000000)

(define-private (mul-down (a uint) (b uint))
    (/ (* a b) ONE_8)
)

(define-private (div-down (a uint) (b uint))
  (if (is-eq a u0)
    u0
    (/ (* a ONE_8) b)
  )
)


