(impl-trait .trait-ownable.ownable-trait)
(impl-trait .trait-semi-fungible.semi-fungible-trait)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-TOO-MANY-POOLS (err u2004))
(define-constant ERR-INVALID-BALANCE (err u1001))
(define-constant ERR-TRANSFER-FAILED (err u3000))
(define-constant ERR-AVAILABLE-AINOMO (err u20000))
(define-constant ERR-BLOCK-HEIGHT (err u2043))
(define-constant ERR-NOT-ENOUGH-AINOMO (err u20001))

(define-fungible-token auto-fwp-ainomo-autoainomo-x)
(define-map token-balances {token-id: uint, owner: principal} uint)
(define-map token-supplies uint uint)
(define-map token-owned principal (list 200 uint))

(define-data-var contract-owner principal tx-sender)
(define-map approved-contracts principal bool)

(define-data-var token-name (string-ascii 32) "Auto AINOMO / autoAINOMO Pool X")
(define-data-var token-symbol (string-ascii 32) "auto-fwp-ainomo-autoainomo-x")

(define-data-var token-decimals uint u8)
(define-data-var transferrable bool false)

(define-read-only (get-transferrable)
	(ok (var-get transferrable))
)

(define-public (set-transferrable (new-transferrable bool))
	(begin 
		(try! (check-is-owner))
		(ok (var-set transferrable new-transferrable))
	)
)

;; @desc get-contract-owner
;; @returns (response principal)
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)
;; @desc set-contractowner
;; @restricted contract-owner
;; @params owner
;; @returns (response bool)
(define-public (set-contract-owner (owner principal))
  (begin
    (try! (check-is-owner))
    (ok (var-set contract-owner owner))
  )
)

;; @desc check-is-approved
;; @restricted contract-owner
;; @params sender
;; @returns (response bool)
(define-private (check-is-approved)
  (ok (asserts! (default-to false (map-get? approved-contracts tx-sender)) ERR-NOT-AUTHORIZED))
)

