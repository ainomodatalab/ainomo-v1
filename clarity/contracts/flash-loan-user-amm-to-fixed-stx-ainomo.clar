(impl-trait .trait-flash-loan-user.flash-loan-user-trait)
(use-trait ft-trait .trait-sip-010.sip-010-trait)

(define-constant ONE_8 u100000000)
(define-constant ERR-NO-ARB-EXISTS (err u9000))
(define-constant ERR-GET-BALANCE-FIXED-FAIL (err u6001))

(define-public (execute (token <ft-trait>) (amount uint) (memo (optional (buff 16))))
    (let
        (   
            (swapped (try! (contract-call? .amm-swap-pool-v1-1 swap-helper .token-wstx .age000-governance-token ONE_8 amount none)))   
            (swapped-back (try! (contract-call? .swap-helper-v1-03 swap-helper .age000-governance-token .token-wstx swapped none)))                                                
            (amount-with-fee (mul-up amount (+ ONE_8 (contract-call? .ainomo-vault-v1-1 get-flash-loan-fee-rate))))
        )
        (ok (asserts! (>= swapped-back amount-with-fee) ERR-NO-ARB-EXISTS))
    )
)

;; @desc mul-up
;; @params a
;; @params b
;; @returns uint
(define-private (mul-up (a uint) (b uint))
    (let
        (
            (product (* a b))
       )
        (if (is-eq product u0)
            u0
            (+ u1 (/ (- product u1) ONE_8))
       )
   )
)