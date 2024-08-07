(define-public (register-user-many (users (list 1000 principal)))
    (fold register-user-iter users (ok true))
)

(define-private (register-user-iter (user principal) (previous-response (response bool uint)))
	(match previous-response prev-ok (if (is-ok (contract-call? .bridge-endpoint-v1-02 register-user user)) (ok true) (err u0)) prev-err previous-response)
)