(define-private (check-is-owner)
	(ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
)

(define-private (check-is-self)
  (ok (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR-NOT-AUTHORIZED))
)

(define-public (add-approved-contract (new-approved-contract principal))
  (begin
    (try! (check-is-owner))
    (map-set approved-contracts new-approved-contract true)
    (ok true)
  )
)

(define-public (set-approved-contract (owner principal) (approved bool))
	(begin
		(try! (check-is-owner))
		(ok (map-set approved-contracts owner approved))
	)
)
(define-read-only (get-token-owned (owner principal))
    (default-to (list) (map-get? token-owned owner))
)

;; @desc set-balance
;; @params token-id
;; @params balance
;; @params owner
;; @returns (response bool)
(define-private (set-balance (token-id uint) (balance uint) (owner principal))
    (begin
		(and 
			(is-none (index-of (get-token-owned owner) token-id))
			(map-set token-owned owner (unwrap! (as-max-len? (append (get-token-owned owner) token-id) u200) ERR-TOO-MANY-POOLS))
		)	
	    (map-set token-balances {token-id: token-id, owner: owner} balance)
        (ok true)
    )
)

;; @desc get-balance-or-default
;; @params token-id
;; @params who
;; @returns (response uint)
(define-private (get-balance-or-default (token-id uint) (who principal))
	(default-to u0 (map-get? token-balances {token-id: token-id, owner: who}))
)

;; @desc get-balance
;; @params token-id
;; @params who
;; @returns (response uint)
(define-read-only (get-balance (token-id uint) (who principal))
	(ok (get-balance-or-default token-id who))
)

;; @desc get-overall-balance
;; @params who
;; @returns (response uint)
(define-read-only (get-overall-balance (who principal))
	(ok (ft-get-balance auto-fwp-ainomo-autoainomo-x who))
)

;; @desc get-total-supply
;; @params token-id
;; @returns (response uint)
(define-read-only (get-total-supply (token-id uint))
	(ok (default-to u0 (map-get? token-supplies token-id)))
)

;; @desc get-overall-supply
;; @returns (response uint)
(define-read-only (get-overall-supply)
	(ok (ft-get-supply auto-fwp-ainomo-autoainomo-x))
)

;; @desc get-decimals
;; @params token-id
;; @returns (response uint)
(define-read-only (get-decimals (token-id uint))
  	(ok (var-get token-decimals))
)

;; @desc get-token-uri
;; @params token-id
;; @returns (response none)
(define-read-only (get-token-uri (token-id uint))
	(ok (var-get token-uri))
)

;; @desc transfer
;; @restricted sender ; tx-sender should be sender
;; @params token-id
;; @params amount
;; @params sender
;; @params recipient
;; @returns (response bool)
(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
	(let
		(
			(sender-balance (get-balance-or-default token-id sender))
		)
    (asserts! (var-get transferrable) ERR-TRANSFER-FAILED)
		(asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
		(asserts! (<= amount sender-balance) ERR-INVALID-BALANCE)
		(try! (ft-transfer? auto-fwp-ainomo-autoainomo-x amount sender recipient))
		(try! (set-balance token-id (- sender-balance amount) sender))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(print {type: "sft_transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient})
		(ok true)
	)
)

;; @desc transfer-memo
;; @restricted sender ; tx-sender should be sender
;; @params token-id
;; @params amount
;; @params sender
;; @params recipient
;; @params memo; expiry
;; @returns (response bool)
(define-public (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)))
	(let
		(
			(sender-balance (get-balance-or-default token-id sender))
		)
    (asserts! (var-get transferrable) ERR-TRANSFER-FAILED)
		(asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
		(asserts! (<= amount sender-balance) ERR-INVALID-BALANCE)
		(try! (ft-transfer? auto-fwp-ainomo-autoainomo-x amount sender recipient))
		(try! (set-balance token-id (- sender-balance amount) sender))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(print {type: "sft_transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient, memo: memo})
		(ok true)
	)
)

;; @desc mint
;; @params token-id
;; @params amount
;; @params recipient
;; @returns (response bool)
(define-public (mint (token-id uint) (amount uint) (recipient principal))
	(begin
		(asserts! (or (is-ok (check-is-approved)) (is-ok (check-is-owner)) (is-ok (check-is-self))) ERR-NOT-AUTHORIZED)
		(try! (ft-mint? auto-fwp-ainomo-autoainomo-x amount recipient))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(map-set token-supplies token-id (+ (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "sft_mint", token-id: token-id, amount: amount, recipient: recipient})
		(ok true)
	)
)

;; @desc burn
;; @restricted contract-owner/Approved Contract
;; @params token-id
;; @params amount
;; @params sender
;; @returns (response bool)
(define-public (burn (token-id uint) (amount uint) (sender principal))
	(begin
		(asserts! (or (is-ok (check-is-approved)) (is-ok (check-is-owner)) (is-ok (check-is-self))) ERR-NOT-AUTHORIZED)
		(try! (ft-burn? auto-fwp-ainomo-autoainomo-x amount sender))
		(try! (set-balance token-id (- (get-balance-or-default token-id sender) amount) sender))
		(map-set token-supplies token-id (- (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "sft_burn", token-id: token-id, amount: amount, sender: sender})
		(ok true)
	)
)

(define-constant ONE_8 u100000000)

;; @desc pow-decimals
;; @returns uint
(define-private (pow-decimals)
  	(pow u10 (unwrap-panic (get-decimals u0)))
)

;; @desc fixed-to-decimals
;; @params amount
;; @returns uint
(define-read-only (fixed-to-decimals (amount uint))
  	(/ (* amount (pow-decimals)) ONE_8)
)

;; @desc decimals-to-fixed 
;; @params amount
;; @returns uint
(define-private (decimals-to-fixed (amount uint))
  	(/ (* amount ONE_8) (pow-decimals))
)

;; @desc get-total-supply-fixed
;; @params token-id
;; @returns (response uint)
(define-read-only (get-total-supply-fixed (token-id uint))
  	(ok (decimals-to-fixed (default-to u0 (map-get? token-supplies token-id))))
)

;; @desc get-balance-fixed
;; @params token-id
;; @params who
;; @returns (response uint)
(define-read-only (get-balance-fixed (token-id uint) (who principal))
  	(ok (decimals-to-fixed (get-balance-or-default token-id who)))
)

;; @desc get-overall-supply-fixed
;; @returns (response uint)
(define-read-only (get-overall-supply-fixed)
	(ok (decimals-to-fixed (ft-get-supply auto-fwp-ainomo-autoainomo-x)))
)

;; @desc get-overall-balance-fixed
;; @params who
;; @returns (response uint)
(define-read-only (get-overall-balance-fixed (who principal))
	(ok (decimals-to-fixed (ft-get-balance auto-fwp-ainomo-autoainomo-x who)))
)

;; @desc transfer-fixed
;; @params token-id
;; @params amount
;; @params sender
;; @params recipient
;; @returns (response boolean)
(define-public (transfer-fixed (token-id uint) (amount uint) (sender principal) (recipient principal))
  	(transfer token-id (fixed-to-decimals amount) sender recipient)
)

;; @desc transfer-memo-fixed
;; @params token-id
;; @params amount
;; @params sender
;; @params recipient
;; @params memo ; expiry
;; @returns (response boolean)
(define-public (transfer-memo-fixed (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)))
  	(transfer-memo token-id (fixed-to-decimals amount) sender recipient memo)
)

;; @desc mint-fixed
;; @params token-id
;; @params amount
;; @params recipient
;; @returns (response boolean)
(define-public (mint-fixed (token-id uint) (amount uint) (recipient principal))
  	(mint token-id (fixed-to-decimals amount) recipient)
)

;; @desc burn-fixed
;; @params token-id
;; @params amount
;; @params sender
;; @returns (response boolean)
(define-public (burn-fixed (token-id uint) (amount uint) (sender principal))
  	(burn token-id (fixed-to-decimals amount) sender)
)

(define-private (transfer-many-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer (get token-id item) (get amount item) (get sender item) (get recipient item)) prev-err previous-response)
)

(define-public (transfer-many (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal})))
	(fold transfer-many-iter transfers (ok true))
)

(define-private (transfer-many-memo-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer-memo (get token-id item) (get amount item) (get sender item) (get recipient item) (get memo item)) prev-err previous-response)
)

(define-public (transfer-many-memo (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)})))
	(fold transfer-many-memo-iter transfers (ok true))
)

