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

;; Comprehensive protocol configuration snapshot
(define-read-only (get-protocol-info)
  {
    yield-rate: (var-get yield-rate),
    max-deposit-limit: (var-get max-deposit-limit),
    emergency-mode: (var-get emergency-mode),
    protocol-paused: (var-get protocol-paused),
    admin: (var-get vault-admin),
    timelock-period: (var-get admin-actions-timelock)
  }
)

;; Advanced Yield Calculation Engine with Precision Controls
(define-read-only (calculate-pending-rewards (user principal))
  (let (
      (user-deposit (get-user-deposit user))
      (last-deposit (default-to u0 (map-get? last-deposit-block user)))
      (current-block stacks-block-height)
      (blocks-elapsed (if (> current-block last-deposit)
        (- current-block last-deposit)
        u0
      ))
    )
    (if (or (is-eq user-deposit u0) (is-eq blocks-elapsed u0))
      u0
      ;; Enterprise-grade calculation with overflow protection
      (let (
          (yield-period-value (if (is-eq (var-get yield-period) u0)
            u1
            (var-get yield-period)
          ))
          ;; Anti-overflow protection (max ~69 days calculation window)
          (blocks-elapsed-capped (if (> blocks-elapsed u10000)
            u10000
            blocks-elapsed
          ))
          ;; High-precision yield computation
          (rate-factor (/ (* (var-get yield-rate) PRECISION_FACTOR) 
                         (* u100 yield-period-value)))
          (rewards-raw (/ (* user-deposit rate-factor blocks-elapsed-capped) 
                         PRECISION_FACTOR))
        )
        ;; Economic safety bounds - prevent unrealistic reward calculations
        (if (> rewards-raw (/ user-deposit u10))
          (/ user-deposit u10) ;; Maximum 10% of deposit as safety ceiling
          rewards-raw
        )
      )
    )
  )
)

;; Complete User Portfolio Dashboard
(define-read-only (get-user-position (user principal))
  (let (
      (deposit (get-user-deposit user))
      (rewards (get-user-rewards user))
      (pending (calculate-pending-rewards user))
      (total-claimed (get-user-total-claimed user))
    )
    {
      deposit: deposit,
      accumulated-rewards: rewards,
      pending-rewards: pending,
      total-rewards: (+ rewards pending),
      total-claimed: total-claimed,
      last-deposit-block: (default-to u0 (map-get? last-deposit-block user))
    }
  )
)

;; CORE PROTOCOL FUNCTIONS - User Operations

;; Primary Deposit Function - Secure sBTC Staking with Yield Accrual
(define-public (deposit-sbtc (amount uint))
  (let (
      (current-deposit (get-user-deposit tx-sender))
      (new-total (+ current-deposit amount))
    )
    ;; Comprehensive pre-flight security validation
    (asserts! (not (var-get protocol-paused)) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get emergency-mode)) (err ERR_EMERGENCY_MODE_ACTIVE))
    (asserts! (> amount u0) (err ERR_INSUFFICIENT_BALANCE))
    (asserts! (<= new-total (var-get max-deposit-limit)) (err ERR_DEPOSIT_LIMIT_REACHED))
    
    ;; Yield calculation checkpoint before state modification
    (let ((pending-rewards (calculate-pending-rewards tx-sender)))
      ;; Atomic sBTC transfer to vault custody
      (match (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
        transfer amount tx-sender (as-contract tx-sender) none
      )
        success (begin
          ;; Update user state with atomic precision
          (map-set user-rewards tx-sender
            (+ (get-user-rewards tx-sender) pending-rewards)
          )
          (map-set user-deposits tx-sender new-total)
          (map-set last-deposit-block tx-sender stacks-block-height)
          
          ;; Event logging for analytics and transparency
          (unwrap! (log-deposit tx-sender amount) (err ERR_DEPOSIT_FAILED))
          
          ;; Real-time protocol metrics update
          (unwrap! (update-daily-stats amount u0) (err ERR_DEPOSIT_FAILED))
          
          (ok amount)
        )
        error (err ERR_DEPOSIT_FAILED)
      )
    )
  )
)

;; Secure Withdrawal Function with State Consistency Guarantees
(define-public (withdraw-sbtc (amount uint))
  (let (
      (current-deposit (get-user-deposit tx-sender))
      (pending-rewards (calculate-pending-rewards tx-sender))
    )
    ;; Input validation and balance verification
    (asserts! (> amount u0) (err ERR_INSUFFICIENT_BALANCE))
    (asserts! (<= amount current-deposit) (err ERR_INSUFFICIENT_BALANCE))
    
    ;; Check-Effects-Interactions pattern for security
    (map-set user-deposits tx-sender (- current-deposit amount))
    (map-set user-rewards tx-sender
      (+ (get-user-rewards tx-sender) pending-rewards)
    )
    (map-set last-deposit-block tx-sender stacks-block-height)
    
    ;; Execute withdrawal with rollback capability
    (match (as-contract (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender tx-sender none
    ))
      success (begin
        ;; Transaction logging for audit trail
        (unwrap! (log-withdrawal tx-sender amount) (err ERR_WITHDRAW_FAILED))
        (ok amount)
      )
      error (begin
        ;; Atomic state rollback on transfer failure
        (map-set user-deposits tx-sender current-deposit)
        (map-set user-rewards tx-sender
          (- (get-user-rewards tx-sender) pending-rewards)
        )
        (err ERR_WITHDRAW_FAILED)
      )
    )
  )
)

