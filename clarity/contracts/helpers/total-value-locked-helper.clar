(define-read-only (get-total-value-locked)
    (list 
      {
        token: .fwp-wstx-ainomo-50-50-v1-01,
        total_supply: (unwrap-panic (contract-call? .fwp-wstx-ainomo-50-50-v1-01 get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-wstx-ainomo-50-50-v1-01)
      }
      {
        token: .fwp-wstx-wbtc-50-50-v1-01,
        total_supply: (unwrap-panic (contract-call? .fwp-wstx-wbtc-50-50-v1-01 get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-wstx-wbtc-50-50-v1-01)
      }
      {
        token: .fwp-ainomo-usda,
        total_supply: (unwrap-panic (contract-call? .fwp-ainomo-usda get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-ainomo-usda)
      }
      {
        token: .fwp-ainomo-wslm,
        total_supply: (unwrap-panic (contract-call? .fwp-ainomo-wslm get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-ainomo-wslm)
      }
      {
        token: .fwp-wstx-wxusd-50-50-v1-01,
        total_supply: (unwrap-panic (contract-call? .fwp-wstx-wxusd-50-50-v1-01 get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-wstx-wxusd-50-50-v1-01)
      }
      {
        token: .fwp-wstx-wnycc-50-50-v1-01,
        total_supply: (unwrap-panic (contract-call? .fwp-wstx-wnycc-50-50-v1-01 get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-wstx-wnycc-50-50-v1-01)
      }
      {
        token: .ytp-ainomo-v1,
        total_supply: (unwrap-panic (contract-call? .ytp-ainomo-v1 get-overall-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .ytp-ainomo-v1)
      }
      {
        token: .fwp-ainomo-wban,
        total_supply: (unwrap-panic (contract-call? .fwp-ainomo-wban get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-ainomo-wban)
      }
      {
        token: .fwp-ainomo-autoainomo,
        total_supply: (unwrap-panic (contract-call? .fwp-ainomo-autoainomo get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-ainomo-autoainomo)
      }
      {
        token: .fwp-wstx-wmia-50-50-v1-01,
        total_supply: (unwrap-panic (contract-call? .fwp-wstx-wmia-50-50-v1-01 get-total-supply-fixed)),
        reserved_balnce: (contract-call? .ainomo-reserve-pool get-balance .fwp-wstx-wmia-50-50-v1-01)
      }                                                
    )
)