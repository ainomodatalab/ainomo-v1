(impl-trait .trait-ownable.ownable-trait)
(impl-trait .trait-semi-fungible.semi-fungible-trait)


(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-TOO-MANY-POOLS (err u2004))
(define-constant ERR-INVALID-BALANCE (err u2008))

(define-fungible-token staked-fwp-wstx-ainomo-50-50-v1-01)
(define-map token-balances {token-id: uint, owner: principal} uint)
(define-map token-supplies uint uint)
(define-map token-owned principal (list 200 uint))

(define-data-var contract-owner principal tx-sender)
(define-map approved-contracts principal bool)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner owner))
  )
)

(define-private (check-is-approved (sender principal))
  (ok (asserts! (or (default-to false (map-get? approved-contracts sender)) (is-eq sender (var-get contract-owner))) ERR-NOT-AUTHORIZED))
)

(define-public (add-approved-contract (new-approved-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set approved-contracts new-approved-contract true)
    (ok true)
  )
)

(define-public (set-approved-contract (owner principal) (approved bool))
	(begin
		(asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
		(ok (map-set approved-contracts owner approved))
	)
)

(define-read-only (get-token-owned (owner principal))
    (default-to (list) (map-get? token-owned owner))
)

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

(define-private (get-balance-or-default (token-id uint) (who principal))
	(default-to u0 (map-get? token-balances {token-id: token-id, owner: who}))
)

(define-read-only (get-balance (token-id uint) (who principal))
	(ok (get-balance-or-default token-id who))
)

(define-read-only (get-overall-balance (who principal))
	(ok (ft-get-balance staked-fwp-wstx-ainomo-50-50-v1-01 who))
)

(define-read-only (get-total-supply (token-id uint))
	(ok (default-to u0 (map-get? token-supplies token-id)))
)

(define-read-only (get-overall-supply)
	(ok (ft-get-supply staked-fwp-wstx-ainomo-50-50-v1-01))
)

(define-read-only (get-decimals (token-id uint))
  	(ok u8)
)

(define-read-only (get-token-uri (token-id uint))
	(ok none)
)

(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
	(let
		(
			(sender-balance (get-balance-or-default token-id sender))
		)
		(asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
		(asserts! (<= amount sender-balance) ERR-INVALID-BALANCE)
		(try! (ft-transfer? staked-fwp-wstx-ainomo-50-50-v1-01 amount sender recipient))
		(try! (set-balance token-id (- sender-balance amount) sender))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(print {type: "sft_transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient})
		(ok true)
	)
)

(define-public (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)))
	(let
		(
			(sender-balance (get-balance-or-default token-id sender))
		)
		(asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
		(asserts! (<= amount sender-balance) ERR-INVALID-BALANCE)
		(try! (ft-transfer? staked-fwp-wstx-ainomo-50-50-v1-01 amount sender recipient))
		(try! (set-balance token-id (- sender-balance amount) sender))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(print {type: "sft_transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient, memo: memo})
		(ok true)
	)
)

(define-public (mint (token-id uint) (amount uint) (recipient principal))
	(begin
		(try! (check-is-approved tx-sender))
		(try! (ft-mint? staked-fwp-wstx-ainomo-50-50-v1-01 amount recipient))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(map-set token-supplies token-id (+ (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "sft_mint", token-id: token-id, amount: amount, recipient: recipient})
		(ok true)
	)
)

(define-public (burn (token-id uint) (amount uint) (sender principal))
	(begin
		(try! (check-is-approved tx-sender))
		(try! (ft-burn? staked-fwp-wstx-ainomo-50-50-v1-01 amount sender))
		(try! (set-balance token-id (- (get-balance-or-default token-id sender) amount) sender))
		(map-set token-supplies token-id (- (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "sft_burn", token-id: token-id, amount: amount, sender: sender})
		(ok true)
	)
)

(define-constant ONE_8 u100000000)

(define-private (pow-decimals)
  	(pow u10 (unwrap-panic (get-decimals u0)))
)

(define-read-only (fixed-to-decimals (amount uint))
  	(/ (* amount (pow-decimals)) ONE_8)
)

(define-private (decimals-to-fixed (amount uint))
  	(/ (* amount ONE_8) (pow-decimals))
)

(define-read-only (get-total-supply-fixed (token-id uint))
  	(ok (decimals-to-fixed (default-to u0 (map-get? token-supplies token-id))))
)

(define-read-only (get-balance-fixed (token-id uint) (who principal))
  	(ok (decimals-to-fixed (get-balance-or-default token-id who)))
)

(define-read-only (get-overall-supply-fixed)
	(ok (decimals-to-fixed (ft-get-supply staked-fwp-wstx-ainomo-50-50-v1-01)))
)

(define-read-only (get-overall-balance-fixed (who principal))
	(ok (decimals-to-fixed (ft-get-balance staked-fwp-wstx-ainomo-50-50-v1-01 who)))
)

(define-public (transfer-fixed (token-id uint) (amount uint) (sender principal) (recipient principal))
  	(transfer token-id (fixed-to-decimals amount) sender recipient)
)

(define-public (transfer-memo-fixed (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)))
  	(transfer-memo token-id (fixed-to-decimals amount) sender recipient memo)
)

(define-public (mint-fixed (token-id uint) (amount uint) (recipient principal))
  	(mint token-id (fixed-to-decimals amount) recipient)
)

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

(map-set approved-contracts .futures-pool true)