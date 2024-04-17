(define-public (roll-auto-helper-1 (amount uint))
    (begin 
        (try! (contract-call? .swap-helper-v1-03 swap-helper .age000-governance-token .auto-ainomo amount none))
        (contract-call? .collateral-rebalancing-pool-v1 roll-auto 
            .ytp-ainomo-v1
            .age000-governance-token
            .auto-ainomo
            .yield-ainomo-v1
            .key-ainomo-autoainomo-v1
            .auto-ytp-ainomo
            .auto-key-ainomo-autoainomo
        )
    )
)