(define-private (transfer-many-fixed-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer-fixed (get token-id item) (get amount item) (get sender item) (get recipient item)) prev-err previous-response)
)

(define-public (transfer-many-fixed (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal})))
	(fold transfer-many-fixed-iter transfers (ok true))
)

(define-private (transfer-many-memo-fixed-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer-memo-fixed (get token-id item) (get amount item) (get sender item) (get recipient item) (get memo item)) prev-err previous-response)
)

(define-public (transfer-many-memo-fixed (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)})))
	(fold transfer-many-memo-fixed-iter transfers (ok true))
)

(define-private (create-tuple-token-balance (token-id uint) (balance uint))
	{ token-id: token-id, balance: (decimals-to-fixed balance) }
)

(define-read-only (get-token-balance-owned-in-fixed (owner principal))
	(begin 
		(match (map-get? token-owned owner)
			token-ids
			(map 
				create-tuple-token-balance 
				token-ids 
				(map 
					get-balance-or-default
					token-ids
					(list 
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
						owner	owner	owner	owner	owner	owner	owner	owner	owner	owner
					)
				)
			)
			(list)
		)
	)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var start-block uint u340282366920938463463374607431768211455)

(define-map tranche-end-block uint uint)

(define-map available-ainomo 
  {
    borrower: principal,
    tranche: uint
  } 
  uint
)

(define-map borrowed-ainomo 
  {
    borrower: principal,
    tranche: uint
  }
  uint
)

(define-read-only (get-start-block)
  (var-get start-block)
)

(define-public (set-start-block (new-start-block uint))
  (begin 
    (try! (check-is-owner))
    (ok (var-set start-block new-start-block))
  )
)

(define-public (set-tranche-end-block (tranche uint) (new-end-block uint))
    (begin 
        (try! (check-is-owner))
        (ok (map-set tranche-end-block tranche new-end-block))
    )
)

(define-read-only (get-tranche-end-block-or-default (tranche uint))
    (default-to u340282366920938463463374607431768211455 (map-get? tranche-end-block tranche))
)

(define-public (set-available-ainomo (user principal) (tranche uint) (new-amount uint))
    (begin 
        (try! (check-is-owner))
        (ok (map-set available-ainomo { borrower: user, tranche: tranche } new-amount))
    )
)

(define-read-only (get-available-ainomo-or-default (user principal) (tranche uint))
    (default-to u0 (map-get? available-ainomo { borrower: user, tranche: tranche }))
)

(define-read-only (get-borrowed-ainomo-or-default (user principal) (tranche uint))
  (default-to u0 (map-get? borrowed-ainomo { borrower: user, tranche: tranche }))
)

