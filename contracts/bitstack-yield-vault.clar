;; BitStack Yield Vault Protocol
;;
;; Title: BitStack Yield Vault - Enterprise-Grade sBTC Yield Generation Protocol
;;
;; Summary: A secure, high-performance Bitcoin-native yield vault built on Stacks Layer 2,
;;          enabling users to earn competitive returns on their sBTC holdings through 
;;          automated yield distribution with enterprise-level security controls.
;;
;; Description: BitStack Yield Vault revolutionizes Bitcoin DeFi by providing institutional-grade
;;              yield generation directly on Bitcoin's Layer 2. This protocol features:
;;              - Advanced yield calculation with precision-engineered algorithms
;;              - Multi-layer security with emergency controls and timelock mechanisms  
;;              - Real-time reward accrual with gas-optimized claim functionality
;;              - Comprehensive audit trail and transparent governance
;;              - Bitcoin-first design philosophy with Layer 2 scalability
;;
;;              Built for the next generation of Bitcoin finance, BitStack Yield Vault
;;              bridges traditional finance expectations with Bitcoin's revolutionary potential.

;; PROTOCOL CONSTANTS & CONFIGURATION

;; Error Code Registry - Comprehensive error handling for production deployment
(define-constant ERR_NOT_OWNER u100)
(define-constant ERR_INSUFFICIENT_BALANCE u101)
(define-constant ERR_INSUFFICIENT_VAULT_FUNDS u102)
(define-constant ERR_UNAUTHORIZED u103)
(define-constant ERR_DEPOSIT_FAILED u104)
(define-constant ERR_WITHDRAW_FAILED u105)
(define-constant ERR_DEPOSIT_LIMIT_REACHED u106)
(define-constant ERR_INVALID_YIELD_RATE u107)
(define-constant ERR_INVALID_TOKEN_CONTRACT u108)
(define-constant ERR_INVALID_DEPOSIT_LIMIT u109)
(define-constant ERR_EMERGENCY_MODE_ACTIVE u110)
(define-constant ERR_TIMELOCK_NOT_EXPIRED u111)

;; Protocol Economics & Security Parameters
(define-constant MIN_DEPOSIT_LIMIT u1000000)      ;; 0.01 sBTC (8 decimals) - Minimum viable deposit
(define-constant MAX_DEPOSIT_LIMIT u100000000000) ;; 1,000 sBTC (8 decimals) - Whale protection limit
(define-constant MAX_YIELD_RATE u1000)            ;; 10% maximum APY (basis points) - Risk management
(define-constant BLOCKS_PER_DAY u144)             ;; ~24 hours (10min average block time)
(define-constant PRECISION_FACTOR u100000)        ;; High-precision mathematical calculations

;; PROTOCOL STATE MANAGEMENT

;; Core Yield Distribution Engine
(define-data-var yield-rate uint u50)                    ;; 0.5% base APY (basis points)
(define-data-var last-yield-distribution uint u0)        ;; Last distribution checkpoint
(define-data-var yield-period uint BLOCKS_PER_DAY)       ;; Compound frequency control
(define-data-var vault-admin principal tx-sender)        ;; Protocol governance authority
(define-data-var global-accumulator uint u0)             ;; Global yield accumulation tracker
(define-data-var next-event-id uint u0)                  ;; Event sequencing for analytics

;; Security & Operational Controls
(define-data-var token-contract-address principal 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token)
(define-data-var emergency-mode bool false)              ;; Circuit breaker mechanism
(define-data-var admin-actions-timelock uint BLOCKS_PER_DAY) ;; 24hr governance delay
(define-data-var max-deposit-limit uint u1000000000)     ;; Individual user deposit ceiling
(define-data-var protocol-paused bool false)             ;; Maintenance mode flag

;; DATA ARCHITECTURE & USER STATE

;; User Portfolio Management
(define-map user-deposits principal uint)           ;; Individual deposit balances
(define-map last-deposit-block principal uint)      ;; Yield calculation checkpoints
(define-map user-rewards principal uint)            ;; Accumulated unclaimed rewards
(define-map user-total-claimed principal uint)      ;; Lifetime reward claims history

;; Governance & Administration Framework
(define-map pending-admin-actions
  { action: (string-ascii 20), param: uint }
  { scheduled-at: uint, executed: bool }
)

;; Analytics & Protocol Intelligence
(define-map daily-stats
  uint ;; day (block-height / BLOCKS_PER_DAY)
  { total-deposits: uint, total-rewards: uint, active-users: uint }
)

;; PUBLIC READ INTERFACE - User & Protocol Queries

;; Retrieve user's current deposit balance
(define-read-only (get-user-deposit (user principal))
  (default-to u0 (map-get? user-deposits user))
)

;; Get user's accumulated pending rewards
(define-read-only (get-user-rewards (user principal))
  (default-to u0 (map-get? user-rewards user))
)

;; Fetch user's total claimed rewards history
(define-read-only (get-user-total-claimed (user principal))
  (default-to u0 (map-get? user-total-claimed user))
)

;; Current protocol yield rate in basis points
(define-read-only (get-yield-rate)
  (var-get yield-rate)
)

;; Real-time vault sBTC balance query
(define-read-only (get-vault-balance)
  (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
    get-balance (as-contract tx-sender)
  )
)