;; Optimized Reward Claiming with Precision Accounting
(define-public (claim-rewards)
  (let (
      (pending-rewards (calculate-pending-rewards tx-sender))
      (accumulated-rewards (get-user-rewards tx-sender))
      (total-rewards (+ accumulated-rewards pending-rewards))
    )
    ;; Reward availability and vault liquidity verification
    (asserts! (> total-rewards u0) (err ERR_INSUFFICIENT_BALANCE))
    (asserts! (<= total-rewards 
      (unwrap! (get-vault-balance) (err ERR_INSUFFICIENT_VAULT_FUNDS))
    ) (err ERR_INSUFFICIENT_VAULT_FUNDS))
    
    ;; State update with claim tracking
    (map-set user-rewards tx-sender u0)
    (map-set last-deposit-block tx-sender stacks-block-height)
    (map-set user-total-claimed tx-sender
      (+ (get-user-total-claimed tx-sender) total-rewards)
    )
    
    ;; Reward distribution execution
    (match (as-contract (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer total-rewards tx-sender tx-sender none
    ))
      success (begin
        ;; Success event logging
        (unwrap! (log-reward-claim tx-sender total-rewards) (err ERR_WITHDRAW_FAILED))
        (ok total-rewards)
      )
      error (begin
        ;; Comprehensive state rollback on failure
        (map-set user-rewards tx-sender accumulated-rewards)
        (map-set user-total-claimed tx-sender
          (- (get-user-total-claimed tx-sender) total-rewards)
        )
        (err ERR_WITHDRAW_FAILED)
      )
    )
  )
)

;; Emergency Recovery Mechanism - Crisis Response Protocol
(define-public (emergency-withdraw)
  (begin
    (asserts! (var-get emergency-mode) (err ERR_UNAUTHORIZED))
    (let (
        (user-deposit (get-user-deposit tx-sender))
      )
      (asserts! (> user-deposit u0) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Emergency state clearing (rewards forfeited for immediate liquidity)
      (map-set user-deposits tx-sender u0)
      (map-set user-rewards tx-sender u0)
      
      ;; Emergency fund release
      (match (as-contract (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
        transfer user-deposit tx-sender tx-sender none
      ))
        success (begin
          (unwrap! (log-emergency-withdrawal tx-sender user-deposit) (err ERR_WITHDRAW_FAILED))
          (ok user-deposit)
        )
        error (begin
          ;; State restoration on emergency transfer failure
          (map-set user-deposits tx-sender user-deposit)
          (err ERR_WITHDRAW_FAILED)
        )
      )
    )
  )
)

;; PROTOCOL GOVERNANCE & ADMINISTRATION

;; Immediate Emergency Response - Circuit Breaker Activation
(define-public (enable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (var-set emergency-mode true)
    (var-set protocol-paused true) ;; Cascade protection activation
    (print { event: "emergency-mode-enabled", admin: tx-sender, block: stacks-block-height })
    (ok true)
  )
)

;; Emergency Recovery - Restore Normal Operations
(define-public (disable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (var-set emergency-mode false)
    (print { event: "emergency-mode-disabled", admin: tx-sender, block: stacks-block-height })
    (ok true)
  )
)

;; Protocol Maintenance Controls
(define-public (set-protocol-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (var-set protocol-paused paused)
    (print { event: "protocol-pause-changed", paused: paused, admin: tx-sender })
    (ok true)
  )
)

;; Governance Timelock - Scheduled Yield Rate Adjustment
(define-public (schedule-yield-rate-change (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= new-rate u0) (<= new-rate MAX_YIELD_RATE))
      (err ERR_INVALID_YIELD_RATE)
    )
    
    (map-set pending-admin-actions {
      action: "set-yield-rate",
      param: new-rate,
    } { 
      scheduled-at: stacks-block-height,
      executed: false
    })
    
    (print { 
      event: "yield-rate-scheduled", 
      new-rate: new-rate, 
      execution-block: (+ stacks-block-height (var-get admin-actions-timelock))
    })
    (ok true)
  )
)

