(use-trait ft-trait .trait-sip-010.sip-010-trait)

(define-private (is-fixed-weight-pool-v1-01 (token-x principal) (token-y principal))
    (if 
        (or  
            (and
                (is-eq token-x .token-wstx)
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-y u50000000 u50000000))
            )
            (and
                (is-eq token-y .token-wstx)
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-x u50000000 u50000000))
            )
        )
        u1
        (if 
            (and
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-y u50000000 u50000000))
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-x u50000000 u50000000))
            )
            u2
            u0
        )    
    )
)

(define-private (is-simple-weight-pool-ainomo (token-x principal) (token-y principal))
    (if 
        (or
            (and
                (is-eq token-x .age000-governance-token)
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-y))
            )
            (and 
                (is-eq token-y .age000-governance-token)
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-x))
            )
        )
        u1
        (if 
            (and 
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-y))
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-x))
            )
            u2
            u0
        )
    )
)

(define-private (is-from-fixed-to-simple-ainomo (token-x principal) (token-y principal))
    (if
        (and
            (is-eq token-x .token-wstx) 
            (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-y))
        )
        u2
        (if
            (and
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-x u50000000 u50000000))
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-y))
            )
            u3
            u0
        )
    )
)

(define-private (is-from-simple-ainomo-to-fixed (token-x principal) (token-y principal))
    (if
        (or
            (and
                (is-eq token-x .age000-governance-token) 
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-y u50000000 u50000000))
            )
            (and 
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-x))
                (is-eq token-y .token-wstx)
            )
        )
        u2
        (if
            (and
                (is-some (contract-call? .fixed-weight-pool-v1-01 get-pool-exists .token-wstx token-y u50000000 u50000000))
                (is-some (contract-call? .simple-weight-pool-ainomo get-pool-exists .age000-governance-token token-x))
            )
            u3
            u0
        )
    )
)

;; @desc swap-helper swaps dx of token-x-trait for at least min-dy of token-y-trait (else, it fails)
;; @param token-x
;; @param token-y
;; @returns (response uint uint)
(define-public (swap-helper (token-x-trait <ft-trait>) (token-y-trait <ft-trait>) (dx uint) (min-dy (optional uint)))
    (let 
        (
            (token-x (contract-of token-x-trait))
            (token-y (contract-of token-y-trait))
        )        
        (ok 
            (if (> (is-fixed-weight-pool-v1-01 token-x token-y) u0) 
                (try! (contract-call? .fixed-weight-pool-v1-01 swap-helper token-x-trait token-y-trait u50000000 u50000000 dx min-dy))                        
                (if (> (is-simple-weight-pool-ainomo token-x token-y) u0)
                    (try! (contract-call? .simple-weight-pool-ainomo swap-helper token-x-trait token-y-trait dx min-dy))        
                    (if (> (is-from-fixed-to-simple-ainomo token-x token-y) u0)
                        (get dy (try! (contract-call? .simple-weight-pool-ainomo swap-ainomo-for-y token-y-trait 
                            (try! (contract-call? .fixed-weight-pool-v1-01 swap-helper token-x-trait .age000-governance-token u50000000 u50000000 dx none)) min-dy))) 
                        (try! (contract-call? .fixed-weight-pool-v1-01 swap-helper .age000-governance-token token-y-trait u50000000 u50000000 
                            (get dx (try! (contract-call? .simple-weight-pool-ainomo swap-y-for-ainomo token-x-trait dx none))) min-dy))
                    )
                )
            )
        )
    )
)

;; @desc get-helper returns estimated dy when swapping token-x for token-y
;; @param token-x
;; @param token-y
;; @returns (response uint uint)
(define-read-only (get-helper (token-x principal) (token-y principal) (dx uint))
    (ok
        (if (> (is-fixed-weight-pool-v1-01 token-x token-y) u0)
            (try! (contract-call? .fixed-weight-pool-v1-01 get-helper token-x token-y u50000000 u50000000 dx))
            (if (> (is-simple-weight-pool-ainomo token-x token-y) u0)
                (try! (contract-call? .simple-weight-pool-ainomo get-helper token-x token-y dx))
                (if (> (is-from-fixed-to-simple-ainomo token-x token-y) u0)
                    (try! (contract-call? .simple-weight-pool-ainomo get-y-given-ainomo token-y 
                        (try! (contract-call? .fixed-weight-pool-v1-01 get-helper token-x .age000-governance-token u50000000 u50000000 dx)))) 
                    (try! (contract-call? .fixed-weight-pool-v1-01 get-helper .age000-governance-token token-y u50000000 u50000000 
                        (try! (contract-call? .simple-weight-pool-ainomo get-ainomo-given-y token-x dx))))
                )
            )
        )
    )
)

;; @desc oracle-instant-helper returns price of token-x in token-y
;; @param token-x
;; @param token-y
;; @returns (response uint uint)
(define-read-only (oracle-instant-helper (token-x principal) (token-y principal))
    (ok
        (if (> (is-fixed-weight-pool-v1-01 token-x token-y) u0)
            (try! (contract-call? .fixed-weight-pool-v1-01 get-oracle-instant token-x token-y u50000000 u50000000))
            (if (> (is-simple-weight-pool-ainomo token-x token-y) u0)
                (try! (contract-call? .simple-weight-pool-ainomo get-oracle-instant token-x token-y))
                (if (> (is-from-fixed-to-simple-ainomo token-x token-y) u0)
                    (div-down 
                        (try! (contract-call? .simple-weight-pool-ainomo get-oracle-instant .age000-governance-token token-y))
                        (try! (contract-call? .fixed-weight-pool-v1-01 get-oracle-instant .age000-governance-token token-x u50000000 u50000000))
                    )
                    (div-down 
                        (try! (contract-call? .fixed-weight-pool-v1-01 get-oracle-instant .age000-governance-token token-y u50000000 u50000000))
                        (try! (contract-call? .simple-weight-pool-ainomo get-oracle-instant .age000-governance-token token-x))                        
                    )                                        
                )
            )
        )
    )
)

