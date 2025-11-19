;; ComicCoin - Micropayment Service for Webcomic Artists
;; Built on STX Blockchain with Clarity

;; Define the ComicCoin fungible token
(define-fungible-token comic-coin)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u2) ;; 2% platform fee
(define-data-var total-earnings uint u0)

;; Data Maps
(define-map artist-profiles
  { artist: principal }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    total-earned: uint,
    is-active: bool
  }
)

(define-map comic-series
  { series-id: uint }
  {
    artist: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    price-per-episode: uint,
    total-sales: uint,
    created-at: uint
  }
)

(define-map episode-purchases
  { reader: principal, series-id: uint, episode-num: uint }
  {
    purchased-at: uint,
    amount-paid: uint
  }
)

(define-data-var next-series-id uint u0)

;; Error Codes
(define-constant ERR-NOT-OWNER (err u1))
(define-constant ERR-NOT-ARTIST (err u2))
(define-constant ERR-SERIES-NOT-FOUND (err u3))
(define-constant ERR-INSUFFICIENT-BALANCE (err u4))
(define-constant ERR-ARTIST-INACTIVE (err u5))
(define-constant ERR-ALREADY-PURCHASED (err u6))
(define-constant ERR-INVALID-PRICE (err u7))
(define-constant ERR-UNAUTHORIZED (err u8))

;; Initialize artist profile
(define-public (register-artist (name (string-ascii 100)) (description (string-ascii 500)))
  (begin
    (map-set artist-profiles
      { artist: tx-sender }
      {
        name: name,
        description: description,
        total-earned: u0,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Update artist profile
(define-public (update-artist-profile (name (string-ascii 100)) (description (string-ascii 500)))
  (let ((artist-data (map-get? artist-profiles { artist: tx-sender })))
    (if (is-none artist-data)
      ERR-NOT-ARTIST
      (begin
        (map-set artist-profiles
          { artist: tx-sender }
          {
            name: name,
            description: description,
            total-earned: (get total-earned (unwrap-panic artist-data)),
            is-active: (get is-active (unwrap-panic artist-data))
          }
        )
        (ok true)
      )
    )
  )
)

;; Create a new comic series
(define-public (create-series (title (string-ascii 100)) (description (string-ascii 500)) (price-per-episode uint))
  (let ((series-id (var-get next-series-id)) (artist-data (map-get? artist-profiles { artist: tx-sender })))
    (if (is-none artist-data)
      ERR-NOT-ARTIST
      (if (is-eq price-per-episode u0)
        ERR-INVALID-PRICE
        (begin
          (map-set comic-series
            { series-id: series-id }
            {
              artist: tx-sender,
              title: title,
              description: description,
              price-per-episode: price-per-episode,
              total-sales: u0,
              created-at: burn-block-height
            }
          )
          (var-set next-series-id (+ series-id u1))
          (ok series-id)
        )
      )
    )
  )
)

;; Update series price
(define-public (update-series-price (series-id uint) (new-price uint))
  (let ((series (map-get? comic-series { series-id: series-id })))
    (if (is-none series)
      ERR-SERIES-NOT-FOUND
      (if (not (is-eq (get artist (unwrap-panic series)) tx-sender))
        ERR-UNAUTHORIZED
                  (if (is-eq new-price u0)
          ERR-INVALID-PRICE
          (begin
            (map-set comic-series
              { series-id: series-id }
              (merge (unwrap-panic series) { price-per-episode: new-price })
            )
            (ok true)
          )
        )
      )
    )
  )
)

;; Purchase an episode
(define-public (purchase-episode (series-id uint) (episode-num uint) (amount uint))
  (let (
    (series (map-get? comic-series { series-id: series-id }))
    (existing-purchase (map-get? episode-purchases { reader: tx-sender, series-id: series-id, episode-num: episode-num }))
    (artist (if (is-some series) (get artist (unwrap-panic series)) tx-sender))
    (price (if (is-some series) (get price-per-episode (unwrap-panic series)) u0))
  )
    (if (is-none series)
      ERR-SERIES-NOT-FOUND
      (if (not (is-none existing-purchase))
        ERR-ALREADY-PURCHASED
        (if (< amount price)
          ERR-INSUFFICIENT-BALANCE
          (begin
            ;; Calculate platform fee and artist earnings
            (let ((fee (/ (* amount (var-get platform-fee)) u100)) (artist-earnings (- amount fee)))
              ;; Record purchase
              (map-set episode-purchases
                { reader: tx-sender, series-id: series-id, episode-num: episode-num }
                { purchased-at: burn-block-height, amount-paid: amount }
              )
              ;; Update series total sales
              (map-set comic-series
                { series-id: series-id }
                (merge (unwrap-panic series) { total-sales: (+ (get total-sales (unwrap-panic series)) u1) })
              )
              ;; Update artist earnings
              (let ((artist-data (map-get? artist-profiles { artist: artist })))
                (if (is-some artist-data)
                  (map-set artist-profiles
                    { artist: artist }
                    (merge (unwrap-panic artist-data) { total-earned: (+ (get total-earned (unwrap-panic artist-data)) artist-earnings) })
                  )
                  true
                )
              )
              ;; Update total platform earnings
              (var-set total-earnings (+ (var-get total-earnings) fee))
              ;; Transfer ComicCoins
              (try! (ft-transfer? comic-coin amount tx-sender artist))
              (ok true)
            )
          )
        )
      )
    )
  )
)

;; Mint ComicCoins (admin only)
(define-public (mint (amount uint) (recipient principal))
  (if (not (is-eq tx-sender (var-get contract-owner)))
    ERR-NOT-OWNER
    (begin
      (try! (ft-mint? comic-coin amount recipient))
      (ok true)
    )
  )
)

;; Burn ComicCoins
(define-public (burn (amount uint))
  (ft-burn? comic-coin amount tx-sender)
)

;; Get artist profile
(define-read-only (get-artist (artist principal))
  (map-get? artist-profiles { artist: artist })
)

;; Get comic series details
(define-read-only (get-series (series-id uint))
  (map-get? comic-series { series-id: series-id })
)

;; Check if episode was purchased
(define-read-only (has-purchased (reader principal) (series-id uint) (episode-num uint))
  (is-some (map-get? episode-purchases { reader: reader, series-id: series-id, episode-num: episode-num }))
)

;; Get account balance
(define-read-only (get-balance (account principal))
  (ft-get-balance comic-coin account)
)

;; Get total ComicCoin supply
(define-read-only (get-total-supply)
  (ft-get-supply comic-coin)
)

;; Get contract info
(define-read-only (get-contract-info)
  {
    owner: (var-get contract-owner),
    platform-fee: (var-get platform-fee),
    total-earnings: (var-get total-earnings),
    next-series-id: (var-get next-series-id)
  }
)

;; Update platform fee (admin only)
(define-public (set-platform-fee (new-fee uint))
  (if (not (is-eq tx-sender (var-get contract-owner)))
    ERR-NOT-OWNER
    (if (> new-fee u100)
      ERR-INVALID-PRICE
      (begin
        (var-set platform-fee new-fee)
        (ok true)
      )
    )
  )
)