(define-public (add-to-position (tranche uint) (dx uint))
    (let 
        (
          (sender tx-sender)
          (pool (try! (contract-call? .simple-weight-pool-ainomo get-token-given-position .age000-governance-token .auto-ainomo dx none)))
          (atainomo-in-ainomo (mul-down (try! (contract-call? .auto-ainomo get-intrinsic)) (get dy pool)))          
          (ainomo-to-atainomo (div-down (mul-down dx atainomo-in-ainomo) (+ dx atainomo-in-ainomo)))
          (atainomo-amount (try! (contract-call? .auto-ainomo get-token-given-position ainomo-to-atainomo)))
          (ainomo-available (get-available-ainomo-or-default sender tranche))
          (ainomo-borrowed (get-borrowed-ainomo-or-default sender tranche))                        
        )
        (asserts! (>= block-height (var-get start-block)) ERR-BLOCK-HEIGHT)
        (asserts! (>= ainomo-available dx) ERR-AVAILABLE-AINOMO)        

        (as-contract (try! (contract-call? .age000-governance-token mint-fixed dx tx-sender)))
        (as-contract (try! (contract-call? .auto-ainomo add-to-position ainomo-to-atainomo)))
        (as-contract (try! (contract-call? .simple-weight-pool-ainomo add-to-position .age000-governance-token .auto-ainomo .fwp-ainomo-autoainomo (- dx ainomo-to-atainomo) (some atainomo-amount))))
        (map-set available-ainomo { borrower: sender, tranche: tranche } (- ainomo-available dx))
        (map-set borrowed-ainomo { borrower: sender, tranche: tranche } (+ ainomo-borrowed dx))
		    (as-contract (try! (mint-fixed tranche (get token pool) sender)))
        (print { object: "pool", action: "position-added", data: (get token pool)})
        (ok { total-ainomo-borrowed: (+ ainomo-borrowed dx), position: (get token pool) })
    )
)

(define-public (reduce-position (tranche uint))
  (let 
    (
      (sender tx-sender)
      (ainomo-borrowed (get-borrowed-ainomo-or-default sender tranche))
      (supply (unwrap-panic (get-balance-fixed tranche sender)))
      (total-supply (unwrap-panic (get-overall-supply-fixed)))
      (share (div-down supply total-supply))
      (pool (as-contract (try! (contract-call? .simple-weight-pool-ainomo reduce-position .age000-governance-token .auto-ainomo .fwp-ainomo-autoainomo share))))  
      (atainomo-in-ainomo (mul-down (try! (contract-call? .auto-ainomo get-intrinsic)) (get dy pool)))
      (ainomo-shortfall (if (<= ainomo-borrowed (get dx pool)) u0 (- ainomo-borrowed (get dx pool))))
    )
    (asserts! (> block-height (get-tranche-end-block-or-default tranche)) ERR-BLOCK-HEIGHT)
    (asserts! (>= atainomo-in-ainomo ainomo-shortfall) ERR-NOT-ENOUGH-AINOMO)

    (let
      (
        (ainomo-to-lender (- ainomo-borrowed ainomo-shortfall))
        (atainomo-to-lender (div-down (mul-down (get dy pool) ainomo-shortfall) atainomo-in-ainomo))
        (ainomo-to-borrower (- (get dx pool) ainomo-to-lender))
        (atainomo-to-borrower (- (get dy pool) atainomo-to-lender))
      )
    
      (and (> ainomo-to-lender u0) (as-contract (try! (contract-call? .age000-governance-token transfer-fixed ainomo-to-lender tx-sender .executor-dao none))))
      (and (> atainomo-to-lender u0) (as-contract (try! (contract-call? .auto-ainomo transfer-fixed atainomo-to-lender tx-sender .executor-dao none))))

      (and (> ainomo-to-borrower u0) (as-contract (try! (contract-call? .age000-governance-token transfer-fixed ainomo-to-borrower tx-sender sender none))))
      (and (> atainomo-to-borrower u0) (as-contract (try! (contract-call? .auto-ainomo transfer-fixed atainomo-to-borrower tx-sender sender none))))

	    (as-contract (try! (burn-fixed tranche supply sender)))
      (print { object: "pool", action: "position-reduced", data: supply })
      (ok { ainomo: ainomo-to-borrower, atainomo: atainomo-to-borrower })
    )
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