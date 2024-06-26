(impl-trait .trait-ownable.ownable-trait)
(impl-trait .trait-semi-fungible.semi-fungible-trait)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-TOO-MANY-POOLS (err u2004))
(define-constant ERR-INVALID-BALANCE (err u1001))
(define-constant ERR-TRANSFER-FAILED (err u3000))

(define-fungible-token amm-swap-pool-v1-1)
(define-map token-balances {token-id: uint, owner: principal} uint)
(define-map token-supplies uint uint)
(define-map token-owned principal (list 200 uint))

(define-data-var contract-owner principal tx-sender)
(define-map approved-contracts principal bool)

(define-data-var token-name (string-ascii 32) "amm-swap-pool-v1-1")
(define-data-var token-symbol (string-ascii 32) "amm-swap-pool-v1-1")
(define-data-var token-decimals uint u8)
(define-data-var transferrable bool true)

(define-read-only (get-transferrable)
	(ok (var-get transferrable))
)

(define-public (set-transferrable (new-transferrable bool))
	(begin 
		(try! (check-is-owner))
		(ok (var-set transferrable new-transferrable))
	)
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (owner principal))
  (begin
    (try! (check-is-owner))
    (ok (var-set contract-owner owner))
  )
)

(define-private (check-is-approved)
  (ok (asserts! (default-to false (map-get? approved-contracts tx-sender)) ERR-NOT-AUTHORIZED))
)

(define-private (check-is-owner)
	(ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
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
	(ok (ft-get-balance amm-swap-pool-v1-1 who))
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
	(ok (ft-get-supply amm-swap-pool-v1-1))
)

;; @desc get-decimals
;; @params token-id
;; @returns (response uint)
(define-read-only (get-decimals (token-id uint))
	(ok (var-get token-decimals))
)

(define-public (set-decimals (new-decimals uint))
	(begin
		(try! (check-is-owner))
		(ok (var-set token-decimals new-decimals))
	)
)

;; @desc get-token-uri 
;; @params token-id
;; @returns (response none)
(define-read-only (get-token-uri (token-id uint))
	(ok (var-get token-uri))
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
	(begin
		(try! (check-is-owner))
		(ok (var-set token-uri new-uri))
	)
)

(define-read-only (get-name (token-id uint))
	(ok (var-get token-name))
)

(define-public (set-name (new-name (string-ascii 32)))
	(begin
		(try! (check-is-owner))
		(ok (var-set token-name new-name))
	)
)

(define-read-only (get-symbol (token-id uint))
	(ok (var-get token-symbol))
)

(define-public (set-symbol (new-symbol (string-ascii 10)))
	(begin
		(try! (check-is-owner))
		(ok (var-set token-symbol new-symbol))
	)
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
		(try! (ft-transfer? amm-swap-pool-v1-1 amount sender recipient))
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
		(try! (ft-transfer? amm-swap-pool-v1-1 amount sender recipient))
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
		(asserts! (or (is-ok (check-is-approved)) (is-ok (check-is-owner))) ERR-NOT-AUTHORIZED)
		(try! (ft-mint? amm-swap-pool-v1-1 amount recipient))
		(try! (set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient))
		(map-set token-supplies token-id (+ (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "sft_mint", token-id: token-id, amount: amount, recipient: recipient})
		(ok true)
	)
)

;; @desc burn
;; @params token-id
;; @params amount
;; @params sender
;; @returns (response bool)
(define-public (burn (token-id uint) (amount uint) (sender principal))
	(begin
		(asserts! (or (is-ok (check-is-approved)) (is-ok (check-is-owner))) ERR-NOT-AUTHORIZED)
		(try! (ft-burn? amm-swap-pool-v1-1 amount sender))
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
	(ok (decimals-to-fixed (ft-get-supply amm-swap-pool-v1-1)))
)

;; @desc get-overall-balance-fixed
;; @params who
;; @returns (response uint)
(define-read-only (get-overall-balance-fixed (who principal))
	(ok (decimals-to-fixed (ft-get-balance amm-swap-pool-v1-1 who)))
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

;; contract initialisation
;; (set-contract-owner .executor-dao)
(map-set approved-contracts .amm-swap-pool-v1-1 true)