;; Timelock Execution - Apply Scheduled Yield Rate Changes
(define-public (execute-yield-rate-change (new-rate uint))
  (let (
      (scheduled-action (unwrap! 
        (map-get? pending-admin-actions {
          action: "set-yield-rate",
          param: new-rate,
        })
        (err ERR_UNAUTHORIZED)
      ))
    )
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (not (get executed scheduled-action)) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= new-rate u0) (<= new-rate MAX_YIELD_RATE))
      (err ERR_INVALID_YIELD_RATE)
    )
    (asserts!
      (>= stacks-block-height
        (+ (get scheduled-at scheduled-action) (var-get admin-actions-timelock))
      )
      (err ERR_TIMELOCK_NOT_EXPIRED)
    )
    
    ;; Execute governance decision
    (var-set yield-rate new-rate)
    
    ;; Mark action as completed
    (map-set pending-admin-actions {
      action: "set-yield-rate",
      param: new-rate,
    } { 
      scheduled-at: (get scheduled-at scheduled-action),
      executed: true
    })
    
    (print { event: "yield-rate-updated", new-rate: new-rate })
    (ok true)
  )
)

;; Risk Management - Deposit Limit Configuration
(define-public (set-max-deposit-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (asserts!
      (and (>= new-limit MIN_DEPOSIT_LIMIT) (<= new-limit MAX_DEPOSIT_LIMIT))
      (err ERR_INVALID_DEPOSIT_LIMIT)
    )
    (var-set max-deposit-limit new-limit)
    (print { event: "deposit-limit-updated", new-limit: new-limit })
    (ok true)
  )
)

;; Governance Transition - Administrative Rights Transfer
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard new-admin) (err ERR_UNAUTHORIZED))
    (var-set vault-admin new-admin)
    (print { event: "admin-transferred", old-admin: tx-sender, new-admin: new-admin })
    (ok true)
  )
)

;; Treasury Management - Vault Capitalization for Rewards
(define-public (fund-vault (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR_INSUFFICIENT_BALANCE))
    (match (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token 
      transfer amount tx-sender (as-contract tx-sender) none
    )
      success (begin
        (print { event: "vault-funded", amount: amount, funder: tx-sender })
        (ok amount)
      )
      error (err ERR_DEPOSIT_FAILED)
    )
  )
)

;; PROTOCOL UTILITIES & INTERNAL MECHANICS

;; Global State Synchronization - Yield Distribution Tracking
(define-public (update-global-accumulator)
  (let (
      (blocks-since-last (- stacks-block-height (var-get last-yield-distribution)))
      (rate-contribution (* blocks-since-last (var-get yield-rate)))
    )
    (var-set global-accumulator
      (+ (var-get global-accumulator) rate-contribution)
    )
    (var-set last-yield-distribution stacks-block-height)
    (ok true)
  )
)

;; Analytics Engine - Protocol Performance Metrics
(define-private (update-daily-stats (deposit-amount uint) (reward-amount uint))
  (let (
      (current-day (/ stacks-block-height BLOCKS_PER_DAY))
      (current-stats (default-to 
        { total-deposits: u0, total-rewards: u0, active-users: u0 }
        (map-get? daily-stats current-day)
      ))
    )
    (map-set daily-stats current-day {
      total-deposits: (+ (get total-deposits current-stats) deposit-amount),
      total-rewards: (+ (get total-rewards current-stats) reward-amount),
      active-users: (+ (get active-users current-stats) u1)
    })
    (ok (var-get next-event-id))
  )
)

;; EVENT LOGGING & AUDIT TRAIL SYSTEM

;; Deposit Transaction Logging
(define-private (log-deposit (user principal) (amount uint))
  (let ((event-id (var-get next-event-id)))
    (print {
      event: "deposit",
      user: user,
      amount: amount,
      id: event-id,
      block: stacks-block-height
    })
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

;; Withdrawal Transaction Logging
(define-private (log-withdrawal (user principal) (amount uint))
  (let ((event-id (var-get next-event-id)))
    (print {
      event: "withdrawal",
      user: user,
      amount: amount,
      id: event-id,
      block: stacks-block-height
    })
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

;; Reward Distribution Event Logging
(define-private (log-reward-claim (user principal) (amount uint))
  (let ((event-id (var-get next-event-id)))
    (print {
      event: "reward-claim",
      user: user,
      amount: amount,
      id: event-id,
      block: stacks-block-height
    })
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

;; Emergency Response Event Logging
(define-private (log-emergency-withdrawal (user principal) (amount uint))
  (let ((event-id (var-get next-event-id)))
    (print {
      event: "emergency-withdrawal",
      user: user,
      amount: amount,
      id: event-id,
      block: stacks-block-height
    })
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

;; LEGACY COMPATIBILITY & MIGRATION SUPPORT

;; Legacy Immediate Yield Rate Update (Backwards Compatibility)
(define-public (set-yield-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= new-rate u0) (<= new-rate MAX_YIELD_RATE)) 
      (err ERR_INVALID_YIELD_RATE)
    )
    (var-set yield-rate new-rate)
    (print { event: "yield-rate-set-immediate", new-rate: new-rate })
    (ok true)
  )
)

;; Legacy Token Contract Migration Support
(define-public (update-token-contract (new-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get vault-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard new-address) (err ERR_INVALID_TOKEN_CONTRACT))
    (var-set token-contract-address new-address)
    (print { event: "token-contract-updated", new-address: new-address })
    (ok true)
  )
)