;; @desc oracle-resilient-helper returns moving average price of token-x in token-y
;; @param token-x
;; @param token-y
;; @returns (response uint uint)
(define-read-only (oracle-resilient-helper (token-x principal) (token-y principal))
    (ok
        (if (> (is-fixed-weight-pool-v1-01 token-x token-y) u0)
            (try! (contract-call? .fixed-weight-pool-v1-01 get-oracle-resilient token-x token-y u50000000 u50000000))
            (if (> (is-simple-weight-pool-ainomo token-x token-y) u0)
                (try! (contract-call? .simple-weight-pool-ainomo get-oracle-resilient token-x token-y))
                (if (> (is-from-fixed-to-simple-ainomo token-x token-y) u0)
                    (div-down 
                        (try! (contract-call? .simple-weight-pool-ainomo get-oracle-resilient .age000-governance-token token-y))
                        (try! (contract-call? .fixed-weight-pool-v1-01 get-oracle-resilient .age000-governance-token token-x u50000000 u50000000))
                    )
                    (div-down 
                        (try! (contract-call? .fixed-weight-pool-v1-01 get-oracle-resilient .age000-governance-token token-y u50000000 u50000000))
                        (try! (contract-call? .simple-weight-pool-ainomo get-oracle-resilient .age000-governance-token token-x))                        
                    )                                        
                )
            )
        )
    )
)

;; @desc fee-helper returns estimated fee required for swap from token-x to token-y
;; @param token-x
;; @param token-y
;; @returns (response uint uint)
(define-read-only (fee-helper (token-x principal) (token-y principal))
    (ok
        (if (is-eq (is-fixed-weight-pool-v1-01 token-x token-y) u1)
            (if (is-eq token-x .token-wstx)
                (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-x .token-wstx token-y u50000000 u50000000))
                (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-y .token-wstx token-x u50000000 u50000000))
            )
            (if (is-eq (is-fixed-weight-pool-v1-01 token-x token-y) u2)
                (+ 
                    (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-x .token-wstx token-y u50000000 u50000000))
                    (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-y .token-wstx token-x u50000000 u50000000))
                )
                (if (is-eq (is-simple-weight-pool-ainomo token-x token-y) u1)
                    (if (is-eq token-x .age000-governance-token)
                        (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-x .age000-governance-token token-y))
                        (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-y .age000-governance-token token-x))
                    )
                    (if (is-eq (is-simple-weight-pool-ainomo token-x token-y) u2)
                        (+ 
                            (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-x .age000-governance-token token-y))
                            (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-y .age000-governance-token token-x))
                        )
                        (if (is-eq (is-from-fixed-to-simple-ainomo token-x token-y) u2)
                            (+
                                (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-x .token-wstx .age000-governance-token u50000000 u50000000))
                                (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-x .age000-governance-token token-y))
                            )
                            (if (is-eq (is-from-fixed-to-simple-ainomo token-x token-y) u3)
                                (+
                                    (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-y .token-wstx token-x u50000000 u50000000))
                                    (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-x .token-wstx .age000-governance-token u50000000 u50000000))
                                    (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-x .age000-governance-token token-y))                                    
                                )
                                (if (is-eq (is-from-simple-ainomo-to-fixed token-x token-y) u2)
                                    (+
                                        (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-y .token-wstx .age000-governance-token u50000000 u50000000))
                                        (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-y .age000-governance-token token-x))
                                    )
                                    (if (is-eq (is-from-simple-ainomo-to-fixed token-x token-y) u3)
                                        (+
                                            (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-x .token-wstx token-y u50000000 u50000000))
                                            (try! (contract-call? .fixed-weight-pool-v1-01 get-fee-rate-y .token-wstx .age000-governance-token u50000000 u50000000))
                                            (try! (contract-call? .simple-weight-pool-ainomo get-fee-rate-y .age000-governance-token token-x))                                    
                                        )
                                        u0
                                    )                                                                                                            
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

;; @desc route-helper returns required routing as a list for swap from token-x to token-y
;; @param token-x
;; @param token-y
;; @returns (response (list 4 principal) uint)
(define-read-only (route-helper (token-x principal) (token-y principal))
    (ok
        (if (or (is-eq (is-fixed-weight-pool-v1-01 token-x token-y) u1) (is-eq (is-simple-weight-pool-ainomo token-x token-y) u1))
            (list token-x token-y)
            (if (is-eq (is-fixed-weight-pool-v1-01 token-x token-y) u2)
                (list token-x .token-wstx token-y)
                (if (or (is-eq (is-simple-weight-pool-ainomo token-x token-y) u2) (is-eq (is-from-fixed-to-simple-ainomo token-x token-y) u2) (is-eq (is-from-simple-ainomo-to-fixed token-x token-y) u2))
                    (list token-x .age000-governance-token token-y)
                    (if (is-eq (is-from-fixed-to-simple-ainomo token-x token-y) u3)
                        (list token-x .token-wstx .age000-governance-token token-y)
                        (if (is-eq (is-from-simple-ainomo-to-fixed token-x token-y) u3)
                            (list token-x .age000-governance-token .token-wstx token-y)
                            (list token-x token-y)
                        )
                    )
                )
            )
        )
    )
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